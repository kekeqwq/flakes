"""Exercise the locker's actual battery selection against fake sysfs."""
import os
from pathlib import Path
import subprocess
import sys
import tempfile

source, compiler = sys.argv[1:]
flags = subprocess.check_output(["pkg-config", "--cflags", "--libs", "cairo"], text=True).split()
with tempfile.TemporaryDirectory() as directory:
    work = Path(directory)
    main = work / "test.c"
    main.write_text(f'#include "{Path(source).resolve()}"\n' + '''
int main(int argc, char **argv) {
    if (argc != 2) return 1;
    char label[32];
    read_power_status(argv[1], getenv("KEKE_SWAYLOCK_BATTERY"), label);
    puts(label);
    return 0;
}
''')
    binary = work / "lock-status-test"
    subprocess.run([compiler, "-std=gnu11", "-Wall", "-Wextra", "-Werror", str(main), "-o", str(binary), *flags], check=True)
    root = work / "power_supply"
    root.mkdir()

    def supply(name, **properties):
        path = root / name
        path.mkdir(exist_ok=True)
        for key, value in properties.items():
            (path / key).write_text(f"{value}\n")

    def expect(label, battery=None, path=root):
        env = os.environ.copy()
        env.pop("KEKE_SWAYLOCK_BATTERY", None)
        if battery is not None:
            env["KEKE_SWAYLOCK_BATTERY"] = battery
        actual = subprocess.check_output([binary, path], env=env, text=True).rstrip("\n")
        assert actual == label, (battery, actual, label)

    supply("BAT1", type="Battery", status="Not charging", capacity=80)
    supply("qcom-battmgr-bat", type="Battery", status="Full", capacity=100)
    supply("input-device", type="Battery", scope="Device", status="Charging", capacity=20)
    supply("ADP1", type="Mains", online=1)
    expect("90%  Plugged in")
    expect("80%  Plugged in", "BAT1")
    expect("", "missing")
    expect("", "BAT1", work / "absent")
    supply("ADP1", online=0)
    supply("BAT1", status="Discharging")
    expect("80%  On battery", "BAT1")
    supply("BAT1", status="Charging")
    expect("80%  Charging", "BAT1")
    supply("BAT1", capacity="not-a-number")
    expect("", "BAT1")
    print("lock-status: battery selection, AC state, missing gauge and default aggregation passed")
