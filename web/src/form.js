// Sheet form: fills the fields from the core's defaults and turns them into
// a request for engine.generate().
//
// Domain checks stay in Lua (web.lua, sheet.lua). This module only reads the
// fields; it never invents defaults of its own. An empty or unreadable number
// field is sent as "", so that Lua answers with a proper message instead of
// silently falling back to a default.

export function createForm(form) {
  const field = (id) => form.querySelector(`#${id}`);
  const operationBoxes = [...form.querySelectorAll('input[name="operation"]')];
  const modeRadios = [...form.querySelectorAll('input[name="size-mode"]')];

  const sizeMode = () => modeRadios.find((radio) => radio.checked).value;
  const hasCode = () => field("code").value.trim() !== "";

  function updateSizeMode() {
    const mode = sizeMode();
    field("minutes-field").hidden = mode !== "minutes";
    field("count-field").hidden = mode !== "count";
  }

  // A sheet code fixes operations, range and tasks (like the CLI's conflict
  // rule), so those fields are locked while one is entered.
  function updateCodeMode() {
    const locked = hasCode();
    for (const id of ["operations-group", "range-group", "size-group"]) {
      field(id).disabled = locked;
    }
    field("code-hint").hidden = !locked;
  }

  function numberValue(id) {
    const input = field(id);
    return input.value === "" || Number.isNaN(input.valueAsNumber) ? "" : input.valueAsNumber;
  }

  for (const radio of modeRadios) {
    radio.addEventListener("change", updateSizeMode);
  }
  field("code").addEventListener("input", updateCodeMode);

  return {
    /** Sets the fields to the defaults from web.defaults(). */
    fill(defaults) {
      for (const box of operationBoxes) {
        box.checked = defaults.operations.includes(box.value);
      }
      field("min").value = defaults.min;
      field("max").value = defaults.max;
      field("minutes").value = defaults.minutes;
      modeRadios.find((radio) => radio.value === "minutes").checked = true;
      updateSizeMode();
      updateCodeMode();
    },

    /** The request for engine.generate(). */
    request() {
      const settings = hasCode()
        ? { code: field("code").value }
        : {
            operations: operationBoxes.filter((box) => box.checked).map((box) => box.value),
            min: numberValue("min"),
            max: numberValue("max"),
            [sizeMode()]: numberValue(sizeMode()),
          };
      return { settings, presentation: { solutions: field("solutions").checked } };
    },
  };
}
