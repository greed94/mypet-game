"""Generate the public test pictures from geometric shapes, without source photos."""

from io import BytesIO
from PIL import Image, ImageDraw


def make_photos() -> dict[str, bytes]:
    sofa = Image.new("RGB", (900, 600), (85, 145, 166))
    draw = ImageDraw.Draw(sofa)
    draw.rounded_rectangle((-40, 105, 940, 451), radius=48, fill=(83, 141, 158))
    draw.line((450, 113, 450, 448), fill=(77, 137, 154), width=7)
    draw.rounded_rectangle((-25, 428, 923, 597), radius=42, fill=(75, 126, 154))
    draw.ellipse((606, 310, 811, 512), fill=(160, 94, 51))
    draw.ellipse((652, 338, 759, 477), fill=(224, 165, 108))
    draw.ellipse((587, 147, 814, 366), fill=(207, 145, 92))
    draw.ellipse((568, 158, 635, 317), fill=(133, 77, 42))
    draw.ellipse((768, 159, 835, 314), fill=(140, 81, 45))
    draw.ellipse((668, 231, 742, 304), fill=(220, 164, 106))
    for x in (659, 743):
        draw.ellipse((x - 8, 210, x + 8, 229), fill=(54, 43, 42))
        draw.ellipse((x - 4, 213, x, 217), fill=(247, 240, 223))
    draw.ellipse((685, 250, 716, 269), fill=(56, 44, 42))
    draw.arc((684, 261, 718, 286), 12, 168, fill=(86, 57, 46), width=3)
    for x in (648, 746):
        draw.ellipse((x - 28, 465, x + 27, 502), fill=(208, 150, 96))

    coat = Image.new("RGB", (96, 96), (239, 232, 224))
    coat_draw = ImageDraw.Draw(coat)
    coat_draw.ellipse((13, 22, 41, 75), fill=(147, 86, 43))
    coat_draw.ellipse((64, 35, 79, 60), fill=(180, 107, 59))
    photos = {}
    for filename, picture, fmt in [
        ("synthetic-beagle.jpg", sofa, "JPEG"),
        ("synthetic-coat.png", coat, "PNG"),
    ]:
        output = BytesIO()
        picture.save(output, format=fmt, **({"quality": 91} if fmt == "JPEG" else {}))
        photos[filename] = output.getvalue()
    return photos


if __name__ == "__main__":
    from pathlib import Path

    for name, data in make_photos().items():
        Path(__file__).with_name(name).write_bytes(data)
