# /// script
# requires-python = ">=3.9"
# dependencies = ["faster-whisper==1.1.1", "requests"]
# ///
"""Speech recognition for the Godot game: turns short recordings into text, offline (Whisper).

The game records the microphone itself (scripts/speech.gd), writes a WAV file and sends its path
over UDP on localhost. This process answers with the text. Nothing leaves the computer; the model
is downloaded once on the first run (base, about 150 MB) and cached.

    uv run tracker/speech.py              started by the game, or by hand
    uv run tracker/speech.py --selftest   load the model and transcribe a second of silence
    uv run tracker/speech.py --model small   better German, slower (about 500 MB)

Protocol (JSON, one packet each):
    game -> here  (port 47803): {"want": 1}                      heartbeat, every 0.5 s
                                {"wav": "/path.wav", "id": 3, "prompt": "words to expect"}
                                {"quit": 1}
    here -> game  (port 47802): {"hello": 1, "state": "loading" | "ready" | "error", "error": "..."}
                                {"id": 3, "text": "...", "secs": 0.8}
"""

import argparse
import json
import os
import socket
import sys
import threading
import time

PORT_OUT = 47802          # to the game
PORT_IN = 47803           # from the game
ALONE_QUIT = 20.0         # started by the game and no heartbeat for this long: end


def send(sock, d):
    try:
        sock.sendto(json.dumps(d).encode("utf-8"), ("127.0.0.1", PORT_OUT))
    except OSError:
        pass


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--model", default=os.environ.get("VISCON_WHISPER", "base"))
    ap.add_argument("--child", action="store_true", help="started by the game: end when it is gone")
    ap.add_argument("--selftest", action="store_true")
    args = ap.parse_args()

    out = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    state = {"model": None, "state": "loading", "error": "", "last": time.time()}

    def load():
        try:
            from faster_whisper import WhisperModel
            t0 = time.time()
            state["model"] = WhisperModel(args.model, device="cpu", compute_type="int8")
            state["state"] = "ready"
            print(f"speech: model {args.model} ready in {time.time() - t0:.1f} s", flush=True)
        except Exception as e:  # missing package, no internet on the first run, ...
            state["state"] = "error"
            state["error"] = str(e)[:200]
            print("speech: could not load the model:", e, flush=True)

    if args.selftest:
        load()
        if state["model"] is None:
            sys.exit(1)
        import numpy as np
        t0 = time.time()
        segs, _ = state["model"].transcribe(np.zeros(16000, dtype=np.float32), language="de")
        print("selftest ok:", repr(" ".join(s.text for s in segs)), f"{time.time() - t0:.2f} s")
        return

    threading.Thread(target=load, daemon=True).start()
    inp = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        inp.bind(("127.0.0.1", PORT_IN))
    except OSError:
        print("speech: port in use, another speech.py is running", flush=True)
        return
    inp.settimeout(0.5)
    print("speech: listening on", PORT_IN, flush=True)
    last_hello = 0.0
    while True:
        now = time.time()
        if now - last_hello > 0.5:
            last_hello = now
            send(out, {"hello": 1, "state": state["state"], "error": state["error"], "model": args.model})
        if args.child and now - state["last"] > ALONE_QUIT:
            print("speech: the game is gone, bye", flush=True)
            return
        try:
            data, _ = inp.recvfrom(65536)
        except socket.timeout:
            continue
        try:
            msg = json.loads(data.decode("utf-8"))
        except ValueError:
            continue
        state["last"] = time.time()
        if msg.get("quit"):
            return
        if "wav" not in msg:
            continue
        if state["model"] is None:
            send(out, {"id": msg.get("id", 0), "text": "", "error": "not ready"})
            continue
        t0 = time.time()
        text = ""
        try:
            segs, _ = state["model"].transcribe(
                msg["wav"], language="de", beam_size=1, vad_filter=True,
                initial_prompt=msg.get("prompt") or None)
            text = " ".join(s.text.strip() for s in segs).strip()
        except Exception as e:
            print("speech: could not transcribe:", e, flush=True)
        send(out, {"id": msg.get("id", 0), "text": text, "secs": round(time.time() - t0, 2)})
        print(f"speech: {time.time() - t0:.2f} s: {text!r}", flush=True)
        try:
            os.remove(msg["wav"])
        except OSError:
            pass


if __name__ == "__main__":
    main()
