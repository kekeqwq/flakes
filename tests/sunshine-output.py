import runpy
import sys

select = runpy.run_path(sys.argv[1])["select"]
internal = {"current_mode": 0}
external = {
    "make": "Ugreen Group Ltd.", "model": "SAMZHE       ",
    "serial": "0x20200210", "current_mode": 0,
}
wrong = dict(external, serial="0x20200211")
assert select({"eDP-1": internal, "DP-1": external}) == ("DP-1", "eDP-1")
assert select({"eDP-1": internal, "DP-1": wrong, "DP-2": external}) == ("DP-2", "eDP-1")
assert select({"eDP-1": internal, "DP-2": dict(external, current_mode=None)}) == (None, "eDP-1")
assert select({"eDP-1": internal, "DP-1": external, "DP-2": external}) == (None, "eDP-1")
assert select({"DP-2": wrong}) == (None, None)
assert select({"DP-2\nother-setting": external}) == (None, None)
print("Sunshine output selection passed")
