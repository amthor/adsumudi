// End-to-end test of the built site (web/dist/) in headless Chromium.
//
//   npm run build && npm test        (from web/)
//   E2E_URL=https://amthor.github.io/adsumudi/ npm test   (the published site)
//
// Serves dist/ itself (or tests E2E_URL), drives the page like a user and compares the PDFs with
// the CLI's (`pdftotext -bbox`: every word with its coordinates; bytes may
// differ by creation date and document id). Needs lua, pdftotext and
// Chromium; set CHROMIUM=/path/to/chrome if it is not found automatically.

import { execFileSync } from "node:child_process";
import { existsSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { createServer } from "node:http";
import { tmpdir } from "node:os";
import { dirname, extname, join, normalize } from "node:path";
import { fileURLToPath } from "node:url";
import puppeteer from "puppeteer-core";

const web = join(dirname(fileURLToPath(import.meta.url)), "..");
const root = join(web, "..");
const dist = join(web, "dist");

const CHROMIUM_CANDIDATES = [
  process.env.CHROMIUM,
  "/usr/bin/chromium-browser",
  "/usr/bin/chromium",
  "/usr/bin/google-chrome",
  "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
].filter(Boolean);

const MIME_TYPES = {
  ".html": "text/html; charset=utf-8",
  ".js": "text/javascript",
  ".mjs": "text/javascript",
  ".css": "text/css",
  ".json": "application/json",
  ".svg": "image/svg+xml",
  ".wasm": "application/wasm",
  ".otf": "font/otf",
  ".lua": "text/plain; charset=utf-8",
  ".typ": "text/plain; charset=utf-8",
  ".txt": "text/plain; charset=utf-8",
};

// --- helpers -------------------------------------------------------------------

let failures = 0;
function check(name, ok, detail = "") {
  console.log(`${ok ? "✓" : "✗"} ${name}${!ok && detail ? `\n    ${detail}` : ""}`);
  if (!ok) {
    failures += 1;
  }
}

function startServer() {
  const server = createServer((request, response) => {
    const path = normalize(decodeURIComponent(new URL(request.url, "http://x").pathname));
    const file = join(dist, path.endsWith("/") ? `${path}index.html` : path);
    if (!file.startsWith(dist) || !existsSync(file)) {
      response.writeHead(404).end();
      return;
    }
    response.writeHead(200, { "Content-Type": MIME_TYPES[extname(file)] ?? "application/octet-stream" });
    response.end(readFileSync(file));
  });
  return new Promise((resolve) => server.listen(0, "127.0.0.1", () => resolve(server)));
}

const bbox = (pdf) =>
  execFileSync("pdftotext", ["-bbox", pdf, "-"], { encoding: "utf8" }).replace(/<head>[\s\S]*?<\/head>/, "");

function cliPdf(dir, code, { solutions, title }) {
  const path = join(dir, `cli-${code}.pdf`);
  const args = ["adsumudi.lua", "-c", code, "-o", path];
  if (solutions) args.push("-l");
  if (title) args.push("--titel", title);
  execFileSync("lua", args, { cwd: root });
  return path;
}

// --- page actions --------------------------------------------------------------

const waitReady = (page) =>
  page.waitForFunction(
    () => !document.getElementById("form-fields").disabled && document.getElementById("status").textContent === "",
    { timeout: 120000 },
  );

/** Sets form fields directly (no clicks, so smooth scrolling cannot interfere). */
function setForm(page, values) {
  return page.evaluate((v) => {
    const set = (id, value) => {
      const input = document.getElementById(id);
      if (input.type === "checkbox") input.checked = value;
      else input.value = value;
      input.dispatchEvent(new Event("input", { bubbles: true }));
      input.dispatchEvent(new Event("change", { bubbles: true }));
    };
    if (v.operations) {
      for (const box of document.querySelectorAll('input[name="operation"]')) box.checked = v.operations.includes(box.value);
    }
    if (v.mode) {
      const radio = document.querySelector(`input[name="size-mode"][value="${v.mode}"]`);
      radio.checked = true;
      radio.dispatchEvent(new Event("change", { bubbles: true }));
    }
    for (const id of ["min", "max", "minutes", "count", "code", "title", "solutions"]) {
      if (id in v) set(id, v[id]);
    }
  }, values);
}

/** Submits and waits for a result or an error. */
async function generate(page, submit = () => page.click("#generate")) {
  await page.evaluate(() => {
    document.getElementById("result-code").textContent = "";
    document.getElementById("form-error").hidden = true;
  });
  await submit();
  await page.waitForFunction(
    () => document.getElementById("result-code").textContent !== "" || !document.getElementById("form-error").hidden,
    { timeout: 120000 },
  );
  return page.evaluate(() => ({
    code: document.getElementById("result-code").textContent,
    error: document.getElementById("form-error").hidden ? null : document.getElementById("form-error").textContent,
  }));
}

async function downloadPdf(page, path) {
  const base64 = await page.evaluate(async () => {
    const bytes = new Uint8Array(await (await fetch(document.getElementById("download").href)).arrayBuffer());
    let text = "";
    for (const byte of bytes) text += String.fromCharCode(byte);
    return btoa(text);
  });
  writeFileSync(path, Buffer.from(base64, "base64"));
  return path;
}

const historyEntries = (page) =>
  page.$$eval(".history-entry", (items) =>
    items.map((li) => ({
      code: li.querySelector(".history-code").textContent,
      meta: li.querySelector(".history-meta").textContent,
    })),
  );

// --- test --------------------------------------------------------------------------

// E2E_URL: test an already published site instead of serving dist/.
const remoteUrl = process.env.E2E_URL;
if (!remoteUrl && !existsSync(join(dist, "index.html"))) {
  console.error("web/dist/ fehlt – zuerst: npm run build");
  process.exit(1);
}
const executablePath = CHROMIUM_CANDIDATES.find((path) => existsSync(path));
if (!executablePath) {
  console.error("Chromium nicht gefunden – Pfad mit CHROMIUM=… angeben");
  process.exit(1);
}

const tmp = mkdtempSync(join(tmpdir(), "adsumudi-e2e-"));
const server = remoteUrl ? null : await startServer();
const url = remoteUrl ?? `http://127.0.0.1:${server.address().port}/`;
console.log(`Teste ${url}\n`);
const browser = await puppeteer.launch({ executablePath, headless: true });
const problems = [];

try {
  const page = await browser.newPage();
  page.on("pageerror", (error) => problems.push(`Seitenfehler: ${error.message}`));
  page.on("response", (r) => r.status() >= 400 && problems.push(`HTTP ${r.status()}: ${r.url()}`));
  await page.setViewport({ width: 1280, height: 900 });
  await page.goto(url);
  await waitReady(page);

  // Defaults come from the Lua core (web.defaults → sheet.DEFAULTS).
  const defaults = await page.evaluate(() => ({
    operations: [...document.querySelectorAll('input[name="operation"]:checked')].map((b) => b.value),
    min: document.getElementById("min").value,
    max: document.getElementById("max").value,
    minutes: document.getElementById("minutes").value,
    title: document.getElementById("title").value,
  }));
  check(
    "Voreinstellungen aus dem Lua-Kern",
    JSON.stringify(defaults) ===
      JSON.stringify({ operations: ["add", "sub"], min: "1", max: "100", minutes: "5", title: "Rechenblatt" }),
    JSON.stringify(defaults),
  );
  // The version comes from the Lua core as well; the CLI must report the same.
  let cliVersion = "";
  try {
    cliVersion = execFileSync("lua", ["adsumudi.lua", "--version"], { cwd: root, encoding: "utf8" }).trim();
  } catch {
    // stays "": the check below fails with a hint
  }
  const versionLog = await page.$eval("#diagnostics-log", (e) => e.textContent);
  check(
    `Version in „Technische Details“ wie in der CLI (${cliVersion || "lua adsumudi.lua --version schlug fehl"})`,
    cliVersion !== "" && versionLog.includes(cliVersion),
    versionLog,
  );
  check("Verlauf anfangs ausgeblendet", await page.$eval("#history", (e) => e.hidden));
  check("Technische Details anfangs zugeklappt", await page.$eval("#diagnostics", (e) => !e.open));

  const first = await generate(page);
  check("Blatt mit Voreinstellungen", /^1-AS-1-100-\d+-\d+$/.test(first.code), JSON.stringify(first));

  // Same tasks and layout as the CLI, also with title and solution page.
  const title = 'Übung für "Lina" & <b>Co</b>';
  const cases = [
    { code: "1-AS-1-100-16-4711", solutions: true, title },
    { code: "1-ASMD-1-100-24-4711", solutions: true, title: "" },
    { code: "1-AS-1-1000-16-4711", solutions: false, title: "" },
  ];
  for (const c of cases) {
    await setForm(page, { code: c.code, solutions: c.solutions, title: c.title });
    const result = await generate(page);
    const web = await downloadPdf(page, join(tmp, `web-${c.code}.pdf`));
    check(
      `${c.code}${c.solutions ? " mit Lösungen" : ""}${c.title ? " und eigenem Titel" : ""}: PDF wie im CLI`,
      result.code === c.code && bbox(web) === bbox(cliPdf(tmp, c.code, c)),
      JSON.stringify(result),
    );
  }

  // Sheet code locks the deciding fields; "Leeren" unlocks them.
  const locked = await page.$eval("#operations-group", (e) => e.disabled);
  await page.click("#code-clear");
  const unlocked = await page.evaluate(() => ({
    code: document.getElementById("code").value,
    locked: document.getElementById("operations-group").disabled,
  }));
  check("Blattcode sperrt Felder, „Leeren“ hebt die Sperre auf", locked && unlocked.code === "" && !unlocked.locked);

  // Input errors come back as German messages from Lua.
  const errors = [
    [{ operations: [] }, "Mindestens eine Rechenart muss gewählt sein"],
    [{ operations: ["add"], max: "" }, "Max muss eine ganze Zahl sein"],
    [{ min: "50", max: "50" }, "Max muss größer als Min sein"],
    [{ min: "1", max: "100", mode: "count", count: "" }, "Die Anzahl muss eine ganze Zahl sein"],
  ];
  for (const [values, message] of errors) {
    await setForm(page, values);
    const result = await generate(page);
    check(`Fehlermeldung „${message}“`, result.error === message, JSON.stringify(result));
  }

  // Valid custom settings.
  await setForm(page, { operations: ["mul", "div"], min: "1", max: "50", mode: "count", count: "12" });
  const custom = await generate(page);
  check("Mal/Geteilt, 1–50, 12 Aufgaben", /^1-MD-1-50-12-\d+$/.test(custom.code), JSON.stringify(custom));

  // History: newest first, survives a reload, a title appears as text.
  const entries = await historyEntries(page);
  check("Verlauf: neuestes Blatt oben", entries[0]?.code === custom.code, JSON.stringify(entries[0]));
  check(
    "Verlauf: Titel als Text, nicht als HTML",
    entries.some((e) => e.meta.includes(title)) && (await page.$(".history-meta b")) === null,
  );
  await page.reload();
  await waitReady(page);
  check("Verlauf übersteht Neuladen", (await historyEntries(page)).length === entries.length);

  // "Mit Lösungen" on an entry rebuilds that sheet with its title.
  const index = (await historyEntries(page)).findIndex((e) => e.code === "1-AS-1-100-16-4711");
  const buttons = await page.$$(`.history-entry:nth-child(${index + 1}) .small-button`);
  const repeated = await generate(page, () => buttons[1].click());
  const repeatedPdf = await downloadPdf(page, join(tmp, "web-repeat.pdf"));
  check(
    "Verlauf „Mit Lösungen“ erzeugt dasselbe Blatt",
    repeated.code === "1-AS-1-100-16-4711" &&
      bbox(repeatedPdf) === bbox(cliPdf(tmp, repeated.code, { solutions: true, title })),
  );
  check("Verlauf: Eintrag rückt nach oben, nicht doppelt", (await historyEntries(page))[0].code === repeated.code);

  const log = await page.$eval("#diagnostics-log", (e) => e.textContent);
  check(
    "Technische Details protokollieren Laden und Blätter",
    /Rechenkern \(Lua\) bereit/.test(log) && /Satzsystem \(Typst\) bereit/.test(log) && /Blatt 1-AS-1-100-16-4711/.test(log),
    log,
  );

  await page.click("#history-clear");
  await page.reload();
  await waitReady(page);
  check("Verlauf löschen", (await historyEntries(page)).length === 0 && (await page.$eval("#history", (e) => e.hidden)));

  // Color scheme: "auto" follows the device, an explicit choice wins and survives a reload.
  const theme = () =>
    page.evaluate(() => ({
      theme: document.documentElement.dataset.theme,
      checked: document.querySelector('input[name="theme"]:checked')?.value,
      paper: getComputedStyle(document.body).backgroundColor,
    }));
  const chooseTheme = (value) => page.$eval(`input[name="theme"][value="${value}"]`, (input) => input.click());
  // The media change event arrives with the next rendering update, not at once.
  const emulateScheme = async (value) => {
    await page.emulateMediaFeatures([{ name: "prefers-color-scheme", value }]);
    await page
      .waitForFunction((v) => document.documentElement.dataset.theme === v, { timeout: 3000 }, value)
      .catch(() => {});
  };
  await emulateScheme("dark");
  const autoDark = await theme();
  await emulateScheme("light");
  const autoLight = await theme();
  check(
    "Farbschema „Automatisch“ folgt dem Gerät",
    autoDark.theme === "dark" && autoDark.checked === "auto" && autoDark.paper === "rgb(28, 25, 21)" &&
      autoLight.theme === "light" && autoLight.paper === "rgb(255, 249, 242)",
    JSON.stringify({ autoDark, autoLight }),
  );
  await chooseTheme("dark");
  await page.reload();
  await waitReady(page);
  const chosenDark = await theme();
  check(
    "Farbschema „Dunkel“ gilt trotz hellem Gerät, auch nach Neuladen",
    chosenDark.theme === "dark" && chosenDark.checked === "dark",
    JSON.stringify(chosenDark),
  );
  await chooseTheme("auto");
  const backToAuto = await theme();
  const stored = await page.evaluate(() => localStorage.getItem("adsumudi.theme.v1"));
  check(
    "Farbschema zurück auf „Automatisch“",
    backToAuto.theme === "light" && stored === null,
    JSON.stringify({ backToAuto, stored }),
  );

  check("keine Seitenfehler und keine fehlgeschlagenen Anfragen", problems.length === 0, problems.join("\n    "));
} finally {
  await browser.close();
  server?.close();
  rmSync(tmp, { recursive: true, force: true });
}

console.log(failures === 0 ? "\nAlle Prüfungen bestanden." : `\n${failures} Prüfung(en) fehlgeschlagen.`);
process.exitCode = failures === 0 ? 0 : 1;
