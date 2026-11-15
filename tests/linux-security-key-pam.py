#!/usr/bin/env python3
"""Isolated real pam-u2f check; never edits /etc/pam.d or accepts a PIN/password.

All arguments are paths/public identifiers, not authentication secrets. The report
contains status only. A bounded retry window allows a human to respond to the
physical key after the agent returns; this is not a production unlock service.
"""

import argparse
import ctypes as C
import json
import os
from pathlib import Path
import tempfile
import time


class Message(C.Structure):
    _fields_ = [("style", C.c_int), ("msg", C.c_char_p)]


class Response(C.Structure):
    _fields_ = [("resp", C.c_void_p), ("ret", C.c_int)]


Callback = C.CFUNCTYPE(
    C.c_int,
    C.c_int,
    C.POINTER(C.POINTER(Message)),
    C.POINTER(C.POINTER(Response)),
    C.c_void_p,
)


class Conversation(C.Structure):
    _fields_ = [("fn", Callback), ("data", C.c_void_p)]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--pam-library", required=True)
    parser.add_argument("--module", required=True)
    parser.add_argument("--credentials", required=True)
    parser.add_argument("--report", required=True)
    parser.add_argument("--attempts", type=int, default=1, choices=range(1, 5))
    args = parser.parse_args()
    os.umask(0o077)
    spec = json.loads(Path(args.credentials).read_text())
    assert spec["user"] == "keke" and spec["origin"] == "pam://keke-flakes"
    assert spec["keys"] and all(
        len(key["credential"].split(",")) == 4
        and key["credential"].split(",")[3] == "+presence"
        and "\n" not in key["credential"]
        and ":" not in key["credential"]
        for key in spec["keys"]
    )
    lib = C.CDLL(args.pam_library)
    lib.pam_start_confdir.argtypes = [
        C.c_char_p,
        C.c_char_p,
        C.POINTER(Conversation),
        C.c_char_p,
        C.POINTER(C.c_void_p),
    ]
    lib.pam_authenticate.argtypes = [C.c_void_p, C.c_int]
    lib.pam_end.argtypes = [C.c_void_p, C.c_int]
    libc = C.CDLL(None)
    libc.calloc.argtypes = [C.c_size_t, C.c_size_t]
    libc.calloc.restype = C.c_void_p
    secret_prompts = []

    @Callback
    def conversation(count, messages, responses, _data):
        # PAM_ERROR_MSG=3 / PAM_TEXT_INFO=4 are noninteractive. Fail closed on
        # every input request, including PIN and password prompts.
        for i in range(count):
            if messages[i].contents.style not in (3, 4):
                secret_prompts.append(True)
                return 19  # PAM_CONV_ERR
        allocation = libc.calloc(count, C.sizeof(Response))
        if not allocation:
            return 5  # PAM_BUF_ERR
        responses[0] = C.cast(allocation, C.POINTER(Response))
        return 0

    conv = Conversation(conversation, None)
    results = []
    passed = False
    with tempfile.TemporaryDirectory(prefix="flakes-u2f-pam-") as directory:
        mapping = Path(directory, "u2f_keys")
        mapping.write_text(
            spec["user"] + ":" + ":".join(k["credential"] for k in spec["keys"]) + "\n"
        )
        Path(directory, "flakes-u2f-isolated").write_text(
            f"auth required {args.module} authfile={mapping} "
            f"origin={spec['origin']} appid={spec['origin']} "
            "userpresence=1 pinverification=0 userverification=0\n"
        )
        for attempt in range(args.attempts):
            handle = C.c_void_p()
            rc = lib.pam_start_confdir(
                b"flakes-u2f-isolated", b"keke", C.byref(conv),
                directory.encode(), C.byref(handle)
            )
            if rc:
                raise RuntimeError(f"pam_start_confdir: {rc}")
            start = time.monotonic()
            print(f"Touch the blinking key (attempt {attempt + 1}).", flush=True)
            try:
                rc = lib.pam_authenticate(handle, 0)
            finally:
                lib.pam_end(handle, rc)
            results.append({"pam_status": rc, "elapsed": round(time.monotonic() - start, 2)})
            passed = rc == 0 and not secret_prompts
            report = {"passed": passed, "secret_prompt_requested": bool(secret_prompts), "attempts": results}
            destination = Path(args.report)
            temporary = destination.with_suffix(".tmp")
            temporary.write_text(json.dumps(report, indent=2) + "\n")
            temporary.replace(destination)
            if passed or secret_prompts:
                break
    print("PASS: touch only, no PIN/password." if passed else "FAIL: production PAM unchanged.", flush=True)
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
