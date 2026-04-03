#!/usr/bin/env python3
"""
generate_icons.py — Xboard-Mihomo 高清图标生成器
基于 V3 极光紫蓝主题: #4527A0 → #1565C0 → #00ACC1

生成文件:
  assets/branding/icon.png              - 1024x1024 主图标
  assets/branding/icon.ico              - Windows 主图标 (多尺寸)
  assets/branding/icon_white.png        - macOS 托盘白色模板
  assets/branding/icon_white.ico        - 白色模板 ICO
  assets/branding/icon_black.png        - 深色托盘图标
  assets/branding/icon_black.ico        - 深色模板 ICO
  assets/branding/icon_connected.png    - 已连接状态托盘
  assets/branding/icon_connected.ico    - 已连接状态 ICO
  assets/branding/icon_disconnected.png - 已断开状态托盘
  assets/branding/icon_disconnected.ico - 已断开状态 ICO

用法: python generate_icons.py
"""

import os
import math
from PIL import Image, ImageDraw, ImageFilter, ImageChops
import numpy as np

# ============================================================
# 路径配置
# ============================================================
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
BRANDING_DIR = os.path.join(SCRIPT_DIR, 'assets', 'branding')

# ============================================================
# 颜色配置
# ============================================================
# V3 极光紫蓝 (主图标)
AURORA = ((69, 39, 160), (21, 101, 192), (0, 172, 193))

# 已连接 (绿松石/翠绿)
CONNECTED = ((0, 121, 107), (0, 150, 136), (38, 166, 154))

# 已断开 (灰色)
DISCONNECTED = ((117, 117, 117), (158, 158, 158), (189, 189, 189))

# ============================================================
# 纸飞机几何坐标 (在 1024x1024 空间中)
# ============================================================
PLANE_UPPER = [(154, 537), (870, 254), (550, 575)]
PLANE_LOWER = [(550, 575), (870, 254), (644, 726)]
PLANE_TAIL  = [(550, 575), (455, 688), (644, 726)]

# 飞行轨迹
TRAILS = [
    [(90, 590, 120, 578, 3.0, 0.30),
     (130, 574, 155, 555, 3.0, 0.25)],
    [(40, 640, 70, 625, 2.5, 0.20),
     (80, 618, 110, 600, 2.5, 0.18)],
]

# 速度线
SPEED_LINES = [
    (80, 440, 200, 400, 2.5, 0.15),
    (130, 490, 230, 465, 2.0, 0.12),
]

# 装饰圆环
CIRCLES = [
    (512, 490, 300, 2.0, 0.07),
    (512, 490, 360, 1.5, 0.04),
]

# 超采样倍数
SS = 4


def make_gradient_np(size, colors):
    """使用 numpy 创建高质量对角渐变"""
    x = np.linspace(0, 1, size, dtype=np.float64)
    t = (x[None, :] + x[:, None]) / 2.0

    c1 = np.array(colors[0], dtype=np.float64)
    c2 = np.array(colors[1], dtype=np.float64)
    c3 = np.array(colors[2], dtype=np.float64)

    mask = t <= 0.5
    f1 = (t * 2.0)[..., None]
    f2 = ((t - 0.5) * 2.0)[..., None]

    rgb = np.where(
        mask[..., None],
        c1 + (c2 - c1) * f1,
        c2 + (c3 - c2) * f2
    ).clip(0, 255).astype(np.uint8)

    alpha = np.full((size, size, 1), 255, dtype=np.uint8)
    rgba = np.concatenate([rgb, alpha], axis=2)
    return Image.fromarray(rgba, 'RGBA')


def scale_pts(pts, factor, ox=0, oy=0):
    return [(int(x * factor + ox), int(y * factor + oy)) for x, y in pts]


def draw_paper_plane(draw, sf, ox=0, oy=0,
                     a_up=242, a_lo=184, a_tail=128,
                     color=(255, 255, 255)):
    r, g, b = color
    draw.polygon(scale_pts(PLANE_UPPER, sf, ox, oy), fill=(r, g, b, a_up))
    draw.polygon(scale_pts(PLANE_LOWER, sf, ox, oy), fill=(r, g, b, a_lo))
    draw.polygon(scale_pts(PLANE_TAIL, sf, ox, oy), fill=(r, g, b, a_tail))


