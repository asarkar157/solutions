/**
 * Loads the module catalog from JSON (see assets/data/modules.json).
 * module-catalog.md must define window.__MODULES_JSON_URL__ (Liquid) before this script runs,
 * so paths respect Jekyll baseurl (e.g. /solutions/assets/data/modules.json on GitHub Pages).
 */
(function () {
  function emitReady() {
    try {
      document.dispatchEvent(
        new CustomEvent("modulesloaded", {
          detail: { count: (window.MODULES || []).length },
        })
      );
    } catch (e) {
      /* IE / very old browsers */
    }
  }

  /**
   * Run fn after MODULES is populated (immediately if already loaded).
   */
  window.onModulesReady = function (fn) {
    if (window.MODULES && Array.isArray(window.MODULES)) {
      try {
        fn();
      } catch (e) {
        console.error(e);
      }
      return;
    }
    document.addEventListener("modulesloaded", function once() {
      document.removeEventListener("modulesloaded", once);
      try {
        fn();
      } catch (e) {
        console.error(e);
      }
    });
  };

  var url = window.__MODULES_JSON_URL__;
  if (!url) {
    console.error(
      "[module-data] Set window.__MODULES_JSON_URL__ before loading module-data.js (see module-catalog.md)."
    );
    window.MODULES = [];
    emitReady();
    return;
  }

  fetch(url, { credentials: "same-origin" })
    .then(function (res) {
      if (!res.ok) {
        throw new Error("modules.json HTTP " + res.status);
      }
      return res.json();
    })
    .then(function (body) {
      window.MODULES = body.modules || [];
      emitReady();
    })
    .catch(function (err) {
      console.error("[module-data] Failed to load catalog JSON", err);
      window.MODULES = [];
      emitReady();
    });
})();
