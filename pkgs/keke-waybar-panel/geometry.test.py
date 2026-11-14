import runpy
import sys

place = runpy.run_path(sys.argv[1])["placement"]
assert place(1920, 1080, 340, 400, 960, "clock") == (790, 66)
assert place(1920, 1080, 340, 400, 940, "clock") == (790, 66)
assert place(1920, 1080, 340, 400, 1500, "audio") == (1330, 66)
assert place(1920, 1080, 340, 400, 1910, "network") == (1564, 66)
assert place(1920, 1080, 340, 400, 5, "brightness") == (16, 66)
assert place(1280, 800, 340, 400, 640, "clock") == (470, 66)
assert place(800, 480, 340, 430, 790, "bluetooth") == (444, 34)
print("popup geometry: centered clock, module anchoring, gap and edge clamps PASS")
