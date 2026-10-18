// MetaMCP admin MCP server: MetaMCP's own management API (the tRPC API its
// web UI calls) as MCP tools, so an agent can manage MCP servers, namespaces
// and endpoints. It runs as a sidecar with the MetaMCP image, for its Node and
// its modules: the MCP SDK, zod, pg and MetaMCP's own request schemas.
//
// Callers send Authorization: Bearer $ADMIN_MCP_TOKEN. The token is separate
// from MetaMCP's API keys, which work on every endpoint of their owner and so
// can't be limited to this one. Treat it as an admin credential: a STDIO
// server runs any command in the MetaMCP container.
//
// tRPC only accepts a better-auth session cookie, so the sidecar keeps its
// own short-lived session for MetaMCP's first user, inserted into the
// sessions table and signed with BETTER_AUTH_SECRET as better-auth signs its
// cookies (HMAC-SHA256, base64). Calls go through MetaMCP's backend, so it
// checks inputs and ownership and restarts the affected servers itself.
//
// Left out: API key creation, the auth settings (the postgres container
// enforces those), OAuth clients and logs. Secret values (API keys, bearer
// tokens, header values, env values other than "${NAME}" placeholders) are
// redacted from every result.

import { createHash, createHmac, randomBytes, randomUUID, timingSafeEqual } from "node:crypto";
import { createServer } from "node:http";
import { createRequire } from "node:module";

const require = createRequire(process.env.MODULE_ROOT ?? "/app/apps/backend/package.json");
const { McpServer } = require("@modelcontextprotocol/sdk/server/mcp.js");
const { StreamableHTTPServerTransport } = require("@modelcontextprotocol/sdk/server/streamableHttp.js");
const { z } = require("zod");
const schemas = require("@repo/zod-types");
const pg = require("pg");

const PORT = Number(process.env.ADMIN_MCP_PORT ?? 12010);
const BACKEND = process.env.METAMCP_BACKEND_URL ?? "http://127.0.0.1:12009";
const USER_AGENT = "metamcp-admin-mcp";
const REDACTED = "<redacted>";

for (const name of ["ADMIN_MCP_TOKEN", "BETTER_AUTH_SECRET", "DATABASE_URL"]) {
  if (!process.env[name]) throw new Error(`${name} is not set`);
}
if (process.env.ADMIN_MCP_TOKEN.length < 32) throw new Error("ADMIN_MCP_TOKEN is shorter than 32 characters");
const tokenDigest = createHash("sha256").update(process.env.ADMIN_MCP_TOKEN).digest();
const db = new pg.Pool({ connectionString: process.env.DATABASE_URL, max: 2 });

// --- MetaMCP session ---------------------------------------------------------

let session; // { cookie, renewAt }
let renewing;

// A new session each hour; each one replaces the sidecar's previous sessions,
// so the database (and its dump in R2) holds at most one.
async function newSession() {
  const token = randomBytes(32).toString("base64url");
  const { rowCount } = await db.query(
    `WITH gone AS (DELETE FROM sessions WHERE user_agent = $3)
     INSERT INTO sessions (id, token, user_id, expires_at, user_agent)
     SELECT $1, $2, id, now() + interval '1 hour', $3 FROM users ORDER BY created_at LIMIT 1`,
    [randomUUID(), token, USER_AGENT],
  );
  if (rowCount !== 1) throw new Error("MetaMCP has no user yet: sign in to the web UI once first");
  const signature = createHmac("sha256", process.env.BETTER_AUTH_SECRET).update(token).digest("base64");
  const value = encodeURIComponent(`${token}.${signature}`);
  return {
    // The name depends on whether APP_URL is https; send both.
    cookie: `__Secure-better-auth.session_token=${value}; better-auth.session_token=${value}`,
    renewAt: Date.now() + 50 * 60 * 1000,
  };
}

