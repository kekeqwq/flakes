// Exercise the pinned Pi's real schema, theme loader and appearance controller.
// No sessions, credentials, extensions, user settings or model calls are loaded.
import assert from "node:assert/strict";
import { cpSync, mkdirSync, mkdtempSync, readFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { pathToFileURL } from "node:url";

const [source, pi] = process.argv.slice(2);
assert(source && pi, "usage: node pi-catppuccin.test.mjs THEMES PI_PACKAGE");
const agentDir = mkdtempSync(join(tmpdir(), "pi-catppuccin-test-"));
process.env.PI_CODING_AGENT_DIR = agentDir;
process.env.COLORTERM = "truecolor";
const pair = "catppuccin-latte/catppuccin-mocha";
const palettes = {
  light: {
    name: "catppuccin-latte",
    text: "#4c4f69",
    base: "#eff1f5",
    accent: "#8839ef",
  },
  dark: {
    name: "catppuccin-mocha",
    text: "#cdd6f4",
    base: "#1e1e2e",
    accent: "#cba6f7",
  },
};
const load = (name) =>
  import(pathToFileURL(join(pi, "dist/modes/interactive/theme", name)).href);
let controller;
let stopWatcher;
try {
  mkdirSync(join(agentDir, "themes"));
  const themeModule = await load("theme.js");
  stopWatcher = themeModule.stopThemeWatcher;
  const { validateThemeJson } = await load("theme-schema.js");
  themeModule.setThemeJsonValidator(validateThemeJson);
  for (const [appearance, palette] of Object.entries(palettes)) {
    const file = `${palette.name}.json`;
    const json = JSON.parse(readFileSync(join(source, file), "utf8"));
    validateThemeJson(file, json);
    assert.equal(json.name, palette.name);
    assert.equal(json.vars.text, palette.text);
    assert.equal(json.vars.base, palette.base);
    cpSync(join(source, file), join(agentDir, "themes", file));
    const loaded = themeModule.loadThemeFromPath(
      join(agentDir, "themes", file),
    );
    assert.equal(loaded.appearance, appearance);
    const colors = themeModule.getResolvedThemeColors(palette.name);
    assert.equal(colors.text, palette.text);
    assert.equal(colors.accent, palette.accent);
    const border = appearance === "light" ? "#d81b80" : "#89b4fa";
    for (const role of [
      "border",
      "borderAccent",
      "borderMuted",
      "thinkingOff",
      "thinkingMinimal",
      "thinkingLow",
      "thinkingMedium",
      "thinkingHigh",
      "thinkingXhigh",
      "thinkingMax",
      "bashMode",
    ]) {
      assert.equal(colors[role], border, `shared editor border: ${role}`);
    }
    assert.equal(
      themeModule.resolveThemeSetting(pair, appearance),
      palette.name,
    );
  }

  const rgb = (hex) => ({
    r: parseInt(hex.slice(1, 3), 16),
    g: parseInt(hex.slice(3, 5), 16),
    b: parseInt(hex.slice(5, 7), 16),
  });
  let appearance = "dark";
  let listener;
  const errors = [];
  const notifications = [];
  const ui = {
    invalidate() {},
    requestRender() {},
    setTerminalColorSchemeNotifications(enabled) {
      notifications.push(enabled);
    },
    onTerminalColorSchemeChange(callback) {
      listener = callback;
      return () => {
        listener = undefined;
      };
    },
    async queryTerminalColors() {
      return {
        foreground: rgb(palettes[appearance].text),
        background: rgb(palettes[appearance].base),
      };
    },
  };
  const { InteractiveThemeController } = await load("theme-controller.js");
  controller = new InteractiveThemeController(ui, {
    initialThemeSetting: pair,
    getSettingsManager: () => ({ getThemeSetting: () => pair }),
    showError: (message) => errors.push(message),
    onChanged() {},
  });
  controller.applyFromSettings();
  await controller.waitForTerminalColors();
  for (const next of ["dark", "light", "dark", "light", "dark"]) {
    appearance = next;
    listener(next);
    await controller.waitForTerminalColors();
    assert.equal(themeModule.theme.name, palettes[next].name);
    assert.equal(themeModule.theme.appearance, next);
  }
  // A stale mode-2031 hint must not override the terminal's actual background.
  listener("light");
  await controller.waitForTerminalColors();
  assert.equal(themeModule.theme.name, palettes.dark.name);
  assert.deepEqual(notifications, [true]);
  assert.deepEqual(errors, []);
  console.log(
    "Pi Catppuccin: strict schema, exact palette and native Latte/Mocha appearance transitions PASS",
  );
} finally {
  controller?.dispose();
  stopWatcher?.();
  rmSync(agentDir, { recursive: true, force: true });
}
