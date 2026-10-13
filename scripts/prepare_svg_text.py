"""Convert the reference's two SVG text labels to portable vector paths.

Run with fonttools available after importing the reference illustrations.
"""
from pathlib import Path
import re
from fontTools.ttLib import TTFont
from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.pens.transformPen import TransformPen
ROOT = Path(__file__).resolve().parents[1]
font = TTFont(ROOT / 'assets/fonts/Geist-SemiBold.ttf')
glyphs = font.getGlyphSet()
cmap = font.getBestCmap()
units = font['head'].unitsPerEm
def vector(match):
    attributes, text = match.groups()
    def attr(name, default):
        value = re.search(fr'{name}="([^"]+)"', attributes)
        return value.group(1) if value else default
    size = float(attr('font-size', '30'))
    scale = size / units
    x, y = float(attr('x', '0')), float(attr('y', '0'))
    names = [cmap[ord(character)] for character in text]
    width = sum(glyphs[name].width for name in names) * scale
    if attr('text-anchor', '') == 'middle': x -= width / 2
    paths = []
    for name in names:
        pen = SVGPathPen(glyphs)
        glyphs[name].draw(TransformPen(pen, (scale, 0, 0, -scale, x, y)))
        paths.append(pen.getCommands())
        x += glyphs[name].width * scale
    return f'<path d="{" ".join(paths)}" fill="{attr("fill", "#477357")}" stroke="none"/>'
for file in (ROOT / 'assets/artwork').glob('*.svg'):
    original = file.read_text()
    converted = re.sub(r'<text([^>]*)>([^<]+)</text>', vector, original)
    if converted != original:
        file.write_text(converted)
        print(f'Converted {file.name} text to vector paths.')
