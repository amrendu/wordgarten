const fs = require('node:fs');
const path = require('node:path');
const {createRequire} = require('node:module');
const root = path.resolve(__dirname,'..');
const reference = path.resolve(process.argv[2] || path.join(root,'../german-exam-prep'));
const sharp = createRequire(path.join(reference,'package.json'))('sharp');
const source = fs.readFileSync(path.join(root,'design/brand/sprouting-dictionary-v1.png'));
async function icon(target,size,maskable=false){
  const inner=maskable?Math.round(size*.8):size;
  const before=Math.floor((size-inner)/2),after=size-inner-before;
  let image=sharp(source).resize(inner,inner,{fit:'contain'});
  // Extra margin keeps the whole mark inside the safe area of PWA icon masks.
  if(maskable)image=image.extend({top:before,left:before,bottom:after,right:after,background:'#477357'});
  await image.flatten({background:'#477357'}).png({compressionLevel:9}).toFile(path.join(root,target));
}
(async()=>{
  fs.mkdirSync(path.join(root,'assets/brand'),{recursive:true});
  await icon('assets/brand/wortgarten-v1.png',256);
  for(const [density,scale]of [['mdpi',1],['hdpi',1.5],['xhdpi',2],['xxhdpi',3],['xxxhdpi',4]]){
    const folder=path.join(root,`android/app/src/main/res/drawable-${density}`);
    fs.mkdirSync(folder,{recursive:true});
    await icon(`android/app/src/main/res/drawable-${density}/splash_logo.png`,Math.round(128*scale));
  }
  for(const [scale,name]of [[1,'LaunchImage.png'],[2,'LaunchImage@2x.png'],[3,'LaunchImage@3x.png']]){
    await icon(`ios/Runner/Assets.xcassets/LaunchImage.imageset/${name}`,128*scale);
  }
  for(const [density,size] of [['mdpi',48],['hdpi',72],['xhdpi',96],['xxhdpi',144],['xxxhdpi',192]]) {
    await icon(`android/app/src/main/res/mipmap-${density}/ic_launcher.png`,size);
  }
  const ios='ios/Runner/Assets.xcassets/AppIcon.appiconset';
  const contents=JSON.parse(fs.readFileSync(path.join(root,ios,'Contents.json')));
  for(const image of contents.images){
    await icon(`${ios}/${image.filename}`,Math.round(parseFloat(image.size)*parseFloat(image.scale)));
  }
  for(const size of [192,512]){
    await icon(`web/icons/Icon-${size}.png`,size);
    await icon(`web/icons/Icon-maskable-${size}.png`,size,true);
  }
  await icon('web/favicon.png',48);
  console.log('Generated the selected Wortgarten logo for the app, Android, iOS and web.');
})().catch(error=>{console.error(error);process.exitCode=1;});
