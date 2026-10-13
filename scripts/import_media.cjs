// Import only vocabulary media referenced by known words. PNG generation
// originals and unrelated exam listening tracks are not application assets.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const {createRequire} = require('node:module');
const {mediaFiles} = require('./vocabulary_media_paths.cjs');
const {canReuseMedia, verifyMediaBytes} = require('./retained_media.cjs');
const {privateMediaSource} = require('./private_media_source.cjs');

module.exports = async function importMedia({reference, root, words, lessons, previousWords=[], fetchPrivateMedia=false}) {
  const req = createRequire(path.join(reference, 'package.json'));
  const sharp = req('sharp');
  const publicRoot = path.join(reference, 'public');
  const manifest = JSON.parse(fs.readFileSync(path.join(reference, 'src/data/vocabulary-art-manifest.json')));
  const audioManifestPath = path.join(reference, 'src/data/vocabulary-audio-manifest.json');
  const audioManifest = fs.existsSync(audioManifestPath) ? JSON.parse(fs.readFileSync(audioManifestPath)) : {};
  const generated = JSON.parse(fs.readFileSync(path.join(reference, 'src/data/vocabulary-artwork.json')));
  const wordImage = mediaFiles(path.join(publicRoot, 'vocabulary-art'), '.webp');
  const wordAudio = mediaFiles(path.join(publicRoot, 'audio/vocabulary'), '.mp3');
  const protectedImage = mediaFiles(path.join(reference, 'protected/images/vocabulary-sources'), '.webp');
  const protectedAudio = mediaFiles(path.join(reference, 'protected/audio/vocabulary'), '.mp3');
  const privateInventoryPath = path.join(reference, 'src/data/vocabulary-media.json');
  const privateInventory = fs.existsSync(privateInventoryPath) ? JSON.parse(fs.readFileSync(privateInventoryPath)) : {};
  const privateSource = privateMediaSource({reference,root,allowDownload:fetchPrivateMedia});
  const oldWords = new Map(previousWords.map(word => [word.id, word]));
  const previousPath = path.join(root, 'assets/data/media-inventory.json');
  const previous = fs.existsSync(previousPath) ? JSON.parse(fs.readFileSync(previousPath)) : {files:[]};
  const files = new Set();
  const topicImages = {};
  const counts = {wordImages:0, customWordImages:0, topicImages:0, termAudio:0, exampleAudio:0, cardAudio:0};
  const retained = {wordImages:0, termAudio:0, exampleAudio:0, cardAudio:0};
  const customWordImageIds = new Set();
  const previousCustomImages = new Set(previous.customWordImageIds??[]);
  const missing = [];
  for (const folder of ['words','topics','audio']) fs.mkdirSync(path.join(root,'assets/media',folder),{recursive:true});

  function publicFile(url) {
    if (!url?.startsWith('/vocabulary-artwork/')) return null;
    const source = path.resolve(publicRoot, '.' + url);
    return source.startsWith(publicRoot + path.sep) && fs.existsSync(source) ? source : null;
  }
  function existingAsset(asset) {
    return asset?.startsWith('assets/media/') &&
      path.resolve(root, asset).startsWith(path.join(root, 'assets/media')+path.sep) &&
      fs.existsSync(path.join(root, asset)) ? asset : null;
  }
  async function imageAsset(source, category, name) {
    const bytes = fs.readFileSync(source);
    const digest = crypto.createHash('sha256').update(bytes).update('mobile-512-q84-v1').digest('hex').slice(0,12);
    const destination = `assets/media/${category}/${name}.${digest}.webp`;
    if (!fs.existsSync(path.join(root,destination))) {
      await sharp(bytes, source.endsWith('.svg')?{density:160}:{})
        .resize(512,512,{fit:'inside',withoutEnlargement:true}).webp({quality:84}).toFile(path.join(root,destination));
    }
    files.add(destination);
    return destination;
  }
  async function importWord(word) {
    if (!/^[a-z0-9][a-z0-9-]*$/.test(word.id)) throw new Error(`Unsafe word ID: ${word.id}`);
    const old = oldWords.get(word.id);
    const record = privateInventory.artwork?.[word.id];
    const override = wordImage(word.id+'.webp', manifest.levels?.[word.id]) ??
      protectedImage(word.id+'.webp', manifest.levels?.[word.id]);
    const protectedSource = override ? null : await privateSource.find(record);
    const previousImage = canReuseMedia(old, word, 'image') && existingAsset(old.imageAsset);
    if (record?.contentType === 'image/webp' && !override && !protectedSource) {
      throw new Error(`Private source illustration unavailable: ${word.id}. Import with --fetch-private-media to retrieve the exact original.`);
    }
    const source = override ?? protectedSource ??
      (previousImage ? null : publicFile(generated[word.id]?.url ?? word.artworkAsset?.url));
    if (source) {
      if (source === protectedSource) verifyMediaBytes(fs.readFileSync(source), record, word.id);
      word.imageAsset = await imageAsset(source,'words',word.id);
      counts.wordImages++;
      if(source===override || record?.contentType === 'image/webp') customWordImageIds.add(word.id);
    } else if (previousImage) {
      word.imageAsset = previousImage;
      files.add(previousImage); counts.wordImages++; retained.wordImages++;
      if (previousCustomImages.has(word.id) || record?.contentType === 'image/webp') customWordImageIds.add(word.id);
    } else missing.push({kind:'image',wordId:word.id});
    const audio = {};
    for(const [kind,suffix] of [['term',''],['example','.example'],['card','.card']]) {
      const record = privateInventory.audio?.[`${word.id}:${kind}`];
      let source = wordAudio(word.id+suffix+'.mp3', audioManifest.levels?.[word.id]) ??
        protectedAudio(word.id+suffix+'.mp3', audioManifest.levels?.[word.id]);
      const previousAudio = canReuseMedia(old, word, kind) && existingAsset(old.audioAssets?.[kind]);
      let previousBytes;
      if (!source && previousAudio) {
        previousBytes=fs.readFileSync(path.join(root, previousAudio));
        try { verifyMediaBytes(previousBytes, record, `${word.id}:${kind}`); }
        catch(error) { if(!fetchPrivateMedia)throw error; previousBytes=null; }
      }
      if(!source && !previousBytes) source=await privateSource.find(record);
      if(!source&&!previousAudio){
        if(record)throw new Error(`Recording only available in private storage: ${word.id}:${kind}. Export it locally before importing.`);
        continue;
      }
      const bytes=source ? fs.readFileSync(source) : previousBytes;
      const mp3=bytes.length>16&&(bytes.subarray(0,3).toString()==='ID3'||bytes[0]===0xff&&(bytes[1]&0xe0)===0xe0);
      if(!mp3){missing.push({kind:'unfinished-audio',wordId:word.id,audioKind:kind});continue;}
      const destination = `assets/media/audio/${word.id}${suffix}.mp3`;
      if(source)fs.writeFileSync(path.join(root,destination),bytes);
      else retained[kind+'Audio']++;
      files.add(destination);audio[kind]=destination;counts[kind+'Audio']++;
    }
    if(Object.keys(audio).length)word.audioAssets=audio;
  }
  // A bounded worker pool keeps image conversion memory use predictable.
  let cursor=0,completed=0;
  let failure;
  try {
    await Promise.all(Array.from({length:6},async()=>{
      while(cursor<words.length&&!failure){
        const word=words[cursor++];
        try {
          await importWord(word);completed++;
          if(completed%500===0)process.stdout.write(`Imported media for ${completed}/${words.length} words.\n`);
        } catch(error) { failure??=error; }
      }
    }));
    if(failure)throw failure;
  } finally { privateSource.close(); }
  for(const kind of new Set(lessons.map(l=>l.artwork))) {
    const source=wordImage(`topic-${kind}.webp`, 'topics') ?? protectedImage(`topic-${kind}.webp`, 'topics');
    if(source){topicImages[kind]=await imageAsset(source,'topics',kind);counts.topicImages++;}
    else if(existingAsset(previous.topicImages?.[kind])) {
      topicImages[kind]=previous.topicImages[kind]; files.add(topicImages[kind]); counts.topicImages++;
    }
  }
  const missingKinds=[...new Set(lessons.map(l=>l.artwork))].filter(kind=>!topicImages[kind]&&!fs.existsSync(path.join(root,'assets/artwork',kind+'.svg')));
  if(missingKinds.length){
    const React=req('react');const {renderToStaticMarkup}=req('react-dom/server');
    const {VocabularyTopicArtwork}=req('./src/components/vocabulary/VocabularyTopicArtwork.tsx');
    for(const kind of missingKinds){
      const svg=renderToStaticMarkup(React.createElement('svg',{xmlns:'http://www.w3.org/2000/svg',viewBox:'0 0 280 210',fill:'none'},
        React.createElement('path',{d:'M38 100C22 51 75 24 133 32c57-22 113 10 109 65 19 56-29 91-84 81-62 17-121-10-120-78Z',fill:'#E6F0E5'}),
        React.createElement('g',{stroke:'#334F45',strokeWidth:2.4,strokeLinecap:'round',strokeLinejoin:'round'},React.createElement(VocabularyTopicArtwork,{kind}))));
      fs.writeFileSync(path.join(root,'assets/artwork',kind+'.svg'),svg);
    }
  }
  counts.customWordImages=customWordImageIds.size;
  const inventory={importedAt:new Date().toISOString(),sourceGeneratedAt:manifest.generatedAt,sourceAudioGeneratedAt:audioManifest.generatedAt,counts,retained,privateMediaDownloads:privateSource.downloads(),customWordImageIds:[...customWordImageIds].sort(),
    topicImages,missing,files:[...files].sort(),bytes:[...files].reduce((sum,file)=>sum+fs.statSync(path.join(root,file)).size,0)};
  fs.mkdirSync(path.join(root,'assets/data'),{recursive:true});
  fs.writeFileSync(previousPath,JSON.stringify(inventory,null,2));
  // Remove only assets tracked by the previous generated inventory after every
  // new asset succeeded; never delete manually maintained workspace files.
  for(const old of previous.files??[])if(old.startsWith('assets/media/')&&!files.has(old)&&
    path.resolve(root,old).startsWith(path.join(root,'assets/media')+path.sep))fs.rmSync(path.join(root,old),{force:true});
  process.stdout.write(`Media complete: ${JSON.stringify(counts)}; ${(inventory.bytes/1024/1024).toFixed(1)} MiB.\n`);
  return {topicImages,counts,bytes:inventory.bytes};
};
