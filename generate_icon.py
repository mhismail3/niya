#!/usr/bin/env python3
"""Generate Niya app icon with geometric Arabic 'نية' logo.

Coordinates measured from original image scan data.
All coordinates are percentages of the logo bounding box (0-100).

Renders at 2x then downscales for antialiasing. Corner rounding is done
via gaussian blur + threshold on a binary mask, which naturally rounds all
outer corners uniformly without seams at joints.
"""

from PIL import Image, ImageDraw, ImageFilter

FINAL_SIZE = 1024
RENDER_SCALE = 2
RS = FINAL_SIZE * RENDER_SCALE
ROUND_PX = 20  # gaussian blur radius at render scale


def draw_logo_mask(size):
    """Return a grayscale mask with the logo, corners rounded via blur."""
    mask = Image.new('L', (size, size), 0)
    d = ImageDraw.Draw(mask)

    margin = int(size * 0.22)
    lw = size - 2 * margin
    lh = size - 2 * margin
    ox = margin + int(size * -0.02)  # nudge left for visual centering
    oy = margin + int(size * -0.01)  # nudge up slightly

    def rect(x1, y1, x2, y2, fill=255):
        px1 = ox + int(x1 / 100 * lw)
        py1 = oy + int(y1 / 100 * lh)
        px2 = ox + int(x2 / 100 * lw)
        py2 = oy + int(y2 / 100 * lh)
        d.rectangle([px1, py1, px2, py2], fill=fill)

    # === Top dots ===
    rect(0.2, 0, 11.8, 11)
    rect(17.0, 0, 28.6, 11)
    rect(88.4, 0, 100, 11)

    # === Left ة shape (solid block, then cut window) ===
    rect(0, 14.2, 28.6, 25.5)
    rect(0, 25.5, 11.4, 46)
    rect(17.4, 14.2, 28.6, 74.7)
    rect(0, 36, 28.6, 46)
    rect(11.4, 27, 17.4, 36, fill=0)  # window cutout

    # === Center bar ===
    rect(53.8, 26, 65.0, 74.7)

    # === Right wall ===
    rect(88.6, 14.2, 100, 85.7)

    # === Bottom bar ===
    rect(17.4, 74.7, 100, 85.7)

    # === Bottom dots ===
    rect(31.4, 89, 57.7, 100)
    rect(61.6, 89, 88.0, 100)

    # Blur + threshold rounds all corners uniformly, no seams at joints
    mask = mask.filter(ImageFilter.GaussianBlur(radius=ROUND_PX))
    mask = mask.point(lambda x: 255 if x > 128 else 0)
    return mask


def create_light_icon():
    bg = (245, 240, 232)   # cream/beige
    logo = (18, 53, 36)    # #123524

    mask = draw_logo_mask(RS)
    img = Image.new('RGB', (RS, RS), bg)
    logo_layer = Image.new('RGB', (RS, RS), logo)
    img.paste(logo_layer, mask=mask)
    return img.resize((FINAL_SIZE, FINAL_SIZE), Image.LANCZOS)


if __name__ == '__main__':
    import os

    out_dir = 'Niya/Resources/Assets.xcassets/AppIcon.appiconset'
    os.makedirs(out_dir, exist_ok=True)

    light = create_light_icon()
    light.save(os.path.join(out_dir, 'AppIcon.png'))
    print('Created light icon')

    contents = '''{
  "images" : [
    {
      "filename" : "AppIcon.png",
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}'''
    with open(os.path.join(out_dir, 'Contents.json'), 'w') as f:
        f.write(contents)
    print('Created Contents.json')
