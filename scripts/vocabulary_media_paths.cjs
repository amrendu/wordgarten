// Resolve organized source media without assuming that an ID's prefix is its
// level. Shared vocabulary can belong to several levels and exam collections.
const fs = require('node:fs');
const path = require('node:path');

function mediaFiles(root, extension) {
  const byName = new Map();
  function scan(folder) {
    if (!fs.existsSync(folder)) return;
    for (const entry of fs.readdirSync(folder, {withFileTypes:true})) {
      const file = path.join(folder, entry.name);
      if (entry.isDirectory()) scan(file);
      else if (entry.isFile() && entry.name.endsWith(extension)) {
        const matches = byName.get(entry.name) ?? [];
        matches.push(file);
        byName.set(entry.name, matches);
      }
    }
  }
  scan(root);
  return function resolve(name, folder) {
    if (path.basename(name) !== name) throw new Error(`Unsafe media filename: ${name}`);
    const matches = byName.get(name) ?? [];
    if (folder) {
      if (!/^[a-z0-9-]+$/i.test(folder)) throw new Error(`Unsafe media folder: ${folder}`);
      const organized = path.join(root, folder.toLowerCase(), name);
      if (matches.includes(organized)) return organized;
    }
    const flat = path.join(root, name);
    if (matches.includes(flat)) return flat;
    if (matches.length > 1) {
      const first = fs.readFileSync(matches[0]);
      if (matches.some(file => !fs.readFileSync(file).equals(first))) {
        throw new Error(`Conflicting source media for ${name}: ${matches.join(', ')}`);
      }
    }
    return matches[0] ?? null;
  };
}

module.exports = {mediaFiles};
