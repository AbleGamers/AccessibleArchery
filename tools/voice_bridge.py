#!/usr/bin/env python3
"""Offline speech -> Accessible Archery voice bridge (Vosk).

Listens to the microphone, recognizes a small fixed vocabulary of archery
commands entirely offline with Vosk, and sends one command token per spoken
word to the running game over UDP (localhost:9009). The game's VoiceAdapter
(scripts/input/voice_adapter.gd) binds that port and maps tokens to intents.

Why a separate process? It keeps the Godot project pure GDScript with zero
native dependencies. Any recognizer that can send these UDP tokens works — Vosk
is just the open-source, offline reference implementation.

Setup (see docs/VOICE.md):
    python3 -m venv .venv && source .venv/bin/activate
    pip install -r tools/requirements.txt
    # download a small model, e.g. vosk-model-small-en-us-0.15, unzip it, then:
    python tools/voice_bridge.py --model /path/to/vosk-model-small-en-us-0.15

Then launch the game, press 5 (Voice), and say: left / right / up / down /
draw / loose / center. Hold-to-draw is emulated: "draw" presses, "loose" fires.
"""

import argparse
import json
import queue
import socket
import sys

import sounddevice as sd
from vosk import KaldiRecognizer, Model

# Spoken word -> command token the game understands. Synonyms welcome.
WORD_TO_TOKEN = {
    "left": "AIM_LEFT",
    "right": "AIM_RIGHT",
    "up": "AIM_UP",
    "down": "AIM_DOWN",
    "draw": "DRAW",
    "pull": "DRAW",
    "loose": "RELEASE",
    "shoot": "RELEASE",
    "fire": "RELEASE",
    "release": "RELEASE",
    "center": "CENTER",
    "middle": "CENTER",
    "reset": "CENTER",
}

# The recognizer is constrained to just our vocabulary, which makes it much
# faster and far more accurate than open dictation.
GRAMMAR = json.dumps(sorted(set(WORD_TO_TOKEN.keys())) + ["[unk]"])


def main() -> int:
    ap = argparse.ArgumentParser(description="Vosk voice bridge for Accessible Archery")
    ap.add_argument("--model", help="path to an unzipped Vosk model directory")
    ap.add_argument("--host", default="127.0.0.1")
    ap.add_argument("--port", type=int, default=9009)
    ap.add_argument("--device", type=int, default=None, help="input device index (see --list)")
    ap.add_argument("--list", action="store_true", help="list audio input devices and exit")
    args = ap.parse_args()

    if args.list:
        print(sd.query_devices())
        return 0

    if not args.model:
        ap.error("--model is required (path to an unzipped Vosk model). Use --list to see audio devices.")

    # Fail clearly if there is no microphone, instead of a cryptic PortAudio
    # error. A Mac mini, for example, has no built-in mic — plug in a USB or
    # Bluetooth mic/headset and it will appear here.
    if not any(d["max_input_channels"] > 0 for d in sd.query_devices()):
        print(
            "No microphone detected. Plug in a USB or Bluetooth mic/headset, then\n"
            "re-run. `--list` shows all audio devices (inputs have 'N in' with N > 0).",
            file=sys.stderr,
        )
        return 1

    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    dest = (args.host, args.port)

    model = Model(args.model)
    samplerate = int(sd.query_devices(args.device, "input")["default_samplerate"])
    rec = KaldiRecognizer(model, samplerate, GRAMMAR)

    audio_q: "queue.Queue[bytes]" = queue.Queue()

    def on_audio(indata, frames, time, status):  # noqa: ANN001 - sounddevice callback
        if status:
            print(status, file=sys.stderr)
        audio_q.put(bytes(indata))

    def emit(words: str) -> None:
        for w in words.split():
            token = WORD_TO_TOKEN.get(w)
            if token:
                sock.sendto(token.encode("utf-8"), dest)
                print(f"  {w} -> {token}")

    print(f"Listening (sr={samplerate}). Sending tokens to {args.host}:{args.port}.")
    print("Say: left / right / up / down / draw / loose / center.  Ctrl+C to stop.")
    with sd.RawInputStream(
        samplerate=samplerate, blocksize=8000, dtype="int16",
        channels=1, device=args.device, callback=on_audio,
    ):
        try:
            while True:
                data = audio_q.get()
                # Emit only on finalized results (a brief pause between words);
                # partials would repeat the same word every audio chunk.
                if rec.AcceptWaveform(data):
                    emit(json.loads(rec.Result()).get("text", ""))
        except KeyboardInterrupt:
            print("\nStopped.")
            return 0


if __name__ == "__main__":
    raise SystemExit(main())
