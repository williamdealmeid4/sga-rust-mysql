"""Generate the local, silent 3-second SGA brand animation (Pillow + FFmpeg)."""
import math
import os
import subprocess
from pathlib import Path
from PIL import Image, ImageDraw

root = Path(__file__).resolve().parents[1]
command = [os.environ.get('SGA_FFMPEG', 'ffmpeg'), '-y', '-loglevel', 'error', '-f', 'rawvideo', '-pix_fmt',
           'rgb24', '-s', '960x540', '-r', '30', '-i', '-', '-an', '-c:v',
           'libx264', '-crf', '23', '-pix_fmt', 'yuv420p', '-movflags',
           '+faststart', str(root / 'web/intro.mp4')]
with subprocess.Popen(command, stdin=subprocess.PIPE) as encoder:
    for frame in range(90):
        image = Image.new('RGB', (960, 540), '#14213d')
        draw = ImageDraw.Draw(image)
        for x in range(0, 960, 48):
            draw.line((x, 0, x, 540), fill='#1e2d4b')
        for y in range(0, 540, 48):
            draw.line((0, y, 960, y), fill='#1e2d4b')
        draw.ellipse((302, 52, 658, 408), outline='#2b4068', width=2)
        points = []
        for step in range(401):
            t = step / 400 * 2 * math.pi
            points.append((480 + 146 * math.cos(t) / (1 + math.sin(t)**2),
                           230 + 146 * math.cos(t) * math.sin(t) / (1 + math.sin(t)**2)))
        draw.line(points, fill='#344e80', width=6)
        progress = min(1, frame / 55)
        length = max(2, int((progress * progress * (3 - 2 * progress)) * 401))
        draw.line(points[:length], fill='#a9beff', width=6)
        if frame > 55:
            x, y = points[int((frame - 55) / 34 * 400)]
            draw.ellipse((x-7, y-7, x+7, y+7), fill='#ffffff')
        encoder.stdin.write(image.tobytes())
    encoder.stdin.close()
    if encoder.wait():
        raise SystemExit('FFmpeg could not generate intro.mp4')
