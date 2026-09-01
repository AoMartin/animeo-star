# Animeo Star architecture

The application is split into a Godot 4.7 desktop UI and an external Python
worker. Godot owns video selection, keyframes, preview, retargeting and GLB
export. Python owns STAR Neutral evaluation and fitting.

## STAR-only constraint

STAR is a parametric human body model. It does not detect a human directly
from an RGB frame. The worker therefore exposes a fitting boundary for pose
observations/fitted parameters, but deliberately contains no MediaPipe,
OpenPose or MMPose dependency. Processing cannot produce valid STAR pose data
until that fitting adapter is implemented or supplied.

## Coordinate convention

The intermediate contract uses a right-handed, Y-up, meter-based convention
named `godot_y_up_right_handed`. All conversion between STAR/Python, Godot and
Blender belongs in one future coordinate-conversion module.

## Local configuration

Machine-specific executables and model paths belong only in the ignored `.env`
file. `.env.example` documents variable names without real paths.

