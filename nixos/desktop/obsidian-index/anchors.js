"use strict";

function captionFor(selection) {
  return selection
    .split(/\r?\n/)
    .filter((line) => !/^\s*(?:```|~~~)/.test(line))
    .map((line) =>
      line
        .trim()
        .replace(/^(?:>\s*)+/, "")
        .replace(/^#{1,6}\s+/, "")
        .replace(/^(?:[-+*]|\d+[.)])\s+(?:\[[ xX]\]\s+)?/, "")
        .replace(/\s*\^[a-zA-Z0-9-]+\s*$/, "")
        .replace(/!?\[\[([^\]]+)\]\]/g, (_, link) => link.split("|").pop())
        .replace(/\[([^\]]+)\]\([^)]*\)/g, "$1")
        .replace(/`([^`]+)`/g, "$1")
        .replace(/(\*\*|__)(.*?)\1/g, "$2"),
    )
    .join(" ")
    .replace(/\s+/g, " ")
    .replace(/\[/g, "［")
    .replace(/\]/g, "］")
    .replace(/\|/g, "｜")
    .trim();
}

// Metadata sections describe complete Markdown blocks. A multi-block selection
// links to its first block; never insert a marker inside code, lists or callouts.
function planAnchor(text, from, to, cache, newId) {
  const selection = text.slice(from, to);
  const first = selection.search(/\S/);
  const caption = captionFor(selection);
  if (first < 0 || !caption) throw new Error("请先选中需要摘取的文字。");
  const start = from + first;
  const covers = (item) =>
    item.position.start.offset <= start && start < item.position.end.offset;
  const span = (item) => item.position.end.offset - item.position.start.offset;
  const existing = Object.values(cache?.blocks || {})
    .filter(covers)
    .sort((a, b) => span(a) - span(b))[0];
  if (existing) return { text, id: existing.id, caption };

  const section = (cache?.sections || [])
    .filter(covers)
    .sort((a, b) => span(a) - span(b))[0];
  if (!section || section.type === "yaml") {
    throw new Error("此选区暂时无法定位，请选择正文并等待笔记保存后重试。");
  }
  let end = section.position.end.offset;
  while (end > section.position.start.offset && /[\r\n]/.test(text[end - 1]))
    end--;
  if (end > text.length || (end < text.length && !/[\r\n]/.test(text[end]))) {
    throw new Error("笔记索引尚未更新，请稍后重新摘取。");
  }
  const block = text.slice(section.position.start.offset, end);
  const inlineId = block.match(/(?:^|\s)\^([a-zA-Z0-9-]+)$/);
  const followingId = text
    .slice(end)
    .match(/^(?:\r?\n[ \t]*)+\^([a-zA-Z0-9-]+)(?:\r?\n|$)/);
  const id = inlineId?.[1] || followingId?.[1];
  if (id) return { text, id, caption };
  if (!/^[a-zA-Z0-9-]+$/.test(newId) || text.includes(`^${newId}`)) {
    throw new Error("定位标记冲突，请重试。");
  }
  const newline = text.includes("\r\n") ? "\r\n" : "\n";
  const marker =
    section.type === "paragraph"
      ? ` ^${newId}`
      : `${newline}${newline}^${newId}`;
  return {
    text: text.slice(0, end) + marker + text.slice(end),
    id: newId,
    caption,
  };
}

function appendEntry(text, entry) {
  if (text.split(/\r?\n/).includes(entry)) return text;
  const newline = text.includes("\r\n") ? "\r\n" : "\n";
  const separator =
    text.length === 0 ? "" : text.endsWith(newline) ? "" : newline;
  return text + separator + entry + newline;
}

module.exports = { captionFor, planAnchor, appendEntry };
