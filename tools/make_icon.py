#!/usr/bin/env python3
"""Draw the CodeGraph icon: a little knowledge graph - one hub file and its satellites.

Pure standard library (zlib + struct), same no-pip rule as the rest of the project.
Every shape is a signed distance function evaluated per pixel with analytic
antialiasing, so each size is rendered natively instead of being scaled down blurry.

    python tools/make_icon.py

Writes assetlib/icon-graph-{512,256,128}.png (dark tile, what the Asset Library wants)
and assetlib/icon-graph-{512,256}-transparent.png (same glyph on a transparent tile).
Godot's rule: the icon must be square and at least 128x128.
"""

from __future__ import annotations

import struct
import sys
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assetlib"

# The palette of the interactive web graph (graph.py's viewer template).
BG = (27, 30, 36)
HUB = (76, 159, 224)        # the file you are looking at
RING = (126, 197, 240)      # selection ring around it
EDGE = (62, 106, 140)       # a relationship between two files
KIND = {
    "signal": (232, 96, 76),
    "autoload": (242, 179, 61),
    "group": (232, 93, 117),
    "extend": (127, 191, 77),
    "plain": (143, 154, 170),
}

# Unit space, 0..1.  Corner radius of the tile.
TILE_R = 0.185
HUB_C, HUB_R = (0.485, 0.545), 0.150
RING_R, RING_W = 0.208, 0.0075
EDGE_W = 0.0165
# centre, radius, kind
NODES = [
    ((0.175, 0.215), 0.098, "autoload"),
    ((0.495, 0.115), 0.068, "signal"),
    ((0.800, 0.230), 0.108, "group"),
    ((0.885, 0.600), 0.060, "plain"),
    ((0.705, 0.860), 0.086, "extend"),
    ((0.295, 0.845), 0.070, "plain"),
    ((0.105, 0.545), 0.058, "signal"),
]
RIM = [(0, 1), (2, 3), (4, 5)]   # extra edges between satellites, so it is not just a star


def check_inside_tile() -> None:
    """A node that pokes out of the rounded tile looks broken at 128 px - fail early."""
    inset = TILE_R
    for (cx, cy), r, _kind in NODES + [(HUB_C, HUB_R, "hub")]:
        if not (r <= cx <= 1 - r and r <= cy <= 1 - r):
            raise SystemExit(f"node at ({cx}, {cy}) r={r} sticks out of the tile")
        for ax in (inset, 1 - inset):
            for ay in (inset, 1 - inset):
                # the node is in this corner's quadrant only when it is past the arc centre
                # on the same side as the corner itself
                if (cx - ax) * (ax - 0.5) > 0 and (cy - ay) * (ay - 0.5) > 0:
                    d = ((cx - ax) ** 2 + (cy - ay) ** 2) ** 0.5
                    if d + r > inset:
                        raise SystemExit(f"node at ({cx}, {cy}) r={r} crosses the rounded corner")


def shapes() -> list[tuple]:
    out: list[tuple] = [("tile", None)]
    ends = [HUB_C] + [n[0] for n in NODES]
    for c in ends[1:]:
        out.append(("edge", (HUB_C[0], HUB_C[1], c[0], c[1], EDGE_W, EDGE)))
    for i, j in RIM:
        a, b = NODES[i][0], NODES[j][0]
        out.append(("edge", (a[0], a[1], b[0], b[1], EDGE_W, EDGE)))
    out.append(("ring", (HUB_C[0], HUB_C[1], RING_R, RING_W, RING)))
    for (cx, cy), r, kind in NODES:
        out.append(("disc", (cx, cy, r, KIND[kind])))
    out.append(("disc", (HUB_C[0], HUB_C[1], HUB_R, HUB)))
    return out


def _seg_dist(x, y, ax, ay, bx, by):
    abx, aby = bx - ax, by - ay
    t = ((x - ax) * abx + (y - ay) * aby) / (abx * abx + aby * aby)
    t = 0.0 if t < 0.0 else (1.0 if t > 1.0 else t)
    return ((x - (ax + t * abx)) ** 2 + (y - (ay + t * aby)) ** 2) ** 0.5


def render(size: int, background: bool) -> bytes:
    check_inside_tile()
    sh = shapes()
    px_w = 1.0 / size
    out = bytearray(size * size * 4)
    for row in range(size):
        y = (row + 0.5) / size
        for col in range(size):
            x = (col + 0.5) / size
            # premultiplied accumulation: C = sa*rgb + C*(1-sa), A = sa + A*(1-sa)
            R = G = B = A = 0.0
            for kind, p in sh:
                if kind == "tile":
                    if not background:
                        continue
                    qx = abs(x - 0.5) - (0.5 - TILE_R)
                    qy = abs(y - 0.5) - (0.5 - TILE_R)
                    d = (max(qx, 0.0) ** 2 + max(qy, 0.0) ** 2) ** 0.5 + min(max(qx, qy), 0.0) - TILE_R
                    rgb = BG
                elif kind == "edge":
                    d = _seg_dist(x, y, p[0], p[1], p[2], p[3]) - p[4]
                    rgb = p[5]
                elif kind == "disc":
                    d = ((x - p[0]) ** 2 + (y - p[1]) ** 2) ** 0.5 - p[2]
                    rgb = p[3]
                else:  # ring
                    d = abs(((x - p[0]) ** 2 + (y - p[1]) ** 2) ** 0.5 - p[2]) - p[3]
                    rgb = p[4]
                if d > px_w * 0.5:
                    continue
                sa = 1.0 if d < -px_w * 0.5 else (0.5 - d / px_w)
                R = sa * rgb[0] + R * (1.0 - sa)
                G = sa * rgb[1] + G * (1.0 - sa)
                B = sa * rgb[2] + B * (1.0 - sa)
                A = sa + A * (1.0 - sa)
            o = (row * size + col) * 4
            if A <= 0.0:
                continue
            out[o] = int(round(R / A))
            out[o + 1] = int(round(G / A))
            out[o + 2] = int(round(B / A))
            out[o + 3] = int(round(255 * (1.0 if A > 1.0 else A)))
    return bytes(out)


def write_png(path: Path, size: int, rgba: bytes) -> None:
    rows = b"".join(b"\x00" + rgba[i * size * 4:(i + 1) * size * 4] for i in range(size))

    def chunk(tag: bytes, data: bytes) -> bytes:
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data))

    path.write_bytes(b"\x89PNG\r\n\x1a\n"
                     + chunk(b"IHDR", struct.pack(">IIBBBBB", size, size, 8, 6, 0, 0, 0))
                     + chunk(b"IDAT", zlib.compress(rows, 9))
                     + chunk(b"IEND", b""))
    print(f"wrote {path.relative_to(ROOT).as_posix()}  {size}x{size}  {len(path.read_bytes())} bytes")


def main() -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    for size in (512, 256, 128):
        write_png(OUT / f"icon-graph-{size}.png", size, render(size, True))
    for size in (512, 256):
        write_png(OUT / f"icon-graph-{size}-transparent.png", size, render(size, False))
    return 0


if __name__ == "__main__":
    sys.exit(main())
