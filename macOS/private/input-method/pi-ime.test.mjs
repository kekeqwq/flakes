import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { stripTypeScriptTypes } from 'node:module';
const source = readFileSync(process.argv[2], 'utf8').replace(
  /^import \{ CustomEditor, type ExtensionAPI \} from .*;$/m,
  'class CustomEditor {}');
const mod = await import('data:text/javascript;base64,' + Buffer.from(stripTypeScriptTypes(source)).toString('base64'));
test('Chinese only for focused plain-text editor', () => {
  assert.equal(mod.isChineseEditor(true, false, '中文问题'), true);
  assert.equal(mod.isChineseEditor(false, false, '中文问题'), false);
  assert.equal(mod.isChineseEditor(true, true, 'inline text suggestions'), true);
  assert.equal(mod.isChineseEditor(true, false, '/model'), false);
  assert.equal(mod.isChineseEditor(true, false, '!ls'), false);
  assert.equal(mod.isChineseEditor(true, false, ''), true);
});
test('dropped absolute image paths stay Chinese, slash commands stay ABC', () => {
  for (const text of [
    '/var/folders/4d/temp/Screenshot\\ 2026-11-03.png ',
    '/Users/keke/Pictures/test.png 请分析',
    '/tmp/image.png', '/image.png', ' /tmp/a.png\n说明',
  ]) {
    assert.equal(mod.isChineseEditor(true, false, text), true, text);
    assert.equal(mod.isChineseEditor(false, false, text), false, text);
  }
  for (const text of ['/', '/mo', '/model', '/model gpt', '/reload', '!ls']) {
    assert.equal(mod.isChineseEditor(true, false, text), false, text);
  }
});
test('custom text focus distinguishes Other answers and quiz notes from menus', () => {
  const fake = '\x1b_pi:fc\x07 \x1b_pi:/fc\x07';
  const focused = '\x1b_pi:c\x07' + fake;
  assert.equal(mod.hasCustomTextFocus(['menu'], false), false);
  assert.equal(mod.hasCustomTextFocus([fake], false), true); // Other answer opens
  assert.equal(mod.hasCustomTextFocus([fake], true), false); // idle quiz note
  assert.equal(mod.hasCustomTextFocus([focused], true), true); // Tab into note
  assert.equal(mod.hasCustomTextFocus(['menu'], true), false);
});
test('factory registers lifecycle without creating timers or files', () => {
  const events = new Map();
  mod.default({ on(name, callback) { events.set(name, callback); } });
  assert.deepEqual([...events.keys()], ['session_start', 'session_shutdown']);
});
