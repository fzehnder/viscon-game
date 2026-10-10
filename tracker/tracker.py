# /// script
# requires-python = ">=3.10"
# dependencies = ["mediapipe==1.1.0"]
# ///
"""Webcam tracker for the Godot game: faces, hands and body poses via MediaPipe.

Runs next to the game and talks to the autoload `Track` (godot/scripts/tracking.gd) over UDP
on localhost. The camera is only open while the game asks for something.

    uv run tracker/tracker.py                 started by the game, or by hand
    uv run tracker/tracker.py --show --want face,hand,pose     look at it without the game
    uv run tracker/tracker.py --selftest      load all models, measure speed
    uv run tracker/tracker.py --fake photo.jpg                 a still picture instead of the camera
    uv run tracker/tracker.py --list-cameras  which cameras there are and which one is taken

Camera: by default the one built into the computer, not a phone that offers itself as a camera
(on a Mac the iPhone does that). --camera or the environment variable VISCON_CAMERA takes a
number or a part of the name instead.

Everything is sent as in a mirror: x = 0 is the left edge of what the players see, y = 0 the top.
Lists are sorted from left to right, so with two players index 0 is P1 (sits left).
"""

import argparse
import json
import math
import os
import socket
import subprocess
import sys
import time
import urllib.request
from pathlib import Path

import cv2
import mediapipe as mp
import numpy as np
from mediapipe.tasks import python as mp_tasks
from mediapipe.tasks.python import vision

HERE = Path(__file__).resolve().parent
MODEL_DIR = HERE / "models"
MODEL_BASE = "https://storage.googleapis.com/mediapipe-models/"
MODELS = {
    "face": "face_landmarker/face_landmarker/float16/1/face_landmarker.task",
    "hand": "hand_landmarker/hand_landmarker/float16/1/hand_landmarker.task",
    "pose": "pose_landmarker/pose_landmarker_lite/float16/1/pose_landmarker_lite.task",
}
KINDS = ("face", "hand", "pose")

IRIS_CM = 1.17          # the human iris is about 11.7 mm wide for everyone: a ruler in every face
GAME_SILENT = 3.0       # no command from the game for this long: release the camera
CHILD_EXIT = 20.0       # started by the game (--child) and no command for this long: quit
PREVIEW_HEIGHT = 240    # the preview keeps the shape of the camera picture (320 x 240 for 4:3)
# cameras that are not the computer's own: phones and tablets nearby, virtual cameras
NOT_BUILT_IN = ("iphone", "ipad", "desk view", "schreibtischansicht", "continuity", "obs", "virtual", "snap camera")
PREVIEW_FPS = 30.0      # every picture: the preview and what is drawn on it stay together
PREVIEW_QUALITY = 55
MAX_PACKET = 60000


def log(*a):
    print("[tracker]", *a, file=sys.stderr, flush=True)


def model_path(kind: str) -> str:
    """Path of the model file, downloaded on first use."""
    target = MODEL_DIR / Path(MODELS[kind]).name
    if not target.exists():
        MODEL_DIR.mkdir(parents=True, exist_ok=True)
        log(f"downloading {target.name} ...")
        tmp = target.with_suffix(".part")
        urllib.request.urlretrieve(MODEL_BASE + MODELS[kind], tmp)
        tmp.replace(target)
    return str(target)


def make(kind: str):
    base = mp_tasks.BaseOptions(model_asset_path=model_path(kind))
    mode = vision.RunningMode.VIDEO
    if kind == "face":
        return vision.FaceLandmarker.create_from_options(vision.FaceLandmarkerOptions(
            base_options=base, running_mode=mode, num_faces=4,
            output_face_blendshapes=True, output_facial_transformation_matrixes=True))
    if kind == "hand":
        return vision.HandLandmarker.create_from_options(vision.HandLandmarkerOptions(
            base_options=base, running_mode=mode, num_hands=4))
    return vision.PoseLandmarker.create_from_options(vision.PoseLandmarkerOptions(
        base_options=base, running_mode=mode, num_poses=4))   # with fewer, a group around the laptop is reported as a changing few


