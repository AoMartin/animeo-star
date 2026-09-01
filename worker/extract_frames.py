"""Extract numbered JPEG frames from a video for Godot preview/scrubbing."""
import argparse
import json
from pathlib import Path


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--video", required=True)
    parser.add_argument("--out-dir", required=True)
    parser.add_argument("--metadata", required=True)
    args = parser.parse_args()
    try:
        import cv2
    except ImportError:
        print("Missing dependency: opencv-python", flush=True)
        return 3
    capture = cv2.VideoCapture(args.video)
    if not capture.isOpened():
        print(f"Could not open video: {args.video}", flush=True)
        return 2
    out_dir = Path(args.out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)
    fps = float(capture.get(cv2.CAP_PROP_FPS) or 30.0)
    count = 0
    while True:
        ok, frame = capture.read()
        if not ok:
            break
        cv2.imwrite(str(out_dir / f"frame_{count:06d}.jpg"), frame, [cv2.IMWRITE_JPEG_QUALITY, 90])
        count += 1
    capture.release()
    Path(args.metadata).write_text(json.dumps({"fps": fps, "frame_count": count, "duration": count / fps if fps else 0.0}), encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
