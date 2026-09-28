"""Draws the six gamepass icons as SVG (512x512, circle-safe composition)."""
import math, os

OUT = os.path.dirname(os.path.abspath(__file__))
INK = "#1b2340"          # outline color shared by every symbol
FONT = "'Arial Rounded MT Bold', 'Arial Black', sans-serif"

def rays(color, n=18):
    """Soft sunburst behind the symbol."""
    parts = []
    for i in range(n):
        if i % 2: continue
        a0 = 2 * math.pi * i / n; a1 = 2 * math.pi * (i + 1) / n
        r = 420
        parts.append(f'<path d="M256,256 L{256+r*math.cos(a0):.1f},{256+r*math.sin(a0):.1f} '
                     f'L{256+r*math.cos(a1):.1f},{256+r*math.sin(a1):.1f} Z" fill="{color}"/>')
    return f'<g opacity="0.16">{"".join(parts)}</g>'

def background(inner, outer, ray="#ffffff"):
    return f'''<defs>
  <radialGradient id="bg" cx="50%" cy="45%" r="70%">
    <stop offset="0" stop-color="{inner}"/><stop offset="1" stop-color="{outer}"/>
  </radialGradient>
  <linearGradient id="gold" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0" stop-color="#fff3a8"/><stop offset="0.55" stop-color="#ffcc2e"/><stop offset="1" stop-color="#ff9d00"/>
  </linearGradient>
  <linearGradient id="shine" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0" stop-color="#ffffff" stop-opacity="0.55"/><stop offset="1" stop-color="#ffffff" stop-opacity="0"/>
  </linearGradient>
</defs>
<rect width="512" height="512" fill="url(#bg)"/>
{rays(ray)}
<circle cx="256" cy="256" r="236" fill="none" stroke="#ffffff" stroke-opacity="0.35" stroke-width="6"/>'''

def label(text, y=430, size=92, fill="url(#gold)"):
    return (f'<text x="256" y="{y}" text-anchor="middle" font-family="{FONT}" font-size="{size}" '
            f'font-weight="900" fill="{fill}" stroke="{INK}" stroke-width="16" stroke-linejoin="round" '
            f'paint-order="stroke" letter-spacing="2">{text}</text>')

S = f'stroke="{INK}" stroke-width="12" stroke-linejoin="round" stroke-linecap="round" paint-order="stroke"'

def egg(cx, cy, scale, fill, spot, rot=0):
    return f'''<g transform="translate({cx},{cy}) rotate({rot}) scale({scale})">
  <path d="M0,-66 C38,-66 56,-8 56,22 C56,56 31,78 0,78 C-31,78 -56,56 -56,22 C-56,-8 -38,-66 0,-66Z" fill="{fill}" {S}/>
  <circle cx="-18" cy="10" r="12" fill="{spot}"/><circle cx="20" cy="36" r="9" fill="{spot}"/><circle cx="14" cy="-22" r="7" fill="{spot}"/>
  <path d="M-30,-30 C-22,-50 -8,-58 4,-58" fill="none" stroke="#ffffff" stroke-opacity="0.8" stroke-width="10" stroke-linecap="round"/>
</g>'''

def arc_arrow(cx, cy, r, a0, a1, color):
    """Arc from angle a0 to a1 (degrees, clockwise) with an arrowhead at a1."""
    p = lambda a: (cx + r * math.cos(math.radians(a)), cy + r * math.sin(math.radians(a)))
    (x0, y0), (x1, y1) = p(a0), p(a1)
    tang = math.radians(a1 + 90)                      # clockwise tangent
    tx, ty = math.cos(tang), math.sin(tang)
    nx, ny = math.cos(math.radians(a1)), math.sin(math.radians(a1))
    tip = (x1 + tx * 30, y1 + ty * 30)
    b1 = (x1 + nx * 26, y1 + ny * 26); b2 = (x1 - nx * 26, y1 - ny * 26)
    return (f'<path d="M{x0:.1f},{y0:.1f} A{r},{r} 0 0 1 {x1:.1f},{y1:.1f}" fill="none" stroke="{INK}" stroke-width="34" stroke-linecap="round"/>'
            f'<path d="M{x0:.1f},{y0:.1f} A{r},{r} 0 0 1 {x1:.1f},{y1:.1f}" fill="none" stroke="{color}" stroke-width="18" stroke-linecap="round"/>'
            f'<path d="M{b1[0]:.1f},{b1[1]:.1f} L{tip[0]:.1f},{tip[1]:.1f} L{b2[0]:.1f},{b2[1]:.1f} Z" fill="{color}" {S}/>')

ICONS = {}

# 1. Auto Click: cursor inside spinning arrows
ICONS["AutoClick"] = background("#7fd6ff", "#1f6fe0") + f'''
{arc_arrow(256, 214, 132, 200, 320, "#ffd24a")}
{arc_arrow(256, 214, 132, 20, 140, "#ffd24a")}
<g transform="translate(218,108) scale(2.1)">
  <path d="M0,0 L0,72 L18,56 L30,82 L43,76 L31,50 L53,50 Z" fill="#ffffff" stroke="{INK}" stroke-width="5.5" stroke-linejoin="round" paint-order="stroke"/>
  <path d="M5,10 L5,55 L16,45" fill="none" stroke="#cfe9ff" stroke-width="4" stroke-linecap="round"/>
</g>
{label("AUTO", y=452, size=88)}'''

# 2. Triple Hatch: three eggs + x3
ICONS["TripleHatch"] = background("#d8b4ff", "#6a2fd8") + f'''
{egg(165, 250, 1.35, "#ff9ad5", "#ff5fb6", -14)}
{egg(347, 250, 1.35, "#8fe3ff", "#3cb8f0", 14)}
{egg(256, 225, 1.7, "#fff3a0", "#ffc400", 0)}
{label("x3", y=440, size=120)}'''

