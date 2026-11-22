// History of generated sheets, kept only in this browser (localStorage).
//
// A sheet code plus the title is enough to rebuild a sheet exactly, so an
// entry stores just that and a little display text. Storage can be missing
// or blocked (private mode, disabled site data); then the history only lives
// for the current page view.

const STORAGE_KEY = "adsumudi.history.v1";
const MAX_ENTRIES = 20;

const dateFormat = new Intl.DateTimeFormat("de-DE", {
  day: "2-digit",
  month: "2-digit",
  year: "numeric",
  hour: "2-digit",
  minute: "2-digit",
});

function readStorage() {
  try {
    const entries = JSON.parse(localStorage.getItem(STORAGE_KEY) ?? "[]");
    return Array.isArray(entries) ? entries : [];
  } catch {
    return [];
  }
}

function writeStorage(entries) {
  try {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(entries));
  } catch {
    // Not persisted; the in-memory list still works.
  }
}

export function createHistory() {
  let entries = readStorage();

  return {
    entries: () => entries,

    /** Adds a generated sheet at the top; the same code and title only once. */
    add(sheet) {
      const entry = {
        code: sheet.code,
        title: sheet.title,
        description: sheet.description,
        count: sheet.count,
        date: new Date().toISOString(),
      };
      entries = [entry, ...entries.filter((e) => e.code !== entry.code || e.title !== entry.title)].slice(
        0,
        MAX_ENTRIES,
      );
      writeStorage(entries);
    },

    clear() {
      entries = [];
      writeStorage(entries);
    },
  };
}

function button(text, onClick) {
  const element = document.createElement("button");
  element.type = "button";
  element.className = "small-button";
  element.textContent = text;
  element.addEventListener("click", onClick);
  return element;
}

/**
 * Renders the entries into a list element.
 * @param onRepeat called with (entry, solutions) for "Nochmal" / "Mit Lösungen"
 */
export function renderHistory(list, entries, onRepeat) {
  list.replaceChildren(
    ...entries.map((entry) => {
      const item = document.createElement("li");
      item.className = "history-entry";

      const head = document.createElement("div");
      head.className = "history-head";
      const code = document.createElement("span");
      code.className = "history-code";
      code.textContent = entry.code;
      const date = document.createElement("time");
      date.dateTime = entry.date;
      date.textContent = dateFormat.format(new Date(entry.date));
      head.append(code, date);

      const meta = document.createElement("p");
      meta.className = "history-meta";
      meta.textContent = `${entry.title} · ${entry.description} · ${entry.count} Aufgaben`;

      const actions = document.createElement("div");
      actions.className = "history-actions";
      actions.append(
        button("Nochmal", () => onRepeat(entry, false)),
        button("Mit Lösungen", () => onRepeat(entry, true)),
      );

      item.append(head, meta, actions);
      return item;
    }),
  );
}
