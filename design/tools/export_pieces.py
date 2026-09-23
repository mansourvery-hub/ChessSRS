#!/usr/bin/env python3
"""
Regenerates every piece / figurine / brand asset from the silhouette path data that lives in
reference/prototype-single-file.html (<g id="gK"> ... and <g id="dK"> detail groups).

  python3 tools/export_pieces.py            # writes SVGs
  python3 tools/export_pieces.py --png      # also renders PNGs (needs playwright + chromium;
                                            # set CHROMIUM_PATH to use a specific browser binary)

The union-outline technique is deliberate: every piece is drawn as three stacked copies of the same
silhouette (halo, outline, fill) so overlapping sub-shapes never show internal seams.
"""
import os, re, sys, pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = (ROOT / "reference" / "prototype-single-file.html").read_text()

def group(id_):
    m = re.search(r'<g id="%s">(.*?)</g>' % id_, SRC, re.S)
    return m.group(1).strip() if m else ""

TYPES = ["K", "Q", "R", "B", "N", "P"]

# Colours per theme. Values are the exact tokens from tokens/tokens.json.
THEMES = {
    "light": {
        "w": dict(fill="#FFFFFF", stroke="#101318", detail="#101318"),
        "b": dict(fill="#101318", stroke="#101318", detail="#F1F3F4"),
        "halo": "#F8F9FA",
    },
    "dark": {
        "w": dict(fill="#ECEEF1", stroke="#0D0F13", detail="#0D0F13"),
        "b": dict(fill="#0D0F13", stroke="#ECEEF1", detail="#ECEEF1"),
        "halo": "#11141A",
    },
}
VIEWBOX = "5 2 90 90"      # pieces
FIG_VIEWBOX = "14 6 72 84" # figurines (tighter crop, single colour)

def piece_svg(theme, color, t):
    c = THEMES[theme][color]; halo = THEMES[theme]["halo"]
    return f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="{VIEWBOX}" width="512" height="512">
  <defs><g id="s">{group("g"+t)}</g></defs>
  <g stroke-linejoin="round" stroke-linecap="round">
    <use href="#s" fill="{halo}" stroke="{halo}" stroke-width="7"/>
    <use href="#s" fill="{c["stroke"]}" stroke="{c["stroke"]}" stroke-width="4.4"/>
    <use href="#s" fill="{c["fill"]}" stroke="none"/>
  </g>
  <g color="{c["detail"]}" fill="none" stroke="none">{group("d"+t)}</g>
</svg>
'''

def main(png=False):
    out = ROOT / "assets"
    for theme in THEMES:
        d = out / "pieces" / theme / "svg"; d.mkdir(parents=True, exist_ok=True)
        for color in "wb":
            for t in TYPES:
                (d / f"{color}{t}.svg").write_text(piece_svg(theme, color, t))
    # source-of-truth silhouettes
    sil = ['<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100"><defs>']
    for t in TYPES:
        sil.append(f'<g id="g{t}">{group("g"+t)}</g>')
        sil.append(f'<g id="d{t}">{group("d"+t)}</g>')
    sil.append("</defs></svg>")
    (out / "pieces" / "silhouettes.svg").write_text("\n".join(sil))
    # figurines: single colour, currentColor, no outline (used inline in notation)
    fd = out / "figurines"; fd.mkdir(exist_ok=True)
    for t in TYPES[:-1]:
        (fd / f"{t}.svg").write_text(
            f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="{FIG_VIEWBOX}"><g fill="currentColor">{group("g"+t)}</g></svg>\n')
    # brand
    bd = out / "brand"; bd.mkdir(exist_ok=True)
    mark = '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 22 22" width="22" height="22">
  <defs><pattern id="h" width="2.4" height="2.4" patternUnits="userSpaceOnUse" patternTransform="rotate(45)"><rect width=".9" height="2.4" fill="currentColor"/></pattern></defs>
  <rect x=".75" y=".75" width="20.5" height="20.5" fill="none" stroke="currentColor" stroke-width="1.5"/>
  <rect x="11" y="1.5" width="9.5" height="9.5" fill="url(#h)"/>
  <rect x="1.5" y="11" width="9.5" height="9.5" fill="url(#h)"/>
</svg>
'''
    (bd / "mark.svg").write_text(mark)
    icon = '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024" width="1024" height="1024">
  <rect width="1024" height="1024" fill="#101318"/>
  <g transform="translate(212 212) scale(27.27)" color="#F1F3F4">
    <defs><pattern id="h" width="2.4" height="2.4" patternUnits="userSpaceOnUse" patternTransform="rotate(45)"><rect width=".9" height="2.4" fill="currentColor"/></pattern></defs>
    <rect x=".75" y=".75" width="20.5" height="20.5" fill="none" stroke="currentColor" stroke-width="1.5"/>
    <rect x="11" y="1.5" width="9.5" height="9.5" fill="url(#h)"/>
    <rect x="1.5" y="11" width="9.5" height="9.5" fill="url(#h)"/>
  </g>
</svg>
'''
    (bd / "icon.svg").write_text(icon)
    print("SVGs written")
    if png:
        import asyncio
        from playwright.async_api import async_playwright
        async def run():
            async with async_playwright() as p:
                b = await p.chromium.launch(executable_path=os.environ.get('CHROMIUM_PATH') or None)
                pg = await b.new_page()
                jobs = []
                for theme in THEMES:
                    for color in "wb":
                        for t in TYPES:
                            jobs.append((out/"pieces"/theme/"svg"/f"{color}{t}.svg", out/"pieces"/theme/"png-512"/f"{color}{t}.png", 512))
                            jobs.append((out/"pieces"/theme/"svg"/f"{color}{t}.svg", out/"pieces"/theme/"png-256"/f"{color}{t}.png", 256))
                jobs.append((bd/"icon.svg", bd/"icon-1024.png", 1024))
                for svg, dst, size in jobs:
                    dst.parent.mkdir(parents=True, exist_ok=True)
                    markup = re.sub(r'width="\d+" height="\d+"', f'width="{size}" height="{size}"', svg.read_text(), count=1)
                    await pg.set_viewport_size({"width": size, "height": size})
                    await pg.set_content(f'<body style="margin:0;background:transparent">{markup}</body>')
                    await pg.screenshot(path=str(dst), omit_background=True)
                await b.close()
        asyncio.run(run()); print("PNGs written")

if __name__ == "__main__":
    main("--png" in sys.argv)