async function sessionCookie(force) {
  if (!force && session && Date.now() < session.renewAt) return session.cookie;
  renewing ??= newSession().then(
    (s) => ((session = s), (renewing = undefined), s),
    (e) => ((renewing = undefined), Promise.reject(e)),
  );
  return (await renewing).cookie;
}

async function trpc(kind, path, input) {
  for (let attempt = 0; ; attempt++) {
    const headers = { cookie: await sessionCookie(attempt > 0) };
    let url = `${BACKEND}/trpc/frontend/frontend.${path}`;
    const init = { headers };
    if (kind === "query") {
      if (input !== undefined) url += `?input=${encodeURIComponent(JSON.stringify(input))}`;
    } else {
      init.method = "POST";
      headers["content-type"] = "application/json";
      init.body = JSON.stringify(input ?? {});
    }
    const res = await fetch(url, init);
    const body = await res.json().catch(() => ({}));
    if (res.status === 401 && attempt === 0) continue; // session gone: make a new one
    if (body.error) throw new Error(`${path}: ${body.error.message ?? JSON.stringify(body.error)}`);
    if (!res.ok) throw new Error(`${path}: HTTP ${res.status}`);
    return body.result?.data;
  }
}

// --- Redaction ---------------------------------------------------------------

const isPlaceholder = (v) => typeof v === "string" && /^\$\{[A-Za-z_][A-Za-z0-9_]*\}$/.test(v);
const SECRET_KEYS = new Set(["key", "bearerToken", "bearer_token", "client_secret", "access_token", "refresh_token", "tokens"]);

function redact(value, key) {
  if (Array.isArray(value)) return value.map((v) => redact(v));
  if (value && typeof value === "object") {
    if (key === "env" || key === "headers") {
      return Object.fromEntries(Object.entries(value).map(([k, v]) => [k, isPlaceholder(v) ? v : REDACTED]));
    }
    return Object.fromEntries(Object.entries(value).map(([k, v]) => [k, redact(v, k)]));
  }
  if (SECRET_KEYS.has(key) && value !== null && value !== undefined && value !== "") return REDACTED;
  return value;
}

// Fill in values a caller copied from a redacted result.
function unredact(next, current) {
  if (next === REDACTED) return current;
  if (next && typeof next === "object" && !Array.isArray(next)) {
    return Object.fromEntries(Object.entries(next).map(([k, v]) => [k, unredact(v, current?.[k])]));
  }
  return next;
}

// --- Tools -------------------------------------------------------------------

// MetaMCP's own request schemas, minus fields the tools set themselves.
function shape(schema, omit = []) {
  const base = schema.shape ? schema : schema._def.schema; // unwrap .refine()
  return Object.fromEntries(Object.entries(base.shape).filter(([k]) => !["user_id", ...omit].includes(k)));
}
const optional = (s) => Object.fromEntries(Object.entries(s).map(([k, v]) => [k, k === "uuid" ? v : v.optional()]));
const uuid = { uuid: z.string().describe("UUID, from the matching list_ tool") };

