#!/usr/bin/env python3
"""
Generate Joy-Con menu bar icon for Berrry Joyful.

Usage:
    uvx --from pillow python3 scripts/generate-icon.py

Generates 1x and 2x PNG icons in the Assets.xcassets folder.
"""

from PIL import Image, ImageDraw


def draw_joycon_pair(size, filename):
    """Draw a pair of Joy-Con controllers as a menu bar icon."""
    # Create transparent image
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Scale factor based on size (base is 18)
    scale = size / 18

    # Joy-Con dimensions (each controller)
    jc_width = int(6 * scale)
    jc_height = int(14 * scale)
    corner_radius = int(2 * scale)
    gap = int(1 * scale)

    # Center the pair
    total_width = jc_width * 2 + gap
    start_x = (size - total_width) // 2
    start_y = (size - jc_height) // 2

    # Color for template image (black, will be tinted by macOS)
    color = (0, 0, 0, 255)
    # Transparent for cutouts
    transparent = (0, 0, 0, 0)

    # Left Joy-Con
    left_x = start_x
    draw.rounded_rectangle(
        [left_x, start_y, left_x + jc_width, start_y + jc_height],
        radius=corner_radius,
        fill=color
    )

    # Right Joy-Con
    right_x = start_x + jc_width + gap
    draw.rounded_rectangle(
        [right_x, start_y, right_x + jc_width, start_y + jc_height],
        radius=corner_radius,
        fill=color
    )

    # Add stick indicators (transparent cutouts)
    stick_radius = int(1.5 * scale)

    # Left stick (upper area of left joycon)
    left_stick_x = left_x + jc_width // 2
    left_stick_y = start_y + int(4 * scale)
    draw.ellipse(
        [left_stick_x - stick_radius, left_stick_y - stick_radius,
         left_stick_x + stick_radius, left_stick_y + stick_radius],
        fill=transparent
    )

    # Left Joy-Con d-pad buttons (4 small dots in cross pattern below stick)
    btn_size = max(1, int(0.8 * scale))
    left_btn_center_x = left_x + jc_width // 2
    left_btn_center_y = start_y + jc_height - int(4 * scale)
    btn_offset = int(1.5 * scale)

    for dx, dy in [(0, -btn_offset), (0, btn_offset), (-btn_offset, 0), (btn_offset, 0)]:
        bx, by = left_btn_center_x + dx, left_btn_center_y + dy
        draw.ellipse([bx - btn_size, by - btn_size, bx + btn_size, by + btn_size], fill=transparent)

    # Right stick (lower area of right joycon)
    right_stick_x = right_x + jc_width // 2
    right_stick_y = start_y + jc_height - int(4 * scale)
    draw.ellipse(
        [right_stick_x - stick_radius, right_stick_y - stick_radius,
         right_stick_x + stick_radius, right_stick_y + stick_radius],
        fill=transparent
    )

    # Right Joy-Con face buttons (4 small dots in diamond pattern)
    btn_center_x = right_x + jc_width // 2
    btn_center_y = start_y + int(4 * scale)

    for dx, dy in [(0, -btn_offset), (0, btn_offset), (-btn_offset, 0), (btn_offset, 0)]:
        bx, by = btn_center_x + dx, btn_center_y + dy
        draw.ellipse([bx - btn_size, by - btn_size, bx + btn_size, by + btn_size], fill=transparent)

    img.save(filename, 'PNG')
    print(f"Created {filename}")


if __name__ == "__main__":
    import os

    # Find the script's directory and navigate to assets
    script_dir = os.path.dirname(os.path.abspath(__file__))
    base_path = os.path.join(script_dir, "..", "Sources", "Assets.xcassets", "JoyConIcon.imageset")

    # Create directory if needed
    os.makedirs(base_path, exist_ok=True)

    # Generate both sizes
    draw_joycon_pair(18, os.path.join(base_path, "joycon-icon.png"))
    draw_joycon_pair(36, os.path.join(base_path, "joycon-icon@2x.png"))
