import {
  CustomEditor,
  type ExtensionAPI,
} from "@earendil-works/pi-coding-agent";
import { mkdirSync, renameSync, unlinkSync, writeFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";
import { execFile } from "node:child_process";

export function isChineseEditor(
  focused: boolean,
  _inlineSuggestions: boolean,
  text: string,
): boolean {
  // Inline suggestions still belong to the text editor. Changing IME when
  // that popup blinks on/off interrupts composition. Full selectors lose focus.
  const input = text.trimStart();
  // Dropped absolute paths (/var/.../image.png) are prompt text, not
  // slash commands. Keep command prefixes/arguments ABC, but allow paths.
  const slashCommand = /^\/[^\s/\\.]*(?:\s|$)/.test(input);
  return focused && !input.startsWith("!") && !slashCommand;
}

export function hasCustomTextFocus(
  lines: string[],
  initialFakeCursor: boolean,
): boolean {
  return lines.some(
    (line) =>
      line.includes("\x1b_pi:c\x07") ||
      (!initialFakeCursor && line.includes("\x1b_pi:fc\x07")),
  );
}

// Report UI state, never change the system input source here. Only metadata is
// written: no prompt text, file names or conversation content leaves Pi.
export default function inputMethod(pi: ExtensionAPI) {
  let enabled = false;
  let editor: CustomEditor | undefined;
  let suspended = false;
  let tuiStopped = false;
  let restoreTui: (() => void) | undefined;
  let textDialogs = 0;
  const customTextEditors = new Set<object>();
  let restoreDialogs: (() => void) | undefined;
  let timer: ReturnType<typeof setInterval> | undefined;
  let last = "";
  const directory = join(homedir(), ".local/state/input-method/pi");
  const file = join(directory, `${process.pid}.json`);
  const temporary = `${file}.tmp`;

  function report(force = false) {
    if (!enabled) return;
    const editing =
      !tuiStopped &&
      (textDialogs > 0 ||
        customTextEditors.size > 0 ||
        (!!editor &&
          !suspended &&
          isChineseEditor(
            editor.focused,
            editor.isShowingAutocomplete(),
            editor.getText(),
          )));
    if (!force && last === String(editing)) return;
    last = String(editing);
    try {
      mkdirSync(directory, { recursive: true, mode: 0o700 });
      writeFileSync(
        temporary,
        JSON.stringify({
          version: 1,
          pid: process.pid,
          editing,
          updated: Date.now() / 1000,
          weztermPane: process.env.WEZTERM_PANE ?? null,
          tmuxPane: process.env.TMUX_PANE ?? null,
          socket: process.env.TMUX?.split(",")[0] ?? null,
        }),
        { mode: 0o600 },
      );
      renameSync(temporary, file);
    } catch {
      /* An absent/unavailable manager must never break the editor. */
    }
  }
  function refreshTmux() {
    if (process.env.TMUX)
      execFile("input-method-tmux-update", [], { timeout: 1500 }, () => {});
  }
  function cleanup() {
    enabled = false;
    restoreTui?.();
    restoreTui = undefined;
    restoreDialogs?.();
    restoreDialogs = undefined;
    textDialogs = 0;
    customTextEditors.clear();
    if (timer) clearInterval(timer);
    timer = undefined;
    for (const path of [file, temporary]) {
      try {
        unlinkSync(path);
      } catch {}
    }
    refreshTmux();
  }

  pi.on("session_start", (_event, ctx) => {
    if (
      process.platform !== "darwin" ||
      ctx.mode !== "tui" ||
      !ctx.hasUI ||
      (!process.env.WEZTERM_PANE && !process.env.TMUX)
    )
      return;
    if (enabled) {
      process.removeListener("exit", cleanup);
      cleanup();
    }
    enabled = true;
    suspended = false;
    last = "";
    // Built-in text dialogs (including ask_user_question's answer editor)
    // are Chinese input areas too. Select/confirm dialogs remain ABC.
    const ui = ctx.ui;
    const oldEditor = ui.editor;
    const oldInput = ui.input;
    const oldCustom = ui.custom;
    const dialogEditor: typeof ui.editor = async (...args) => {
      textDialogs++;
      report();
      try {
        return await oldEditor.apply(ui, args);
      } finally {
        textDialogs--;
        report();
      }
    };
    const dialogInput: typeof ui.input = async (...args) => {
      textDialogs++;
      report();
      try {
        return await oldInput.apply(ui, args);
      } finally {
        textDialogs--;
        report();
      }
    };
    const dialogCustom: typeof ui.custom = async (factory, options) => {
      let component: Awaited<ReturnType<typeof factory>> | undefined;
      let restoreRender: (() => void) | undefined;
      try {
        return await oldCustom(async (...args) => {
          const element = await factory(...args);
          component = element;
          const originalRender = element.render;
          let initialFakeCursor: boolean | undefined;
          element.render = function (width: number) {
            const lines = originalRender.call(element, width);
            // Public cursor marker covers properly focused fields (quiz notes).
            // Older widgets omit Editor.focused: their newly appearing fake
            // cursor still identifies entering Other/custom-answer mode.
            const fakeCursor = lines.some((line) =>
              line.includes("\x1b_pi:fc\x07"),
            );
            initialFakeCursor ??= fakeCursor;
            const textFocus = hasCustomTextFocus(lines, initialFakeCursor);
            if (textFocus) customTextEditors.add(element);
            else customTextEditors.delete(element);
            report();
            return lines;
          };
          restoreRender = () => {
            element.render = originalRender;
          };
          return element;
        }, options);
      } finally {
        restoreRender?.();
        if (component) customTextEditors.delete(component);
        report();
      }
    };
    ui.editor = dialogEditor;
    ui.input = dialogInput;
    ui.custom = dialogCustom;
    restoreDialogs = () => {
      if (ui.editor === dialogEditor) ui.editor = oldEditor;
      if (ui.input === dialogInput) ui.input = oldInput;
      if (ui.custom === dialogCustom) ui.custom = oldCustom;
    };
    ctx.ui.setEditorComponent((tui, theme, keys) => {
      // Public lifecycle also covers external editors opened from dialogs.
      tuiStopped = false;
      const oldStop = tui.stop;
      const oldStart = tui.start;
      const stop: typeof tui.stop = (...args) => {
        tuiStopped = true;
        report();
        return oldStop.apply(tui, args);
      };
      const start: typeof tui.start = (...args) => {
        const value = oldStart.apply(tui, args);
        tuiStopped = false;
        report();
        return value;
      };
      tui.stop = stop;
      tui.start = start;
      restoreTui = () => {
        if (tui.stop === stop) tui.stop = oldStop;
        if (tui.start === start) tui.start = oldStart;
      };
      class InputContextEditor extends CustomEditor {
        constructor() {
          super(tui, theme, keys);
          let focus = this.focused;
          Object.defineProperty(this, "focused", {
            configurable: true,
            get: () => focus,
            set: (value: boolean) => {
              focus = value;
              report();
            },
          });
        }
        render(width: number) {
          suspended = false;
          const lines = super.render(width);
          report();
          return lines;
        }
        handleInput(data: string) {
          if (keys.matches(data, "app.editor.external")) {
            suspended = true;
            report();
          }
          super.handleInput(data);
          report();
        }
      }
      editor = new InputContextEditor();
      return editor;
    });
    report(true);
    refreshTmux();
    // A short lease makes SIGKILL/crashes fail back to ABC instead of leaving
    // a stale Chinese context forever. The timer doesn't read user input.
    timer = setInterval(() => report(true), 2000);
    timer.unref();
    process.once("exit", cleanup);
  });
  pi.on("session_shutdown", () => {
    process.removeListener("exit", cleanup);
    cleanup();
  });
}
