#!/usr/bin/env python3
"""
ACPChat app icon generator.

Концепция: multi-agent orchestration.
  - Три узла (codestral / magistral / opus-peer) в вершинах равностороннего треугольника,
    каждый со своим неоновым свечением (оранжевый / пурпурный / циан-синий).
  - Центральный белый оркестратор с play-треугольником ▶ — символ TURN → addr/poll.
  - Тонкие полупрозрачные связи между узлами (poll-arrows).
  - Глубокий тёмно-фиолетовый радиальный градиент-фон.

Выход: 1024x1024 PNG без прозрачности (требование App Store Connect).
Путь:  ../ACPChat/Assets.xcassets/AppIcon.appiconset/icon-1024.png
"""

from __future__ import annotations

import math
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

W = 1024
OUT = Path(__file__).resolve().parent.parent / "ACPChat" / "Assets.xcassets" / "AppIcon.appiconset" / "icon-1024.png"


def radial_bg() -> Image.Image:
    """Радиальный градиент: центр #1B2248, края #04050D (глубокий космос)."""
    xs, ys = np.meshgrid(np.arange(W), np.arange(W), indexing="xy")
    dx = (xs - W / 2) / (W / 2)
    dy = (ys - W / 2) / (W / 2)
    d = np.clip(np.sqrt(dx * dx + dy * dy), 0.0, 1.0) ** 1.25
    c0 = np.array([27, 34, 72], dtype=np.float32)   # center
    c1 = np.array([4, 5, 13], dtype=np.float32)     # edge
    arr = c0 + (c1 - c0) * d[..., None]
    return Image.fromarray(arr.astype(np.uint8), mode="RGB").convert("RGBA")


def node_with_glow(base: Image.Image, cx: float, cy: float, r: float, color: tuple[int, int, int]) -> Image.Image:
    """Круглый узел с мягким неоновым ореолом. base — RGBA canvas, мутирует и возвращается."""
    glow = Image.new("RGBA", base.size, (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    # Три слоя halo с убывающей прозрачностью и растущим радиусом.
    for alpha, scale in [(70, 2.6), (110, 1.8), (180, 1.3)]:
        gd.ellipse(
            [cx - r * scale, cy - r * scale, cx + r * scale, cy + r * scale],
            fill=color + (alpha,),
        )
    glow = glow.filter(ImageFilter.GaussianBlur(radius=r * 0.55))
    base = Image.alpha_composite(base, glow)

    core = Image.new("RGBA", base.size, (0, 0, 0, 0))
    cd = ImageDraw.Draw(core)
    # Плотное ядро.
    cd.ellipse([cx - r, cy - r, cx + r, cy + r], fill=color + (255,))
    # Светлый блик сверху-слева (объём).
    cd.ellipse(
        [cx - r * 0.55, cy - r * 0.7, cx + r * 0.05, cy - r * 0.15],
        fill=(255, 255, 255, 90),
    )
    core = core.filter(ImageFilter.GaussianBlur(radius=1.2))
    return Image.alpha_composite(base, core)


def draw_connections(base: Image.Image, pts: list[tuple[float, float]]) -> Image.Image:
    """Тонкие полупрозрачные рёбра между всеми парами узлов (граф POLL)."""
    layer = Image.new("RGBA", base.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    for i in range(len(pts)):
        for j in range(i + 1, len(pts)):
            d.line([pts[i], pts[j]], fill=(255, 255, 255, 55), width=5)
    layer = layer.filter(ImageFilter.GaussianBlur(radius=2.5))
    return Image.alpha_composite(base, layer)


def draw_orchestrator(base: Image.Image, cx: float, cy: float, r: float) -> Image.Image:
    """Центр: белый узел с play-треугольником (▶) — маркер addr/poll от orchestrator'а."""
    glow = Image.new("RGBA", base.size, (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    for alpha, scale in [(70, 3.3), (120, 2.2), (200, 1.4)]:
        gd.ellipse(
            [cx - r * scale, cy - r * scale, cx + r * scale, cy + r * scale],
            fill=(255, 255, 255, alpha),
        )
    glow = glow.filter(ImageFilter.GaussianBlur(radius=r * 0.85))
    base = Image.alpha_composite(base, glow)

    d = ImageDraw.Draw(base)
    # Белое ядро.
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(255, 255, 255, 255))
    # Тонкий тёмный ободок для контраста с белым ядром.
    d.ellipse([cx - r, cy - r, cx + r, cy + r], outline=(10, 20, 45, 180), width=3)
    # Equilateral-ish play-треугольник, центр смещён вправо для оптической балансировки.
    t = r * 0.55
    tri = [
        (cx - t * 0.45, cy - t * 0.8),
        (cx - t * 0.45, cy + t * 0.8),
        (cx + t * 0.95, cy),
    ]
    d.polygon(tri, fill=(14, 22, 55, 255))
    return base


def main() -> None:
    img = radial_bg()

    # Три узла на треугольнике (120° apart).
    cx0, cy0 = W / 2, W / 2
    R = W * 0.265
    angles_deg = [-90, 30, 150]  # вершина сверху
    colors = [
        (74, 158, 255),    # codestral = cyan-blue (cold/static)
        (255, 140, 66),    # magistral = orange (thinking/fire)
        (185, 103, 255),   # opus/devstral = purple (premium/deep)
    ]
    pts = []
    for a in angles_deg:
        rad = math.radians(a)
        pts.append((cx0 + R * math.cos(rad), cy0 + R * math.sin(rad)))

    # Сначала рёбра — они должны быть ПОД узлами.
    img = draw_connections(img, pts)

    # Узлы.
    node_r = W * 0.115
    for (x, y), color in zip(pts, colors):
        img = node_with_glow(img, x, y, node_r, color)

    # Центр-оркестратор.
    img = draw_orchestrator(img, cx0, cy0, W * 0.075)

    # Лёгкий top-highlight (имитация сферы, «глянец»).
    top = Image.new("RGBA", img.size, (0, 0, 0, 0))
    td = ImageDraw.Draw(top)
    td.ellipse([-W * 0.1, -W * 0.55, W * 1.1, W * 0.45], fill=(255, 255, 255, 18))
    top = top.filter(ImageFilter.GaussianBlur(radius=40))
    img = Image.alpha_composite(img, top)

    # App Store требует непрозрачный PNG → flatten на чёрном.
    final = Image.new("RGB", img.size, (0, 0, 0))
    final.paste(img, mask=img.split()[3])

    OUT.parent.mkdir(parents=True, exist_ok=True)
    final.save(OUT, "PNG", optimize=True)
    print(f"wrote: {OUT}  ({OUT.stat().st_size} bytes)")


if __name__ == "__main__":
    main()
