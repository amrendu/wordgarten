// Capture the real Flutter startup; no alternate HTML animation or app assets.
const fs = require('node:fs');
const path = require('node:path');
const {createRequire} = require('node:module');
const root = path.resolve(__dirname, '..');
const req = createRequire(path.resolve(root, '../german-exam-prep/package.json'));
const puppeteer = req('puppeteer');
const sharp = req('sharp');
const pause = ms => new Promise(resolve => setTimeout(resolve, ms));

(async () => {
  const output = path.join(root, 'output/screenshots');
  fs.mkdirSync(output, {recursive:true});
  const browser = await puppeteer.launch({headless:true,
    executablePath:'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
    userDataDir:'/tmp/wortgarten-splash-qa', args:['--no-sandbox','--disable-dev-shm-usage']});
  try {
    const page = await browser.newPage();
    await page.setViewport({width:360, height:800, deviceScaleFactor:2});
    await page.setBypassServiceWorker(true);
    await page.setCacheEnabled(false);
    await page.emulateMediaFeatures([{name:'prefers-reduced-motion',value:'no-preference'}]);
    const errors = [];
    page.on('pageerror', error => errors.push(error.message));
    await page.evaluateOnNewDocument(() => {
      window.__wortgartenFirstFrame = false;
      window.addEventListener('flutter-first-frame', () => { window.__wortgartenFirstFrame = true; }, {once:true});
    });
    await page.goto('http://127.0.0.1:7357', {waitUntil:'networkidle0'});
    // Dedicated preview profile only; show a returning learner's Home handoff.
    await page.evaluate(() => localStorage.setItem('flutter.wortgarten.progress.v1',
      JSON.stringify(JSON.stringify({schema:1, accessVersion:1, onboarded:true, level:'A1', goal:10}))));
    const frames = [], times = [];
    await page.reload({waitUntil:'domcontentloaded'});
    await page.waitForSelector('flutter-view');
    await page.waitForFunction(() => window.__wortgartenFirstFrame === true);
    const start = Date.now();
    for (let i = 0; i < 36; i++) {
      times.push(Date.now() - start);
      frames.push(await page.screenshot({type:'png'}));
      await pause(35);
    }
    if (errors.length) throw new Error(errors.join('\n'));
    const delays = times.map((time, i) => i < times.length - 1 ? times[i+1] - time : 850);
    const raw = await Promise.all(frames.map(frame => sharp(frame).resize(360,800).ensureAlpha().raw().toBuffer()));
    await sharp(Buffer.concat(raw), {raw:{width:360,height:800*raw.length,channels:4,pageHeight:800}})
      .gif({delay:delays,loop:0,effort:7,dither:.1})
      .toFile(path.join(output, 'splash-improved.gif'));
    const chosen = [0, times.findIndex(time => time >= 850), times.findIndex(time => time >= 1750), frames.length-1]
      .map(i => Math.max(0, i));
    const strips = await Promise.all(chosen.map(async (i, index) => ({
      input:await sharp(frames[i]).resize(360,800).toBuffer(), left:index*380, top:0,
    })));
    await sharp({create:{width:1500,height:800,channels:4,background:'#eef0e8'}})
      .composite(strips).png().toFile(path.join(output, 'splash-preview.png'));
    fs.writeFileSync(path.join(output,'splash-capture.json'), JSON.stringify({frames:frames.length,timesMs:times,delaysMs:delays},null,2));
    console.log(`Captured ${frames.length} Flutter frames across ${times.at(-1)} ms.`);
  } finally { await browser.close(); }
})().catch(error => { console.error(error.message); process.exitCode=1; });
