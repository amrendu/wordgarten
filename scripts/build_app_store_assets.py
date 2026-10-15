"""Compose App Store artwork from current native screenshots and existing branding."""
from pathlib import Path
import json, zipfile
from PIL import Image, ImageDraw, ImageFont, ImageFilter, ImageCms
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'output/app-store'
FONT=ROOT/'assets/fonts'
ICC=ImageCms.ImageCmsProfile(ImageCms.createProfile('sRGB')).tobytes()
INK='#263F34'; GREEN='#477357'; CREAM='#FAFAF5'; MINT='#E6F0E5'
def font(size,bold=False):return ImageFont.truetype(str(FONT/('Geist-Bold.ttf' if bold else 'Geist-Regular.ttf')),int(size))
def save(im,path):
 path.parent.mkdir(parents=True,exist_ok=True);im.convert('RGB').save(path,icc_profile=ICC,optimize=True)
def fit_font(lines,width,start):
 while max(font(start,True).getlength(x) for x in lines)>width:start-=1
 return font(start,True)
def text_lines(draw,xy,lines,ft,fill=INK,spacing=12):
 x,y=xy
 for line in lines:
  draw.text((x,y),line,font=ft,fill=fill,anchor='lt');y+=ft.size+spacing
 return y
SPECS=[
 ('01-illustrated',('German words.','Lasting roots.'),('Deutsch lernen.','Wort für Wort.'),'Illustrations, meanings and examples.','Bilder, Bedeutungen und Beispiele.',CREAM),
 ('02-recall',('Recall first.','Reveal next.'),('Erst erinnern.','Dann aufdecken.'),'Flip a card. See what you remember.','Lernkarten, die zum Nachdenken anregen.',MINT),
 ('03-exams',('Goethe & telc.','Words for exams.'),('Goethe & telc.','Wörter für Prüfungen.'),'Vocabulary organized for your exam.','Wortschatz passend zu deiner Prüfung.',CREAM),
 ('04-levels',('Your level.','From A1 to C1.'),('Dein Niveau.','Von A1 bis C1.'),'Choose a level. Explore useful topics.','Wähle dein Niveau und passende Themen.','#EDE9F6'),
 ('05-audio',('Listen. Repeat.','Remember.'),('Anhören.','Besser merken.'),'Hear German words and examples offline.','Deutsche Wörter und Beispiele offline hören.',CREAM),
 ('06-progress',('Small steps.','Visible progress.'),('Kleine Schritte.','Sichtbare Fortschritte.'),'Track your streak and words learned.','Lernserie und gelernte Wörter im Blick.',MINT),
 ('07-home',('Your daily','word garden.'),('Dein täglicher','Wortgarten.'),'Build a habit, a few words at a time.','Ein paar Wörter am Tag. In deinem Tempo.',CREAM),
]
icon=Image.open(ROOT/'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png').convert('RGB')
def rounded_paste(canvas,image,box,radius):
 x,y,w,h=box;picture=image.resize((w,h),Image.Resampling.LANCZOS)
 mask=Image.new('L',(w,h));ImageDraw.Draw(mask).rounded_rectangle((0,0,w-1,h-1),radius=radius,fill=255)
 canvas.paste(picture,(x,y),mask)
