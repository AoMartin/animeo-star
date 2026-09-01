"""STAR-only processing entry point.

STAR is a parametric body model, not an RGB detector. This worker intentionally
does not include MediaPipe or another detector. A future STAR fitting adapter
must provide pose observations or fitted pose parameters for selected frames.
"""
import argparse
import json
import os
from pathlib import Path


def neutral_model_path() -> Path:
    configured = os.environ.get("STAR_MODEL_PATH", "")
    if configured:
        path = Path(configured)
        if not path.is_absolute():
            path = Path(__file__).resolve().parent.parent / path
        return path
    return Path(__file__).resolve().parent.parent / "star_1_1" / "neutral"


def main() -> int:
    parser = argparse.ArgumentParser(description="Process selected frames with STAR Neutral")
    parser.add_argument("--input", required=True, help="Input motion JSON")
    parser.add_argument("--output", required=True, help="Output motion JSON")
    args = parser.parse_args()
    # utf-8-sig also accepts regular UTF-8 and JSON files created by Windows PowerShell.
    data = json.loads(Path(args.input).read_text(encoding="utf-8-sig"))
    data["schema_version"] = 1
    data["model"] = "STAR_NEUTRAL"
    data["coordinate_system"] = "godot_y_up_right_handed"
    model_dir = neutral_model_path()
    data["star_model_available"] = (model_dir / "model.npz").is_file() if model_dir.is_dir() else model_dir.is_file()
    data.setdefault("keyframes", [])
    for keyframe in data["keyframes"]:
        keyframe.setdefault("status", "pending")
        keyframe.setdefault("error", "STAR fitting adapter not configured; neutral model detected" if data["star_model_available"] else "STAR Neutral model not found")
    Path(args.output).parent.mkdir(parents=True, exist_ok=True)
    Path(args.output).write_text(json.dumps(data, indent=2), encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
