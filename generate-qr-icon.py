#!/usr/bin/env python3

import qrcode
from PIL import Image

# 生成二维码
qr = qrcode.QRCode(
    version=1,
    error_correction=qrcode.constants.ERROR_CORRECT_L,
    box_size=10,
    border=4,
)
qr.add_data('macQR')
qr.make(fit=True)

# 创建二维码图像
img = qr.make_image(fill_color="black", back_color="white")

# 保存为PNG文件
img.save("qrcode.png")

# 调整大小为512x512像素，适合作为应用图标
img = img.resize((512, 512), Image.LANCZOS)
img.save("qrcode_512.png")

print("二维码图标生成成功！")
