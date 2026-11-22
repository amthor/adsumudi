// Color scheme: "auto" (follow the device), "light" or "dark", chosen with the
// switch in the masthead and kept per browser in localStorage.
//
// Unlike the other files this is a classic script, loaded synchronously in
// <head>: it sets <html data-theme="light|dark"> before the first paint, so the
// page never flashes in the wrong colors. style.css only knows those two values.

(() => {
  const STORAGE_KEY = "adsumudi.theme.v1";
  const CHOICES = ["auto", "light", "dark"];
  const systemDark = matchMedia("(prefers-color-scheme: dark)");

  function load() {
    try {
      const value = localStorage.getItem(STORAGE_KEY);
      return CHOICES.includes(value) ? value : "auto";
    } catch {
      return "auto";
    }
  }

  function save(value) {
    try {
      if (value === "auto") localStorage.removeItem(STORAGE_KEY);
      else localStorage.setItem(STORAGE_KEY, value);
    } catch {
      // Without storage the choice lasts until the page is reloaded.
    }
  }

  let choice = load();

  function apply() {
    const dark = choice === "dark" || (choice === "auto" && systemDark.matches);
    document.documentElement.dataset.theme = dark ? "dark" : "light";
  }

  apply();
  // "auto" follows a change of the device setting while the page is open.
  systemDark.addEventListener("change", apply);

  document.addEventListener("DOMContentLoaded", () => {
    for (const input of document.querySelectorAll('input[name="theme"]')) {
      input.checked = input.value === choice;
      input.addEventListener("change", () => {
        choice = input.value;
        save(choice);
        apply();
      });
    }
  });
})();
