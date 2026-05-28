import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const root = dirname(fileURLToPath(import.meta.url));
const read = (name) => readFileSync(join(root, name), 'utf8');

const chat = read('chat.html');
const discover = read('discover.html');
const msConfig = read('js/ms-config.js');
const msApi = read('js/ms-api.js');
const matchSpec = readFileSync(join(root, '../docs/MATCH_SPEC.md'), 'utf8');
const combined = `${chat}\n${discover}\n${msConfig}\n${msApi}`;

test('BFF URL points to ms.show and token stays off frontend', () => {
  assert.match(msConfig, /PETSOUL_BFF_URL.*ms\.show/);
  assert.doesNotMatch(combined, /MS_TOKEN\s*=/);
  assert.doesNotMatch(combined, /ms-[a-f0-9]{20,}/i);
});

test('match formula documented', () => {
  assert.match(matchSpec, /55.*35.*10/);
  assert.match(combined, /match-engine\.js/);
});

test('agent messages require owner confirmation in chat', () => {
  assert.match(chat, /agent-preview/);
  assert.match(chat, /確認發送/);
  assert.match(chat, /所有真實消息發送前需主人確認/);
  assert.match(chat, /臨時會話 · 同場 · 不加微信/);
});

test('discover uses compass naming and pass privacy toast', () => {
  assert.match(discover, /緣分羅盤/);
  assert.match(discover, /寵物 Agent · 破冰建議/);
  assert.match(discover, /passToast/);
  assert.match(discover, /對方不會收到通知/);
  assert.match(discover, /replaceChildren/);
});

test('discover drawer hides hero to avoid text overlap', () => {
  assert.match(discover, /clue-drawer\[data-open="1"\]/);
});
