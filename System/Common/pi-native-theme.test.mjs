// Native-controller regressions: no models, accounts, prompts or real terminal.
import assert from "node:assert/strict";
import { mkdtempSync, readFileSync, readdirSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { pathToFileURL } from "node:url";
const pkg = process.argv[2];
assert(pkg);
const dir = mkdtempSync(join(tmpdir(), "pi-native-theme-"));
process.env.PI_CODING_AGENT_DIR = dir;
process.env.PI_PACKAGE_DIR = pkg;
delete process.env.COLORFGBG;
const load = (path) => import(pathToFileURL(path).href);
const root = join(pkg, "dist/modes/interactive/theme");
const tm = await load(join(root, "theme.js"));
const { InteractiveThemeController } = await load(
  join(root, "theme-controller.js"),
);
const light = {
  background: { r: 239, g: 241, b: 245 },
  foreground: { r: 76, g: 79, b: 105 },
};
const dark = {
  background: { r: 30, g: 30, b: 46 },
  foreground: { r: 205, g: 214, b: 244 },
};
let listener;
let query = () => Promise.resolve(light);
let renders = 0;
const errors = [];
const ui = {
  invalidate() {
    renders++;
  },
  requestRender() {
    renders++;
  },
  setTerminalColorSchemeNotifications() {},
  onTerminalColorSchemeChange(fn) {
    listener = fn;
    return () => {
      listener = undefined;
    };
  },
  queryTerminalColors(options) {
    return query(options);
  },
};
let controller;
try {
  controller = new InteractiveThemeController(ui, {
    initialThemeSetting: "light/dark",
    getSettingsManager: () => ({ getThemeSetting: () => "light/dark" }),
    showError: (e) => errors.push(e),
    onChanged() {},
  });
  controller.applyFromSettings();
  await controller.waitForTerminalColors();
  assert.equal(tm.theme.name, "light");

  // Real failure mode: after a native switch, OSC RGB replies may time out.
  query = () => Promise.resolve({});
  for (const next of ["dark", "light", "dark", "light"]) {
    listener(next);
    assert.equal(
      tm.theme.name,
      next,
      "native notification must not wait for OSC RGB",
    );
    await controller.waitForTerminalColors();
    assert.equal(
      tm.theme.name,
      next,
      "old RGB must not defeat a new notification on timeout",
    );
  }
  // Partial palette-only replies cannot resurrect the previous appearance.
  query = () => Promise.resolve({ palette: [] });
  listener("dark");
  await controller.waitForTerminalColors();
  assert.equal(tm.theme.name, "dark");

  const pending = [];
  query = (options) =>
    new Promise((resolve) => pending.push({ resolve, ...options }));
  listener("light");
  const oldQuery = controller.waitForTerminalColors();
  listener("dark");
  pending[1].resolve(dark);
  await controller.waitForTerminalColors();
  pending[0].resolve(light);
  await oldQuery;
  pending[0].onLateReply(light);
  assert.equal(
    tm.theme.name,
    "dark",
    "late/superseded replies must not roll back appearance",
  );

  // Fresh actual RGB still wins over a contradictory/stale native hint.
  query = () => Promise.resolve(dark);
  listener("light");
  await controller.waitForTerminalColors();
  assert.equal(tm.theme.name, "dark");
  controller.setThemeName("light");
  listener("dark");
  assert.equal(
    tm.theme.name,
    "light",
    "a fixed user selection must remain fixed",
  );
  const before = renders;
  controller.dispose();
  pending[1].onLateReply(light);
  assert.equal(
    renders,
    before,
    "disposed controllers must not render from late replies",
  );
  assert.deepEqual(errors, []);

  // Exercise the real TUI lifecycle with a fake terminal (no second renderer).
  const { TuiAltScreen } = await load(
    join(dirname(pkg), "pi-tui/dist/index.js"),
  );
  const writes = [];
  const terminal = new Proxy(
    { columns: 80, rows: 24, write: (s) => writes.push(s) },
    {
      get(target, key) {
        return key in target ? target[key] : () => {};
      },
    },
  );
  const tui = new TuiAltScreen(terminal);
  tui.setTerminalColorSchemeNotifications(true);
  tui.start();
  tui.stop();
  assert(
    writes.some((s) => s.includes("\x1b[?2031h\x1b[?996n")),
    "request the initial native scheme",
  );
  const bundleDir = join(pkg, "dist/bundle");
  const bundledFix = readdirSync(bundleDir, { recursive: true })
    .filter((file) => file.endsWith(".js"))
    .some((file) =>
      readFileSync(join(bundleDir, file), "utf8").includes(
        "terminalColorQueryRevision",
      ),
    );
  assert(bundledFix, "the running CLI bundle chunks must include the fix");
  console.log(
    "Pi native appearance: initial DSR, timeouts, partial/late replies, rapid changes, fixed selection, cleanup and CLI bundle PASS",
  );
} finally {
  controller?.dispose();
  tm.stopThemeWatcher();
  rmSync(dir, { recursive: true, force: true });
}
