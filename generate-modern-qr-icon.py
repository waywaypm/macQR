#!/usr/bin/env python3

from PIL import Image, ImageDraw, ImageColor

# 创建一个512x512像素的图标
icon_size = 512
icon = Image.new('RGBA', (icon_size, icon_size), (255, 255, 255, 0))
draw = ImageDraw.Draw(icon)

# 定义颜色方案（使用macOS系统风格的蓝色调）
background_color = ImageColor.getrgb('#007AFF')  # macOS系统蓝色
accent_color = (255, 255, 255)  # 白色

# 绘制圆角矩形背景
radius = 80
draw.rounded_rectangle(
    [0, 0, icon_size, icon_size],
    radius=radius,
    fill=background_color
)

# 绘制抽象二维码框架
qr_size = 300
qr_padding = (icon_size - qr_size) // 2
cell_size = qr_size // 7

# 绘制外框
outer_padding = 20
draw.rectangle(
    [qr_padding - outer_padding, qr_padding - outer_padding, 
     qr_padding + qr_size + outer_padding, qr_padding + qr_size + outer_padding],
    fill=accent_color,
    width=0
)

# 绘制内部背景
inner_padding = outer_padding + 10
draw.rectangle(
    [qr_padding - inner_padding, qr_padding - inner_padding, 
     qr_padding + qr_size + inner_padding, qr_padding + qr_size + inner_padding],
    fill=background_color,
    width=0
)

# 绘制抽象二维码图案（不是真实二维码，而是代表二维码的图案）
# 绘制角落的三个定位图案
corner_size = 4 * cell_size
offset = qr_padding

# 左上角定位图案
draw.rectangle([offset, offset, offset + corner_size, offset + corner_size], fill=accent_color)
draw.rectangle([offset + cell_size, offset + cell_size, offset + corner_size - cell_size, offset + corner_size - cell_size], fill=background_color)
draw.rectangle([offset + cell_size * 2, offset + cell_size * 2, offset + corner_size - cell_size * 2, offset + corner_size - cell_size * 2], fill=accent_color)

# 右上角定位图案
draw.rectangle([offset + qr_size - corner_size, offset, offset + qr_size, offset + corner_size], fill=accent_color)
draw.rectangle([offset + qr_size - corner_size + cell_size, offset + cell_size, offset + qr_size - cell_size, offset + corner_size - cell_size], fill=background_color)
draw.rectangle([offset + qr_size - corner_size + cell_size * 2, offset + cell_size * 2, offset + qr_size - cell_size * 2, offset + corner_size - cell_size * 2], fill=accent_color)

# 左下角定位图案
draw.rectangle([offset, offset + qr_size - corner_size, offset + corner_size, offset + qr_size], fill=accent_color)
draw.rectangle([offset + cell_size, offset + qr_size - corner_size + cell_size, offset + corner_size - cell_size, offset + qr_size - cell_size], fill=background_color)
draw.rectangle([offset + cell_size * 2, offset + qr_size - corner_size + cell_size * 2, offset + corner_size - cell_size * 2, offset + qr_size - cell_size * 2], fill=accent_color)

# 绘制中间的抽象线条（代表二维码的扫描线）
scan_line_y = qr_padding + qr_size // 2
draw.rectangle(
    [qr_padding, scan_line_y - 5, qr_padding + qr_size, scan_line_y + 5],
    fill=accent_color,
    width=0
)

# 保存为PNG文件
icon.save("macQR_modern.png")

print("现代风格二维码图标生成成功！")
