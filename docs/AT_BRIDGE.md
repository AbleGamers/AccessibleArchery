# The AT Bridge — connect *any* assistive interface

The AT Bridge is a tiny UDP text protocol that lets **any external program
drive the game**. If you can read your device from any language — Python on a
laptop, an ESP32 with Wi-Fi, a phone app — you can play Accessible Archery with
it. No engine code, no plugins, no native builds: send short text lines to a
local port.

This is the "device nobody has written support for yet" path promised by the
input architecture. Real examples this enables today:

- an **Arduino/ESP32 sip-and-puff** sensor (pressure sensor → `DRAW` on sip,
  `RELEASE` on puff)
- an **EMG muscle band** or **BCI** rig (threshold crossing → `DRAW`/`RELEASE`)
- **webcam head tracking** (MediaPipe/OpenCV pose → `AIM x y`)
- a **smartphone as a tilt controller** (accelerometer → `AIM_AXIS x y`)
- any **switch hardware** on a Raspberry Pi's GPIO pins

## Quick start

1. Run the game and press **6** (or pick *AT Bridge (UDP)* in the Esc menu).
2. In a terminal:

   ```
   python3 tools/at_bridge_demo.py
   ```

   The demo fires a scripted shot, then drops into an interactive prompt where
   you can type protocol commands yourself.

## Protocol

One command per UDP datagram, plain UTF-8 text, to **`127.0.0.1:9010`**.
Commands are case-insensitive. Malformed lines are ignored.

| Command | Meaning |
|---|---|
| `AIM x y` | Absolute aim. `x`,`y` ∈ [-1, 1]; `0 0` is centre, `+y` is up. For point-to-aim devices (head/eye tracking). |
| `AIM_AXIS x y` | Rate steering, like holding a stick. Values ∈ [-1, 1]; **send `AIM_AXIS 0 0` to stop turning**. |
| `NUDGE_LEFT` / `NUDGE_RIGHT` / `NUDGE_UP` / `NUDGE_DOWN` | Stepped absolute aim (one small step per command). For discrete switches. |
| `CENTER` | Recentre the aim. |
| `DRAW` | Start pulling the string. |
| `RELEASE` | Loose the arrow (aliases: `LOOSE`, `FIRE`, `SHOOT`). Only fires at full draw — earlier releases cancel, like every other device. |
| `STEADY` / `UNSTEADY` | Hold / release breath manually at full draw (only relevant when *Auto-hold breath* is off — it is **on** by default, so most bridges never need these). |

A complete shot, as a shell one-liner (macOS/Linux, `nc` from any package
manager):

```sh
printf 'AIM 0 0.3' | nc -u -w0 127.0.0.1 9010
printf 'DRAW'      | nc -u -w0 127.0.0.1 9010
sleep 1.5
printf 'RELEASE'   | nc -u -w0 127.0.0.1 9010
```

Or in Python, the entire "driver" for a hypothetical two-sensor sip-and-puff:

```python
import socket
sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
def send(cmd): sock.sendto(cmd.encode(), ("127.0.0.1", 9010))

while True:
    reading = read_my_sensor()          # your hardware here
    if reading.sip:  send("DRAW")
    if reading.puff: send("RELEASE")
```

## Design notes

- **Fairness is preserved.** The bridge reports the same abstract intents as
  every built-in device, so a bridge player gets the same full-draw-only shots,
  the same aim envelope, and the same steady/breath rules as everyone else.
  The scheme supports the `steady` intent, and the auto-hold default covers
  interfaces that can't express it.
- **Local only.** The adapter binds `127.0.0.1` — nothing is exposed to the
  network. Run the bridge program on the same machine.
- **Stateless & lossy-tolerant.** UDP datagrams may drop; design your bridge to
  re-send state (e.g. keep streaming `AIM` at 30 Hz) rather than assume
  delivery.
- Scores banked from a bridge are tagged on the leaderboard with the 🔌 Bridge
  badge, like every other scheme.

## Related

- `scripts/input/bridge_adapter.gd` — the in-game half (≈100 lines).
- `tools/at_bridge_demo.py` — runnable reference client.
- `docs/VOICE.md` — the voice bridge, the same pattern specialized for speech.
