// Browser QA of the real compiled Flutter app, not a separate HTML mockup.
const path=require('node:path');
const {createRequire}=require('node:module');
const fs=require('node:fs');
const root=path.resolve(__dirname,'..');
const reference=path.resolve(process.argv[2]||path.join(root,'../german-exam-prep'));
const puppeteer=createRequire(path.join(reference,'package.json'))('puppeteer');
const sharp=createRequire(path.join(reference,'package.json'))('sharp');
const pause=ms=>new Promise(resolve=>setTimeout(resolve,ms));
(async()=>{
  fs.mkdirSync(path.join(root,'output/screenshots'),{recursive:true});
  const browser=await puppeteer.launch({headless:true,
    executablePath:process.env.PUPPETEER_EXECUTABLE_PATH||'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
    userDataDir:'/tmp/wortgarten-browser-qa',args:['--no-sandbox','--disable-dev-shm-usage']});
  try{
    const page=await browser.newPage();
    await page.setCacheEnabled(false);
    await page.setBypassServiceWorker(true);
    const errors=[];page.on('pageerror',error=>errors.push(error.message));
    const mediaResponses=[];
    page.on('response',response=>{
      if(response.url().includes('/media/'))mediaResponses.push({url:response.url(),status:response.status()});
    });
    await page.setViewport({width:390,height:844,deviceScaleFactor:2});
    const enableSemantics=async()=>{
      await page.waitForSelector('flutter-view');await pause(300);
      const element=await page.$('flt-semantics-placeholder');if(element)await element.evaluate(el=>el.click());await pause(300);
    };
    const click=async(text)=>{
      await page.waitForFunction(text=>[...document.querySelectorAll('flt-semantics[flt-tappable]')].some(el=>
        (el.innerText||el.getAttribute('aria-label')||el.textContent||'').trim()===text),{timeout:5000},text);
      const found=await page.evaluate(text=>{
        const element=[...document.querySelectorAll('flt-semantics[flt-tappable]')].find(el=>
          (el.innerText||el.getAttribute('aria-label')||el.textContent||'').trim()===text);
        if(!element)return false;element.click();return true;
      },text);
      if(!found) {
        await page.screenshot({path:path.join(root,'output/screenshots/qa-error.png')});
        console.log('Page errors:',errors);
        console.log('Visible semantics:',await page.evaluate(()=>document.body.innerText));
        console.log(await page.evaluate(()=>[...document.querySelectorAll('flt-semantics[flt-tappable]')].map(el=>el.innerText||el.getAttribute('aria-label'))));
        throw new Error('Missing app control: '+text);
      }
      await pause(450);
    };
    const screenshot=async(name)=>page.screenshot({path:path.join(root,`output/screenshots/${name}.png`)});
    await page.goto('http://127.0.0.1:7357',{waitUntil:'networkidle0'});
    // This profile is dedicated to QA; reset only this app's test progress.
    await page.evaluate(()=>localStorage.removeItem('flutter.wortgarten.progress.v1'));
    await page.reload({waitUntil:'networkidle0'});await enableSemantics();
    if((await page.evaluate(()=>document.body.innerText)).includes('Start growing')){
      await screenshot('welcome');await click('Start growing');
      await screenshot('onboarding-preferences');await click('Try my first word');
      await screenshot('onboarding-word');await click('Reveal meaning');await click('Got it');
      await click('Continue');await screenshot('paywall');await click('Continue free');
    }
    await screenshot('home');
    for(const name of ['Goethe','telc']){
      await page.waitForFunction(name=>[...document.querySelectorAll('flt-semantics[flt-tappable]')]
        .some(el=>[el.innerText,el.getAttribute('aria-label')]
          .some(label=>label?.includes(name+' exam vocabulary'))),{timeout:5000},name);
      await page.evaluate(name=>[...document.querySelectorAll('flt-semantics[flt-tappable]')]
        .find(el=>[el.innerText,el.getAttribute('aria-label')]
          .some(label=>label?.includes(name+' exam vocabulary'))).click(),name);
      await pause(450);
      const examPage=await page.evaluate(()=>document.body.innerText);
      if(!examPage.includes(name+' · A1')||!examPage.includes('By exam'))
        throw new Error('Home shortcut did not open the selected exam: '+name);
      if(examPage.includes('Wortgarten Premium'))
        throw new Error('Browsing an exam unexpectedly opened the paywall');
      await screenshot(name.toLowerCase()+'-exam');
      await click('Home Home');
    }
    await screenshot('home-exams');
    console.log('Verified Home Goethe/telc shortcuts open the selected exam vocabulary.');
    await page.mouse.move(200,600);await page.mouse.wheel({deltaY:620});await pause(500);
    await screenshot('practice-shortcuts');
    await click('Learn Learn');await click('By topic');await screenshot('topics');
    await click('By level');
    await page.evaluate(()=>[...document.querySelectorAll('flt-semantics[flt-tappable]')]
      .find(el=>(el.innerText||'').startsWith('Food & drinks'))?.click());await pause(400);
    await screenshot('lesson');await click('Practise this topic');await click('Flashcards Reveal, recall, remember');
    await screenshot('flashcard');await click('Reveal meaning');await screenshot('flashcard-revealed');await click('Got it');await click('Next word');
    await click('Close and save session');await click('Back');
    await click('Progress Progress');await screenshot('progress');
    await page.mouse.move(200,600);await page.mouse.wheel({deltaY:470});await pause(500);
    await screenshot('infographics');
    await pause(300);
    const stored=await page.evaluate(()=>{
      const value=JSON.parse(localStorage.getItem('flutter.wortgarten.progress.v1'));
      return typeof value==='string'?JSON.parse(value):value;
    });
    if(stored.session.index!==1||Object.keys(stored.progress).length!==2)throw new Error('The completed answers were not persisted');
    await page.reload({waitUntil:'networkidle0'});await enableSemantics();
    const after=await page.evaluate(()=>document.body.innerText);
    if(!after.includes('Pick up where you left off'))throw new Error('Session resume was lost on reload');
    console.log('Verified onboarding, topic browsing, lesson details, flashcard recall, saved session, and persisted progress after reload.');
    await click('Learn Learn');
    await page.evaluate(()=>[...document.querySelectorAll('flt-semantics[flt-tappable]')]
      .find(el=>(el.innerText||'').startsWith('Food & drinks'))?.click());await pause(400);
    await click('Practise this topic');await click('Review Explore words and examples');
    await screenshot('recorded-review');
    // A real user gesture satisfies browser audio policy. The recording must
    // complete naturally before the persisted review session moves forward.
    const audioControl=await page.evaluate(()=>{
      const el=[...document.querySelectorAll('flt-semantics[flt-tappable]')].find(el=>
        (el.innerText||el.getAttribute('aria-label')||el.textContent||'').trim()==='Auto-play review');
      if(!el)return null;const r=el.getBoundingClientRect();return {x:r.x+r.width/2,y:r.y+r.height/2};
    });
    if(!audioControl)throw new Error('Review audio control was not available');
    await page.mouse.click(audioControl.x,audioControl.y);
    await page.waitForFunction(()=>{
      const raw=JSON.parse(localStorage.getItem('flutter.wortgarten.progress.v1'));
      const state=typeof raw==='string'?JSON.parse(raw):raw;
      return state.session?.mode==='review'&&state.session.index===1;
    },{timeout:30000});
    await click('Pause auto-play');
    await pause(500);
    const pausedIndex=await page.evaluate(()=>{
      const raw=JSON.parse(localStorage.getItem('flutter.wortgarten.progress.v1'));
      return (typeof raw==='string'?JSON.parse(raw):raw).session.index;
    });
    if(pausedIndex!==1)throw new Error('Pausing audio changed the current card');
    if(!mediaResponses.some(r=>r.status>=200&&r.status<300&&r.url.endsWith('/apfel.card.mp3')))
      throw new Error('Bundled full-card MP3 was not loaded');
    if(!mediaResponses.some(r=>r.status>=200&&r.status<300&&/\/words\/apfel\.[a-f0-9]+\.webp$/.test(r.url)))
      throw new Error('Individual word image was not loaded');
    const failedMedia=mediaResponses.filter(r=>r.status>=400);
    if(failedMedia.length)throw new Error(JSON.stringify(failedMedia));
    console.log('Verified custom word/topic images, bundled full-card MP3 playback, completion-based advancement and pause.');
    await click('Example & word details');await screenshot('word-details');
    const opened=await page.evaluate(()=>{
      const el=[...document.querySelectorAll('flt-semantics[flt-tappable]')].find(el=>
        (el.getAttribute('aria-label')||el.innerText||'').startsWith('Enlarge image'));
      if(!el)return false;el.click();return true;
    });
    if(!opened)throw new Error('Image preview was not available from word details');
    await pause(500);await screenshot('artwork-zoom');
    if(!(await page.evaluate(()=>document.body.innerText)).includes('Pinch to zoom'))
      throw new Error('Image preview did not open');
    await click('Close image preview');
    console.log('Verified larger image preview opens and returns to word details.');
    if(errors.length)throw new Error(errors.join('\n'));
    const names=['home','topics','flashcard'];
    await sharp({create:{width:1218,height:844,channels:4,background:'#eef0e8'}}).composite(
      await Promise.all(names.map(async(name,i)=>({input:await sharp(path.join(root,`output/screenshots/${name}.png`)).resize(390,844).toBuffer(),left:i*414,top:0})))
    ).png().toFile(path.join(root,'output/screenshots/app-preview.png'));
    const upgrade=['home','practice-shortcuts','infographics'];
    await sharp({create:{width:1218,height:844,channels:4,background:'#eef0e8'}}).composite(
      await Promise.all(upgrade.map(async(name,i)=>({input:await sharp(path.join(root,`output/screenshots/${name}.png`)).resize(390,844).toBuffer(),left:i*414,top:0})))
    ).png().toFile(path.join(root,'output/screenshots/ui-upgrade-preview.png'));
    const artwork=['topics','flashcard','recorded-review'];
    await sharp({create:{width:1218,height:844,channels:4,background:'#eef0e8'}}).composite(
      await Promise.all(artwork.map(async(name,i)=>({input:await sharp(path.join(root,`output/screenshots/${name}.png`)).resize(390,844).toBuffer(),left:i*414,top:0})))
    ).png().toFile(path.join(root,'output/screenshots/artwork-preview.png'));
    const onboarding=['welcome','onboarding-preferences','onboarding-word','paywall'];
    await sharp({create:{width:1632,height:844,channels:4,background:'#eef0e8'}}).composite(
      await Promise.all(onboarding.map(async(name,i)=>({input:await sharp(path.join(root,`output/screenshots/${name}.png`)).resize(390,844).toBuffer(),left:i*414,top:0})))
    ).png().toFile(path.join(root,'output/screenshots/onboarding-preview.png'));
  }finally{await browser.close();}
})().catch(error=>{console.error(error.message);process.exitCode=1;});
