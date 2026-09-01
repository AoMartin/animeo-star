# Animeo Star

MVP desktop scaffold for selecting sparse video keyframes and processing them
through a STAR Neutral worker.

## Run

1. Configure `.env` locally. It is ignored by Git.
2. Open the project with Godot 4.7 or run:

```powershell
& $env:GODOT_EXECUTABLE_PATH --path . --editor
```

3. Select a video, move the timeline, mark two or more keyframes, and choose
   `Process Keyframes`.

The current MVP validates the UI/keyframe/JSON/worker flow. STAR model fitting,
humanoid import/retargeting and GLB export are the next implementation layer;
the worker reports this explicitly until a STAR fitting adapter is configured.

