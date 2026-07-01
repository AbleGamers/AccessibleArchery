# Voice control (offline, open-source)

The Voice input scheme is driven by an **out-of-process** speech recognizer so
the game itself stays pure GDScript with no native dependencies. The reference
backend is [Vosk](https://alphacephei.com/vosk/) — fully offline, open-source,
no API keys, no cloud.

```
microphone ──► tools/voice_bridge.py (Vosk) ──UDP token──► game VoiceAdapter
```

The bridge recognizes a small fixed vocabulary and sends one command token per
spoken word to `127.0.0.1:9009`. The game's
[`VoiceAdapter`](../scripts/input/voice_adapter.gd) binds that port and maps
tokens to archery intents. Any recognizer that can send those UDP tokens works —
Vosk is just the default.

## Vocabulary

| Say | Does |
|-----|------|
| **left / right / up / down** | nudge aim |
| **draw** (or *pull*) | start the draw (charge builds) |
| **loose** (or *shoot* / *fire* / *release*) | release the arrow |
| **center** (or *middle* / *reset*) | re-center aim |

## You need a microphone

Some Macs (e.g. **Mac mini**) have **no built-in microphone** — plug in a USB or
Bluetooth mic/headset first. `python tools/voice_bridge.py --list` shows audio
devices; an input has `N in` with N > 0. With no mic, the bridge exits with a
clear "No microphone detected" message rather than running.

## Setup

```bash
cd AccessibleArchery
python3 -m venv .venv
source .venv/bin/activate                 # Windows: .venv\Scripts\activate
pip install -r tools/requirements.txt
```

Download a small English model (≈40 MB) from
https://alphacephei.com/vosk/models — e.g. `vosk-model-small-en-us-0.15` — and
unzip it anywhere.

> macOS: the first run will prompt for **microphone permission** for your
> terminal app. Allow it (System Settings ▸ Privacy & Security ▸ Microphone).

## Run

1. Start the game, press **5** to select the Voice scheme.
2. In a second terminal:
   ```bash
   source .venv/bin/activate
   python tools/voice_bridge.py --model /path/to/vosk-model-small-en-us-0.15
   ```
3. Speak the commands. The bridge prints each recognized `word -> TOKEN`.

`python tools/voice_bridge.py --list` shows input devices; pass
`--device <index>` to pick one.

## No microphone? Keyboard debug bridge

The Voice scheme also accepts keys so you can test the mapping with no mic:
**arrows/WASD** nudge aim, **Q** draw, **E** loose, **C** center.