# 3. +3 Pet Equip: paw print + "+3"
ICONS["PetSlots"] = background("#a6f5bd", "#1e9e58") + f'''
<g fill="#ffffff" {S}>
  <ellipse cx="256" cy="290" rx="92" ry="76"/>
  <ellipse cx="148" cy="190" rx="38" ry="48" transform="rotate(-22 148 190)"/>
  <ellipse cx="220" cy="136" rx="38" ry="50" transform="rotate(-6 220 136)"/>
  <ellipse cx="292" cy="136" rx="38" ry="50" transform="rotate(6 292 136)"/>
  <ellipse cx="364" cy="190" rx="38" ry="48" transform="rotate(22 364 190)"/>
</g>
<ellipse cx="236" cy="262" rx="44" ry="20" fill="#ffffff" opacity="0.0"/>
<g fill="#ffd9ec"><ellipse cx="256" cy="298" rx="52" ry="38"/></g>
{label("+3", y=440, size=120)}'''

# 4. Lucky: four-leaf clover with sparkles on gold
heart = "M0,0 C-12,-22 -70,-44 -54,-92 C-42,-122 -6,-118 0,-94 C6,-118 42,-122 54,-92 C70,-44 12,-22 0,0Z"
leaves = "".join(f'<path d="{heart}" transform="translate(256,232) rotate({a})" fill="#34c96a" {S}/>' for a in (45, 135, 225, 315))
veins = "".join(f'<path d="M0,-10 L0,-78" transform="translate(256,232) rotate({a})" stroke="#8ff0a8" stroke-width="8" stroke-linecap="round"/>' for a in (45, 135, 225, 315))
def sparkle(x, y, s):
    return (f'<path d="M{x},{y-s} Q{x+s*0.18},{y-s*0.18} {x+s},{y} Q{x+s*0.18},{y+s*0.18} {x},{y+s} '
            f'Q{x-s*0.18},{y+s*0.18} {x-s},{y} Q{x-s*0.18},{y-s*0.18} {x},{y-s}Z" fill="#ffffff" stroke="{INK}" stroke-width="6" stroke-linejoin="round" paint-order="stroke"/>')
ICONS["Lucky"] = background("#fff0a0", "#f29a00", ray="#ffffff") + f'''
<path d="M256,240 C270,300 300,340 330,380" fill="none" stroke="{INK}" stroke-width="34" stroke-linecap="round"/>
<path d="M256,240 C270,300 300,340 330,380" fill="none" stroke="#2aa85a" stroke-width="18" stroke-linecap="round"/>
{leaves}{veins}
<circle cx="256" cy="232" r="16" fill="#1f9e52" stroke="{INK}" stroke-width="6"/>
{sparkle(118, 120, 34)}{sparkle(400, 140, 26)}{sparkle(410, 370, 30)}{sparkle(110, 360, 22)}
{label("LUCKY", y=455, size=84)}'''

# 5. Fast Hatch: egg with speed lines and a lightning bolt
speed = "".join(f'<path d="M{x1},{y} L{x2},{y}" stroke="{INK}" stroke-width="26" stroke-linecap="round"/>'
                f'<path d="M{x1},{y} L{x2},{y}" stroke="#ffffff" stroke-width="12" stroke-linecap="round"/>'
                for x1, x2, y in ((60, 150, 190), (40, 150, 250), (70, 160, 310)))
ICONS["FastHatch"] = background("#ffd08a", "#ff5a1f") + f'''
{speed}
{egg(270, 240, 1.75, "#fff6e0", "#ffb347", 18)}
<g transform="translate(360,200) scale(0.95)">
  <path d="M20,-110 L-60,15 L-5,15 L-25,110 L65,-20 L10,-20 Z" fill="url(#gold)" {S}/>
</g>
{label("FAST", y=440, size=100)}'''

# 6. VIP: gold crown with gems
ICONS["VIP"] = background("#c69bff", "#4b1aa8") + f'''
<g transform="translate(256,215)">
  <path d="M-150,70 L-172,-72 L-86,-6 L0,-118 L86,-6 L172,-72 L150,70 Z" fill="url(#gold)" {S}/>
  <rect x="-160" y="58" width="320" height="52" rx="16" fill="url(#gold)" {S}/>
  <circle cx="-172" cy="-78" r="20" fill="#ff5a7a" {S}/>
  <circle cx="0" cy="-124" r="24" fill="#4ad8ff" {S}/>
  <circle cx="172" cy="-78" r="20" fill="#ff5a7a" {S}/>
  <circle cx="-80" cy="84" r="13" fill="#4ad8ff" stroke="{INK}" stroke-width="5"/>
  <circle cx="0" cy="84" r="15" fill="#ff5a7a" stroke="{INK}" stroke-width="5"/>
  <circle cx="80" cy="84" r="13" fill="#4ad8ff" stroke="{INK}" stroke-width="5"/>
  <path d="M-120,40 L-136,-30 M0,20 L0,-70 M120,40 L136,-30" stroke="#fff8c9" stroke-width="10" stroke-linecap="round" opacity="0.85"/>
</g>
{label("VIP", y=430, size=130)}'''

for name, body in ICONS.items():
    svg = f'<svg xmlns="http://www.w3.org/2000/svg" width="512" height="512" viewBox="0 0 512 512">{body}</svg>'
    with open(os.path.join(OUT, name + ".svg"), "w") as f:
        f.write(svg)
    with open(os.path.join(OUT, name + ".html"), "w") as f:
        f.write(f'<!doctype html><html><body style="margin:0;background:transparent">{svg}</body></html>')
print("wrote", ", ".join(ICONS))
