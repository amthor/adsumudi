// Page wiring. For now (stage 2) a single button that generates a sheet with
// the defaults; the full form follows in form.js.

import { createEngine, InputError } from "./engine.js";

const $ = (id) => document.getElementById(id);

function showStatus(text, isError = false) {
  $("status").textContent = text;
  $("status").classList.toggle("error", isError);
}

let pdfUrl;
function showResult(sheet) {
  if (pdfUrl) {
    URL.revokeObjectURL(pdfUrl);
  }
  pdfUrl = URL.createObjectURL(new Blob([sheet.pdf], { type: "application/pdf" }));
  $("result-code").textContent = sheet.code;
  $("result-count").textContent = sheet.count;
  $("download").href = pdfUrl;
  $("download").download = `rechenblatt-${sheet.code}.pdf`;
  $("preview").src = pdfUrl;
  $("result").hidden = false;
}

const engine = createEngine();

engine.luaReady.then(() => {
  showStatus("Lade Satzsystem …");
  $("generate").disabled = false;
});
engine.typstReady.then(
  () => showStatus(""),
  (error) => showStatus(`Das Satzsystem konnte nicht geladen werden: ${error.message}`, true),
);
engine.luaReady.catch((error) => showStatus(`Der Rechenkern konnte nicht geladen werden: ${error.message}`, true));

$("generate").addEventListener("click", async () => {
  $("generate").disabled = true;
  try {
    const defaults = await engine.defaults();
    showResult(await engine.generate({ settings: defaults, presentation: { title: defaults.title } }));
    showStatus("");
  } catch (error) {
    showStatus(error instanceof InputError ? error.message : `Fehler: ${error.message}`, true);
  } finally {
    $("generate").disabled = false;
  }
});
