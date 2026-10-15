"""Crop-safe App Store brand artwork using existing Wortgarten vocabulary art."""
from PIL import Image, ImageDraw, ImageFont, ImageFilter


def render_creative(root, lang, size, safe_area):
    w, h = size
    sx, sy, sw, sh = safe_area
    scale = w / 3840
    def font(n, bold=False):
        return ImageFont.truetype(str(root / 'assets/fonts' / ('Geist-Bold.ttf' if bold else 'Geist-Regular.ttf')), round(n))
    im = Image.new('RGBA', size, '#F7F7EE')
    d = ImageDraw.Draw(im)
    d.ellipse((-w*.32, -h*.72, w*.40, h*1.55), fill='#DFEBD9')
    d.ellipse((w*.75, -h*.20, w*1.37, h*1.50), fill='#E9E5D5')
    # A garden path carries the eye across the full canvas, even outside crops.
    d.arc((-w*.13, h*.78, w*1.13, h*1.90), 190, 345, fill='#C8D9BE', width=round(10*scale))

    def card(asset, cx, cy, width, angle):
        width = round(width)
        height = round(width*1.15)
        tile = Image.new('RGBA', (width+100, height+100))
        td = ImageDraw.Draw(tile)
        td.rounded_rectangle((32,42,width+68,height+78), radius=round(width*.10), fill=(38,63,52,34))
        tile = tile.filter(ImageFilter.GaussianBlur(18*scale))
        td = ImageDraw.Draw(tile)
        td.rounded_rectangle((30,25,width+70,height+65), radius=round(width*.10), fill='#FFFFFF', outline='#D6E0D1', width=round(3*scale))
        art = Image.open(root/asset).convert('RGB').resize((width-54,width-54), Image.Resampling.LANCZOS)
        mask=Image.new('L',art.size);ImageDraw.Draw(mask).rounded_rectangle((0,0,art.width,art.height),radius=round(width*.065),fill=255)
        tile.paste(art,(77,58),mask)
        # Graphic audio/wave motif, not a simulated interactive control.
        td=ImageDraw.Draw(tile)
        baseline=height-24
        for i,bar in enumerate([16,32,46,32,16]):
            x=width/2+27+(i-2)*18*scale
            td.rounded_rectangle((x,baseline-bar*scale/2,x+7*scale,baseline+bar*scale/2),radius=3*scale,fill='#699072')
        tile=tile.rotate(angle,resample=Image.Resampling.BICUBIC,expand=True)
        im.alpha_composite(tile,(round(cx-tile.width/2),round(cy-tile.height/2)))

    # Side illustrations are deliberately nonessential: brand and meaning stay safe.
    card('assets/media/words/apfel.ee913250f9bc.webp',w*.12,h*.43,w*.19,-12)
    card('assets/media/words/kaffee.1bf314bbdb59.webp',w*.86,h*.58,w*.19,12)
    if h/w > .55:
        card('assets/media/words/hallo.e6d40796b706.webp',w*.39,h*.84,w*.15,8)
        card('assets/media/words/termin.4e427f822369.webp',w*.64,h*.91,w*.17,-9)

    # Large brand lockup fills the official safe area, with generous internal breathing room.
    d=ImageDraw.Draw(im)
    title='wortgarten'
    title_font=font(sw*.125,True)
    isz=round(min(sh*.37,sw*.19));gap=round(sw*.035)
    while isz+gap+d.textlength(title,font=title_font)>sw*.94:
        title_font=font(title_font.size-1,True)
    lock_w=isz+gap+d.textlength(title,font=title_font)
    left=sx+(sw-lock_w)/2
    top=sy+sh*.15
    icon=Image.open(root/'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png').convert('RGB').resize((isz,isz),Image.Resampling.LANCZOS)
    mask=Image.new('L',(isz,isz));ImageDraw.Draw(mask).rounded_rectangle((0,0,isz,isz),radius=isz*.25,fill=255)
    im.paste(icon,(round(left),round(top)),mask)
    d=ImageDraw.Draw(im)
    d.text((left+isz+gap,top+isz*.14),title,font=title_font,fill='#263F34',anchor='lt')
    sub='German vocabulary · Deutsch lernen'
    sf=font(sw*.052)
    while d.textlength(sub,font=sf)>sw*.93:sf=font(sf.size-1)
    d.text((sx+sw/2,sy+sh*.69),sub,font=sf,fill='#477357',anchor='mt')
    levels=font(sh*.078,True)
    exam_line='A1–C1 · Goethe & telc'
    while d.textlength(exam_line,font=levels)>sw*.94:levels=font(levels.size-1,True)
    d.text((sx+sw/2,sy+sh*.86),exam_line,font=levels,fill='#477357',anchor='mt')
    return im.convert('RGB')
