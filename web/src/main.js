// Page wiring: engine (Lua + Typst) ↔ form ↔ result ↔ history, plus the
// "Technische Details" log.

import { createDiagnostics } from "./diagnostics.js";
import { createEngine, InputError } from "./engine.js";
import { createForm } from "./form.js";
import { createHistory, renderHistory } from "./history.js";

const $ = (id) => document.getElementById(id);

const diagnostics = createDiagnostics($("diagnostics-log"));
diagnostics.log(`Browser: ${navigator.userAgent}`);
const engine = createEngine();
const form = createForm($("sheet-form"));
const history = createHistory();
let busy = false;

function updateHistory() {
  const entries = history.entries();
  $("history").hidden = entries.length === 0;
  renderHistory($("history-list"), entries, (entry, solutions) => {
    // Not before the defaults are loaded (they would overwrite the entry) and
    // not while a sheet is being generated.
    if (busy || $("form-fields").disabled) {
      return;
    }
    form.load({ code: entry.code, title: entry.title, solutions });
    $("sheet-form").requestSubmit();
  });
}

$("history-clear").addEventListener("click", () => {
  history.clear();
  updateHistory();
});
updateHistory();

function setStatus(text) {
  $("status").textContent = text;
}

function showError(message) {
  // Messages from Lua may start in lower case ("mindestens eine Rechenart …").
  $("form-error").textContent = message.charAt(0).toUpperCase() + message.slice(1);
  $("form-error").hidden = false;
}

let pdfUrl;
function showResult(sheet) {
  if (pdfUrl) {
    URL.revokeObjectURL(pdfUrl);
  }
  pdfUrl = URL.createObjectURL(new Blob([sheet.pdf], { type: "application/pdf" }));
  $("result-code").textContent = sheet.code;
  $("result-meta").textContent = `${sheet.description} · ${sheet.count} Aufgaben`;
  $("download").href = pdfUrl;
  $("download").download = `rechenblatt-${sheet.code}.pdf`;
  $("preview").src = pdfUrl;
  $("result").hidden = false;
  // On narrow screens the result sits below the form.
  if (window.matchMedia("(max-width: 899px)").matches) {
    $("result").scrollIntoView({ behavior: "smooth", block: "start" });
  }
}

let typstReady = false;

engine.luaReady
  .then(async ({ ms }) => {
    const def = await engine.defaults();
    form.fill(def);
    diagnostics.log(`(Adsumudi ${def.version})`);
    diagnostics.log(`Rechenkern (Lua) bereit nach ${ms} ms`);
    $("form-fields").disabled = false;
    if (!typstReady) {
      setStatus("Lade Satzsystem … (beim ersten Besuch einige Sekunden)");
    }
  })
  .catch((error) => {
    setStatus(`Der Rechenkern konnte nicht geladen werden: ${error.message}`);
    diagnostics.log(`Fehler beim Laden von Lua: ${error.stack ?? error}`);
  });

engine.typstReady
  .then(({ ms }) => {
    typstReady = true;
    setStatus("");
    diagnostics.log(`Satzsystem (Typst) bereit nach ${ms} ms`);
    diagnostics.logDownloads();
  })
  .catch((error) => {
    setStatus(`Das Satzsystem konnte nicht geladen werden: ${error.message}`);
    diagnostics.log(`Fehler beim Laden von Typst: ${error.stack ?? error}`);
  });

$("sheet-form").addEventListener("submit", async (event) => {
  event.preventDefault();
  if (busy) {
    return;
  }
  busy = true;
  const button = $("generate");
  $("form-error").hidden = true;
  button.disabled = true;
  button.textContent = typstReady ? "Erzeuge …" : "Warte auf Satzsystem …";
  try {
    const sheet = await engine.generate(form.request());
    showResult(sheet);
    const kb = Math.round(sheet.pdf.length / 1024);
    diagnostics.log(
      `Blatt ${sheet.code} (${sheet.count} Aufgaben): Lua ${sheet.timings.luaMs} ms, Typst ${sheet.timings.typstMs} ms, PDF ${kb} KB`,
    );
    history.add(sheet);
    updateHistory();
  } catch (error) {
    showError(error instanceof InputError ? error.message : `Fehler: ${error.message}`);
    diagnostics.log(error instanceof InputError ? `Eingabe: ${error.message}` : `Fehler: ${error.stack ?? error}`);
  } finally {
    busy = false;
    button.disabled = false;
    button.textContent = "Blatt erzeugen";
  }
});