def status_bar(raw,device):
 # IntegrationTest captures app windows; add the standard status bar omitted by
 # that native capture method. No app UI or vocabulary is altered.
 raw=raw.convert('RGB');d=ImageDraw.Draw(raw);w,h=raw.size
 if device=='iphone':
  d.text((72,72),'9:41',font=font(44,True),fill=INK,anchor='lt')
  d.rounded_rectangle((w//2-168,36,w//2+168,108),radius=36,fill='#101813')
  for i in range(4):d.rounded_rectangle((w-248+i*16,91-i*10,w-238+i*16,105),radius=3,fill=INK)
  d.rounded_rectangle((w-126,68,w-56,103),radius=8,outline=INK,width=4);d.rectangle((w-119,75,w-63,96),fill=INK);d.rectangle((w-54,78,w-49,93),fill=INK)
 else:
  d.text((40,25),'9:41',font=font(28,True),fill=INK,anchor='lt')
  d.rounded_rectangle((w-102,22,w-38,48),radius=5,outline=INK,width=3);d.rectangle((w-96,28,w-44,42),fill=INK)
 return raw
files=[]
for device,dimensions in [('iphone',(1320,2868)),('ipad',(2064,2752))]:
 rawdir=OUT/'raw'/device
 if not rawdir.exists():continue
 for lang in ['en','de']:
  for slug,en,de,suben,subde,bg in SPECS:
   raw=Image.open(rawdir/(slug+'.png'));W,H=dimensions
   im=Image.new('RGB',(W,H),bg);d=ImageDraw.Draw(im)
   # Gentle foliage outside the focal content; a shared visual rhythm.
   d.ellipse((W-420,-300,W+460,660),fill='#DDE7D7')
   d.arc((-420,H-920,560,H+220),230,355,fill='#BED2B9',width=5)
   if device=='iphone':
    margin=92;brandY=86;titleY=245;subY=503;screenY=640;screenW=976
    ft=fit_font(en if lang=='en' else de,W-2*margin,106)
   else:
    margin=140;brandY=54;titleY=154;subY=383;screenY=480;screenW=1670
    ft=fit_font(en if lang=='en' else de,W-2*margin,98)
   rounded_paste(im,icon,(margin,brandY,76,76),20)
   d.text((margin+96,brandY+20),'wortgarten',font=font(42,True),fill=GREEN,anchor='lt')
   text_lines(d,(margin,titleY),en if lang=='en' else de,ft)
   d.text((margin,subY),suben if lang=='en' else subde,font=font(35 if device=='iphone' else 46),fill=GREEN,anchor='lt')
   screenH=round(screenW*raw.height/raw.width)
   x=(W-screenW)//2;y=screenY
   shadow=Image.new('RGBA',(W,H));sd=ImageDraw.Draw(shadow)
   sd.rounded_rectangle((x-16,y+12,x+screenW+16,y+screenH+35),radius=90,fill=(38,63,52,45));shadow=shadow.filter(ImageFilter.GaussianBlur(30))
   im=Image.alpha_composite(im.convert('RGBA'),shadow).convert('RGB');d=ImageDraw.Draw(im)
   d.rounded_rectangle((x-14,y-14,x+screenW+14,y+screenH+14),radius=90,fill='#26362D')
   rounded_paste(im,status_bar(raw,device),(x,y,screenW,screenH),76)
   assert y+screenH+14 < H, (device,slug,'device exceeds canvas')
   dest=OUT/lang/device/(slug+'.png');save(im,dest);files.append(str(dest.relative_to(OUT)))

# Exact creative canvases and safe rectangles from Apple's official Sketch file.
CREATIVES=[('product-page-header',(3840,1646),(1097,493,1646,661)),('search-results',(3840,2560),(836,765,2168,1030)),('universal',(5244,2950),(1921,660,1402,962))]
for lang in ['en','de']:
 for name,(W,H),(sx,sy,sw,sh) in CREATIVES:
  from app_store_creative import render_creative
  im=render_creative(ROOT,lang,(W,H),(sx,sy,sw,sh))
  dest=OUT/lang/'creative'/(name+'.png');save(im,dest);files.append(str(dest.relative_to(OUT)))
  guide=im.copy();gd=ImageDraw.Draw(guide);gd.rectangle((sx,sy,sx+sw,sy+sh),outline='#D07A55',width=8)
  save(guide,OUT/'preview'/(lang+'-'+name+'-safe-area.png'))

save(icon,OUT/'app-icon-1024.png');files.append('app-icon-1024.png')
for lang in ['en','de']:
 cards=[Image.open(OUT/lang/'iphone'/(s[0]+'.png')) for s in SPECS]
 thumbW=280;thumbH=round(thumbW*2868/1320)
 sheet=Image.new('RGB',(4*(thumbW+24)+24,2*(thumbH+64)+28),CREAM);d=ImageDraw.Draw(sheet)
 for i,(card,spec) in enumerate(zip(cards,SPECS)):
  x=24+(i%4)*(thumbW+24);y=24+(i//4)*(thumbH+64)
  sheet.paste(card.resize((thumbW,thumbH),Image.Resampling.LANCZOS),(x,y))
  d.text((x,y+thumbH+12),spec[0],font=font(16),fill=INK)
 save(sheet,OUT/'preview'/(lang+'-contact-sheet.png'))
manifest={'createdAt':'2026-10-13','appVersion':next(line.split(':',1)[1].strip() for line in (ROOT/'pubspec.yaml').read_text().splitlines() if line.startswith('version:')),'languages':['en','de'],'capture':'Native iOS integration screenshots with in-memory representative progress; no user data or payments accessed','germanLocalization':'German marketing text; current app interface remains English','screenshots':{'iphone':[1320,2868],'ipad':[2064,2752]},'creativeTemplates':{'source':'https://devimages-cdn.apple.com/design/resources/download/app-store/creative_assets-templates.sketch','canvases':[{'name':n,'size':s,'safeArea':a} for n,s,a in CREATIVES]},'files':files,'guidance':['https://developer.apple.com/app-store/asset-best-practices/','https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications'],'rules':['Current real app UI','Short localized headlines','No pricing, discounts, URLs, awards or other marketplace logos','Opaque RGB PNG exports with sRGB profile','Key creative content within official safe areas'],'videoPreviewIncluded':False}
(OUT/'assets.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
(OUT/'UPLOAD-INSTRUCTIONS.txt').write_text("""WORTGARTEN APP STORE IMAGE ASSETS — 2026-10-13

35 opaque sRGB PNG images, based on the current app UI and existing brand.

SCREENSHOTS
Upload en/iphone/01 through 07 to the English iPhone large-display screenshot slot.
Upload de/iphone/01 through 07 to the German iPhone large-display screenshot slot.
iPhone exports: 1320 x 2868 pixels.
For iPad, use the equivalent en/ipad or de/ipad files in the 13-inch slot.
iPad exports: 2064 x 2752 pixels.
Maintain the numbered order. The German version translates the marketing headlines;
the application interface in these captures is English.

CREATIVE ASSETS
Use each language's creative/product-page-header.png for Header and creative/search-results.png for Search Results.
Separate layouts make better use of each placement. universal.png is an optional alternative.
Canvas sizes and safe areas were read from Apple's official Sketch template.
Review cropping in App Store Connect's Preview tool before submitting.
The safe-area-guide images in the preview directory are not upload artwork.

ICON
app-icon-1024.png is the existing approved Wortgarten icon, exported without alpha.
The icon is already included in the app binary; use this file where a master image is requested.

CAPTURE AND VALIDATION
Native iPhone 18 Pro Max and iPad Pro 13-inch simulator captures.
Representative progress was seeded in memory. No personal progress or live purchases accessed.
Audio was held in a playing state for still captures; screenshots use actual production widgets.
Both native capture runs passed. All upload files have verified dimensions and RGB format.
No prices, discounts, URLs, awards or other marketplace logos are included.
App preview videos are not included in this image package.

Sources:
https://developer.apple.com/app-store/asset-best-practices/
https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications
https://devimages-cdn.apple.com/design/resources/download/app-store/creative_assets-templates.sketch
""", encoding='utf-8')
with zipfile.ZipFile(OUT/'wortgarten-app-store-assets.zip','w',zipfile.ZIP_DEFLATED) as z:
 for name in files+['assets.json','UPLOAD-INSTRUCTIONS.txt']:
  z.write(OUT/name,name)
print('Exported',len(files),'upload images plus previews and ZIP.')