def r(v: float, n: int = 4) -> float:
    return round(float(v), n)


def px_dist(a, b, w: int, h: int) -> float:
    return math.hypot((a.x - b.x) * w, (a.y - b.y) * h)


def face_out(lm, blend, matrix, w: int, h: int) -> dict:
    xs = [p.x for p in lm]
    ys = [p.y for p in lm]
    nose = lm[1]
    # iris rings: 469/471 are the left and right edge of one iris, 474/476 of the other
    iris_px = (px_dist(lm[469], lm[471], w, h) + px_dist(lm[474], lm[476], w, h)) / 2.0
    iris_px = max(iris_px, 1.0)
    b = {c.category_name: c.score for c in blend}
    # The camera picture is not mirrored when we detect, so "Left" is the player's own left eye.
    look_x = ((b.get("eyeLookOutRight", 0) + b.get("eyeLookInLeft", 0))
              - (b.get("eyeLookOutLeft", 0) + b.get("eyeLookInRight", 0))) / 2.0
    look_y = ((b.get("eyeLookDownLeft", 0) + b.get("eyeLookDownRight", 0))
              - (b.get("eyeLookUpLeft", 0) + b.get("eyeLookUpRight", 0))) / 2.0
    # Head rotation from the face matrix. Camera space: x to the right of the raw picture,
    # y up, z towards the camera. Flip the left/right angles so they match the mirrored picture.
    rot = np.array(matrix)[:3, :3]
    fwd = rot @ np.array([0.0, 0.0, 1.0])
    up = rot @ np.array([0.0, 1.0, 0.0])
    fwd /= max(np.linalg.norm(fwd), 1e-6)
    yaw = -math.degrees(math.atan2(fwd[0], fwd[2]))
    pitch = math.degrees(math.asin(max(-1.0, min(1.0, fwd[1]))))
    roll = -math.degrees(math.atan2(up[0], up[1]))
    return {
        "x": r(1.0 - nose.x), "y": r(nose.y),
        "box": [r(1.0 - max(xs)), r(min(ys)), r(max(xs) - min(xs)), r(max(ys) - min(ys))],
        # iris centres: the player's own left eye (left in the mirrored picture), then the right one
        "eyes": [[r(1.0 - lm[473].x), r(lm[473].y)], [r(1.0 - lm[468].x), r(lm[468].y)]],
        "yaw": r(yaw, 1), "pitch": r(pitch, 1), "roll": r(roll, 1),
        "blink_l": r(b.get("eyeBlinkLeft", 0), 3), "blink_r": r(b.get("eyeBlinkRight", 0), 3),
        "look_x": r(look_x, 3), "look_y": r(look_y, 3),
        "mouth": r(b.get("jawOpen", 0), 3),
        "cm_per_x": r(IRIS_CM * w / iris_px, 2), "cm_per_y": r(IRIS_CM * h / iris_px, 2),
    }


def hand_out(lm, handed, w: int, h: int) -> dict:
    size = max(px_dist(lm[0], lm[9], w, h), 1.0)     # wrist to middle knuckle
    tips = sum(px_dist(lm[i], lm[0], w, h) for i in (8, 12, 16, 20)) / 4.0
    palm = [lm[i] for i in (0, 5, 9, 13, 17)]
    label = handed[0].category_name if handed else ""
    return {
        "x": r(1.0 - lm[8].x), "y": r(lm[8].y),      # tip of the index finger
        "palm": [r(1.0 - sum(p.x for p in palm) / 5.0), r(sum(p.y for p in palm) / 5.0)],
        "pinch": r(px_dist(lm[4], lm[8], w, h) / size, 3),   # about 0.1 closed, above 1 wide open
        "open": r(tips / size, 3),                   # about 1 for a fist, about 2 for a flat hand
        # MediaPipe assumes a mirrored picture for left/right, we detect on the raw one: swap.
        "side": {"Left": "R", "Right": "L"}.get(label, ""),
        "pts": [[r(1.0 - p.x), r(p.y)] for p in lm],
    }


