// Page wiring: engine (Lua + Typst) ↔ form ↔ result.

import { createEngine, InputError } from "./engine.js";
import { createForm } from "./form.js";

const $ = (id) => document.getElementById(id);

const engine = createEngine();
const form = createForm($("sheet-form"));

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
  .then(async () => {
    form.fill(await engine.defaults());
    $("form-fields").disabled = false;
    if (!typstReady) {
      setStatus("Lade Satzsystem … (beim ersten Besuch einige Sekunden)");
    }
  })
  .catch((error) => setStatus(`Der Rechenkern konnte nicht geladen werden: ${error.message}`));

engine.typstReady
  .then(() => {
    typstReady = true;
    setStatus("");
  })
  .catch((error) => setStatus(`Das Satzsystem konnte nicht geladen werden: ${error.message}`));

$("sheet-form").addEventListener("submit", async (event) => {
  event.preventDefault();
  const button = $("generate");
  $("form-error").hidden = true;
  button.disabled = true;
  button.textContent = typstReady ? "Erzeuge …" : "Warte auf Satzsystem …";
  try {
    showResult(await engine.generate(form.request()));
  } catch (error) {
    showError(error instanceof InputError ? error.message : `Fehler: ${error.message}`);
  } finally {
    button.disabled = false;
    button.textContent = "Blatt erzeugen";
  }
});
