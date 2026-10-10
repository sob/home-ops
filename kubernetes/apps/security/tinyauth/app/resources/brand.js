// Swaps Tinyauth's generic OAuth icon for provider logos on the login page.
// Tinyauth picks icons from a hard-coded map by provider id; until upstream
// has plex/apple, this matches buttons by their visible name instead.
// Purely cosmetic: if the markup changes, the buttons keep the generic icon.
(function () {
  "use strict";
  var NS = "http://www.w3.org/2000/svg";
  var ICONS = {
    // Simple Icons "apple" (CC0). currentColor follows light/dark mode.
    Apple: {
      viewBox: "0 0 24 24",
      paths: [["currentColor", "M12.152 6.896c-.948 0-2.415-1.078-3.96-1.04-2.04.027-3.91 1.183-4.961 3.014-2.117 3.675-.546 9.103 1.519 12.09 1.013 1.454 2.208 3.09 3.792 3.039 1.52-.065 2.09-.987 3.935-.987 1.831 0 2.35.987 3.96.948 1.637-.026 2.676-1.48 3.676-2.948 1.156-1.688 1.636-3.325 1.662-3.415-.039-.013-3.182-1.221-3.22-4.857-.026-3.04 2.48-4.494 2.597-4.559-1.429-2.09-3.623-2.324-4.39-2.376-2-.156-3.675 1.09-4.61 1.09zM15.53 3.83c.843-1.012 1.4-2.427 1.245-3.83-1.207.052-2.662.805-3.532 1.818-.78.896-1.454 2.338-1.273 3.714 1.338.104 2.715-.688 3.559-1.701"]]
    },
    // Plex chevron in Plex orange (geometric; the wordmark is too wide here).
    Plex: {
      viewBox: "0 0 24 24",
      paths: [["#E5A00D", "M5 2h6.5l8 10-8 10H5l8-10z"]]
    },
    // Google "G", same paths as Tinyauth's built-in Google icon.
    Google: {
      viewBox: "0 0 256 262",
      paths: [
        ["#4285f4", "M255.878 133.451c0-10.734-.871-18.567-2.756-26.69H130.55v48.448h71.947c-1.45 12.04-9.283 30.172-26.69 42.356l-.244 1.622l38.755 30.023l2.685.268c24.659-22.774 38.875-56.282 38.875-96.027"],
        ["#34a853", "M130.55 261.1c35.248 0 64.839-11.605 86.453-31.622l-41.196-31.913c-11.024 7.688-25.82 13.055-45.257 13.055c-34.523 0-63.824-22.773-74.269-54.25l-1.531.13l-40.298 31.187l-.527 1.465C35.393 231.798 79.49 261.1 130.55 261.1"],
        ["#fbbc05", "M56.281 156.37c-2.756-8.123-4.351-16.827-4.351-25.82c0-8.994 1.595-17.697 4.206-25.82l-.073-1.73L15.26 71.312l-1.335.635C5.077 89.644 0 109.517 0 130.55s5.077 40.905 13.925 58.602z"],
        ["#eb4335", "M130.55 50.479c24.514 0 41.05 10.589 50.479 19.438l36.844-35.974C195.245 12.91 165.798 0 130.55 0C79.49 0 35.393 29.301 13.925 71.947l42.211 32.783c10.59-31.477 39.891-54.251 74.414-54.251"]
      ]
    }
  };

  function icon(def) {
    var svg = document.createElementNS(NS, "svg");
    svg.setAttribute("viewBox", def.viewBox);
    svg.setAttribute("aria-hidden", "true");
    svg.setAttribute("data-brand", "1");
    svg.style.width = "1rem";
    svg.style.height = "1rem";
    svg.style.flexShrink = "0";
    for (var i = 0; i < def.paths.length; i++) {
      var p = document.createElementNS(NS, "path");
      p.setAttribute("fill", def.paths[i][0]);
      p.setAttribute("d", def.paths[i][1]);
      svg.appendChild(p);
    }
    return svg;
  }

  function apply() {
    var buttons = document.querySelectorAll("button");
    for (var i = 0; i < buttons.length; i++) {
      var b = buttons[i];
      var def = ICONS[(b.textContent || "").trim()];
      if (!def) continue;
      var current = b.querySelector("svg");
      if (!current || current.getAttribute("data-brand") === "1") continue;
      current.replaceWith(icon(def));
    }
  }

  // --- App launcher -----------------------------------------------------
  // On the signed-in page (the one with a Logout button), list the apps this
  // user can open. For each app in apps.json, /_brand/can asks Tinyauth
  // whether this session would be let in to its host, so the launcher
  // follows Tinyauth's access rules exactly (break-glass included). Apps
  // marked "everyone" aren't behind Tinyauth and do their own sign-in. This
  // is a convenience, not a gate: each app still enforces its own access.
  var launcher = { state: "idle", data: null };

  function loadLauncher() {
    launcher.state = "loading";
    fetch("/_brand/apps.json", { credentials: "same-origin" }).then(function (r) {
      return r.json();
    }).then(function (catalogue) {
      return Promise.all(catalogue.apps.map(canOpen)).then(function (allowed) {
        return catalogue.apps.filter(function (a, i) { return allowed[i]; });
      });
    }).then(function (apps) {
      launcher.data = apps;
      launcher.state = "ready";
      placeLauncher();
    }).catch(function () { launcher.state = "failed"; });
  }

  function canOpen(app) {
    if (app.everyone) return Promise.resolve(true);
    var host;
    try { host = new URL(app.url).hostname; } catch (e) { return Promise.resolve(false); }
    return fetch("/_brand/can?host=" + encodeURIComponent(host), {
      credentials: "same-origin",
      cache: "no-store"
    }).then(function (r) { return r.ok; }, function () { return false; });
  }

  function logoutButton() {
    var buttons = document.querySelectorAll("button");
    for (var i = 0; i < buttons.length; i++) {
      if (/^log\s?out$/i.test((buttons[i].textContent || "").trim())) return buttons[i];
    }
    return null;
  }

  function buildLauncher(apps) {
    var wrap = document.createElement("nav");
    wrap.className = "ta-launcher";
    wrap.setAttribute("aria-label", "Your apps");
    for (var i = 0; i < apps.length; i++) {
      var a = document.createElement("a");
      a.className = "ta-app";
      a.href = apps[i].url;
      var img = document.createElement("img");
      img.src = apps[i].icon;
      img.alt = "";
      img.loading = "lazy";
      var label = document.createElement("span");
      label.textContent = apps[i].name;
      a.appendChild(img);
      a.appendChild(label);
      wrap.appendChild(a);
    }
    return wrap;
  }

  function placeLauncher() {
    var btn = logoutButton();
    if (!btn) return;
    if (document.querySelector(".ta-launcher")) return;
    if (launcher.state === "idle") return loadLauncher();
    if (launcher.state !== "ready" || !launcher.data.length) return;
    btn.parentNode.insertBefore(buildLauncher(launcher.data), btn);
  }

  // The signed-in page lives at /logout and is titled "Logout". Present it
  // as the app launcher instead: heading, tab title and address bar. The
  // URL change is cosmetic (replaceState): reloading "/" while signed in
  // lands here again, and the Logout button works as before.
  function retitle() {
    if (!logoutButton()) return;
    var nodes = document.querySelectorAll("h1, h2, h3, div, p");
    for (var i = 0; i < nodes.length; i++) {
      var n = nodes[i];
      if (n.children.length === 0 && !n.closest("button") &&
          /^log\s?out$/i.test((n.textContent || "").trim())) {
        n.textContent = "Your apps";
      }
    }
    if (document.title !== "56kbps.io") document.title = "56kbps.io";
    if (location.pathname === "/logout") history.replaceState(history.state, "", "/");
  }

  function tick() {
    apply();
    placeLauncher();
    retitle();
  }

  // React re-renders the buttons (loading states, navigation); re-apply.
  new MutationObserver(tick).observe(document.documentElement, { childList: true, subtree: true });
  tick();
})();