def pose_out(lm) -> dict:
    return {
        "x": r(1.0 - (lm[11].x + lm[12].x) / 2.0), "y": r((lm[11].y + lm[12].y) / 2.0),
        "pts": [[r(1.0 - p.x, 3), r(p.y, 3), r(p.visibility or 0.0, 2)] for p in lm],
    }


class Detectors:
    def __init__(self):
        self.models = {}
        self.ts = 0

    def run(self, frame_bgr, kinds) -> dict:
        h, w = frame_bgr.shape[:2]
        rgb = cv2.cvtColor(frame_bgr, cv2.COLOR_BGR2RGB)
        image = mp.Image(image_format=mp.ImageFormat.SRGB, data=rgb)
        self.ts = max(self.ts + 1, int(time.monotonic() * 1000))    # must always grow
        out = {}
        for kind in kinds:
            if kind not in self.models:
                log(f"loading {kind} model")
                self.models[kind] = make(kind)
            res = self.models[kind].detect_for_video(image, self.ts)
            if kind == "face":
                faces = [face_out(lm, res.face_blendshapes[i], res.facial_transformation_matrixes[i], w, h)
                         for i, lm in enumerate(res.face_landmarks)]
                out["faces"] = sorted(faces, key=lambda f: f["x"])
            elif kind == "hand":
                hands = [hand_out(lm, res.handedness[i], w, h) for i, lm in enumerate(res.hand_landmarks)]
                out["hands"] = sorted(hands, key=lambda f: f["palm"][0])
            else:
                out["poses"] = sorted((pose_out(lm) for lm in res.pose_landmarks), key=lambda f: f["x"])
        return out


def list_cameras() -> list:
    """The cameras with the numbers OpenCV gives them, and their names: [{"index", "name", "model"}].
    Only macOS tells the names without extra packages; elsewhere the list is empty."""
    if sys.platform != "darwin":
        return []
    try:
        raw = subprocess.run(["system_profiler", "SPCameraDataType", "-json"], capture_output=True, timeout=10).stdout
        cams = json.loads(raw).get("SPCameraDataType", [])
    except Exception:
        return []
    # OpenCV sorts the devices by their unique id and counts from 0 (cap_avfoundation_mac.mm).
    # A phone that comes into reach can therefore push the built-in camera from 0 to 1.
    cams.sort(key=lambda c: str(c.get("spcamera_unique-id", "")))
    return [{"index": i, "name": str(c.get("_name", "?")), "model": str(c.get("spcamera_model-id", ""))}
            for i, c in enumerate(cams)]


def is_built_in(cam: dict) -> bool:
    text = (cam["name"] + " " + cam["model"]).lower()
    return not any(word in text for word in NOT_BUILT_IN)


def pick_camera(spec: str) -> tuple:
    """(number for OpenCV, name or ""). spec: "auto", a number, or a part of the name."""
    cams = list_cameras()
    names = {c["index"]: c["name"] for c in cams}
    spec = spec.strip()
    if spec.lstrip("-").isdigit():
        return int(spec), names.get(int(spec), "")
    if spec.lower() not in ("", "auto"):
        for c in cams:
            if spec.lower() in c["name"].lower():
                return c["index"], c["name"]
        log(f"no camera with '{spec}' in its name, choosing one myself")
    for c in cams:
        if is_built_in(c):
            return c["index"], c["name"]
    return 0, names.get(0, "")


