#!/usr/bin/env python3
"""Reference client for the AT Bridge (docs/AT_BRIDGE.md).

Sends intent commands to the game over local UDP. Use it to:
  * smoke-test the bridge      : python3 at_bridge_demo.py         (scripted shot)
  * drive the game by hand     : python3 at_bridge_demo.py -i      (interactive)
  * as a template for real hardware — replace the input source with your
    sensor reads (serial, GPIO, OpenCV, ...) and keep the send() calls.

In the game, select the AT Bridge scheme first (press 6, or Esc menu).
Pure stdlib; no dependencies.
"""

import argparse
import socket
import sys
import time

ADDR = ("127.0.0.1", 9010)


def make_sender():
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)

    def send(cmd: str) -> None:
        sock.sendto(cmd.encode("utf-8"), ADDR)
        print(f"  -> {cmd}")

    return send


def scripted_shot(send) -> None:
    """One full shot: aim slightly up (arrows drop!), draw, release at full draw."""
    print("Scripted shot (make sure the game is on the AT Bridge scheme — key 6):")
    send("CENTER")
    time.sleep(0.3)
    send("AIM 0.0 0.12")   # ~3.5 degrees up compensates the arrow's drop to the near target
    time.sleep(0.5)
    send("DRAW")
    time.sleep(2.0)     # full draw takes ~1.2 s by default; breath holds it steady
    send("RELEASE")
    print("Done — the arrow should be on its way.")


def interactive(send) -> None:
    print("Interactive mode. Type protocol commands (e.g. 'AIM 0 0.3', 'DRAW',")
    print("'RELEASE', 'NUDGE_LEFT', 'CENTER'). Ctrl-D or 'quit' to exit.")
    try:
        for line in sys.stdin:
            line = line.strip()
            if not line:
                continue
            if line.lower() in ("quit", "exit"):
                break
            send(line)
    except KeyboardInterrupt:
        pass


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("-i", "--interactive", action="store_true",
                        help="read commands from stdin instead of the scripted shot")
    args = parser.parse_args()
    send = make_sender()
    if args.interactive:
        interactive(send)
    else:
        scripted_shot(send)


if __name__ == "__main__":
    main()