const tools = [
  // MCP servers
  ["list_servers", "List MCP servers.", {}, () => trpc("query", "mcpServers.list")],
  ["get_server", "Get an MCP server.", uuid, (i) => trpc("query", "mcpServers.get", i)],
  [
    "create_server",
    'Create an MCP server, private to the MetaMCP user. STDIO servers run "command args" in the MetaMCP container; ' +
      'pin package versions (e.g. "-y pkg@1.2.3"). For secrets, set env values to "${NAME}": MetaMCP fills them in from ' +
      "its own environment (the metamcp-secret Secret), so the values never reach its database. " +
      "Add the server to a namespace to serve it.",
    shape(schemas.CreateMcpServerRequestSchema),
    (i) => trpc("mutation", "mcpServers.create", i),
  ],
  [
    "update_server",
    "Change an MCP server. Fields left out keep their current values; env and headers replace the whole map, " +
      `and "${REDACTED}" keeps a value as it is.`,
    optional(shape(schemas.UpdateMcpServerRequestSchema)),
    async (i) => {
      const current = (await trpc("query", "mcpServers.get", { uuid: i.uuid }))?.data;
      if (!current) throw new Error(`no MCP server ${i.uuid}`);
      const input = { uuid: i.uuid };
      for (const f of ["name", "description", "type", "command", "args", "env", "url", "bearerToken", "headers"]) {
        const v = f in i ? unredact(i[f], current[f]) : current[f];
        if (v !== null && v !== undefined) input[f] = v;
      }
      return trpc("mutation", "mcpServers.update", input);
    },
  ],
  ["delete_server", "Delete an MCP server.", uuid, (i) => trpc("mutation", "mcpServers.delete", i)],
  [
    "list_server_tools",
    "List the tools MetaMCP has recorded for an MCP server.",
    shape(schemas.GetToolsByMcpServerUuidRequestSchema),
    (i) => trpc("query", "tools.getByMcpServerUuid", i),
  ],

  // Namespaces
  ["list_namespaces", "List namespaces (groups of MCP servers that endpoints serve).", {}, () => trpc("query", "namespaces.list")],
  ["get_namespace", "Get a namespace and its servers.", uuid, (i) => trpc("query", "namespaces.get", i)],
  ["create_namespace", "Create a namespace from MCP servers.", shape(schemas.CreateNamespaceRequestSchema), (i) => trpc("mutation", "namespaces.create", i)],
  [
    "update_namespace",
    "Change a namespace. mcpServerUuids replaces its whole server list.",
    shape(schemas.UpdateNamespaceRequestSchema),
    (i) => trpc("mutation", "namespaces.update", i),
  ],
  ["delete_namespace", "Delete a namespace.", uuid, (i) => trpc("mutation", "namespaces.delete", i)],
  [
    "list_namespace_tools",
    "List a namespace's tools and whether each is on.",
    shape(schemas.GetNamespaceToolsRequestSchema),
    (i) => trpc("query", "namespaces.getTools", i),
  ],
  [
    "set_namespace_server_status",
    "Turn an MCP server on or off within a namespace.",
    shape(schemas.UpdateNamespaceServerStatusRequestSchema),
    (i) => trpc("mutation", "namespaces.updateServerStatus", i),
  ],
  [
    "set_namespace_tool_status",
    "Turn a tool on or off within a namespace.",
    shape(schemas.UpdateNamespaceToolStatusRequestSchema),
    (i) => trpc("mutation", "namespaces.updateToolStatus", i),
  ],
  [
    "set_namespace_tool_overrides",
    "Rename a tool or change its title, description or annotations within a namespace.",
    shape(schemas.UpdateNamespaceToolOverridesRequestSchema),
    (i) => trpc("mutation", "namespaces.updateToolOverrides", i),
  ],

  // Endpoints
  ["list_endpoints", "List endpoints (the URLs that serve a namespace: /metamcp/<name>/mcp).", {}, () => trpc("query", "endpoints.list")],
  ["get_endpoint", "Get an endpoint.", uuid, (i) => trpc("query", "endpoints.get", i)],
  [
    "create_endpoint",
    "Create an endpoint at /metamcp/<name>/mcp serving a namespace. It needs API key or OAuth auth " +
      "(MetaMCP's database refuses one with neither); any of the user's API keys works on it.",
    shape(schemas.CreateEndpointRequestSchema, ["useQueryParamAuth", "createMcpServer"]),
    // createMcpServer would add the endpoint to MetaMCP as a server of its own,
    // with a new API key.
    (i) => trpc("mutation", "endpoints.create", { ...i, useQueryParamAuth: false, createMcpServer: false }),
  ],
  [
    "update_endpoint",
    "Change an endpoint. Fields left out keep their current values.",
    optional(shape(schemas.UpdateEndpointRequestSchema, ["useQueryParamAuth"])),
    async (i) => {
      const current = (await trpc("query", "endpoints.get", { uuid: i.uuid }))?.data;
      if (!current) throw new Error(`no endpoint ${i.uuid}`);
      return trpc("mutation", "endpoints.update", {
        uuid: i.uuid,
        name: i.name ?? current.name,
        description: i.description ?? current.description ?? undefined,
        namespaceUuid: i.namespaceUuid ?? current.namespace_uuid ?? current.namespace?.uuid,
        enableApiKeyAuth: i.enableApiKeyAuth ?? current.enable_api_key_auth,
        enableOauth: i.enableOauth ?? current.enable_oauth,
        useQueryParamAuth: false,
      });
    },
  ],
  ["delete_endpoint", "Delete an endpoint.", uuid, (i) => trpc("mutation", "endpoints.delete", i)],

  // API keys: listing and deleting only.
  ["list_api_keys", "List API keys (names and UUIDs; the keys themselves are redacted).", {}, () => trpc("query", "apiKeys.list")],
  ["delete_api_key", "Delete an API key.", shape(schemas.DeleteApiKeyRequestSchema), (i) => trpc("mutation", "apiKeys.delete", i)],
];

