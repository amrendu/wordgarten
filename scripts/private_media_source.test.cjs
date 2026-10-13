const {test} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const crypto = require('node:crypto');
const {privateMediaSource} = require('./private_media_source.cjs');

function fixture(t) {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'wortgarten-private-media-'));
  t.after(() => fs.rmSync(root, {recursive:true, force:true}));
  return {root, reference:path.join(root, 'reference')};
}
function record(bytes) {
  return {key:'protected/images/vocabulary/apfel.hash.webp', bytes:bytes.length,
    sha256:crypto.createHash('sha256').update(bytes).digest('hex')};
}
function write(file, bytes) {
  fs.mkdirSync(path.dirname(file), {recursive:true}); fs.writeFileSync(file, bytes);
}

test('reads verified originals from the protected reference folder', async t => {
  const dirs = fixture(t), bytes = Buffer.from('original image'), asset = record(bytes);
  const source = path.join(dirs.reference, asset.key); write(source, bytes);
  const reader = privateMediaSource({...dirs, allowDownload:false});
  assert.equal(await reader.find(asset), source);
  assert.equal(reader.downloads(), 0);
});

test('uses the exact cached original after source files are removed', async t => {
  const dirs = fixture(t), bytes = Buffer.from('new C1 image'), asset = record(bytes);
  const cached = path.join(dirs.root, 'output/reference-media', asset.key); write(cached, bytes);
  const reader = privateMediaSource({...dirs, allowDownload:false});
  assert.equal(await reader.find(asset), cached);
});

test('rejects stale cached bytes instead of treating the old image as new', async t => {
  const dirs = fixture(t), asset = record(Buffer.from('new image'));
  write(path.join(dirs.root, 'output/reference-media', asset.key), Buffer.from('old image'));
  const reader = privateMediaSource({...dirs, allowDownload:false});
  await assert.rejects(reader.find(asset), /Source media differs/);
});

test('does not access unrelated storage objects or fetch without the explicit flag', async t => {
  const dirs = fixture(t), reader = privateMediaSource({...dirs, allowDownload:false});
  assert.equal(await reader.find(record(Buffer.from('not cached'))), null);
  await assert.rejects(reader.find({key:'protected/accounts/data.json'}), /Invalid private vocabulary/);
  await assert.rejects(reader.find({key:'protected/images/vocabulary/../outside.webp'}), /Invalid private vocabulary/);
});
