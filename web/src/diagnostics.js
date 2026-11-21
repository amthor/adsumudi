// "Technische Details": a hidden-by-default log of load and generation times,
// download sizes and errors, for checking how the page behaves on a device.

const numberFormat = new Intl.NumberFormat("de-DE", { maximumFractionDigits: 1 });
const megabytes = (bytes) => `${numberFormat.format(bytes / 1024 / 1024)} MB`;

export function createDiagnostics(output) {
  const start = performance.now();

  function log(line) {
    const seconds = numberFormat.format((performance.now() - start) / 1000);
    output.textContent += `[${seconds} s] ${line}\n`;
  }

  return {
    log,

    /** Logs what the page has downloaded so far, and how much came from the cache. */
    logDownloads() {
      const entries = performance.getEntriesByType("resource");
      const size = entries.reduce((sum, e) => sum + (e.encodedBodySize || 0), 0);
      const transferred = entries.reduce((sum, e) => sum + (e.transferSize || 0), 0);
      const wasm = entries
        .filter((e) => e.name.endsWith(".wasm"))
        .map((e) => `${e.name.split("/").pop()} ${megabytes(e.encodedBodySize)}`);
      log(`Dateien: ${megabytes(size)} (${wasm.join(", ")}), davon übertragen: ${megabytes(transferred)}`);
    },
  };
}
