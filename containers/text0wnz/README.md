# text0wnz with Server-Side Storage

Custom build of [xero/text0wnz](https://github.com/xero/text0wnz) ANSI art editor with server-side file storage.

## Changes from Upstream

1. **Removed Caddy** - Runs on port 3000 with plain HTTP (SSL handled by ingress)
2. **Added File Management API** - REST endpoints for server-side file storage
3. **Storage Adapter** - Frontend uses server storage instead of localStorage
4. **Persistent Storage** - Files saved to `/art` volume

## API Endpoints

- `GET /api/files` - List all saved files
- `GET /api/files/:filename` - Load a specific file
- `POST /api/files/:filename` - Save a file (JSON body: `{content: "..."}`)
- `DELETE /api/files/:filename` - Delete a file

## Environment Variables

All configuration can be overridden at runtime:

| Variable | Description | Default |
|----------|-------------|---------|
| `NODE_ENV` | Node environment | `production` |
| `TZ` | Timezone (e.g., America/Chicago) | `UTC` |
| `PORT` | HTTP server port | `3000` |
| `SAVE_INTERVAL` | WebSocket session autosave interval (ms) | `30000` |
| `FILES_DIR` | Directory for art file storage | `/art` |
| `DEBUG` | Enable debug logging | `false` |

## Build

```bash
podman build --platform linux/amd64 -t ghcr.io/sob/text0wnz:latest .
```

## Run

```bash
# Basic run
podman run -d \
  -p 3000:3000 \
  -v ./art:/art \
  ghcr.io/sob/text0wnz:latest

# With custom environment variables
podman run -d \
  -p 3000:3000 \
  -v ./art:/art \
  -e TZ=America/Chicago \
  -e DEBUG=true \
  -e FILES_DIR=/art \
  ghcr.io/sob/text0wnz:latest
```

## Integration with Enigma-BBS

This container is designed to run as a sidecar in the enigma-bbs pod,
sharing the `/art` volume for seamless ANSI art integration.