class Camera:
    def __init__(self, spec: str, fake: str):
        self.spec = str(spec)
        self.name = ""
        self.cap = None
        self.retry_at = 0.0
        self.still = None
        if fake:
            self.still = cv2.imread(fake)
            if self.still is None:
                raise SystemExit(f"cannot read picture: {fake}")

    def read(self):
        if self.still is not None:
            time.sleep(1.0 / 30.0)
            return self.still.copy()
        if self.cap is None:
            if time.monotonic() < self.retry_at:
                return None
            backend = {"darwin": cv2.CAP_AVFOUNDATION, "win32": cv2.CAP_DSHOW}.get(sys.platform, cv2.CAP_ANY)
            index, self.name = pick_camera(self.spec)   # every time: the numbers change when a phone comes or goes
            cap = cv2.VideoCapture(index, backend)
            if not cap.isOpened():
                cap.release()
                self.retry_at = time.monotonic() + 2.0    # no permission or in use: do not hammer it
                return None
            cap.set(cv2.CAP_PROP_FRAME_WIDTH, 640)
            cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 480)
            cap.set(cv2.CAP_PROP_BUFFERSIZE, 1)
            self.cap = cap
            log(f"camera on: number {index}" + (f", {self.name}" if self.name else ""))
        ok, frame = self.cap.read()
        return frame if ok else None

    def close(self):
        if self.cap is not None:
            self.cap.release()
            self.cap = None
            log("camera off")


def draw(frame, data: dict):
    """Mirrored picture with everything that was found, for --show."""
    img = cv2.flip(frame, 1)
    h, w = img.shape[:2]
    for f in data.get("faces", []):
        x, y, bw, bh = f["box"]
        cv2.rectangle(img, (int(x * w), int(y * h)), (int((x + bw) * w), int((y + bh) * h)), (60, 220, 150), 2)
        txt = f"yaw {f['yaw']:.0f} pitch {f['pitch']:.0f} blink {f['blink_l']:.1f}/{f['blink_r']:.1f}"
        cv2.putText(img, txt, (int(x * w), int(y * h) - 8), cv2.FONT_HERSHEY_SIMPLEX, 0.5, (60, 220, 150), 1)
    for hd in data.get("hands", []):
        for px, py in hd["pts"]:
            cv2.circle(img, (int(px * w), int(py * h)), 3, (60, 200, 255), -1)
        cv2.putText(img, f"{hd['side']} pinch {hd['pinch']:.2f}", (int(hd['x'] * w), int(hd['y'] * h) - 10),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.5, (60, 200, 255), 1)
    for p in data.get("poses", []):
        for px, py, vis in p["pts"]:
            if vis > 0.5:
                cv2.circle(img, (int(px * w), int(py * h)), 4, (255, 140, 80), -1)
    return img


def make_socket() -> socket.socket:
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    # macOS allows only 9216 bytes per UDP packet unless the send buffer is raised
    s.setsockopt(socket.SOL_SOCKET, socket.SO_SNDBUF, 1 << 20)
    return s