def draw_decorations(draw, sf, ox=0, oy=0):
    for cx, cy, r, w, op in CIRCLES:
        scx = int(cx * sf + ox)
        scy = int(cy * sf + oy)
        sr = int(r * sf)
        sw = max(1, int(w * sf))
        a = int(255 * op)
        draw.ellipse([scx - sr, scy - sr, scx + sr, scy + sr],
                     outline=(255, 255, 255, a), width=sw)

    for trail_segs in TRAILS:
        for x1, y1, x2, y2, w, op in trail_segs:
            sw = max(1, int(w * sf))
            a = int(255 * op)
            draw.line([(int(x1*sf+ox), int(y1*sf+oy)),
                       (int(x2*sf+ox), int(y2*sf+oy))],
                      fill=(255, 255, 255, a), width=sw)

    for x1, y1, x2, y2, w, op in SPEED_LINES:
        sw = max(1, int(w * sf))
        a = int(255 * op)
        draw.line([(int(x1*sf+ox), int(y1*sf+oy)),
                   (int(x2*sf+ox), int(y2*sf+oy))],
                  fill=(255, 255, 255, a), width=sw)


def create_shadow_layer(size, sf, ox=0, oy=0):
    shadow = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(shadow, 'RGBA')
    draw_paper_plane(draw, sf, ox, oy, a_up=55, a_lo=35, a_tail=20, color=(0, 0, 0))
    offset = max(1, size // 170)
    shifted = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    shifted.paste(shadow, (0, offset))
    blur_r = max(1, size // 85)
    return shifted.filter(ImageFilter.GaussianBlur(radius=blur_r))


def apply_rounded_rect_mask(img, radius_ratio=0.215):
    size = img.size[0]
    radius = int(size * radius_ratio)
    mask = Image.new('L', (size, size), 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle([0, 0, size - 1, size - 1], radius=radius, fill=255)
    result = img.copy()
    if result.mode == 'RGBA':
        existing_alpha = result.split()[3]
        combined = ImageChops.multiply(existing_alpha, mask)
        result.putalpha(combined)
    else:
        result.putalpha(mask)
    return result


def apply_circle_mask(img):
    size = img.size[0]
    mask = Image.new('L', (size, size), 0)
    draw = ImageDraw.Draw(mask)
    draw.ellipse([0, 0, size - 1, size - 1], fill=255)
    result = img.copy()
    if result.mode == 'RGBA':
        existing_alpha = result.split()[3]
        combined = ImageChops.multiply(existing_alpha, mask)
        result.putalpha(combined)
    else:
        result.putalpha(mask)
    return result


# ============================================================
# 主图标生成
# ============================================================
def generate_app_icon(target_size=1024):
    ss = target_size * SS
    sf = ss / 1024.0
    print(f'  渲染 {ss}x{ss} → {target_size}x{target_size} ...')

    bg = make_gradient_np(ss, AURORA)
    bg = apply_rounded_rect_mask(bg)

    deco = Image.new('RGBA', (ss, ss), (0, 0, 0, 0))
    draw_decorations(ImageDraw.Draw(deco, 'RGBA'), sf)

    shadow = create_shadow_layer(ss, sf)

    plane = Image.new('RGBA', (ss, ss), (0, 0, 0, 0))
    draw_paper_plane(ImageDraw.Draw(plane, 'RGBA'), sf)

    result = Image.alpha_composite(bg, deco)
    result = Image.alpha_composite(result, shadow)
    result = Image.alpha_composite(result, plane)

    return result.resize((target_size, target_size), Image.LANCZOS)


# ============================================================
# 托盘图标
# ============================================================
def generate_tray_icon(target_size=256, colors=CONNECTED, shape='circle'):
    ss = target_size * SS
    sf = ss / 1024.0

    bg = make_gradient_np(ss, colors)
    if shape == 'circle':
        bg = apply_circle_mask(bg)
    else:
        bg = apply_rounded_rect_mask(bg, 0.22)

    plane = Image.new('RGBA', (ss, ss), (0, 0, 0, 0))
    draw_paper_plane(ImageDraw.Draw(plane, 'RGBA'), sf,
                     a_up=250, a_lo=200, a_tail=150)

    result = Image.alpha_composite(bg, plane)
    return result.resize((target_size, target_size), Image.LANCZOS)


# ============================================================
# 剪影图标
# ============================================================
def generate_silhouette(target_size=256, color=(255, 255, 255)):
    ss = target_size * SS
    sf = ss / 1024.0

    img = Image.new('RGBA', (ss, ss), (0, 0, 0, 0))
    draw_paper_plane(ImageDraw.Draw(img, 'RGBA'), sf,
                     a_up=255, a_lo=210, a_tail=160, color=color)

    return img.resize((target_size, target_size), Image.LANCZOS)


# ============================================================
# ICO
# ============================================================
def save_ico(src, path, sizes=None):
    if sizes is None:
        sizes = [(16,16),(24,24),(32,32),(48,48),(64,64),(128,128),(256,256)]
    valid = [s for s in sizes if s[0] <= src.size[0]]
    src.save(path, format='ICO', sizes=valid)
    names = ','.join(f'{s[0]}' for s in valid)
    print(f'    -> {os.path.basename(path)} ({names}px)')


def save_ico_tray(src, path):
    save_ico(src, path, [(16,16),(24,24),(32,32),(48,48),(64,64),(128,128)])


# ============================================================
# macOS 图标集
# ============================================================
def gen_macos(src, out_dir):
    os.makedirs(out_dir, exist_ok=True)
    for name, sz in [('app_icon_16.png',16),('app_icon_32.png',32),
                     ('app_icon_64.png',64),('app_icon_128.png',128),
                     ('app_icon_256.png',256),('app_icon_512.png',512),
                     ('app_icon_1024.png',1024)]:
        r = src.resize((sz, sz), Image.LANCZOS)
        r.save(os.path.join(out_dir, name), 'PNG')
        print(f'    -> {name} ({sz}x{sz})')


# ============================================================
# Android webp
# ============================================================
def gen_android_webp(src, out_dir):
    dpis = {'mipmap-mdpi':48,'mipmap-hdpi':72,'mipmap-xhdpi':96,
            'mipmap-xxhdpi':144,'mipmap-xxxhdpi':192}
    for d, sz in dpis.items():
        dp = os.path.join(out_dir, d)
        os.makedirs(dp, exist_ok=True)
        r = src.resize((sz, sz), Image.LANCZOS)
        r.save(os.path.join(dp, 'ic_launcher.webp'), 'WEBP', quality=95)
        cr = apply_circle_mask(r)
        cr.save(os.path.join(dp, 'ic_launcher_round.webp'), 'WEBP', quality=95)
        print(f'    -> {d}/ ({sz}x{sz})')

    ps = src.resize((512, 512), Image.LANCZOS)
    ps.save(os.path.join(out_dir, 'ic_launcher-playstore.png'), 'PNG')
    print(f'    -> ic_launcher-playstore.png (512x512)')


# ============================================================
# 主入口
# ============================================================
def main():
    os.makedirs(BRANDING_DIR, exist_ok=True)
    print()
    print('=' * 52)
    print('  Xboard-Mihomo 高清图标生成器')
    print('  V3 极光紫蓝: #4527A0 -> #1565C0 -> #00ACC1')
    print('=' * 52)

    # 1. 主图标
    print('\n[1/7] 主应用图标 (1024x1024)...')
    icon = generate_app_icon(1024)
    icon.save(os.path.join(BRANDING_DIR, 'icon.png'), 'PNG')
    print('    -> icon.png')
    save_ico(icon, os.path.join(BRANDING_DIR, 'icon.ico'))

    # 2. 白色模板
    print('\n[2/7] 白色模板 (macOS 托盘)...')
    w = generate_silhouette(256, (255, 255, 255))
    w.save(os.path.join(BRANDING_DIR, 'icon_white.png'), 'PNG')
    print('    -> icon_white.png')
    save_ico_tray(w, os.path.join(BRANDING_DIR, 'icon_white.ico'))

    # 3. 黑色模板
    print('\n[3/7] 黑色模板...')
    b = generate_silhouette(256, (33, 33, 33))
    b.save(os.path.join(BRANDING_DIR, 'icon_black.png'), 'PNG')
    print('    -> icon_black.png')
    save_ico_tray(b, os.path.join(BRANDING_DIR, 'icon_black.ico'))

    # 4. 已连接
    print('\n[4/7] 已连接状态托盘...')
    c = generate_tray_icon(256, CONNECTED, 'circle')
    c.save(os.path.join(BRANDING_DIR, 'icon_connected.png'), 'PNG')
    print('    -> icon_connected.png')
    save_ico_tray(c, os.path.join(BRANDING_DIR, 'icon_connected.ico'))

    # 5. 已断开
    print('\n[5/7] 已断开状态托盘...')
    d = generate_tray_icon(256, DISCONNECTED, 'circle')
    d.save(os.path.join(BRANDING_DIR, 'icon_disconnected.png'), 'PNG')
    print('    -> icon_disconnected.png')
    save_ico_tray(d, os.path.join(BRANDING_DIR, 'icon_disconnected.ico'))

    # 6. macOS 精确缩放图标集
    print('\n[6/7] macOS 图标集 (7 种精确尺寸)...')
    mac_dir = os.path.join(BRANDING_DIR, 'macos_iconset')
    gen_macos(icon, mac_dir)

    # 7. Android webp
    print('\n[7/7] Android webp 图标集...')
    and_dir = os.path.join(BRANDING_DIR, 'android_webp')
    gen_android_webp(icon, and_dir)

    print('\n' + '=' * 52)
    print('  全部完成！文件位于 assets/branding/')
    print('  下一步: 运行 dart run branding.dart')
    print('=' * 52)
    print()


if __name__ == '__main__':
    main()
