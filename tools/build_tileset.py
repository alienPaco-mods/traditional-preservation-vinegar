#!/usr/bin/env python3
"""Builds the Traditional Preservation (Vinegar) art: the tileset, the bucket icons and model textures, and the bucket item script.

Each station is a pair of tiles, east facing then south facing. The pair numbers are in VESSEL, CASK, FLOOR, OVERLAYS
and HOSE_OVERLAYS, and the Lua reads them from the generated 42/media/lua/shared/TraditionalPreservationVinegar/Tiles.lua. Overlays are layered over the base tile by
TraditionalPreservationVinegarWorld.lua, so a state only paints what it adds. Workstations need their own sprite: the game refuses to load a world if two entities share one.

Usage: python3 tools/build_tileset.py [path/to/ProjectZomboid/projectzomboid]
Needs Pillow. Rerun after editing the colours or sizes below.
"""
import io
import math
import os
import random
import struct
import sys
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw

sys.path.insert(0, str(Path(os.environ.get("TPCORE", Path(__file__).resolve().parents[2] / "_tpcore")) / "tools"))
import pzart  # noqa: E402

NAME = "traditionalpreservationvinegar"
TILESET = NAME + "_01"
COLUMNS, ROWS = 8, 5
PAGE_SIZE = 1024
TILE_W, TILE_H = 128, 256
SS = 4  # supersampling
# The mod list icon, in the Fish mod's style.
MOD_ICON_SIZE, MOD_ICON_MARGIN, MOD_ICON_CORNER, MOD_ICON_BADGE = 128, 8, 16, 52
MOD_ICON_SKY = (176, 196, 204, 255)
BUILD_ICON_SIZE = 64
FOOT_X, FOOT_Y = 64, 226

VESSEL, CASK, FLOOR = 0, 10, 24
OVERLAYS = {
    "vessel": {"filled": 2, "bubbling": 4, "sediment": 6, "finished": 8},
    "cask": {"filled": 12, "film1": 14, "film2": 16, "film3": 18, "finished": 20, "mother": 22},
    "floor": {"steeped": 26, "sprouting": 28, "rootlets": 30, "finished": 32},
}
# Drawn over whatever state a station is in, while a hose joins the vessel to a cask.
HOSE_OVERLAYS = {"vessel": 34, "cask": 36}
HOSE = (46, 44, 42)
HOSE_LIT = (92, 88, 82)

# The wood, iron and weathering follow the Salting Tub in Traditional Preservation (Fish), so the stations sit together.
STAVE = (130, 84, 50)
VESSEL_WOOD = (128, 74, 52)  # a redder wood than the cask, like redwood
HEAD_WOOD = (112, 74, 46)
SEAM = (38, 22, 14)
INSIDE_WOOD = (110, 74, 46)
IRON = (62, 64, 68)
IRON_LIT = (96, 98, 102)
RUST = (92, 58, 38)
RUST_CHANCE = 0.03
PIPE = (88, 74, 62)
PIPE_LIT = (126, 108, 88)
SHADOW = (0, 0, 0, 90)
SQUASH = 0.5
FOOT_SHADE = 0.65
WOOD_WEATHER = 0.15
# The pixel finish: how far colours are pulled to grey, how strong each pixel's grain is, and a mask
# that drops the lowest colour bits so tones step like hand-painted pixels.
MUTE = 0.2
PIXEL_GRAIN = 0.07
COLOUR_STEP = 0xFC
OVERLAY_WEATHER = 0.2
STAVES = 8
INSIDE_STAVES = 8
INSIDE_DEPTH = 16.0
INSIDE_SHADE = 0.55

LINEN = (98, 112, 126)  # a cool slate, so the cloth stands apart from the pale film and the warm wood
TWINE = (168, 142, 96)
TAP = (146, 114, 60)
TAP_LIT = (196, 164, 100)
FILM = (176, 166, 138)
VINEGAR = (96, 62, 30)
CIDER = (128, 92, 42)
SEDIMENT = (48, 34, 24)
GLASS = (66, 88, 72)
JAR_GLASS = (110, 124, 122)
WATER = (78, 104, 112)
BUNG = (86, 60, 40)

# The bucket items: name, display name, weight, contents colour, and whether the contents are solid.
# Wort and everything after it are liquids in vanilla containers, so only the mash is a bucket item.
BUCKETS = [
    ("BucketMash", "Bucket of Mash", 11.0, (150, 128, 84), True),
    ("BucketPreparedMash", "Bucket of Prepared Mash", 11.0, (120, 84, 44), True),
]
SOLID_SPECKS = (0.7, 1.2)
# Buckets of the two liquids, only as icons for the vessel's and cask's menus, in the fluids' ColorReference.
LIQUID_ICONS = [("BucketWort", (244, 164, 96)), ("BucketFermentedWort", (210, 180, 140))]
# The grain stages: name, display name, weight, colour, and whether it has sprouted.
GRAINS = [
    ("SteepedGrain", "Steeped Grain", 0.8, (168, 146, 96), False),
    ("GreenMalt", "Green Malt", 0.7, (160, 150, 92), True),
    ("Malt", "Malt", 0.5, (150, 104, 54), False),
    ("SpentGrain", "Spent Grain", 0.8, (104, 80, 52), False),
]
# Left over from straining. It rots like food, the composter takes it, and farm animals eat it from a trough.
COMPOSTABLE = {"SpentGrain": (3, 6)}
SPROUT = (214, 206, 170)
# The Mother of Vinegar in a jar: a living culture that keeps about a month, then dies like food.
MOTHER = ("MotherOfVinegar", "Mother of Vinegar", 0.6, 30, 40)
MOTHER_LIQUID = (124, 86, 44)
MOTHER_SKIN = (206, 190, 150)

# What heating turns these into, in minutes.
COOKED = {
    "BucketMash": ("BucketPreparedMash", 60),
    "GreenMalt": ("Malt", 120),
}
# Green malt keeps growing and then moulds unless it is kilned within a few days: fresh and rotten days.
# Rotten food skips ReplaceOnCooked, so rotten green malt never kilns into Malt, and the composter takes it.
SPOILS = {"GreenMalt": (2, 5)}

TILE_PROPS = {}
for base, custom, group in ((VESSEL, "Vessel", "Fermentation"), (CASK, "Cask", "Vinegar"), (FLOOR, "Floor", "Malting")):
    for offset, facing in ((0, "E"), (1, "S")):
        # The engine only links the facings of tiles with a GroupName, and that link lets a moved station rotate.
        TILE_PROPS[base + offset] = [("BlocksPlacement", ""), ("CustomName", custom), ("Facing", facing), ("GroupName", group), ("IsMoveAble", ""), ("PickUpWeight", "200"), ("solidtrans", "")]


def new_layer():
    return Image.new("RGBA", (TILE_W * SS, TILE_H * SS), (0, 0, 0, 0))


def shrink(layer):
    return layer.resize((TILE_W, TILE_H), Image.LANCZOS)


def shade(colour, amount):
    return tuple(max(0, min(255, int(c * amount))) for c in colour[:3]) + (255,)


def light_at(angle):
    """A curved front lit from the left and falling away hard on the right, like vanilla's barrels."""
    return 0.72 + 0.3 * max(0.0, math.cos(angle - 2.2)) ** 1.4


