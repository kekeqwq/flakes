import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync, mkdtempSync, existsSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { stripTypeScriptTypes } from "node:module";
const source = readFileSync(process.argv[2], "utf8").replace(
  /import\s*\{[\s\S]*?\}\s*from\s*["']@earendil-works\/pi-coding-agent["'];/,
  `class CustomEditor {
    focused = true;
    text = '';
    isShowingAutocomplete() { return false; }
    getText() { return this.text; }
    render() { return ['']; }
    handleInput() {}
  }`,
);
const mod = await import(
  "data:text/javascript;base64," +
    Buffer.from(stripTypeScriptTypes(source)).toString("base64")
);
test("Chinese only for focused plain-text editor", () => {
  assert.equal(mod.isChineseEditor(true, false, "中文问题"), true);
  assert.equal(mod.isChineseEditor(false, false, "中文问题"), false);
  assert.equal(
    mod.isChineseEditor(true, true, "inline text suggestions"),
    true,
  );
  assert.equal(mod.isChineseEditor(true, false, "/model"), false);
  assert.equal(mod.isChineseEditor(true, false, "!ls"), false);
  assert.equal(mod.isChineseEditor(true, false, ""), true);
});
test("dropped absolute image paths stay Chinese, slash commands stay ABC", () => {
  for (const text of [
    "/var/folders/4d/temp/Screenshot\\ 2026-11-03.png ",
    "/Users/keke/Pictures/test.png 请分析",
    "/tmp/image.png",
    "/image.png",
    " /tmp/a.png\n说明",
  ]) {
    assert.equal(mod.isChineseEditor(true, false, text), true, text);
    assert.equal(mod.isChineseEditor(false, false, text), false, text);
  }
  for (const text of ["/", "/mo", "/model", "/model gpt", "/reload", "!ls"]) {
    assert.equal(mod.isChineseEditor(true, false, text), false, text);
  }
});
test("custom text focus distinguishes Other answers and quiz notes from menus", () => {
  const fake = "\x1b_pi:fc\x07 \x1b_pi:/fc\x07";
  const focused = "\x1b_pi:c\x07" + fake;
  assert.equal(mod.hasCustomTextFocus(["menu"], false), false);
  assert.equal(mod.hasCustomTextFocus([fake], false), true); // Other answer opens
  assert.equal(mod.hasCustomTextFocus([fake], true), false); // idle quiz note
  assert.equal(mod.hasCustomTextFocus([focused], true), true); // Tab into note
  assert.equal(mod.hasCustomTextFocus(["menu"], true), false);
});
test("factory registers lifecycle without creating timers or files", () => {
  const events = new Map();
  mod.default({
    on(name, callback) {
      events.set(name, callback);
    },
  });
  assert.deepEqual([...events.keys()], ["session_start", "session_shutdown"]);
});
test("direct Ghostty publishes exact surface identity, focus and shutdown lease", () => {
  const home = mkdtempSync(join(tmpdir(), "pi-ime-direct-"));
  const keys = [
    "HOME",
    "TMUX",
    "TMUX_PANE",
    "WEZTERM_PANE",
    "GHOSTTY_SURFACE_ID",
  ];
  const saved = Object.fromEntries(keys.map((key) => [key, process.env[key]]));
  const originalInterval = globalThis.setInterval;
  const originalClear = globalThis.clearInterval;
  let timerCallback;
  let cleared = false;
  const events = new Map();
  const titles = [];
  let editor;
  const tui = { stop() {}, start() {} };
  const file = join(
    home,
    ".local/state/input-method/pi",
    `${process.pid}.json`,
  );
  try {
    process.env.HOME = home;
    delete process.env.TMUX;
    process.env.TMUX_PANE = "%inherited"; // Without TMUX this is not a tmux context.
    delete process.env.WEZTERM_PANE;
    process.env.GHOSTTY_SURFACE_ID = "surface-a";
    globalThis.setInterval = (cb) => {
      timerCallback = cb;
      return { unref() {} };
    };
    globalThis.clearInterval = () => {
      cleared = true;
    };
    mod.default({
      on(name, cb) {
        events.set(name, cb);
      },
    });
    events.get("session_start")(
      {},
      {
        mode: "tui",
        hasUI: true,
        ui: {
          setTitle(title) {
            titles.push(title);
          },
          editor() {},
          input() {},
          custom() {},
          setEditorComponent(factory) {
            editor = factory(
              tui,
              {},
              {
                matches() {
                  return false;
                },
              },
            );
          },
        },
      },
    );
    const value = () => JSON.parse(readFileSync(file, "utf8"));
    assert.equal(value().ghosttySurface, "surface-a");
    assert.equal(value().pid, process.pid);
    assert.equal(value().tmuxPane, null);
    assert.equal(value().editing, true);
    assert.equal(titles.at(-1), `pi-ime:${process.pid}:surface-a`);
    editor.focused = false;
    assert.equal(value().editing, false);
    editor.focused = true;
    assert.equal(value().editing, true);
    const beforeStop = titles.length;
    tui.stop();
    timerCallback();
    assert.equal(value().editing, false);
    assert.equal(
      titles.length,
      beforeStop,
      "stopped TUI must not overwrite a subprocess title",
    );
    tui.start();
    timerCallback();
    assert.equal(value().editing, true);
    events.get("session_shutdown")();
    assert.equal(existsSync(file), false);
    assert.equal(cleared, true);
  } finally {
    events.get("session_shutdown")?.();
    for (const [key, value] of Object.entries(saved)) {
      if (value === undefined) delete process.env[key];
      else process.env[key] = value;
    }
    globalThis.setInterval = originalInterval;
    globalThis.clearInterval = originalClear;
    rmSync(home, { recursive: true, force: true });
  }
});
