// Assembles web/dist/, the complete static site.
//
// No bundler, this only copies files. Lua sources, the Typst template and
// fonts come directly from the project, such that CLI and web always share the same
// sources. Served from dist/ (as it will be hosted).
//
//   npm run build        (from web/)

import {
  copyFileSync,
  cpSync,
  mkdirSync,
  readdirSync,
  rmSync,
  writeFileSync,
} from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const web = dirname(fileURLToPath(import.meta.url));
const root = join(web, "..");
const dist = join(web, "dist");
const modules = join(web, "node_modules");

function copy(from, to) {
  mkdirSync(dirname(to), { recursive: true });
  copyFileSync(from, to);
}

function copyMatching(fromDir, toDir, pattern) {
  for (const name of readdirSync(fromDir).filter((n) => pattern.test(n))) {
    copy(join(fromDir, name), join(toDir, name));
  }
}

rmSync(dist, { recursive: true, force: true });

// The page itself.
copy(join(web, "index.html"), join(dist, "index.html"));
copy(join(web, "style.css"), join(dist, "style.css"));
copy(join(web, "favicon.svg"), join(dist, "favicon.svg"));
cpSync(join(web, "src"), join(dist, "src"), { recursive: true });

// Lua core. All modules are copied; only the ones web.lua requires get loaded.
const luaFiles = [];
for (const name of readdirSync(join(root, "src", "adsumudi")).filter((n) =>
  n.endsWith(".lua"),
)) {
  luaFiles.push(`adsumudi/${name}`);
}
luaFiles.push("dkjson/dkjson.lua");
for (const file of luaFiles) {
  const source = file.startsWith("dkjson/")
    ? join(root, file)
    : join(root, "src", file);
  copy(source, join(dist, "lua", file));
}
writeFileSync(
  join(dist, "lua-files.json"),
  JSON.stringify(luaFiles, null, 2) + "\n",
);

// Typst template and fonts (with their license).
copy(
  join(root, "templates", "adsumudi.typ"),
  join(dist, "typst", "adsumudi.typ"),
);
copyMatching(join(root, "fonts"), join(dist, "fonts"), /\.otf$|^OFL\.txt$/);

// Third-party runtime files.
copyMatching(
  join(modules, "wasmoon", "dist"),
  join(dist, "vendor", "wasmoon"),
  /^index\.js$|^glue\.wasm$/,
);
copy(
  join(modules, "wasmoon", "LICENSE"),
  join(dist, "vendor", "wasmoon", "LICENSE"),
);
cpSync(
  join(modules, "@myriaddreamin", "typst.ts", "dist", "esm"),
  join(dist, "vendor", "typst.ts"),
  {
    recursive: true,
    filter: (path) => !/\.d\.mts$|\.map$/.test(path),
  },
);
copyMatching(
  join(modules, "@myriaddreamin", "typst-ts-web-compiler", "pkg"),
  join(dist, "vendor", "typst-ts-web-compiler"),
  /\.mjs$|_bg\.wasm$/,
);
// Apache-2.0 requires the license text alongside redistributed files. The
// compiler package ships none, but comes from the same typst.ts project.
const typstLicense = join(modules, "@myriaddreamin", "typst.ts", "LICENSE");
copy(typstLicense, join(dist, "vendor", "typst.ts", "LICENSE"));
copy(typstLicense, join(dist, "vendor", "typst-ts-web-compiler", "LICENSE"));

console.log(
  `dist/ gebaut: ${luaFiles.length} Lua-Dateien, Template, Schriften, Wasmoon, typst.ts`,
);
