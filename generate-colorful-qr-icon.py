#!/usr/bin/env python3

import qrcode
from PIL import Image, ImageDraw, ImageColor

# 创建一个彩色背景
background = Image.new('RGB', (512, 512), color=ImageColor.getrgb('#4A90E2'))

# 生成二维码
qr = qrcode.QRCode(
    version=1,
    error_correction=qrcode.constants.ERROR_CORRECT_H,
    box_size=10,
    border=4,
)
qr.add_data('macQR')
qr.make(fit=True)

# 创建二维码图像，使用白色填充，透明背景
qr_img = qr.make_image(fill_color="white", back_color="transparent")
qr_img = qr_img.convert("RGBA")

# 调整二维码大小
qr_img = qr_img.resize((300, 300), Image.LANCZOS)

# 将二维码居中放置在彩色背景上
pos = ((512 - qr_img.size[0]) // 2, (512 - qr_img.size[1]) // 2)
background.paste(qr_img, pos, qr_img)

# 保存为PNG文件
background.save("macQR_colorful.png")

print("彩色二维码图标生成成功！")
