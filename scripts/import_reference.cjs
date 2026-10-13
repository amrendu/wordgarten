// Read only the vocabulary/artwork of the reference project. Never copy its
// auth, billing, environment files, or browser-specific implementation.
const fs = require('node:fs');
const path = require('node:path');
const {createRequire} = require('node:module');
const {canReuseMedia} = require('./retained_media.cjs');
const root = path.resolve(__dirname, '..');
const args = process.argv.slice(2);
const dataOnly = args.includes('--data-only');
const includeMedia = args.includes('--include-media');
const fetchPrivateMedia = args.includes('--fetch-private-media');
const reference = path.resolve(args.find(arg => !arg.startsWith('--')) || path.join(root, '../german-exam-prep'));
const fromReference = createRequire(path.join(reference, 'package.json'));
const ts = fromReference('typescript');
for (const extension of ['.ts', '.tsx']) {
  require.extensions[extension] = (module, filename) => module._compile(
    ts.transpileModule(fs.readFileSync(filename, 'utf8'), {
      fileName: filename,
      compilerOptions: {module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2022,
        esModuleInterop: true, jsx: ts.JsxEmit.ReactJSX},
    }).outputText, filename);
}
const vocabulary = fromReference('./src/data/vocabulary.ts');
const {getVocabularyExamReference} = fromReference('./src/data/vocabulary-exam-reference.ts');
for (const dir of dataOnly ? ['assets/data'] : ['assets/data', 'assets/artwork', 'assets/fonts']) {
  fs.mkdirSync(path.join(root, dir), {recursive: true});
}
const words = vocabulary.vocabularyWords;
const lessons = vocabulary.allVocabularyLessons.map(lesson => ({
  ...lesson, words: undefined, wordIds: lesson.words.map(word => word.id),
  source: lesson.sourceReference
    ? getVocabularyExamReference(lesson.sourceReference, lesson.level ?? 'A1').title
    : `${lesson.level ?? 'A1'} vocabulary · original definitions and examples`,
  coverage: 'reference',
}));
const sources = [...new Set(lessons.map(lesson => lesson.level ?? 'A1'))].flatMap(level =>
  ['goethe', 'telc'].map(exam => ({level, exam, ...getVocabularyExamReference(exam, level)})));
async function exportReference(){
const previousPath=path.join(root,'assets/data/reference.json');
const previous=fs.existsSync(previousPath)?JSON.parse(fs.readFileSync(previousPath)):null;
const media=includeMedia?await require('./import_media.cjs')({reference,root,words,lessons,previousWords:previous?.words??[],fetchPrivateMedia}):previous?.media;
if(!includeMedia&&previous){
  const byId=new Map(previous.words.map(word=>[word.id,word]));
  for(const word of words){
    const old=byId.get(word.id);
    if(!old)continue;
    if(canReuseMedia(old,word,'image')&&old.imageAsset&&fs.existsSync(path.join(root,old.imageAsset)))word.imageAsset=old.imageAsset;
    const audio={};
    for(const [kind,asset] of Object.entries(old.audioAssets??{})){
      if(canReuseMedia(old,word,kind)&&fs.existsSync(path.join(root,asset)))audio[kind]=asset;
    }
    if(Object.keys(audio).length)word.audioAssets=audio;
  }
}
const catalog = {version: 1, importedAt: new Date().toISOString().slice(0, 10), words, lessons, sources,...(media?{media,topicImages:media.topicImages}:{})};
fs.writeFileSync(path.join(root, 'assets/data/reference.json'), JSON.stringify(catalog, null, 2));
if (dataOnly) {
  console.log(`Imported ${words.length} unique reference words and ${lessons.length} lessons.`);
  return;
}
const React = fromReference('react');
const {renderToStaticMarkup} = fromReference('react-dom/server');
const {VocabularyArtwork, GrowthArtwork} = fromReference('./src/components/vocabulary/VocabularyArtwork.tsx');
for (const kind of new Set(words.map(word => word.artwork))) {
  let svg = renderToStaticMarkup(React.createElement(VocabularyArtwork, {kind}));
  svg = svg.replace(/aria-hidden="true"/g, '').replace(/class=""/g, '');
  fs.writeFileSync(path.join(root, `assets/artwork/${kind}.svg`), svg);
}
fs.writeFileSync(path.join(root, 'assets/artwork/growth.svg'),
  renderToStaticMarkup(React.createElement(GrowthArtwork, {stage: 4}))
    .replaceAll('currentColor', '#477357'));
fs.copyFileSync(path.join(reference, 'src/assets/fonts/OFL.txt'), path.join(root, 'assets/fonts/OFL.txt'));
console.log(`Imported ${words.length} unique words, ${lessons.length} lessons, and original SVG artwork.`);
}
exportReference().catch(error=>{console.error(error);process.exitCode=1;});
