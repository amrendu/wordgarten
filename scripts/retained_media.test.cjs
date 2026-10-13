const {test} = require('node:test');
const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const {canReuseMedia, verifyMediaBytes} = require('./retained_media.cjs');
const original = {
  id:'apfel', term:'der Apfel', part:'noun', translation:'apple',
  example:'Ich esse einen Apfel.', exampleTranslation:'I eat an apple.',
};

test('keeps unchanged local media when the website moves its files', () => {
  const relocated = {...original, artworkAsset:{url:'/api/vocabulary/artwork/apfel'}};
  for (const kind of ['image','term','example','card']) {
    assert.equal(canReuseMedia(original, relocated, kind), true);
  }
});

test('keeps pronunciation but invalidates recordings of a changed example', () => {
  const changed = {...original, example:'Der Apfel ist rot.'};
  assert.equal(canReuseMedia(original, changed, 'term'), true);
  assert.equal(canReuseMedia(original, changed, 'example'), false);
  assert.equal(canReuseMedia(original, changed, 'card'), false);
});

test('invalidates full-card narration when its English example changes', () => {
  const changed = {...original, exampleTranslation:'I am eating an apple.'};
  assert.equal(canReuseMedia(original, changed, 'example'), true);
  assert.equal(canReuseMedia(original, changed, 'card'), false);
});

test('does not reuse illustrations or narration for a changed meaning', () => {
  const changed = {...original, translation:'pear'};
  assert.equal(canReuseMedia(original, changed, 'image'), false);
  assert.equal(canReuseMedia(original, changed, 'card'), false);
});

test('does not reuse media for a different word or teaching sense', () => {
  for (const changed of [{...original, term:'die Birne'}, {...original, sense:'another sense'}]) {
    for (const kind of ['image','term','example','card']) {
      assert.equal(canReuseMedia(original, changed, kind), false);
    }
  }
});

test('checks retained recordings against the private source inventory', () => {
  const bytes = Buffer.from('original recording');
  const record = {bytes:bytes.length, sha256:crypto.createHash('sha256').update(bytes).digest('hex')};
  assert.doesNotThrow(() => verifyMediaBytes(bytes, record, 'apfel:term'));
  assert.throws(() => verifyMediaBytes(Buffer.from('different recording'), record, 'apfel:term'),
    /Source media differs/);
});
