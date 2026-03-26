#!/usr/bin/env python3
"""Generate MarkView app icon — v2, modern macOS style."""
from PIL import Image, ImageDraw, ImageFont, ImageFilter
import subprocess, os, shutil, math

SIZE = 1024
PAD = 40  # icon padding

img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
draw = ImageDraw.Draw(img)

# --- Background: rich gradient ---
for y in range(PAD, SIZE - PAD):
    t = (y - PAD) / (SIZE - 2 * PAD)
    r = int(58 + t * 30)    # 58 -> 88
    g = int(120 + t * (-60)) # 120 -> 60
    b = int(220 + t * 20)   # 220 -> 240
    draw.line([(PAD, y), (SIZE - PAD, y)], fill=(r, g, b))

# Round the corners
mask = Image.new("L", (SIZE, SIZE), 0)
mask_draw = ImageDraw.Draw(mask)
mask_draw.rounded_rectangle([PAD, PAD, SIZE - PAD, SIZE - PAD], radius=200, fill=255)
img.putalpha(mask)

# --- Document page (white, with shadow) ---
doc_left, doc_top = 220, 140
doc_right, doc_bottom = SIZE - 220, SIZE - 120
doc_radius = 40

# Shadow layer
shadow = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
shadow_draw = ImageDraw.Draw(shadow)
shadow_draw.rounded_rectangle(
    [doc_left + 8, doc_top + 12, doc_right + 8, doc_bottom + 12],
    radius=doc_radius, fill=(0, 0, 0, 80)
)
shadow = shadow.filter(ImageFilter.GaussianBlur(radius=18))
img = Image.alpha_composite(img, shadow)
draw = ImageDraw.Draw(img)

# Page
draw.rounded_rectangle(
    [doc_left, doc_top, doc_right, doc_bottom],
    radius=doc_radius, fill=(255, 255, 255, 240)
)

# --- Content on the page ---
cx = doc_left + 50  # content x start
cw = doc_right - doc_left - 100  # content width

# Heading line (thick, dark)
y = doc_top + 70
draw.rounded_rectangle([cx, y, cx + cw * 0.7, y + 18], radius=9, fill=(40, 40, 60, 200))

# Thin "paragraph" lines
for i, frac in enumerate([1.0, 0.85, 0.92, 0.6]):
    ly = y + 60 + i * 32
    w = int(cw * frac)
    draw.rounded_rectangle([cx, ly, cx + w, ly + 10], radius=5, fill=(80, 90, 120, 90))

# "Code block" — subtle colored rectangle
code_y = y + 210
draw.rounded_rectangle(
    [cx, code_y, cx + cw, code_y + 70],
    radius=12, fill=(88, 160, 220, 35)
)
# Code lines inside
for i, frac in enumerate([0.65, 0.45]):
    cly = code_y + 18 + i * 26
    w = int(cw * frac)
    draw.rounded_rectangle([cx + 16, cly, cx + 16 + w, cly + 8], radius=4, fill=(50, 120, 200, 80))

# Another text line below code
for i, frac in enumerate([0.9, 0.75]):
    ly = code_y + 100 + i * 32
    w = int(cw * frac)
    draw.rounded_rectangle([cx, ly, cx + w, ly + 10], radius=5, fill=(80, 90, 120, 90))

# --- "Md" badge — bottom right corner ---
badge_size = 200
badge_x = SIZE - PAD - badge_size - 40
badge_y = SIZE - PAD - badge_size - 20

# Badge background
badge = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
badge_draw = ImageDraw.Draw(badge)
# Orange-amber gradient badge
for by in range(badge_size):
    t = by / badge_size
    r = int(255 - t * 20)
    g = int(140 - t * 30)
    b = int(50 + t * 10)
    badge_draw.line(
        [(badge_x, badge_y + by), (badge_x + badge_size, badge_y + by)],
        fill=(r, g, b)
    )

# Mask badge to rounded rect
badge_mask = Image.new("L", (SIZE, SIZE), 0)
badge_mask_draw = ImageDraw.Draw(badge_mask)
badge_mask_draw.rounded_rectangle(
    [badge_x, badge_y, badge_x + badge_size, badge_y + badge_size],
    radius=50, fill=255
)
badge.putalpha(badge_mask)

# Composite badge shadow
bshadow = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
bshadow_draw = ImageDraw.Draw(bshadow)
bshadow_draw.rounded_rectangle(
    [badge_x + 4, badge_y + 6, badge_x + badge_size + 4, badge_y + badge_size + 6],
    radius=50, fill=(0, 0, 0, 60)
)
bshadow = bshadow.filter(ImageFilter.GaussianBlur(radius=10))
img = Image.alpha_composite(img, bshadow)
img = Image.alpha_composite(img, badge)
draw = ImageDraw.Draw(img)

# "Md" text on badge
try:
    font_badge = ImageFont.truetype("/System/Library/Fonts/SFCompact-Bold.otf", 110)
except:
    try:
        font_badge = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 110)
    except:
        font_badge = ImageFont.load_default()

bbox = draw.textbbox((0, 0), "Md", font=font_badge)
tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
tx = badge_x + (badge_size - tw) // 2
ty = badge_y + (badge_size - th) // 2 - 8
draw.text((tx, ty), "Md", fill=(255, 255, 255), font=font_badge)

# --- Save as iconset ---
iconset = "MarkView.iconset"
os.makedirs(iconset, exist_ok=True)

sizes = [16, 32, 64, 128, 256, 512]
for s in sizes:
    resized = img.resize((s, s), Image.LANCZOS)
    resized.save(f"{iconset}/icon_{s}x{s}.png")
    resized2x = img.resize((s * 2, s * 2), Image.LANCZOS)
    resized2x.save(f"{iconset}/icon_{s}x{s}@2x.png")

print("Converting to .icns...")
subprocess.run(["iconutil", "-c", "icns", iconset, "-o", "MarkView.icns"], check=True)
shutil.rmtree(iconset)
print("MarkView.icns created!")
