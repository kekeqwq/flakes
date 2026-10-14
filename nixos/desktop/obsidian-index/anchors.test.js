"use strict";
const test = require("node:test");
const assert = require("node:assert/strict");
const { captionFor, planAnchor, appendEntry } = require("./anchors");
const section = (type, start, end) => ({
  type,
  position: { start: { offset: start }, end: { offset: end } },
});
const cache = (...sections) => ({ sections });

test("paragraph selection preserves all text and anchors the complete paragraph", () => {
  const text = "first line\nsecond line\n\nother";
  const result = planAnchor(
    text,
    11,
    22,
    cache(section("paragraph", 0, 22)),
    "test-id",
  );
  assert.equal(result.text, "first line\nsecond line ^test-id\n\nother");
  assert.equal(result.caption, "second line");
});
test("multiblock selection links to its first block, not its last", () => {
  const text = "one\n\ntwo";
  const result = planAnchor(
    text,
    0,
    text.length,
    cache(section("paragraph", 0, 3), section("paragraph", 5, 8)),
    "test-id",
  );
  assert.equal(result.text, "one ^test-id\n\ntwo");
  assert.equal(result.caption, "one two");
});
test("heading text remains unchanged so existing heading links keep working", () => {
  const text = "# 标题\n\n正文";
  const result = planAnchor(
    text,
    0,
    4,
    cache(section("heading", 0, 4)),
    "test-id",
  );
  assert.equal(result.text, "# 标题\n\n^test-id\n\n正文");
  assert.equal(result.caption, "标题");
});
test("fenced code markers remain outside the code", () => {
  const text = "```python\nprint(1)\n```\n\nnext";
  const result = planAnchor(
    text,
    10,
    18,
    cache(section("code", 0, 22)),
    "test-id",
  );
  assert.equal(result.text, "```python\nprint(1)\n```\n\n^test-id\n\nnext");
});
test("lists, callouts and tables use standalone markers", () => {
  for (const [type, text] of [
    ["list", "- one\n- two"],
    ["blockquote", "> [!note]\n> text"],
    ["table", "| a |\n|---|\n| b |"],
  ]) {
    const result = planAnchor(
      text,
      0,
      text.length,
      cache(section(type, 0, text.length)),
      "test-id",
    );
    assert.equal(result.text, text + "\n\n^test-id");
  }
});
test("existing cached IDs are reused without modifying the source", () => {
  const text = "one ^existing";
  const blocks = {
    existing: {
      id: "existing",
      position: { start: { offset: 0 }, end: { offset: text.length } },
    },
  };
  const result = planAnchor(text, 0, 3, { blocks }, "test-id");
  assert.equal(result.id, "existing");
  assert.equal(result.text, text);
});
test("existing IDs are reused even before cache update", () => {
  for (const text of ["one ^existing", "one\n\n^existing"]) {
    const result = planAnchor(
      text,
      0,
      3,
      cache(section("paragraph", 0, text.split("\n")[0].length)),
      "test-id",
    );
    assert.equal(result.id, "existing");
    assert.equal(result.text, text);
  }
});
test("selection whitespace skips to the first selected content", () => {
  const text = "one\n\ntwo";
  const result = planAnchor(
    text,
    3,
    8,
    cache(section("paragraph", 0, 3), section("paragraph", 5, 8)),
    "test-id",
  );
  assert.equal(result.text, "one\n\ntwo ^test-id");
});
test("CRLF is preserved", () => {
  const text = "- one\r\n- two\r\n";
  const result = planAnchor(
    text,
    0,
    12,
    cache(section("list", 0, 12)),
    "test-id",
  );
  assert.equal(result.text, "- one\r\n- two\r\n\r\n^test-id\r\n");
});
test("frontmatter, stale metadata and colliding IDs are rejected", () => {
  assert.throws(() =>
    planAnchor(
      "---\na: b\n---",
      4,
      8,
      cache(section("yaml", 0, 12)),
      "test-id",
    ),
  );
  assert.throws(() =>
    planAnchor(
      "one changed",
      0,
      3,
      cache(section("paragraph", 0, 3)),
      "test-id",
    ),
  );
  assert.throws(() =>
    planAnchor("one", 0, 3, cache(section("paragraph", 0, 3)), "bad_id"),
  );
  assert.throws(() =>
    planAnchor(
      "one\n\nother ^test-id",
      0,
      3,
      cache(section("paragraph", 0, 3)),
      "test-id",
    ),
  );
});
test("caption is a single safe wiki-link alias without changing identifiers", () => {
  assert.equal(
    captionFor("## **重点**\n- `some_name` | [[Python|链接]]"),
    "重点 some_name ｜ 链接",
  );
  assert.equal(captionFor("text ]] | [literal]"), "text ］］ ｜ ［literal］");
});
test("append preserves target content and avoids identical entries", () => {
  const entry = "- [[Python#^id|重点]]";
  assert.equal(appendEntry("", entry), entry + "\n");
  assert.equal(
    appendEntry("# Checklist\n", entry),
    "# Checklist\n" + entry + "\n",
  );
  assert.equal(appendEntry(entry + "\n", entry), entry + "\n");
});
