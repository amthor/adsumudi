// The engine: Lua core (Wasmoon) + Typst compiler (typst.ts) in the browser.
//
// createEngine() starts both right away and in parallel. Lua is ready after
// a few hundred milliseconds; Typst needs its 29 MB WebAssembly module, which
// can take seconds on a first visit. generate() waits for whatever is missing.
//
// The only interface to Lua is src/rechenblatt/web.lua: one JSON string in,
// one JSON string out (see the comments there).

import { createTypstCompiler } from "../vendor/typst.ts/compiler.mjs";
import { disableDefaultFontAssets, loadFonts } from "../vendor/typst.ts/options.init.mjs";

// Root of the site (dist/), independent of where the page is hosted.
const BASE = new URL("../", import.meta.url);
const FONTS = ["FiraSans-Regular.otf", "FiraSans-SemiBold.otf", "FiraSans-Bold.otf"];
// Path of the template in typst.ts's virtual file system.
const TEMPLATE_PATH = "/rechenblatt.typ";

/** An error the user caused (invalid input); its message is meant to be shown. */
export class InputError extends Error {}

async function fetchOk(path, as = "text") {
  const response = await fetch(new URL(path, BASE));
  if (!response.ok) {
    throw new Error(`${path}: HTTP ${response.status}`);
  }
  return as === "json" ? response.json() : response.text();
}

async function startLua() {
  // wasmoon only ships a UMD bundle; index.html loads it as a classic script,
  // which defines the global `wasmoon`.
  const factory = new globalThis.wasmoon.LuaFactory(new URL("vendor/wasmoon/glue.wasm", BASE).href);
  const files = await fetchOk("lua-files.json", "json");
  const sources = await Promise.all(files.map((file) => fetchOk(`lua/${file}`)));
  for (const [i, file] of files.entries()) {
    await factory.mountFile(`/lua/${file}`, sources[i]);
  }
  const lua = await factory.createEngine();
  await lua.doString(`
    package.path = "/lua/?.lua"
    local web = require("rechenblatt.web")
    web_defaults, web_generate = web.defaults, web.generate
  `);
  return { defaults: lua.global.get("web_defaults"), generate: lua.global.get("web_generate") };
}

async function startTypst() {
  const compiler = createTypstCompiler();
  await compiler.init({
    // Load the compiler module and its WebAssembly by path instead of by
    // package name, which a browser cannot resolve without a bundler.
    getWrapper: () => import("../vendor/typst-ts-web-compiler/wasm-pack-shim.mjs"),
    getModule: () => new URL("vendor/typst-ts-web-compiler/typst_ts_web_compiler_bg.wasm", BASE),
    // Only the bundled fonts, like `typst compile --ignore-system-fonts --font-path fonts`.
    beforeBuild: [disableDefaultFontAssets(), loadFonts(FONTS.map((f) => new URL(`fonts/${f}`, BASE).href))],
  });
  compiler.addSource(TEMPLATE_PATH, await fetchOk("typst/rechenblatt.typ"));
  return compiler;
}

const since = (t0) => Math.round(performance.now() - t0);

export function createEngine() {
  const t0 = performance.now();
  const lua = startLua();
  const typst = startTypst();
  // Avoid "unhandled rejection" noise; callers see the error when they await.
  lua.catch(() => {});
  typst.catch(() => {});

  return {
    /** Resolves with {ms} (since createEngine) when the Lua core is ready. */
    luaReady: lua.then(() => ({ ms: since(t0) })),
    /** Resolves with {ms} (since createEngine) when Typst is ready (PDF output). */
    typstReady: typst.then(() => ({ ms: since(t0) })),

    /** Form defaults from the Lua core: {operations, min, max, minutes, title}. */
    async defaults() {
      return JSON.parse((await lua).defaults());
    },

    /**
     * Generates a sheet.
     * @param request {settings: {operations?, min?, max?, count?, minutes?, code?},
     *                 presentation: {title?, solutions?}}
     * @returns {code, count, description, title, pdf: Uint8Array,
     *           timings: {luaMs, typstMs}} (typstMs excludes waiting for Typst to load)
     * @throws InputError with a German message for invalid input
     */
    async generate(request) {
      let start = performance.now();
      const response = JSON.parse((await lua).generate(JSON.stringify(request)));
      const luaMs = since(start);
      if (!response.ok) {
        throw new InputError(response.error);
      }
      const compiler = await typst;
      start = performance.now();
      // runWithWorld frees the compilation's memory afterwards.
      const { result, diagnostics } = await compiler.runWithWorld(
        { mainFilePath: TEMPLATE_PATH, inputs: { daten: response.source } },
        (world) => world.pdf({ diagnostics: "unix" }),
      );
      if (!result) {
        throw new Error(`Typst ist fehlgeschlagen:\n${(diagnostics ?? []).join("\n")}`);
      }
      const { source, ok, ...sheet } = response;
      return { ...sheet, pdf: result, timings: { luaMs, typstMs: since(start) } };
    },
  };
}
