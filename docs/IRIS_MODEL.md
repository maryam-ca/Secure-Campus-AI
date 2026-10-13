# Iris Recognition Model — Documentation

This document explains, as required by the project spec (sections 11 and
55), exactly what recognition approach SecureCampus uses, why, its
inputs, preprocessing, matching, thresholding, and — most importantly —
its limitations.

## 1. What was selected, and why

**Classical algorithmic pipeline (Daugman / Masek method)**, implemented
from scratch in `iris_ai/app/recognition/` using OpenCV, NumPy, and
FFT-based Log-Gabor filtering. No pretrained neural network weights are
used or required.

This was a deliberate choice, not a shortcut:

- It is a **real, published, peer-reviewed approach** (J. Daugman, "High
  Confidence Visual Recognition of Persons by a Test of Statistical
  Independence", 1993; the specific coding scheme mirrors L. Masek's
  widely-cited 2003 open-source implementation), not an invented
  algorithm.
- It requires **no external model weights**, so there is nothing to
  license, nothing that could silently be unavailable at demo time, and
  nothing whose provenance can't be fully explained. A deep-learning
  iris-embedding model would need pretrained weights, and the sandboxed
  build environment used for this project cannot reach model
  repositories such as Hugging Face or PyTorch Hub (only a specific
  allow-listed set of package registries is reachable) — so committing
  to a "pretrained deep model" would either have been unbuildable here
  or would have required silently faking the download, which the spec
  explicitly forbids. The architecture (see §7) leaves room to swap in a
  deep embedding model later if you have separate access to weights.
- It is fully **explainable stage-by-stage**, which matters for a
  defensible FYP viva: every stage below is inspectable code, not a
  black box.

## 2. Pipeline stages

```
Frame → Eye/Pupil localization → Iris outer-boundary detection (segmentation)
      → Rubber-sheet normalization → Log-Gabor phase encoding (embedding)
      → Hamming-distance matching → Threshold → Known Student / Unknown Person
```

| Stage | File | What it does |
|---|---|---|
| Segmentation | `recognition/segmentation.py` | Two-stage circle search: (1) Otsu threshold separates the whole iris+pupil complex from the brighter sclera; (2) within that region, a percentile sweep finds the most circular, centrally-located dark blob — the pupil. The outer iris boundary is then found with a Hough circle search constrained to be concentric with the pupil. |
| Normalization | `recognition/normalization.py` | Daugman's rubber-sheet model: the annular region between the pupil and iris circles is unwrapped into a fixed 64×512 rectangular image, so images with different pupil dilation/distance/rotation become comparable. A simplified eyelid-occlusion mask blanks the top/bottom angular bands. |
| Encoding (embedding) | `recognition/encoding.py` | A 1-D Log-Gabor filter is applied to each row; the complex response's phase is quantized into a 2-bit Gray code per sample. The result — a binary "iris code" plus a validity mask — **is** the embedding. |
| Matching | `recognition/matcher.py` | Fractional Hamming distance between two iris codes, restricted to bits both masks agree are valid, searched over a small range of angular (rotation) shifts and minimized. Distance ∈ [0, 0.5]; 0 = identical, ~0.5 = statistically unrelated. |
| Threshold | `IRIS_MATCH_THRESHOLD` (config) | Distance ≤ threshold → match (known student); otherwise → unknown person. |

## 3. Input requirements

- A BGR image (any resolution) containing a visible eye, roughly
  forward-facing, with the pupil and iris not fully occluded by
  eyelashes/eyelids/glasses glare.
- No specific camera hardware is assumed by the code — the pipeline
  works on whatever `cv2.imdecode` can produce. What *does* vary
  dramatically is **image quality**, discussed in §5.

## 4. Enrollment and matching, concretely

- **Enroll**: `POST /iris/enroll` with a `student_id` and an eye image →
  pipeline runs → resulting code+mask are stored in Firestore
  `irisProfiles/{studentId}` (never exposed to any client, see
  `firebase/firestore.rules`).
- **Recognize**: a captured frame is run through the same pipeline, then
  compared against every enrolled template (`recognize_against_enrolled`
  in `app/pipeline.py`), and the best match is checked against the
  threshold.

## 5. Critical limitation: RGB (iPhone) vs. near-infrared (NIR) capture

**This is the single most important caveat in this document, and it is
called out explicitly in the project spec (§14) as something that must
not be glossed over.**

Iris recognition, as a biometric field, is built around **near-infrared
(700–900nm) imaging**. Under NIR light:

- Melanin pigment in the iris, which makes many irises look almost
  uniformly dark-brown under visible light, becomes far more
  transparent — the fine radial texture (crypts, furrows, collarette)
  that the recognition pipeline actually keys on becomes clearly
  visible even in dark eyes.
- The pupil becomes very strongly separated from the iris in intensity
  (pupils appear extremely dark under NIR), which is exactly what the
  classical segmentation stage assumes.
- NIR illumination avoids most corneal specular reflections that visible
  light and camera flashes cause, which otherwise punch bright
  artifacts straight through the texture the algorithm is trying to
  read.

