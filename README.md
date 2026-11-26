# Clinometer-dig

A digital sighting clinometer for iPhone, built for laying out trail. You aim the
camera at a mark at your own eye (lens) height, either on an assistant or on a
ribbon tied to a tree, and the app reads the slope as **percent grade** and **degrees**.

The interface is styled after a field optical clinometer: a matte black housing,
an off-white rolling scale drum (degrees on the left, percent on the right), and
a single safety-orange hairline.

## Status: v0.1 (first working version)

- Live camera sighting scope with a center reticle and a hairline that crosses the scale
- Tilt from Core Motion, accurate to roughly 0.1–0.2° once calibrated
- Rolling scale drum plus large digital readouts
- Smoothed display, with a steadiness indicator (STEADY / SETTLING)
- **HOLD** freezes the average of the last 0.5 s. The **volume buttons** also toggle HOLD, so you don't have to tap the screen
- **ZERO** calibration, saved between launches, to correct for small camera/sensor misalignment
- 1× / 2× / 4× zoom for distant targets
- A roll guide (dashed amber line) that appears when the phone is tilted sideways
- The screen stays awake while the app is open

## Running it on your iPhone

You need a Mac with **Xcode 16 or later** (free from the Mac App Store).

1. Clone this repo and open `Clinometer.xcodeproj`.
2. In the project navigator, select **Clinometer**, open the **Signing & Capabilities** tab, and set
   **Team** to your Apple ID. A free account works; choose *Add an Account…* if needed.
3. Change **Bundle Identifier** to something unique, e.g. `com.yourname.clinometer`.
4. Connect your iPhone by cable and choose it as the run destination at the top of Xcode.
   - The first time, turn on **Settings → Privacy & Security → Developer Mode** on the phone and restart it.
   - With a free account you'll also need to trust the developer under
     **Settings → General → VPN & Device Management**. Free-account installs expire after 7 days; just run it again from Xcode.
5. Press **Run** (⌘R) and allow camera access.

The simulator has no camera or motion sensors, so it is only useful for checking layout.

> If Xcode won't open the project, regenerate it: `brew install xcodegen && xcodegen`
> (uses `project.yml`).

## Using it in the field

**Calibrating your target (as you were taught):**
- *With an assistant:* stand side by side on level ground, hold the phone in your
  sighting posture, and note which feature of their face is at lens height (eyebrow, nose, chin).
- *Alone:* stand at the tree in your sighting posture and tie the ribbon at lens height.

Always hold the phone the same way, at the same height. The lens has replaced your eye.

**Zeroing the instrument** (do this once per phone, and redo it if a case changes the grip):
1. On level ground, with your assistant beside you, sight their calibrated mark from
   a few meters away. Or use the reciprocal check below.
2. Tap **ZERO → Set zero on current sight**.

*Reciprocal check (works on any slope):* read the grade A→B, then have your assistant
stand at A while you read B→A. The two readings should be equal and opposite. Half
their sum is the remaining zero error.

**Taking a reading:** put the hairline on the mark, wait for **STEADY**, and press a
volume button to HOLD. Press again to release.

**Validate against your physical clinometer** on a few shots before relying on it.

## How it works

| Piece | File |
|---|---|
| Gravity → elevation / roll / percent grade | `Clinometer/GradeMath.swift` |
| Motion sensors, smoothing, hold, zero | `Clinometer/InclinometerModel.swift` |
| Camera session and preview | `Clinometer/CameraController.swift` |
| Scale drum | `Clinometer/ScaleTapeView.swift` |
| Reticle | `Clinometer/ReticleView.swift` |
| Main screen | `Clinometer/ClinometerView.swift` |
| Colors and type | `Clinometer/Theme.swift` |

The key formula: Core Motion reports the gravity vector `g` in the phone's own
coordinates. The back camera looks along −z, so the line of sight's angle above the
horizon is `asin(g.z)`, computed as `atan2(g.z, √(g.x² + g.y²))`. That doesn't depend
on how the phone is rolled. Percent grade is `tan(angle) × 100`.

## Roadmap

1. **Target-grade mode.** Enter e.g. 8 %; the reticle turns green when the mark is on grade, so you can call "up/down" to an assistant.
2. **Station log.** Grade, GPS, flag number, and notes, exported to CSV/GPX.
3. **Guided calibration.** Step-by-step reciprocal zeroing.
4. **Distance.** LiDAR/ARKit range for rise and run.
5. **Optional face tracking.** Vision face landmarks to snap the reticle to an assistant's calibrated feature.