def selftest(args) -> int:
    ok = True
    # 1. a packet as large as a preview picture has to get through on localhost
    rx = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    rx.bind(("127.0.0.1", 0))
    rx.settimeout(1.0)
    try:
        make_socket().sendto(b"x" * 30000, rx.getsockname())
        got = len(rx.recv(65535))
        print(f"udp     ok ({got} bytes in one packet)")
    except OSError as e:
        ok = False
        print(f"udp     FAILED: {e}")
    rx.close()
    # 2. every model loads and runs
    cam = Camera(args.camera, args.fake)
    frame = cam.read()
    if frame is None:
        print("camera  FAILED: no picture (permission? other program using it?)")
        print("        models are tested on a grey picture instead")
        frame = np.full((480, 640, 3), 128, np.uint8)
        ok = False
    else:
        print(f"camera  ok ({frame.shape[1]}x{frame.shape[0]}" + (f", {cam.name})" if cam.name else ")"))
    det = Detectors()
    for kind in KINDS:
        det.run(frame, [kind])      # first run loads the model
        t0 = time.perf_counter()
        n = 15
        for _ in range(n):
            f2 = cam.read()
            data = det.run(f2 if f2 is not None else frame, [kind])
        ms = (time.perf_counter() - t0) / n * 1000.0
        print(f"{kind:7s} ok ({ms:.0f} ms per picture, found {len(next(iter(data.values())))})")
    cam.close()
    print("RESULT", "ok" if ok else "problems")
    return 0 if ok else 1


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--port", type=int, default=47800, help="game listens here")
    ap.add_argument("--cmd-port", type=int, default=47801, help="tracker listens here")
    ap.add_argument("--camera", default=os.environ.get("VISCON_CAMERA", "auto"),
                    help="auto (the built-in one), a number, or a part of the name; also the environment variable VISCON_CAMERA")
    ap.add_argument("--list-cameras", action="store_true", help="show the cameras and which one would be used")
    ap.add_argument("--fake", default="", help="use this picture instead of the camera")
    ap.add_argument("--want", default="", help="always track these, e.g. face,hand,pose (without the game)")
    ap.add_argument("--show", action="store_true", help="open a window with the result")
    ap.add_argument("--child", action="store_true", help="quit when the game is gone")
    ap.add_argument("--selftest", action="store_true")
    args = ap.parse_args()

    if args.list_cameras:
        cams = list_cameras()
        chosen, name = pick_camera(args.camera)
        if not cams:
            print(f"This system does not tell the names. Camera number {chosen} is used; try --camera 1, 2, ... with --show.")
        for c in cams:
            print(f"{'->' if c['index'] == chosen else '  '} {c['index']}  {c['name']}" + ("" if is_built_in(c) else "   (phone or virtual camera)"))
        return 0
    if args.selftest:
        return selftest(args)

    forced = [k for k in args.want.split(",") if k in KINDS]
    game = ("127.0.0.1", args.port)
    out = make_socket()
    cmd = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        cmd.bind(("127.0.0.1", args.cmd_port))
    except OSError:
        log(f"port {args.cmd_port} is taken: is another tracker running?")
        return 3
    cmd.setblocking(False)

    cam = Camera(args.camera, args.fake)
    det = Detectors()
    want, want_preview = [], False
    last_cmd = time.monotonic()
    last_hello = last_preview = 0.0
    frames, fps, fps_t = 0, 0.0, time.monotonic()
    log("ready")

    def send(obj: dict):
        out.sendto(b"J" + json.dumps(obj, separators=(",", ":")).encode(), game)

    while True:
        now = time.monotonic()
        try:
            while True:
                msg = json.loads(cmd.recv(4096))
                last_cmd = now
                if msg.get("quit"):
                    log("game said quit")
                    cam.close()
                    return 0
                want = [k for k in msg.get("want", []) if k in KINDS]
                want_preview = bool(msg.get("preview", False))
        except (BlockingIOError, ValueError):
            pass

        silent = now - last_cmd
        if args.child and silent > CHILD_EXIT:
            log("game is gone, quitting")
            cam.close()
            return 0
        kinds = list(dict.fromkeys(forced + (want if silent < GAME_SILENT else [])))
        if not kinds:
            cam.close()
            if now - last_hello > 1.0:
                last_hello = now
                send({"hello": 1})
            time.sleep(0.05)
            continue

        frame = cam.read()
        if frame is None:
            if now - last_hello > 1.0:
                last_hello = now
                send({"error": "camera"})
            time.sleep(0.2)
            continue

        data = det.run(frame, kinds)
        frames += 1
        if now - fps_t >= 1.0:
            fps, frames, fps_t = frames / (now - fps_t), 0, now
        data["fps"] = r(fps, 1)
        data["aspect"] = r(frame.shape[1] / frame.shape[0], 3)
        data["cam"] = cam.name
        send(data)

        if (want_preview and silent < GAME_SILENT) and now - last_preview >= 0.9 / PREVIEW_FPS:
            last_preview = now
            pw = int(round(PREVIEW_HEIGHT * frame.shape[1] / frame.shape[0] / 2.0)) * 2
            small = cv2.flip(cv2.resize(frame, (pw, PREVIEW_HEIGHT)), 1)
            ok, jpg = cv2.imencode(".jpg", small, [cv2.IMWRITE_JPEG_QUALITY, PREVIEW_QUALITY])
            if ok and len(jpg) < MAX_PACKET:
                try:
                    out.sendto(b"P" + jpg.tobytes(), game)
                except OSError:
                    pass    # too large for this system: the game simply has no preview

        if args.show:
            cv2.imshow("tracker (q = quit)", draw(frame, data))
            if cv2.waitKey(1) & 0xFF == ord("q"):
                cam.close()
                return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        pass
