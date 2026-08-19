#!/usr/bin/env python3
"""Generate the CapNoeh icon. Original artwork - no third-party assets."""
from PIL import Image, ImageDraw

S = 512
BG1, BG2 = (16, 18, 22), (26, 32, 44)
A1, A2 = (0, 208, 221), (18, 230, 164)      # cyan -> mint


def lerp(c1, c2, t):
    return tuple(int(a + (b - a) * t) for a, b in zip(c1, c2))


img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
d = ImageDraw.Draw(img)

# rounded-square backdrop with a soft vertical gradient
bg = Image.new("RGBA", (S, S), (0, 0, 0, 0))
bd = ImageDraw.Draw(bg)
for y in range(S):
    bd.line([(0, y), (S, y)], fill=lerp(BG1, BG2, y / S))
mask = Image.new("L", (S, S), 0)
ImageDraw.Draw(mask).rounded_rectangle([0, 0, S - 1, S - 1], radius=112, fill=255)
img.paste(bg, (0, 0), mask)

# gradient play triangle (the "run it" half)
tri = Image.new("RGBA", (S, S), (0, 0, 0, 0))
td = ImageDraw.Draw(tri)
td.polygon([(168, 132), (168, 380), (352, 256)], fill=(255, 255, 255, 255))
grad = Image.new("RGBA", (S, S))
gd = ImageDraw.Draw(grad)
for x in range(S):
    gd.line([(x, 0), (x, S)], fill=lerp(A1, A2, x / S) + (255,))
img.paste(grad, (0, 0), tri.split()[3])

# cut mark (the "edit it" half) - a clean vertical slice through the triangle
slice_mask = Image.new("L", (S, S), 0)
ImageDraw.Draw(slice_mask).rounded_rectangle(
    [286, 108, 314, 404], radius=14, fill=255
)
img.paste(Image.new("RGBA", (S, S), BG1 + (255,)), (0, 0), slice_mask)

bar = Image.new("L", (S, S), 0)
ImageDraw.Draw(bar).rounded_rectangle([328, 150, 356, 362], radius=14, fill=255)
img.paste(grad, (0, 0), bar)

img.save("capnoeh.png")
img.resize((256, 256), Image.LANCZOS).save("capnoeh-256.png")
print("wrote capnoeh.png (512) and capnoeh-256.png")
