"""Generate the local, silent 3-second SGA brand animation (Pillow + FFmpeg)."""
import math
import subprocess
from pathlib import Path
from PIL import Image, ImageDraw

root = Path(__file__).resolve().parents[1]
command = ['ffmpeg', '-y', '-loglevel', 'error', '-f', 'rawvideo', '-pix_fmt',
           'rgb24', '-s', '960x540', '-r', '30', '-i', '-', '-an', '-c:v',
           'libx264', '-crf', '23', '-pix_fmt', 'yuv420p', '-movflags',
           '+faststart', str(root / 'web/intro.mp4')]
with subprocess.Popen(command, stdin=subprocess.PIPE) as encoder:
    for frame in range(90):
        image = Image.new('RGB', (960, 540), '#112b3c')
        draw = ImageDraw.Draw(image)
        points = []
        for step in range(401):
            t = step / 400 * 2 * math.pi
            points.append((480 + 146 * math.cos(t) / (1 + math.sin(t)**2),
                           230 + 146 * math.cos(t) * math.sin(t) / (1 + math.sin(t)**2)))
        draw.line(points, fill='#284b5d', width=8)
        length = max(2, min(401, int(frame / 55 * 401)))
        draw.line(points[:length], fill='#88d7cc', width=8)
        if frame > 55:
            x, y = points[int((frame - 55) / 34 * 400)]
            draw.ellipse((x-7, y-7, x+7, y+7), fill='#ffffff')
        encoder.stdin.write(image.tobytes())
    encoder.stdin.close()
    if encoder.wait():
        raise SystemExit('FFmpeg could not generate intro.mp4')
