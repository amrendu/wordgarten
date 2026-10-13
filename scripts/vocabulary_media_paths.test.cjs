const {test} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const {mediaFiles} = require('./vocabulary_media_paths.cjs');

function fixture(t, files) {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'wortgarten-media-paths-'));
  t.after(() => fs.rmSync(root, {recursive:true, force:true}));
  for (const [relative, bytes] of Object.entries(files)) {
    const file = path.join(root, relative);
    fs.mkdirSync(path.dirname(file), {recursive:true});
    fs.writeFileSync(file, bytes);
  }
  return root;
}

test('uses the manifest level rather than the word ID prefix', t => {
  const root = fixture(t, {'a1/b1-shared.card.mp3':'current', 'b1/b1-shared.card.mp3':'old'});
  assert.equal(mediaFiles(root, '.mp3')('b1-shared.card.mp3', 'a1'),
    path.join(root, 'a1/b1-shared.card.mp3'));
});

test('supports flat media and organized topic images', t => {
  const root = fixture(t, {'apfel.webp':'word', 'topics/topic-school.webp':'topic'});
  const resolve = mediaFiles(root, '.webp');
  assert.equal(resolve('apfel.webp', 'a1'), path.join(root, 'apfel.webp'));
  assert.equal(resolve('topic-school.webp', 'topics'), path.join(root, 'topics/topic-school.webp'));
  assert.equal(resolve('missing.webp'), null);
});

test('discovers nested media missing from a stale manifest', t => {
  const root = fixture(t, {'c1/exam/new-word.example.mp3':'ready', 'source.png':'original'});
  const resolve = mediaFiles(root, '.mp3');
  assert.equal(resolve('new-word.example.mp3', 'b1'), path.join(root, 'c1/exam/new-word.example.mp3'));
  assert.equal(resolve('source.png'), null);
});

test('rejects conflicting duplicate files without a declared location', t => {
  const root = fixture(t, {'a1/shared.mp3':'one', 'b1/shared.mp3':'two'});
  assert.throws(() => mediaFiles(root, '.mp3')('shared.mp3'), /Conflicting source media/);
});

test('allows identical copies during folder migration', t => {
  const root = fixture(t, {'a1/shared.mp3':'same', 'b1/shared.mp3':'same'});
  const found = mediaFiles(root, '.mp3')('shared.mp3');
  assert.equal(fs.readFileSync(found, 'utf8'), 'same');
});

test('rejects paths outside the media root', t => {
  const root = fixture(t, {'apfel.mp3':'ready'});
  const resolve = mediaFiles(root, '.mp3');
  assert.throws(() => resolve('../apfel.mp3'), /Unsafe media filename/);
  assert.throws(() => resolve('apfel.mp3', '../outside'), /Unsafe media folder/);
});
