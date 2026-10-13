const crypto = require('node:crypto');

function canReuseMedia(old, word, kind) {
  if (!old || old.id !== word.id || old.term !== word.term ||
      old.part !== word.part || old.sense !== word.sense) return false;
  if (kind === 'image') return old.translation === word.translation;
  if (kind === 'term') return true;
  if (old.example !== word.example) return false;
  if (kind === 'example') return true;
  return kind === 'card' && old.translation === word.translation &&
    old.exampleTranslation === word.exampleTranslation;
}

function verifyMediaBytes(bytes, record, label) {
  if (!record) return;
  if (record.bytes !== undefined && record.bytes !== bytes.length ||
      record.sha256 && crypto.createHash('sha256').update(bytes).digest('hex') !== record.sha256) {
    throw new Error(`Source media differs from its private inventory: ${label}. Export the updated source file before importing.`);
  }
}

module.exports = {canReuseMedia, verifyMediaBytes};
