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
      color: "currentColor",
      path: "M12.152 6.896c-.948 0-2.415-1.078-3.96-1.04-2.04.027-3.91 1.183-4.961 3.014-2.117 3.675-.546 9.103 1.519 12.09 1.013 1.454 2.208 3.09 3.792 3.039 1.52-.065 2.09-.987 3.935-.987 1.831 0 2.35.987 3.96.948 1.637-.026 2.676-1.48 3.676-2.948 1.156-1.688 1.636-3.325 1.662-3.415-.039-.013-3.182-1.221-3.22-4.857-.026-3.04 2.48-4.494 2.597-4.559-1.429-2.09-3.623-2.324-4.39-2.376-2-.156-3.675 1.09-4.61 1.09zM15.53 3.83c.843-1.012 1.4-2.427 1.245-3.83-1.207.052-2.662.805-3.532 1.818-.78.896-1.454 2.338-1.273 3.714 1.338.104 2.715-.688 3.559-1.701"
    },
    // Plex chevron in Plex orange (geometric; the wordmark is too wide here).
    Plex: {
      color: "#E5A00D",
      path: "M5 2h6.5l8 10-8 10H5l8-10z"
    }
  };

  function icon(def) {
    var svg = document.createElementNS(NS, "svg");
    svg.setAttribute("viewBox", "0 0 24 24");
    svg.setAttribute("aria-hidden", "true");
    svg.setAttribute("data-brand", "1");
    svg.style.width = "1rem";
    svg.style.height = "1rem";
    svg.style.flexShrink = "0";
    var p = document.createElementNS(NS, "path");
    p.setAttribute("d", def.path);
    p.setAttribute("fill", def.color);
    svg.appendChild(p);
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

  // React re-renders the buttons (loading states, navigation); re-apply.
  new MutationObserver(apply).observe(document.documentElement, { childList: true, subtree: true });
  apply();
})();
