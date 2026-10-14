import assert from "node:assert/strict";
import { test } from "node:test";
import { pathToFileURL } from "node:url";

const root = process.env.PI_TEST_PACKAGE_DIR;
const { InteractiveThemeController } = await import(
  pathToFileURL(`${root}/dist/modes/interactive/theme/theme-controller.js`)
);

function fixture(run) {
  const originalSet = globalThis.setInterval;
  const originalClear = globalThis.clearInterval;
  const timers = new Set();
  globalThis.setInterval = (callback, delay) => {
    assert.equal(delay, 1000);
    const timer = { callback, unref() {} };
    timers.add(timer);
    return timer;
  };
  globalThis.clearInterval = (timer) => timers.delete(timer);
  const stats = { queries: 0, changes: 0, renders: 0 };
  const ui = {
    stopped: false,
    pendingTerminalColorQueries: [],
    invalidate() {},
    requestRender() {
      stats.renders++;
    },
    onTerminalColorSchemeChange() {
      return () => {};
    },
    setTerminalColorSchemeNotifications() {},
  };
  const controller = new InteractiveThemeController(ui, {
    getSettingsManager: () => ({ getThemeSetting: () => undefined }),
    showError: (message) => assert.fail(message),
    onChanged: () => stats.changes++,
  });
  controller.queryTerminalColors = () => stats.queries++;
  try {
    run({ controller, ui, stats, timers });
  } finally {
    controller.dispose();
    assert.equal(timers.size, 0);
    globalThis.setInterval = originalSet;
    globalThis.clearInterval = originalClear;
  }
}

test("system theme polls; repeated enabling does not create extra timers", () => {
  fixture(({ controller, timers, stats }) => {
    controller.applyFromSettings();
    assert.equal(controller.getThemeSelection(), "system");
    assert.equal(timers.size, 1);
    controller.setAutoSync(true);
    assert.equal(timers.size, 1);
    const before = stats.queries;
    [...timers][0].callback();
    assert.equal(stats.queries, before + 1);
  });
});

test("paused TUI and pending color replies are not polled", () => {
  fixture(({ controller, ui, timers, stats }) => {
    controller.setAutoSync(true);
    const tick = [...timers][0].callback;
    ui.stopped = true;
    tick();
    assert.equal(stats.queries, 0);
    ui.stopped = false;
    ui.pendingTerminalColorQueries.push({});
    tick();
    assert.equal(stats.queries, 0);
    ui.pendingTerminalColorQueries.length = 0;
    tick();
    assert.equal(stats.queries, 1);
  });
});

test("manual fixed themes stop polling; returning to system resumes", () => {
  fixture(({ controller, timers }) => {
    controller.applyFromSettings();
    controller.setThemeName("dark");
    assert.equal(timers.size, 0);
    controller.setThemeName("system");
    assert.equal(timers.size, 1);
    controller.disableAutoSync();
    assert.equal(timers.size, 0);
  });
});

test("only changed terminal colors repaint the system theme", () => {
  fixture(({ controller, stats }) => {
    controller.applyFromSettings();
    const dark = {
      background: { r: 30, g: 30, b: 46 },
      foreground: { r: 205, g: 214, b: 244 },
    };
    const light = {
      background: { r: 239, g: 241, b: 245 },
      foreground: { r: 76, g: 79, b: 105 },
    };
    controller.applyTerminalColors(dark);
    assert.equal(controller.getTerminalTheme(), "dark");
    const before = stats.renders;
    controller.applyTerminalColors(structuredClone(dark));
    assert.equal(stats.renders, before);
    controller.applyTerminalColors(light);
    assert.equal(controller.getTerminalTheme(), "light");
    assert.equal(stats.renders, before + 1);
    controller.applyTerminalColors(dark);
    assert.equal(controller.getTerminalTheme(), "dark");
  });
});