def darken_down(layer, top_y, bottom_y, lowest):
    """Fades a layer towards lowest brightness between two heights, so it sinks into the ground."""
    ramp = Image.new("L", layer.size, 255)
    top, bottom = int(top_y * SS), int(bottom_y * SS)
    fade = Image.linear_gradient("L").resize((layer.width, bottom - top)).point(lambda v: 255 - int(v * (1 - lowest)))
    ramp.paste(fade, (0, top))
    ramp.paste(int(255 * lowest), (0, bottom, layer.width, layer.height))
    rgb = ImageChops.multiply(layer.convert("RGB"), Image.merge("RGB", (ramp, ramp, ramp)))
    rgb.putalpha(layer.getchannel("A"))
    return rgb


def soft_noise(rng, size, cell_w, cell_h):
    """Smooth random greys, with blobs about cell_w by cell_h pixels."""
    small = Image.new("L", (max(2, size[0] // cell_w + 2), max(2, size[1] // cell_h + 2)))
    small.putdata([rng.randrange(256) for _ in range(small.width * small.height)])
    return small.resize(size, Image.BICUBIC)


def weather(tile, seed, depth, streaks=False):
    """Mottles a finished tile with dirt and grain, and water stains running down it when streaks is set.
    Vanilla art is hand painted and never flat, so everything goes through this."""
    rng = random.Random(seed * 31 + 7)
    dirt = Image.blend(soft_noise(rng, tile.size, 13, 13), soft_noise(rng, tile.size, 3, 3), 0.5)
    dirt = Image.blend(dirt, soft_noise(rng, tile.size, 1, 1), 0.35)
    if streaks:
        dirt = ImageChops.multiply(dirt, soft_noise(rng, tile.size, 3, 44).point(lambda v: 150 + v * 105 // 255))
        dirt = dirt.point(lambda v: min(255, v * 3 // 2))
    grime = dirt.point(lambda v: max(0, min(255, int(255 * (1 - depth * (1 - v / 150))))))
    rgb = ImageChops.multiply(tile.convert("RGB"), Image.merge("RGB", (grime, grime, grime)))
    rgb = pixel_finish(rgb, rng)
    rgb.putalpha(tile.getchannel("A"))
    return rgb


def pixel_finish(rgb, rng):
    """Vanilla tiles are painted at their real size, so every pixel has its own grain and the colours are
    muted. This mutes the supersampled art, adds grain in 1x2 pixel flecks, and steps the colours a little."""
    grey = rgb.convert("L").convert("RGB")
    rgb = Image.blend(rgb, grey, MUTE)
    pixels = rgb.load()
    width, height = rgb.size
    for y in range(0, height, 2):
        for x in range(width):
            amount = 1 + rng.uniform(-PIXEL_GRAIN, PIXEL_GRAIN)
            for dy in (0, 1):
                if y + dy < height:
                    r, g, b = pixels[x, y + dy]
                    pixels[x, y + dy] = (min(255, int(r * amount)) & COLOUR_STEP, min(255, int(g * amount)) & COLOUR_STEP, min(255, int(b * amount)) & COLOUR_STEP)
    return rgb


def box(cx, cy, rx, ry):
    return [(cx - rx) * SS, (cy - ry) * SS, (cx + rx) * SS, (cy + ry) * SS]


def poly(draw, points, colour):
    draw.polygon([(x * SS, y * SS) for x, y in points], fill=colour)


def line(draw, start, end, colour, width):
    draw.line([start[0] * SS, start[1] * SS, end[0] * SS, end[1] * SS], fill=colour, width=max(1, int(width * SS)))


def barrel_point(height, radius, belly, level, angle):
    """A point on a barrel's side, level being its height as a fraction of the barrel's."""
    rx = radius + belly * math.sin(level * math.pi)
    return (FOOT_X + rx * math.cos(angle), FOOT_Y - height * level + rx * SQUASH * math.sin(angle))


def paint_staves(layer, rng, height, radius, belly, wood):
    """Staves in slightly different tones, a little grain, and a soft seam between them. Kept close to
    vanilla's barrels, which are smooth with only faint stave lines."""
    draw = ImageDraw.Draw(layer)
    levels = [i / 14 for i in range(15)]
    edges = [0.0]
    while edges[-1] < math.pi:
        edges.append(edges[-1] + math.pi / STAVES * rng.uniform(0.75, 1.25))
    edges[-1] = math.pi
    for first, second in zip(edges, edges[1:]):
        tone = light_at((first + second) / 2) * rng.uniform(0.96, 1.04)
        left = [barrel_point(height, radius, belly, level, first) for level in levels]
        right = [barrel_point(height, radius, belly, level, second) for level in levels]
        poly(draw, left + right[::-1], shade(wood, tone))
        for _ in range(5):
            across = first + (second - first) * rng.random()
            start = rng.random()
            end = min(1.0, start + rng.uniform(0.1, 0.3))
            line(draw, barrel_point(height, radius, belly, start, across), barrel_point(height, radius, belly, end, across), shade(wood, tone * rng.uniform(0.9, 1.06)), 0.4)
        seam = shade(wood, tone * 0.62)
        draw.line([(x * SS, y * SS) for x, y in left], fill=seam, width=max(1, SS * 3 // 4))


def paint_hoop(draw, rng, height, radius, belly, level, half_height):
    """A flat iron band round the front, patched with rust."""
    steps = 40
    rust_left = 0
    for i in range(steps):
        first, second = math.pi * i / steps, math.pi * (i + 1) / steps
        if rust_left == 0 and rng.random() < RUST_CHANCE:
            rust_left = rng.randint(1, 5)
        colour = tuple(int(a + (b - a) * rng.uniform(0.25, 0.6)) for a, b in zip(IRON, RUST)) if rust_left else IRON
        rust_left = max(0, rust_left - 1)
        tone = light_at((first + second) / 2) * rng.uniform(0.9, 1.08)
        low = height * level - half_height
        high = height * level + half_height
        points = []
        for z, angle in ((high, first), (high, second), (low, second), (low, first)):
            x, y = barrel_point(height, radius + 0.7, belly, level, angle)
            points.append((x, y + height * level - z))
        poly(draw, points, shade(colour, tone))
        line(draw, points[0], points[1], shade(IRON_LIT, tone), 0.5)
        line(draw, points[2], points[3], shade(IRON, tone * 0.45), 1)


def paint_barrel_body(rng, height, radius, belly, hoops, wood=STAVE):
    """Everything but the top: the shadow, then the staves darkening to the ground, then the hoops."""
    layer = new_layer()
    draw = ImageDraw.Draw(layer)
    draw.ellipse(box(FOOT_X + 1, FOOT_Y + 1, radius + 2, (radius + 2) * SQUASH), fill=SHADOW)
    paint_staves(layer, rng, height, radius, belly, wood)
    layer = darken_down(layer, FOOT_Y - height, FOOT_Y, FOOT_SHADE)
    draw = ImageDraw.Draw(layer)
    for level, half_height in hoops:
        paint_hoop(draw, rng, height, radius, belly, level, half_height)
    return layer


def inside_mask(rim_y, rx):
    mask = Image.new("L", (TILE_W * SS, TILE_H * SS), 0)
    ImageDraw.Draw(mask).ellipse(box(FOOT_X, rim_y, rx, rx * SQUASH), fill=255)
    return mask


def clipped(art, mask):
    result = art.copy()
    result.putalpha(ImageChops.multiply(art.getchannel("A"), mask))
    return result


def paint_inside(rng, rim_y, rx):
    """The far wall's staves running down into the dark, lit on the right as the light comes from the left."""
    layer = new_layer()
    draw = ImageDraw.Draw(layer)
    floor_y, floor_rx = rim_y + INSIDE_DEPTH, rx * 0.8
    draw.ellipse(box(FOOT_X, rim_y, rx, rx * SQUASH), fill=shade(INSIDE_WOOD, 0.6))
    edges = [math.pi]
    while edges[-1] < math.tau:
        edges.append(edges[-1] + math.pi / INSIDE_STAVES * rng.uniform(0.8, 1.2))
    edges[-1] = math.tau

    def ring(cy, radius, angle):
        return (FOOT_X + radius * math.cos(angle), cy + radius * SQUASH * math.sin(angle))

    for first, second in zip(edges, edges[1:]):
        tone = (0.72 + 0.34 * max(0.0, math.cos((first + second) / 2))) * rng.uniform(0.95, 1.05)
        poly(draw, [ring(rim_y, rx, first), ring(rim_y, rx, second), ring(floor_y, floor_rx, second), ring(floor_y, floor_rx, first)], shade(INSIDE_WOOD, tone))
        line(draw, ring(rim_y, rx, second), ring(floor_y, floor_rx, second), SEAM + (255,), 0.7)
    draw.ellipse(box(FOOT_X, floor_y, floor_rx, floor_rx * SQUASH), fill=shade(INSIDE_WOOD, 0.4))
    return darken_down(layer, rim_y - rx * SQUASH, floor_y + floor_rx * SQUASH, INSIDE_SHADE)


CASK_HEIGHT, CASK_RADIUS, CASK_BELLY = 65, 26.5, 5.3
CASK_TOP = FOOT_Y - CASK_HEIGHT
CASK_HOOPS = [(0.08, 2.6), (0.3, 2.2), (0.72, 2.2), (0.93, 2.6)]
CASK_INNER = CASK_RADIUS - 3
CASK_RY = CASK_RADIUS * SQUASH
LIQUID_DROP = 6
SKIN_FROM = 0.9  # the film's coverage from which it is one unbroken skin


def paint_cask(east):
    rng = random.Random(5 + east)
    layer = paint_barrel_body(rng, CASK_HEIGHT, CASK_RADIUS, CASK_BELLY, CASK_HOOPS)
    draw = ImageDraw.Draw(layer)
    draw.ellipse(box(FOOT_X, CASK_TOP, CASK_RADIUS, CASK_RY), fill=shade(STAVE, 1.05))
    layer.alpha_composite(clipped(paint_inside(rng, CASK_TOP, CASK_INNER), inside_mask(CASK_TOP, CASK_INNER)))
    # The spigot low on the front, on the side the cask faces.
    draw = ImageDraw.Draw(layer)
    side = 1 if east else -1
    x, y = FOOT_X + side * 15, FOOT_Y - 2
    line(draw, (x, y), (x + side * 9, y + 3), shade(HEAD_WOOD, 0.5), 4)
    line(draw, (x, y - 1), (x + side * 9, y + 2), shade(HEAD_WOOD, 0.8), 1.4)
    line(draw, (x + side * 9, y + 3), (x + side * 9, y + 8), shade(HEAD_WOOD, 0.45), 3)
    return weather(shrink(layer), 5 + east, WOOD_WEATHER, streaks=True)


def surface(colour):
    """The liquid in the cask, a little below the rim so the front rim stays in front of it."""
    layer = new_layer()
    draw = ImageDraw.Draw(layer)
    y = CASK_TOP + LIQUID_DROP
    draw.ellipse(box(FOOT_X, y, CASK_INNER, CASK_INNER * SQUASH), fill=shade(colour, 0.72))
    draw.ellipse(box(FOOT_X - 3, y - 1, CASK_INNER - 6, (CASK_INNER - 6) * SQUASH), fill=colour + (255,))
    return layer


def paint_film(layer, coverage, seed, y=CASK_TOP + LIQUID_DROP, rx=CASK_INNER):
    """The mother: pale patches that spread from the rim and join into one unbroken skin."""
    rng = random.Random(seed)
    film = new_layer()
    draw = ImageDraw.Draw(film)
    if coverage >= SKIN_FROM:
        draw.ellipse(box(FOOT_X, y, rx, rx * SQUASH), fill=shade(FILM, 0.84))
    for _ in range(int(90 * coverage)):
        angle = rng.uniform(0, 2 * math.pi)
        reach = rng.uniform(1 - coverage, 1) ** 0.5
        px = FOOT_X + math.cos(angle) * reach * (rx - 2)
        py = y + math.sin(angle) * reach * (rx - 2) * SQUASH
        size = rng.uniform(2.0, 5.0)
        draw.ellipse(box(px, py, size, size * 0.55), fill=shade(FILM, rng.uniform(0.82, 1.08))[:3] + (int(150 + 90 * coverage),))
    if coverage >= SKIN_FROM:
        # Wrinkles where the skin has puckered.
        for _ in range(16):
            angle = rng.uniform(0, 2 * math.pi)
            reach = rng.uniform(0, 0.9)
            px = FOOT_X + math.cos(angle) * reach * rx
            py = y + math.sin(angle) * reach * rx * SQUASH
            line(draw, (px, py), (px + rng.uniform(-6, 6), py + rng.uniform(-1.5, 1.5)), shade(FILM, rng.uniform(0.66, 0.76)), 0.7)
    layer.alpha_composite(film)


def paint_cloth(layer):
    """The breathable cover, drawn back over the rear half and tied with twine, so the surface shows at the front."""
    rng = random.Random(61)
    draw = ImageDraw.Draw(layer)
    cx, cy, rx, ry = FOOT_X, CASK_TOP, CASK_RADIUS + 1, CASK_RY + 1
    points = [(cx + rx * math.cos(a), cy + ry * math.sin(a)) for a in [math.pi + i * math.pi / 24 for i in range(25)]]
    points += [(cx + rx - 8, cy - 2), (cx + 8, cy - 4), (cx - 8, cy - 5), (cx - rx + 8, cy - 3)]
    poly(draw, points, LINEN + (255,))
    for _ in range(26):
        x = cx + rng.uniform(-rx + 6, rx - 6)
        top = cy - ry * rng.uniform(0.3, 0.9)
        line(draw, (x, top), (x + rng.uniform(-3, 3), top + rng.uniform(3, 8)), shade(LINEN, rng.uniform(0.72, 1.1)), 0.8)
    draw.arc(box(cx, cy, rx, ry), 180, 360, fill=TWINE + (255,), width=int(1.4 * SS))


def paint_bottles(layer):
    draw = ImageDraw.Draw(layer)
    for index, (bx, by) in enumerate(((98, 216), (108, 210), (88, 224))):
        draw.ellipse(box(bx, by, 4.5, 2.5), fill=SHADOW)
        poly(draw, [(bx - 3.5, by), (bx + 3.5, by), (bx + 3.5, by - 13), (bx + 1.4, by - 17), (bx + 1.4, by - 22), (bx - 1.4, by - 22), (bx - 1.4, by - 17), (bx - 3.5, by - 13)], shade(GLASS, 0.9 + index * 0.05))
        line(draw, (bx - 2, by - 2), (bx - 2, by - 12), shade(GLASS, 1.4), 0.8)
        poly(draw, [(bx - 1.5, by - 22), (bx + 1.5, by - 22), (bx + 1.5, by - 24), (bx - 1.5, by - 24)], shade(HEAD_WOOD, 1))


def cask_overlay(state, seed):
    if state == "mother":
        layer = new_layer()
        paint_film(layer, 1.0, 77, CASK_TOP + LIQUID_DROP + 4, CASK_INNER - 3)
    else:
        layer = surface(VINEGAR if state == "finished" else CIDER)
        coverage = {"filled": 0, "film1": 0.3, "film2": 0.6, "film3": 1.0, "finished": 1.0}[state]
        if coverage:
            paint_film(layer, coverage, 40)
    layer = clipped(layer, inside_mask(CASK_TOP, CASK_INNER))
    paint_cloth(layer)
    if state == "finished":
        paint_bottles(layer)
    return weather(shrink(layer), seed, OVERLAY_WEATHER)


def paint_hose(draw, points, coil):
    """A rubber hose along points, with its spare length coiled on the ground at coil (x, y, radius)."""
    cx, cy, radius = coil
    draw.ellipse(box(cx + 1, cy + 1, radius + 2, (radius + 2) * SQUASH), fill=SHADOW)
    for ring in (radius, radius - 2.6):
        draw.ellipse(box(cx, cy, ring, ring * SQUASH), outline=HOSE + (255,), width=int(2.6 * SS))
        draw.ellipse(box(cx - 0.4, cy - 0.5, ring, ring * SQUASH), outline=HOSE_LIT + (255,), width=SS // 2 + 1)
    for start, end in zip(points, points[1:]):
        line(draw, start, end, HOSE + (255,), 3)
    for start, end in zip(points, points[1:]):
        line(draw, (start[0] - 0.5, start[1] - 0.5), (end[0] - 0.5, end[1] - 0.5), HOSE_LIT + (255,), 0.8)


def hose_overlay(kind, east, seed):
    layer = new_layer()
    draw = ImageDraw.Draw(layer)
    side = 1 if east else -1
    if kind == "vessel":
        # Pushed over the tap's spout, then down to a coil on the ground beside the vessel.
        spout_x = FOOT_X - side * (TAP_OFFSET + SPOUT_LEAN)
        coil_x = FOOT_X - side * 34
        points = [(spout_x, FOOT_Y + 2), (spout_x - side * 3, FOOT_Y + 9), (spout_x - side * 12, FOOT_Y + 13), (coil_x + side * 8, FOOT_Y + 12)]
        paint_hose(draw, points, (coil_x, FOOT_Y + 10, 8))
        # A twist of twine binding it to the spout.
        line(draw, (spout_x - 2.5, FOOT_Y + 3), (spout_x + 2.5, FOOT_Y + 3), (168, 150, 112, 255), 1.4)
    else:
        # In under the cloth on the left, over the rim and down the staves to a coil.
        rim_x = FOOT_X - (CASK_RADIUS - 3)
        out_x = FOOT_X - (CASK_RADIUS + 2)
        points = [(rim_x + 6, CASK_TOP + 2), (rim_x, CASK_TOP - 2), (out_x, CASK_TOP + 4), (out_x - 1, FOOT_Y - 24), (out_x - 4, FOOT_Y + 2)]
        paint_hose(draw, points, (out_x - 10, FOOT_Y + 6, 7))
    return weather(shrink(layer), seed, OVERLAY_WEATHER)


VESSEL_HEIGHT, VESSEL_RADIUS, VESSEL_BELLY = 62, 25, 4.5
VESSEL_TOP = FOOT_Y - VESSEL_HEIGHT
VESSEL_HOOPS = [(0.06, 2.4), (0.34, 2.0), (0.66, 2.0), (0.94, 2.4)]
TAP_OFFSET, SPOUT_LEAN = 8, 2  # the sample cup sits under the spout's tip, at their sum
HEAD_LIGHT = (1.12, 1.26)  # a lid faces the sky, so it is lighter than the staves


def bung(east):
    return FOOT_X + (8 if east else -8)


def jar_x(east):
    return FOOT_X + (33 if east else -33)


def paint_pipe(draw, points):
    for start, end in zip(points, points[1:]):
        line(draw, start, end, shade(PIPE, 0.6), 3)
    for start, end in zip(points, points[1:]):
        line(draw, (start[0] - 0.4, start[1] - 0.4), (end[0] - 0.4, end[1] - 0.4), PIPE_LIT + (255,), 1)


def paint_jar(layer, jx):
    """A small jar of water on the ground, that the gas bubbles out through."""
    draw = ImageDraw.Draw(layer)
    base, top = FOOT_Y + 2, FOOT_Y - 16
    draw.ellipse(box(jx + 1, base + 1, 9, 4.5), fill=SHADOW)
    poly(draw, [(jx - 7, base), (jx + 7, base), (jx + 7, top), (jx - 7, top)], shade(JAR_GLASS, 0.62))
    draw.ellipse(box(jx, base, 7, 3.5), fill=shade(JAR_GLASS, 0.62))
    poly(draw, [(jx - 7, base), (jx + 7, base), (jx + 7, base - 10), (jx - 7, base - 10)], WATER + (255,))
    draw.ellipse(box(jx, base, 7, 3.5), fill=WATER + (255,))
    draw.ellipse(box(jx, base - 10, 7, 3.5), fill=shade(WATER, 1.25))
    line(draw, (jx - 5, base - 1), (jx - 5, top + 2), shade(JAR_GLASS, 1.15), 0.8)
    draw.ellipse(box(jx, top, 7, 3.5), outline=shade(JAR_GLASS, 1.1), width=SS)


def paint_vessel(east):
    rng = random.Random(9 + east)
    layer = paint_barrel_body(rng, VESSEL_HEIGHT, VESSEL_RADIUS, VESSEL_BELLY, VESSEL_HOOPS, VESSEL_WOOD)
    draw = ImageDraw.Draw(layer)
    # The sealed head, set in a little from the rim, with a shadow line where it meets the staves.
    ry = VESSEL_RADIUS * SQUASH
    draw.ellipse(box(FOOT_X, VESSEL_TOP, VESSEL_RADIUS, ry), fill=shade(VESSEL_WOOD, 1.1))
    draw.ellipse(box(FOOT_X, VESSEL_TOP + 0.5, VESSEL_RADIUS - 2.5, ry - 1.2), fill=shade(SEAM, 1.3))
    head = new_layer()
    head_draw = ImageDraw.Draw(head)
    width = VESSEL_RADIUS * 2 / 6
    for index in range(6):
        x = FOOT_X - VESSEL_RADIUS + index * width
        tone = rng.uniform(*HEAD_LIGHT)
        poly(head_draw, [(x, VESSEL_TOP - ry), (x + width, VESSEL_TOP - ry), (x + width, VESSEL_TOP + ry), (x, VESSEL_TOP + ry)], shade(VESSEL_WOOD, tone))
        for _ in range(3):
            gx = x + rng.uniform(0, width)
            gy = VESSEL_TOP + rng.uniform(-ry, ry)
            line(head_draw, (gx, gy), (gx, gy + rng.uniform(2, 6)), shade(VESSEL_WOOD, tone * rng.uniform(0.84, 1.08)), 0.4)
        line(head_draw, (x, VESSEL_TOP - ry), (x, VESSEL_TOP + ry), shade(SEAM, 1.6), 0.5)
    layer.alpha_composite(clipped(head, inside_mask(VESSEL_TOP + 0.4, VESSEL_RADIUS - 3)))
    # A brass tap low on the front, to draw it off.
    draw = ImageDraw.Draw(layer)
    side = 1 if east else -1
    tap_x, tap_y = FOOT_X - side * TAP_OFFSET, FOOT_Y - 7
    draw.ellipse(box(tap_x, tap_y, 5, 4.2), fill=shade(TAP, 0.45))
    draw.ellipse(box(tap_x, tap_y - 0.5, 3.6, 3), fill=shade(TAP, 0.9))
    line(draw, (tap_x, tap_y), (tap_x - side * SPOUT_LEAN, tap_y + 7), shade(TAP, 0.55), 5)
    line(draw, (tap_x - 0.6, tap_y), (tap_x - side * SPOUT_LEAN - 0.6, tap_y + 7), TAP_LIT + (255,), 1.6)
    line(draw, (tap_x - side * SPOUT_LEAN, tap_y + 7), (tap_x - side * SPOUT_LEAN, tap_y + 11), shade(TAP, 0.5), 4)
    line(draw, (tap_x, tap_y - 2), (tap_x, tap_y - 7), shade(TAP, 0.6), 2.6)
    line(draw, (tap_x - 5, tap_y - 7), (tap_x + 5, tap_y - 7), shade(TAP, 0.6), 3)
    line(draw, (tap_x - 5, tap_y - 7.6), (tap_x + 5, tap_y - 7.6), TAP_LIT + (255,), 1)
    # The gas outlet: a bung and a bent pipe down into the jar.
    bung_x, jx = bung(east), jar_x(east)
    draw.ellipse(box(bung_x, VESSEL_TOP + 1, 4, 2), fill=shade(BUNG, 0.7))
    draw.ellipse(box(bung_x, VESSEL_TOP, 3.4, 1.7), fill=shade(BUNG, 1.1))
    paint_jar(layer, jx)
    paint_pipe(ImageDraw.Draw(layer), [(bung_x, VESSEL_TOP), (bung_x, VESSEL_TOP - 9), (jx, VESSEL_TOP - 9), (jx, FOOT_Y - 7)])
    return weather(shrink(layer), 9 + east, WOOD_WEATHER, streaks=True)


def paint_foam(draw, rng, east, colour, patches):
    """Foam worked up round the bung, spreading across the lid."""
    bx = bung(east)
    for _ in range(patches):
        angle = rng.uniform(0, math.tau)
        reach = rng.uniform(2, 10)
        size = rng.uniform(1.4, 3.2)
        draw.ellipse(box(bx + math.cos(angle) * reach, VESSEL_TOP + 1 + math.sin(angle) * reach * SQUASH, size, size * 0.6), fill=shade(colour, rng.uniform(0.86, 1.08)))
    draw.ellipse(box(bx, VESSEL_TOP, 3.4, 1.7), fill=shade(BUNG, 1.1))


def paint_cup(draw, east, colour, lees):
    """A sample drawn off from the tap, stood on the ground in front of it. Lees sink to the bottom."""
    side = 1 if east else -1
    x, y = FOOT_X - side * (TAP_OFFSET + SPOUT_LEAN), FOOT_Y + 11
    draw.ellipse(box(x + 1, y + 1, 6, 3), fill=SHADOW)
    poly(draw, [(x - 4.5, y), (x + 4.5, y), (x + 5, y - 9), (x - 5, y - 9)], shade(JAR_GLASS, 0.72))
    draw.ellipse(box(x, y, 4.5, 2.2), fill=shade(JAR_GLASS, 0.72))
    poly(draw, [(x - 4.5, y), (x + 4.5, y), (x + 4.8, y - 7), (x - 4.8, y - 7)], colour + (255,))
    draw.ellipse(box(x, y, 4.5, 2.2), fill=colour + (255,))
    if lees:
        poly(draw, [(x - 4.5, y), (x + 4.5, y), (x + 4.6, y - lees), (x - 4.6, y - lees)], SEDIMENT + (255,))
        draw.ellipse(box(x, y, 4.5, 2.2), fill=SEDIMENT + (255,))
    draw.ellipse(box(x, y - 7, 4.8, 2.3), fill=shade(colour, 1.2))
    draw.ellipse(box(x, y - 9, 5, 2.5), outline=shade(JAR_GLASS, 1.1), width=SS // 2 + 1)


CHALK = (176, 172, 158)


def paint_chalk_stroke(draw, rng, start, end):
    """One stroke of chalk: a slight bow and wobble, tapering at both ends, with dry gaps on the grain."""
    steps = 14
    bow = rng.uniform(-0.8, 0.8)
    dx, dy = end[0] - start[0], end[1] - start[1]
    length = math.hypot(dx, dy)
    nx, ny = -dy / length, dx / length
    points = []
    for i in range(steps + 1):
        t = i / steps
        offset = bow * math.sin(t * math.pi) + rng.uniform(-0.15, 0.15)
        points.append((start[0] + dx * t + nx * offset, start[1] + dy * t + ny * offset))
    for i in range(steps):
        t = (i + 0.5) / steps
        if rng.random() < 0.1:
            continue
        width = 0.7 + 1.9 * math.sin(t * math.pi) ** 0.8
        alpha = int(255 * rng.uniform(0.7, 1.0))
        line(draw, points[i], points[i + 1], CHALK + (alpha,), width)


def vessel_overlay(state, east, seed):
    layer = new_layer()
    draw = ImageDraw.Draw(layer)
    rng = random.Random(21)
    if state == "filled":
        # A wet ring round the bung from filling it.
        draw.ellipse(box(bung(east), VESSEL_TOP + 1, 7, 3.5), fill=shade(VESSEL_WOOD, 0.7))
        draw.ellipse(box(bung(east), VESSEL_TOP, 3.4, 1.7), fill=shade(BUNG, 1.1))
    elif state == "bubbling":
        paint_foam(draw, rng, east, FILM, 34)
        jx = jar_x(east)
        for _ in range(8):
            bx, by = jx + rng.uniform(-4, 4), FOOT_Y + 2 - rng.uniform(2, 10)
            draw.ellipse(box(bx, by, 1.2, 1.2), outline=shade(JAR_GLASS, 1.4), width=SS // 2)
    elif state == "sediment":
        # The foam has dropped back to a crust, and a sample shows the lees settling.
        paint_foam(draw, rng, east, shade(CIDER, 1.1)[:3], 14)
        paint_cup(draw, east, shade(CIDER, 0.8)[:3], 2)
    else:
        paint_cup(draw, east, shade(CIDER, 1.15)[:3], 3)
        # A chalk cross on the staves: ready to draw off. Two quick hand strokes, the second a little shorter.
        cx, cy = FOOT_X + 3, FOOT_Y - 33
        chalk_rng = random.Random(seed * 7 + 3)
        paint_chalk_stroke(draw, chalk_rng, (cx - 5.5, cy - 5), (cx + 5, cy + 5.5))
        paint_chalk_stroke(draw, chalk_rng, (cx + 4.5, cy - 4.5), (cx - 4.5, cy + 4))
    return weather(shrink(layer), seed, OVERLAY_WEATHER)


DIAMOND_HALF_W, DIAMOND_HALF_H = 62, 31
TRAY_LONG, TRAY_SHORT = 0.44, 0.31  # tiles from the middle to each side
TRAY_HEIGHT, TRAY_FOOT = 18, 4
BED_DROP = 5  # how far the grain lies below the rim
SHOVEL = (112, 82, 54)


def project(x, y, z=0.0):
    """x and y are in tiles from the middle of the floor (+x runs down-right, +y down-left), z in pixels."""
    return (FOOT_X + (x - y) * DIAMOND_HALF_W, FOOT_Y + (x + y) * DIAMOND_HALF_H - z)


def tray_size(east):
    return (TRAY_LONG, TRAY_SHORT) if east else (TRAY_SHORT, TRAY_LONG)


def paint_side(draw, rng, first, second, tone):
    """A tray side between two corners, of three boards with grain and seams."""
    boards = 3
    for board in range(boards):
        low = TRAY_FOOT + (TRAY_HEIGHT - TRAY_FOOT) * board / boards
        high = TRAY_FOOT + (TRAY_HEIGHT - TRAY_FOOT) * (board + 1) / boards
        shade_here = tone * rng.uniform(0.93, 1.07)
        poly(draw, [project(*first, high), project(*second, high), project(*second, low), project(*first, low)], shade(STAVE, shade_here))
        for _ in range(26):
            t = rng.random()
            run = rng.uniform(0.06, 0.26)
            z = rng.uniform(low, high)
            start = (first[0] + (second[0] - first[0]) * t, first[1] + (second[1] - first[1]) * t)
            u = min(1, t + run)
            end = (first[0] + (second[0] - first[0]) * u, first[1] + (second[1] - first[1]) * u)
            line(draw, project(*start, z), project(*end, z), shade(STAVE, shade_here * rng.uniform(0.78, 1.14)), 0.4)
        line(draw, project(*first, low), project(*second, low), SEAM + (255,), 0.7)


def paint_floor(east):
    """A shallow wooden tray on low battens, that grain is spread out in to sprout."""
    rng = random.Random(14 + east)
    layer = new_layer()
    draw = ImageDraw.Draw(layer)
    hx, hy = tray_size(east)
    back, right, front, left = (-hx, -hy), (hx, -hy), (hx, hy), (-hx, hy)
    poly(draw, [project(back[0] - 0.03, back[1] - 0.03), project(right[0] + 0.05, right[1] - 0.03), project(front[0] + 0.05, front[1] + 0.05), project(left[0] - 0.03, left[1] + 0.05)], SHADOW)
    # Inside, seen over the near rim: the bottom boards, then the two far walls in lit wood like vanilla's
    # composter, the one facing the light brighter, each with seams between its boards.
    inset, floor_z = 0.86, TRAY_FOOT + 3
    def inner(corner):
        return project(corner[0] * inset, corner[1] * inset, floor_z)
    poly(draw, [inner(back), inner(right), inner(front), inner(left)], shade(STAVE, 0.74))
    # Seams between the bottom boards, running parallel to the back edge.
    for t in (0.33, 0.66):
        near = (back[0] + (left[0] - back[0]) * t, back[1] + (left[1] - back[1]) * t)
        far = (right[0] + (front[0] - right[0]) * t, right[1] + (front[1] - right[1]) * t)
        line(draw, inner(near), inner(far), shade(STAVE, 0.54), 0.6)
    for first, second, tone in ((back, right, 1.02), (left, back, 0.8)):
        poly(draw, [project(*first, TRAY_HEIGHT), project(*second, TRAY_HEIGHT), inner(second), inner(first)], shade(STAVE, tone))
        for t in (0.34, 0.67):
            z = TRAY_HEIGHT + (floor_z - TRAY_HEIGHT) * t
            def at(corner):
                k = 1 + (inset - 1) * t
                return project(corner[0] * k, corner[1] * k, z)
            line(draw, at(first), at(second), shade(STAVE, tone * 0.7), 0.7)
    paint_side(draw, rng, left, front, 1.06)
    paint_side(draw, rng, front, right, 0.84)
    # The rim, lit along the top.
    for first, second, tone in ((back, right, 0.9), (right, front, 0.8), (front, left, 1.12), (left, back, 1.0)):
        line(draw, project(*first, TRAY_HEIGHT), project(*second, TRAY_HEIGHT), shade(STAVE, tone), 2.4)
    layer = darken_down(layer, FOOT_Y - TRAY_HEIGHT, FOOT_Y + 26, 0.85)
    return weather(shrink(layer), 14 + east, WOOD_WEATHER, streaks=True)


def bed_point(rng, east):
    hx, hy = tray_size(east)
    return project(rng.uniform(-hx, hx) * 0.88, rng.uniform(-hy, hy) * 0.88, TRAY_HEIGHT - BED_DROP)


def floor_overlay(state, east, seed):
    """The grain spread in the tray, wet at first, then sprouting pale rootlets that mat together."""
    rng = random.Random(40)
    layer = new_layer()
    draw = ImageDraw.Draw(layer)
    hx, hy = tray_size(east)
    z = TRAY_HEIGHT - BED_DROP
    corners = [project(-hx * 0.9, -hy * 0.9, z), project(hx * 0.9, -hy * 0.9, z), project(hx * 0.9, hy * 0.9, z), project(-hx * 0.9, hy * 0.9, z)]
    colour = {"steeped": (112, 96, 62), "sprouting": (130, 112, 72), "rootlets": (138, 126, 80), "finished": (150, 138, 86)}[state]
    poly(draw, corners, shade(colour, 0.8))
    for _ in range(520):
        x, y = bed_point(rng, east)
        draw.ellipse(box(x, y, 1.3, 0.8), fill=shade(colour, rng.uniform(0.72, 1.28)))
    sprouts = {"steeped": 0, "sprouting": 60, "rootlets": 240, "finished": 420}[state]
    for _ in range(sprouts):
        x, y = bed_point(rng, east)
        line(draw, (x, y), (x + rng.uniform(-3, 3), y + rng.uniform(-2, 1)), shade(SPROUT, rng.uniform(0.76, 1.05)), 0.5)
    if state == "finished":
        # A wooden malt shovel left on the bed: it has been turned for the last time.
        x, y = project(0.1, -0.05, z + 2)
        line(draw, (x - 18, y - 11), (x + 7, y + 4), shade(SHOVEL, 0.55), 2.6)
        line(draw, (x - 18, y - 12), (x + 7, y + 3), shade(SHOVEL, 1.15), 1)
        poly(draw, [(x + 6, y + 1), (x + 15, y + 1), (x + 19, y + 9), (x + 8, y + 10)], shade(SHOVEL, 1.05))
    return weather(shrink(layer), seed, OVERLAY_WEATHER)


def write_string(out, value):
    data = value.encode("utf8")
    out.write(struct.pack("<I", len(data)))
    out.write(data)


def write_pack(path, tiles):
    page = Image.new("RGBA", (PAGE_SIZE, PAGE_SIZE), (0, 0, 0, 0))
    entries = []
    x = y = shelf = 0
    for index, tile in sorted(tiles.items()):
        ox, oy, right, bottom = tile.getbbox()
        image = tile.crop((ox, oy, right, bottom))
        if x + image.width > PAGE_SIZE:
            x, y, shelf = 0, y + shelf, 0
        if y + image.height > PAGE_SIZE:
            raise SystemExit("tiles do not fit on the page")
        page.paste(image, (x, y))
        entries.append((f"{TILESET}_{index}", (x, y, image.width, image.height, ox, oy, tile.width, tile.height)))
        x += image.width
        shelf = max(shelf, image.height)

    png = io.BytesIO()
    page.save(png, "PNG")
    path.parent.mkdir(parents=True, exist_ok=True)
    with open(path, "wb") as out:
        out.write(b"PZPK")
        out.write(struct.pack("<II", 1, 1))
        write_string(out, NAME + "0")
        out.write(struct.pack("<II", len(entries), 1))
        for name, values in entries:
            write_string(out, name)
            out.write(struct.pack("<8I", *values))
        out.write(struct.pack("<I", len(png.getvalue())))
        out.write(png.getvalue())


def write_tiles(path):
    with open(path, "wb") as out:
        out.write(b"tdef")
        out.write(struct.pack("<II", 1, 1))
        out.write(f"{TILESET}\n{TILESET}.png\n".encode("utf8"))
        out.write(struct.pack("<IIII", COLUMNS, ROWS, 1, COLUMNS * ROWS))
        for index in range(COLUMNS * ROWS):
            props = TILE_PROPS.get(index, [])
            out.write(struct.pack("<I", len(props)))
            for key, value in props:
                out.write(f"{key}\n{value}\n".encode("utf8"))


def read_string(f):
    (length,) = struct.unpack("<I", f.read(4))
    return f.read(length).decode("utf8", "replace")


def extract_sprites(pack_path, wanted):
    """Returns {sprite name: full-size RGBA image} from a vanilla pack."""
    found = {}
    with open(pack_path, "rb") as f:
        if f.read(4) != b"PZPK":
            raise SystemExit(f"{pack_path}: not a PZPK pack")
        _version, pages = struct.unpack("<II", f.read(8))
        for _ in range(pages):
            read_string(f)
            count, _alpha = struct.unpack("<II", f.read(8))
            entries = []
            for _ in range(count):
                name = read_string(f)
                entries.append((name, struct.unpack("<8I", f.read(32))))
            (size,) = struct.unpack("<I", f.read(4))
            hits = [entry for entry in entries if entry[0] in wanted]
            if not hits:
                f.seek(size, 1)
                continue
            page = Image.open(io.BytesIO(f.read(size))).convert("RGBA")
            for name, (x, y, w, h, ox, oy, full_w, full_h) in hits:
                tile = Image.new("RGBA", (full_w, full_h), (0, 0, 0, 0))
                tile.paste(page.crop((x, y, x + w, y + h)), (ox, oy))
                found[name] = tile
    missing = wanted - found.keys()
    if missing:
        raise SystemExit(f"sprites not found in {pack_path}: {sorted(missing)}")
    return found


def recolour(image, is_fluid, colour, solid):
    """Repaints the fluid pixels in colour, keeping their light and dark unless the contents are solid."""
    rng = random.Random(1842)
    result = image.copy()
    pixels = result.load()
    fluid = [(x, y) for y in range(image.height) for x in range(image.width) if is_fluid(x, y)]
    brightness = [sum(pixels[point][:3]) / 3 for point in fluid]
    average = sum(brightness) / len(brightness)
    for point, value in zip(fluid, brightness):
        amount = rng.uniform(*SOLID_SPECKS) if solid else 0.9 + 0.1 * value / average
        pixels[point] = shade(colour, amount)[:3] + (pixels[point][3],)
    return result


def write_textures(folder, game):
    folder.mkdir(parents=True, exist_ok=True)
    icons = extract_sprites(game / "media/texturepacks/UI2.pack", {"Item_MetalBucket", "Item_MetalBucket_Water"})
    empty, water = icons["Item_MetalBucket"], icons["Item_MetalBucket_Water"]
    models = game / "media/textures/WorldItems"
    texture = Image.open(models / "BucketFullWater_New.png").convert("RGBA")
    mask = Image.open(models / "BucketFullWater_NewFLUIDTINT.png").convert("RGBA")
    for name, _label, _weight, colour, solid in BUCKETS:
        recolour(water, lambda x, y: empty.getpixel((x, y)) != water.getpixel((x, y)), colour, solid).save(folder / f"Item_{name}.png")
        recolour(texture, lambda x, y: mask.getpixel((x, y))[3] > 0, colour, solid).save(folder / f"{name}Model.png")
    for name, colour in LIQUID_ICONS:
        recolour(water, lambda x, y: empty.getpixel((x, y)) != water.getpixel((x, y)), colour, False).save(folder / f"Item_{name}.png")
    for name, _label, _weight, colour, sprouted in GRAINS:
        paint_grain_icon(colour, sprouted).save(folder / f"Item_{name}.png")
        paint_grain_texture(colour).save(folder / f"{name}Model.png")
    jars = extract_sprites(game / "media/texturepacks/UI2.pack", {"Item_GlassJar", "Item_GlassJar_Mask"})
    paint_mother_icon(jars["Item_GlassJar"], jars["Item_GlassJar_Mask"]).save(folder / f"Item_{MOTHER[0]}.png")


def paint_mother_icon(jar, mask):
    """The vanilla jar with vinegar in it and a pale skin floating on top."""
    icon = jar.copy()
    pixels = icon.load()
    fluid = [(x, y) for y in range(mask.height) for x in range(mask.width) if mask.getpixel((x, y))[3] > 0]
    top = min(y for _, y in fluid)
    for x, y in fluid:
        colour = MOTHER_SKIN if y < top + 3 else shade(MOTHER_LIQUID, 1.1 - 0.25 * (y - top) / max(1, mask.height - top))
        alpha = max(pixels[x, y][3], 200)
        pixels[x, y] = colour[:3] + (alpha,)
    return icon


def paint_grain_icon(colour, sprouted):
    """A little heap of grain, drawn large and shrunk, for the inventory."""
    rng = random.Random(sum(colour))
    size = 32 * SS
    icon = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(icon)
    draw.ellipse([3 * SS, 19 * SS, 29 * SS, 29 * SS], fill=(0, 0, 0, 90))
    for _ in range(170):
        height = rng.random()
        spread = 13 * (1 - height * 0.8)
        x = 16 + rng.uniform(-spread, spread)
        y = 25 - height * 15 + rng.uniform(-1.5, 1.5)
        draw.ellipse([(x - 1.7) * SS, (y - 1) * SS, (x + 1.7) * SS, (y + 1) * SS], fill=shade(colour, rng.uniform(0.7, 1.22)), outline=shade(colour, 0.5))
        if sprouted and rng.random() < 0.3:
            draw.line([x * SS, y * SS, (x + rng.uniform(-3, 3)) * SS, (y - rng.uniform(1, 3)) * SS], fill=shade(SPROUT, 1), width=SS // 2 + 1)
    return icon.resize((32, 32), Image.LANCZOS)


def paint_grain_texture(colour):
    rng = random.Random(sum(colour) + 1)
    texture = Image.new("RGBA", (64, 64), shade(colour, 0.8))
    draw = ImageDraw.Draw(texture)
    for _ in range(420):
        x, y = rng.randrange(64), rng.randrange(64)
        draw.ellipse([x - 2, y - 1, x + 2, y + 1], fill=shade(colour, rng.uniform(0.7, 1.25)))
    return texture


def write_build_icon(tile, path):
    """Crops a sprite to its art and centres it in a square, for the build menu."""
    art = tile.crop(tile.getbbox())
    scale = BUILD_ICON_SIZE / max(art.size)
    art = art.resize((max(1, round(art.width * scale)), max(1, round(art.height * scale))), Image.LANCZOS)
    icon = Image.new("RGBA", (BUILD_ICON_SIZE, BUILD_ICON_SIZE), (0, 0, 0, 0))
    icon.alpha_composite(art, ((BUILD_ICON_SIZE - art.width) // 2, (BUILD_ICON_SIZE - art.height) // 2))
    icon.save(path)


def item_lines(name, weight):
    """Anything heated has to be food, as only food cooks, but nobody can eat it."""
    lines = [f"    item {name}", "    {"]
    if name in COOKED:
        result, minutes = COOKED[name]
        lines += ["        DisplayCategory = Food,", "        ItemType = base:food,", "        CantEat = true,", "        CantBeFrozen = true,", "        IsCookable = true,",
                  f"        MinutesToCook = {minutes},", "        MinutesToBurn = 1440,", f"        ReplaceOnCooked = TraditionalPreservationVinegar.{result},", "        FoodType = NoExplicit,"]
        if name in SPOILS:
            fresh, rotten = SPOILS[name]
            lines += ["        Tags = base:iscompostable,", f"        DaysFresh = {fresh},", f"        DaysTotallyRotten = {rotten},"]
    elif name in COMPOSTABLE:
        fresh, rotten = COMPOSTABLE[name]
        lines += ["        DisplayCategory = Material,", "        ItemType = base:food,", "        CantEat = true,", "        Tags = base:iscompostable,", "        AnimalFeedType = AnimalFeed,", "        HungerChange = -10.0,",
                  f"        DaysFresh = {fresh},", f"        DaysTotallyRotten = {rotten},", "        FoodType = NoExplicit,"]
    else:
        lines += ["        DisplayCategory = Material,", "        ItemType = base:normal,"]
    lines += [f"        Weight = {weight},", f"        Icon = {name},", f"        WorldStaticModel = {name}Ground,", f"        Tooltip = Tooltip_TraditionalPreservationVinegar_{name},", "    }", ""]
    return lines


def write_bucket_script(path):
    lines = ["/* Written by tools/build_tileset.py. */", "module TraditionalPreservationVinegar", "{", "    imports", "    {", "        Base,", "    }", ""]
    for name, _label, weight, _colour, _solid in BUCKETS:
        lines += [f"    model {name}Ground", "    {", "        mesh = WorldItems/BucketFull,", f"        texture = {name}Model,", "        scale = 0.35,", "    }", ""]
        lines += item_lines(name, weight)
    for name, _label, weight, _colour, _sprouted in GRAINS:
        lines += [f"    model {name}Ground", "    {", "        mesh = WorldItems/Poultice,", f"        texture = {name}Model,", "        scale = 0.6,", "    }", ""]
        lines += item_lines(name, weight)
    name, _label, weight, fresh, rotten = MOTHER
    lines += [f"    item {name}", "    {", "        DisplayCategory = Food,", "        ItemType = base:food,", "        CantEat = true,", "        FoodType = NoExplicit,",
              f"        DaysFresh = {fresh},", f"        DaysTotallyRotten = {rotten},", f"        Weight = {weight},", f"        Icon = {name},",
              "        WorldStaticModel = JarFoodBrown,", f"        Tooltip = Tooltip_TraditionalPreservationVinegar_{name},", "    }", ""]
    lines.append("}")
    path.write_text("\n".join(lines) + "\n")


def write_mod_icon(art, path, badge=None):
    """The station on the Fish mod's pale sky with rounded corners, so the series matches in the mod list."""
    art = art.crop(art.getbbox())
    scale = (MOD_ICON_SIZE - MOD_ICON_MARGIN) / max(art.size)
    art = art.resize((max(1, round(art.width * scale)), max(1, round(art.height * scale))), Image.LANCZOS)
    icon = Image.new("RGBA", (MOD_ICON_SIZE, MOD_ICON_SIZE), MOD_ICON_SKY)
    icon.alpha_composite(art, ((MOD_ICON_SIZE - art.width) // 2, MOD_ICON_SIZE - art.height - MOD_ICON_MARGIN // 2))
    if badge is not None:
        badge = badge.crop(badge.getbbox())
        badge = badge.resize((MOD_ICON_BADGE * badge.width // max(badge.size), MOD_ICON_BADGE * badge.height // max(badge.size)), Image.NEAREST)
        icon.alpha_composite(badge, (MOD_ICON_SIZE - badge.width - MOD_ICON_MARGIN // 2, MOD_ICON_SIZE - badge.height - MOD_ICON_MARGIN // 2))
    mask = Image.new("L", (MOD_ICON_SIZE * 4, MOD_ICON_SIZE * 4), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, mask.width - 1, mask.height - 1), MOD_ICON_CORNER * 4, fill=255)
    icon.putalpha(mask.resize(icon.size, Image.LANCZOS))
    path.parent.mkdir(parents=True, exist_ok=True)
    icon.save(path)


def lua_tiles():
    prefix = TILESET + "_"
    stations = {"vessel": VESSEL, "cask": CASK, "floor": FLOOR}
    return {
        "PREFIX": prefix,
        "SHEETS": [{"prefix": prefix, "tiles": COLUMNS * ROWS}],
        "FACE_COUNT": 2,
        "STATIONS": [prefix + str(base + face) for base in stations.values() for face in range(2)],
        **{name.upper(): base for name, base in stations.items()},
        "OVERLAYS": OVERLAYS,
        "HOSE": HOSE_OVERLAYS,
    }


def main():
    pzart.write_lua_tiles(Path(__file__).resolve().parent.parent / "42/media", "TraditionalPreservationVinegar", lua_tiles(), "tools/build_tileset.py")
    default_game = Path.home() / ".local/share/Steam/steamapps/common/ProjectZomboid/projectzomboid"
    game = Path(sys.argv[1]) if len(sys.argv) > 1 else default_game
    media = Path(__file__).resolve().parent.parent / "42/media"
    write_textures(media / "textures", game)
    tiles = {}
    for offset, east in ((0, True), (1, False)):
        tiles[VESSEL + offset] = paint_vessel(east)
        tiles[CASK + offset] = paint_cask(east)
        tiles[FLOOR + offset] = paint_floor(east)
        for state, index in OVERLAYS["floor"].items():
            tiles[index + offset] = floor_overlay(state, east, index)
        for state, index in OVERLAYS["vessel"].items():
            tiles[index + offset] = vessel_overlay(state, east, index)
        for state, index in OVERLAYS["cask"].items():
            tiles[index + offset] = cask_overlay(state, index)
        for kind, index in HOSE_OVERLAYS.items():
            tiles[index + offset] = hose_overlay(kind, east, index)
    write_pack(media / "texturepacks" / f"{NAME}.pack", tiles)
    write_tiles(media / f"{NAME}.tiles")
    write_build_icon(tiles[VESSEL + 1], media / "textures" / "Item_FermentationVessel.png")
    write_build_icon(tiles[CASK + 1], media / "textures" / "Item_VinegarCask.png")
    write_build_icon(tiles[FLOOR + 1], media / "textures" / "Item_MaltingFloor.png")
    # The mod list shows a cask ready to bottle, with the mother's skin and bottles at its foot.
    ready = tiles[CASK + 1].copy()
    ready.alpha_composite(tiles[OVERLAYS["cask"]["finished"] + 1])
    write_mod_icon(ready, media.parent / "icon.png")
    write_bucket_script(media / "scripts" / "TraditionalPreservationVinegar_items.txt")

    # A contact sheet for checking the art by eye, kept out of the mod.
    if len(sys.argv) > 2:
        sheet = Image.new("RGBA", (TILE_W * 7, TILE_H * 3), (96, 110, 88, 255))
        rows = [[VESSEL] + list(OVERLAYS["vessel"].values()), [CASK] + list(OVERLAYS["cask"].values()), [FLOOR] + list(OVERLAYS["floor"].values())]
        for y, row in enumerate(rows):
            for x, index in enumerate(row):
                cell = tiles[row[0]].copy()
                if index != row[0]:
                    cell.alpha_composite(tiles[index])
                sheet.alpha_composite(cell, (x * TILE_W, y * TILE_H))
        sheet.save(sys.argv[2])


if __name__ == "__main__":
    main()