function newMcpServer() {
  const server = new McpServer({ name: "metamcp-admin", version: "1.0.0" });
  for (const [name, description, inputSchema, run] of tools) {
    server.registerTool(name, { description, inputSchema }, async (input) => {
      try {
        const result = redact(await run(input));
        return { content: [{ type: "text", text: JSON.stringify(result ?? null, null, 2) }] };
      } catch (e) {
        return { isError: true, content: [{ type: "text", text: String(e?.message ?? e) }] };
      }
    });
  }
  return server;
}

// --- HTTP --------------------------------------------------------------------

function authorized(req) {
  const m = /^Bearer (.+)$/.exec(req.headers.authorization ?? "");
  return !!m && timingSafeEqual(createHash("sha256").update(m[1]).digest(), tokenDigest);
}

function reply(res, status, body) {
  res.writeHead(status, { "content-type": "application/json" }).end(JSON.stringify(body));
}

async function readJson(req) {
  let size = 0;
  const chunks = [];
  for await (const chunk of req) {
    if ((size += chunk.length) > 1 << 20) throw new Error("request body over 1 MiB");
    chunks.push(chunk);
  }
  return JSON.parse(Buffer.concat(chunks).toString("utf8"));
}

createServer(async (req, res) => {
  const path = new URL(req.url, "http://localhost").pathname;
  if (path === "/healthz") return reply(res, 200, { ok: true });
  if (path !== "/admin/mcp") return reply(res, 404, { error: "not_found" });
  if (!authorized(req)) {
    res.setHeader("www-authenticate", 'Bearer realm="metamcp-admin"');
    return reply(res, 401, { error: "unauthorized" });
  }
  // Stateless: a new MCP server and transport per request, no sessions.
  if (req.method !== "POST") {
    return reply(res, 405, { jsonrpc: "2.0", error: { code: -32000, message: "Method not allowed" }, id: null });
  }
  let body;
  try {
    body = await readJson(req);
  } catch (e) {
    return reply(res, 400, { jsonrpc: "2.0", error: { code: -32700, message: String(e.message) }, id: null });
  }
  const server = newMcpServer();
  const transport = new StreamableHTTPServerTransport({ sessionIdGenerator: undefined, enableJsonResponse: true });
  res.on("close", () => {
    transport.close();
    server.close();
  });
  try {
    await server.connect(transport);
    await transport.handleRequest(req, res, body);
  } catch (e) {
    console.error("request failed:", e);
    if (!res.headersSent) reply(res, 500, { jsonrpc: "2.0", error: { code: -32603, message: "Internal error" }, id: null });
  }
}).listen(PORT, () => console.log(`metamcp-admin MCP listening on :${PORT}/admin/mcp`));

for (const signal of ["SIGTERM", "SIGINT"]) process.on(signal, () => process.exit(0));
