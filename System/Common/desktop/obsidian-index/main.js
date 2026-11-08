"use strict";
const { Plugin, FuzzySuggestModal, Notice } = require("obsidian");
const { planAnchor, appendEntry } = require("./anchors");

class DestinationPicker extends FuzzySuggestModal {
  constructor(app, source, preferred, choose) {
    super(app);
    this.source = source;
    this.preferred = preferred;
    this.choose = choose;
    this.setPlaceholder("搜索目标笔记，回车追加重点索引（Esc 取消）");
  }
  getItems() {
    return this.app.vault
      .getMarkdownFiles()
      .filter((file) => file.path !== this.source.path)
      .sort((a, b) =>
        a.path === this.preferred
          ? -1
          : b.path === this.preferred
            ? 1
            : a.path.localeCompare(b.path),
      );
  }
  getItemText(file) {
    return file.path.replace(/\.md$/, "");
  }
  onChooseItem(file) {
    this.choose(file);
  }
}

module.exports = class SelectionIndex extends Plugin {
  async onload() {
    this.settings = (await this.loadData()) || {};
    this.busy = false;
    this.addCommand({
      id: "append-selection",
      name: "摘取选区到指定笔记（保留原文）",
      editorCheckCallback: (checking, editor, view) => {
        const available =
          !!view.file && !!editor.getSelection().trim() && !this.busy;
        if (checking || !available) return available;
        const source = view.file;
        const original = editor.getValue();
        const from = editor.posToOffset(editor.getCursor("from"));
        const to = editor.posToOffset(editor.getCursor("to"));
        new DestinationPicker(
          this.app,
          source,
          this.settings.lastTarget,
          (target) => {
            void this.append(source, target, editor, original, from, to);
          },
        ).open();
        return true;
      },
    });
  }

  async append(source, target, editor, original, from, to) {
    if (this.busy) return;
    this.busy = true;
    let anchored;
    let sourceWritten = false;
    let targetWritten = false;
    try {
      if (
        editor.getValue() !== original ||
        (await this.app.vault.read(source)) !== original
      ) {
        throw new Error("原文尚未保存或选区已变化，请稍后重新选中并摘取。");
      }
      if (this.app.vault.getAbstractFileByPath(target.path) !== target) {
        throw new Error("目标笔记已移动或删除，请重试。");
      }
      const random = new Uint32Array(2);
      globalThis.crypto.getRandomValues(random);
      const id = `excerpt-${random[0].toString(36)}-${random[1].toString(36)}`;
      const plan = planAnchor(
        original,
        from,
        to,
        this.app.metadataCache.getFileCache(source),
        id,
      );
      anchored = plan.text;
      const entry =
        "- " +
        this.app.fileManager.generateMarkdownLink(
          source,
          target.path,
          `#^${plan.id}`,
          plan.caption,
        );
      if (anchored !== original) {
        await this.app.vault.process(source, (current) => {
          if (current !== original || editor.getValue() !== original) {
            throw new Error("原文刚刚发生变化，已取消摘取，请重试。");
          }
          return anchored;
        });
        sourceWritten = true;
      }
      let duplicate = false;
      await this.app.vault.process(target, (current) => {
        const result = appendEntry(current, entry);
        duplicate = result === current;
        return result;
      });
      targetWritten = true;
      this.settings.lastTarget = target.path;
      // Remembering the last destination is optional; a failure must not undo
      // an already successful index entry.
      try {
        await this.saveData(this.settings);
      } catch (error) {
        console.warn("Selection Index settings:", error);
      }
      new Notice(
        duplicate
          ? "该条目已存在，未重复添加。"
          : `已追加重点索引到 ${target.basename}；原文保留。`,
      );
    } catch (error) {
      if (sourceWritten && !targetWritten) {
        try {
          // Roll back only our exact write; never overwrite a concurrent edit.
          await this.app.vault.process(source, (current) =>
            current === anchored ? original : current,
          );
        } catch (rollbackError) {
          console.error("Selection Index rollback:", rollbackError);
        }
      }
      console.error("Selection Index:", error);
      new Notice(`摘取失败：${error.message || error}`);
    } finally {
      this.busy = false;
    }
  }
};
