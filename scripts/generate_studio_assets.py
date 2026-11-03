"""Deterministic generator for AI Companion Character Studio project-original visual assets."""

import os
import struct
import zlib


def create_png(width: int, height: int, pixel_data_rgb: bytes) -> bytes:
    """Generate a valid PNG byte string from raw RGB bytes (width * height * 3)."""
    # Each scanline starts with filter byte 0
    raw_scanlines = bytearray()
    row_bytes = width * 3
    for y in range(height):
        raw_scanlines.append(0)  # filter type None
        start = y * row_bytes
        raw_scanlines.extend(pixel_data_rgb[start : start + row_bytes])

    compressed = zlib.compress(bytes(raw_scanlines), level=9)

    def chunk(tag: bytes, data: bytes) -> bytes:
        crc = zlib.crc32(tag + data) & 0xFFFFFFFF
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", crc)

    header = b"\x89PNG\r\n\x1a\n"
    # IHDR: width (4), height (4), bit depth (1), color type (2: RGB), comp (0), filter (0), interlace (0)
    ihdr = struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0)
    return header + chunk(b"IHDR", ihdr) + chunk(b"IDAT", compressed) + chunk(b"IEND", b"")


def generate_backdrop(width: int, height: int, c_top: tuple[int, int, int], c_mid: tuple[int, int, int], c_bottom: tuple[int, int, int]) -> bytes:
    pixels = bytearray()
    for y in range(height):
        t = y / (height - 1)
        if t < 0.5:
            f = t / 0.5
            r = int(c_top[0] * (1 - f) + c_mid[0] * f)
            g = int(c_top[1] * (1 - f) + c_mid[1] * f)
            b = int(c_top[2] * (1 - f) + c_mid[2] * f)
        else:
            f = (t - 0.5) / 0.5
            r = int(c_mid[0] * (1 - f) + c_bottom[0] * f)
            g = int(c_mid[1] * (1 - f) + c_bottom[1] * f)
            b = int(c_mid[2] * (1 - f) + c_bottom[2] * f)
        for x in range(width):
            # Gentle horizontal vignette at edges
            edge_factor = 1.0 - 0.25 * ((2.0 * x / width - 1.0) ** 2)
            pixels.extend((
                int(max(0, min(255, r * edge_factor))),
                int(max(0, min(255, g * edge_factor))),
                int(max(0, min(255, b * edge_factor))),
            ))
    return create_png(width, height, bytes(pixels))


def create_png_rgba(width: int, height: int, pixel_data_rgba: bytes) -> bytes:
    """Generate a valid PNG byte string from raw RGBA bytes (width * height * 4)."""
    raw_scanlines = bytearray()
    row_bytes = width * 4
    for y in range(height):
        raw_scanlines.append(0)  # filter type None
        start = y * row_bytes
        raw_scanlines.extend(pixel_data_rgba[start : start + row_bytes])

    compressed = zlib.compress(bytes(raw_scanlines), level=9)

    def chunk(tag: bytes, data: bytes) -> bytes:
        crc = zlib.crc32(tag + data) & 0xFFFFFFFF
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", crc)

    header = b"\x89PNG\r\n\x1a\n"
    # IHDR: width (4), height (4), bit depth (1), color type (6: RGBA), comp (0), filter (0), interlace (0)
    ihdr = struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)
    return header + chunk(b"IHDR", ihdr) + chunk(b"IDAT", compressed) + chunk(b"IEND", b"")


def generate_portrait(width: int, height: int, base_color: tuple[int, int, int], accent_color: tuple[int, int, int]) -> bytes:
    pixels = bytearray()
    cx, cy = width / 2.0, height / 2.0
    for y in range(height):
        for x in range(width):
            dx = (x - cx) / (width / 2.0)
            dy = (y - cy) / (height / 2.0)

            # Stylized torso/head silhouette calculation with smooth antialiased alpha
            head_metric = (dx * 2.0) ** 2 + ((dy + 0.35) * 2.2) ** 2
            body_metric = (dx * 1.3) ** 2 + ((dy - 0.3) * 1.0) ** 2 if dy > -0.15 else 999.0

            # Calculate distance to threshold for antialiased boundary
            head_coverage = max(0.0, min(1.0, (0.30 - head_metric) / 0.05))
            body_coverage = max(0.0, min(1.0, (0.75 - body_metric) / 0.08))
            coverage = max(head_coverage, body_coverage)

            if coverage > 0.0:
                # Figure foreground with soft shading
                depth_shade = max(0.6, min(1.0, 1.0 - (dy + 0.2) * 0.25))
                r = int((accent_color[0] * 0.85 + base_color[0] * 0.15) * depth_shade)
                g = int((accent_color[1] * 0.85 + base_color[1] * 0.15) * depth_shade)
                b = int((accent_color[2] * 0.85 + base_color[2] * 0.15) * depth_shade)
                alpha = int(coverage * 255)
            else:
                # Transparent background allows studio backdrop to show through
                r, g, b, alpha = 0, 0, 0, 0

            pixels.extend((
                max(0, min(255, r)),
                max(0, min(255, g)),
                max(0, min(255, b)),
                max(0, min(255, alpha)),
            ))
    return create_png_rgba(width, height, bytes(pixels))


def main():
    target_dir = os.path.abspath("frontend/flutter/apps/desktop/assets/studio")
    os.makedirs(target_dir, exist_ok=True)

    backdrops = {
        "backdrop_cozy_studio.png": ((40, 28, 22), (65, 45, 34), (24, 18, 14)),
        "backdrop_cyber_lounge.png": ((15, 22, 45), (28, 42, 80), (10, 14, 28)),
        "backdrop_twilight_balcony.png": ((45, 24, 52), (80, 42, 75), (22, 14, 30)),
        "backdrop_minimalist_vault.png": ((22, 26, 35), (38, 45, 58), (14, 17, 24)),
    }

    for filename, (c1, c2, c3) in backdrops.items():
        data = generate_backdrop(600, 400, c1, c2, c3)
        path = os.path.join(target_dir, filename)
        with open(path, "wb") as f:
            f.write(data)
        print(f"Generated {filename} ({len(data)} bytes)")

    portraits = {
        "portrait_warm_companion.png": ((28, 22, 20), (225, 145, 95)),
        "portrait_playful.png": ((20, 26, 38), (120, 195, 230)),
        "portrait_formal_advisor.png": ((20, 22, 32), (180, 185, 215)),
        "portrait_neutral_assistant.png": ((18, 20, 26), (150, 160, 175)),
    }

    for filename, (base, accent) in portraits.items():
        data = generate_portrait(320, 480, base, accent)
        path = os.path.join(target_dir, filename)
        with open(path, "wb") as f:
            f.write(data)
        print(f"Generated {filename} ({len(data)} bytes)")


if __name__ == "__main__":
    main()