**The iPhone 13's rear/front camera is an RGB (visible-light) sensor,
not an NIR sensor.** Running the exact same, real, non-fake algorithmic
pipeline on RGB frames instead of NIR frames means:

- Segmentation is noticeably less reliable on dark irises, where
  pupil/iris contrast in visible light can be very low (this project's
  own synthetic-image test suite in `iris_ai/tests/test_pipeline.py`
  needed a two-stage segmentation fix during development specifically
  because a naive single-threshold approach — the kind that works fine
  on high-contrast NIR images — failed to separate pupil from iris on
  lower-contrast input; see the git history / commit notes for that
  fix).
- Texture detail available to the Log-Gabor encoder is reduced,
  especially for medium-to-dark brown irises, which increases the
  overlap between "different person" and "same person" distance
  distributions.
- Expect a **materially higher False Rejection Rate (FRR) and False
  Acceptance Rate (FAR)** than published NIR iris-recognition numbers
  (which are typically quoted as EER well under 1% on datasets like
  CASIA-IrisV4, which are all NIR).

**We do not compensate for this by inventing numbers or by quietly
loosening the algorithm.** Instead:

- The pipeline is architected so `CAMERA_RTSP_URL` can point at a real
  NIR iris/eye camera in the future with **no code changes** beyond
  potentially retuning `IRIS_MATCH_THRESHOLD` — segmentation,
  normalization, encoding, and matching are all camera-agnostic.
- Section 6 below documents evaluation status honestly, including the
  fact that FAR/FRR **has not yet been measured on real captured
  images** (only on synthetic test images, which validate that the code
  is mechanically correct, not that it is biometrically accurate — see
  the docstring at the top of `iris_ai/tests/test_pipeline.py`).
- For the practical demo, expect to need: good, even lighting; the
  subject looking directly at the camera at close range; and possibly
  a higher `IRIS_MATCH_THRESHOLD` than NIR literature would suggest, to
  be tuned empirically once real enrollment images exist.

If, during your evaluation period, RGB recognition proves too unreliable
for a convincing live demo, the documented, honest fallback options are:

1. Reduce IRIS_MATCH_THRESHOLD tuning against your actual 10 enrolled
   students' real images (this is legitimate calibration, not faking).
2. Constrain capture conditions tightly (fixed distance, fixed
   lighting, direct gaze) to raise consistency.
3. Note in your FYP report/demo, explicitly and matter-of-factly, that
   the system implements a real iris-recognition pipeline validated on
   RGB input with these characteristics, and that a dedicated NIR
   sensor is the documented upgrade path for production accuracy — this
   is a legitimate, defensible, and common thing for a student project
   to state; it is not a weakness to hide.

## 6. Evaluation status (spec §55 — do not invent numbers)

| Metric | Status |
|---|---|
| Recognition accuracy on real students | **Not yet evaluated.** Requires real enrollment images from the 10 test students. |
| False Acceptance Rate (FAR) | **Not yet evaluated.** |
| False Rejection Rate (FRR) | **Not yet evaluated.** |
| Recognition time | Measured on synthetic 400×400 test images on this dev machine: ~40–60ms per image for the full segment→normalize→encode pipeline (excludes network/Firestore round-trip). Real captured-image timing has not yet been measured. |
| Similarity threshold | `IRIS_MATCH_THRESHOLD = 0.32` (config default) — a standard starting point from the iris-recognition literature, **not yet calibrated against your real enrolled students.** Plan to run a small calibration pass (several genuine + several impostor comparisons among your 10 students) before the live demo and adjust. |
| Known-person recognition (synthetic) | Validated mechanically: identical synthetic "iris" images match at distance < 0.05; see `tests/test_pipeline.py::test_same_identity_matches_itself`. |
| Unknown-person rejection (synthetic) | Validated mechanically: distinct synthetic "iris" textures reject at distance > 0.32; see `tests/test_pipeline.py::test_different_identities_do_not_match`. |

Once real images exist, extend `tests/` with an evaluation script that
computes FAR/FRR across all genuine and impostor pairs among your 10
students and fill in this table with real numbers for your report —
do not report the synthetic-test numbers above as if they were
biometric accuracy figures.

## 7. Future upgrade path (documented, not built, since no NIR hardware is available)

To swap in a real NIR iris camera later:

1. Point `CAMERA_RTSP_URL` (or a direct capture-device path) at the NIR
   source instead of the iPhone RTSP stream — no other camera-layer
   code changes.
2. Re-run threshold calibration (§6) — NIR images typically permit a
   *tighter* threshold (lower FAR at the same FRR) than RGB.
3. Optionally replace `recognition/encoding.py`'s Log-Gabor encoder with
   a deep embedding model (e.g. a CNN trained on an NIR iris dataset) if
   you obtain the weights separately — `pipeline.py`'s
   `IrisTemplate`/`compare_templates` interfaces don't need to change,
   only what produces the code/mask arrays.

## 8. Licensing

- OpenCV (Apache 2.0), NumPy (BSD), SciPy (BSD), FastAPI (MIT) — all
  permissive open-source, no attribution burden beyond standard license
  inclusion.
- No third-party pretrained model weights are bundled or downloaded, so
  there is no model-license question to resolve for this pipeline.
