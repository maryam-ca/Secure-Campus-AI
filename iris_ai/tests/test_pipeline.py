"""
These tests validate that the segmentation -> normalization -> encoding
-> matching pipeline is mechanically correct: it runs end-to-end, the
same iris produces (near-)identical codes, and different synthetic
"iris textures" produce codes far apart.

IMPORTANT: this uses procedurally generated synthetic eye images, not
real iris photographs. It proves the code works and matches what it's
supposed to match - it is NOT a biometric accuracy measurement. Real
accuracy (FAR/FRR) must be measured against real captured iris images
per docs/IRIS_MODEL.md, and is documented there as "not yet evaluated"
until that data collection happens.
"""

from __future__ import annotations

import numpy as np
import cv2

from app.pipeline import process_image, recognize_against_enrolled
from app.recognition.matcher import compare_templates


def make_synthetic_eye(seed: int, rotation_deg: float = 0.0, size: int = 400) -> np.ndarray:
    """Draws a synthetic eye: pale sclera, a textured iris ring (unique
    per seed), and a dark pupil - enough structure for the segmentation
    and encoding stages to have something real to operate on."""
    rng = np.random.default_rng(seed)
    img = np.full((size, size, 3), 235, dtype=np.uint8)  # sclera background

    cx, cy = size // 2, size // 2
    iris_r = size // 3
    pupil_r = iris_r // 3

    # Iris base color/ring
    cv2.circle(img, (cx, cy), iris_r, (110, 90, 60), -1, lineType=cv2.LINE_AA)

    # Radial texture unique to this "identity" (seed), drawn as streaks -
    # analogous in spirit to real iris crypts/furrows, not a claim of
    # biological realism.
    for _ in range(220):
        theta = rng.uniform(0, 2 * np.pi) + np.deg2rad(rotation_deg)
        r0 = rng.uniform(pupil_r * 1.1, iris_r * 0.98)
        r1 = r0 + rng.uniform(3, 14)
        x0 = int(cx + r0 * np.cos(theta))
        y0 = int(cy + r0 * np.sin(theta))
        x1 = int(cx + r1 * np.cos(theta))
        y1 = int(cy + r1 * np.sin(theta))
        shade = int(rng.uniform(40, 200))
        cv2.line(img, (x0, y0), (x1, y1), (shade, shade, shade), 1, lineType=cv2.LINE_AA)

    # Pupil
    cv2.circle(img, (cx, cy), pupil_r, (10, 10, 10), -1, lineType=cv2.LINE_AA)

    # Mild blur to avoid unrealistic hard edges dominating the encoder
    img = cv2.GaussianBlur(img, (3, 3), 0)
    return img


def test_segmentation_and_encoding_runs_end_to_end():
    eye = make_synthetic_eye(seed=1)
    result = process_image(eye)
    assert result.success, result.reason
    assert result.template is not None
    assert result.template.code.shape == result.template.mask.shape
    assert result.template.mask.any()  # at least some usable bits


def test_same_identity_matches_itself():
    eye = make_synthetic_eye(seed=42)
    r1 = process_image(eye)
    r2 = process_image(eye)
    assert r1.success and r2.success

    match = compare_templates(r1.template, r2.template, threshold=0.32)
    assert match.distance is not None
    assert match.distance < 0.05, f"identical image should match near-perfectly, got distance={match.distance}"
    assert match.is_match


def test_different_identities_do_not_match():
    eye_a = process_image(make_synthetic_eye(seed=7))
    eye_b = process_image(make_synthetic_eye(seed=999))
    assert eye_a.success and eye_b.success

    match = compare_templates(eye_a.template, eye_b.template, threshold=0.32)
    assert match.distance is not None
    assert match.distance > 0.32, f"different textures should not match, got distance={match.distance}"
    assert not match.is_match


def test_rotation_tolerance_within_search_range():
    base = process_image(make_synthetic_eye(seed=15, rotation_deg=0))
    rotated = process_image(make_synthetic_eye(seed=15, rotation_deg=3))
    assert base.success and rotated.success

    match = compare_templates(base.template, rotated.template, threshold=0.32)
    assert match.distance is not None
    # Small rotations should still be recognized thanks to the shift search.
    assert match.is_match, f"expected small-rotation match, got distance={match.distance}"


def test_recognize_against_enrolled_returns_unknown_for_novel_eye():
    enrolled_eye = process_image(make_synthetic_eye(seed=101))
    stranger_eye = process_image(make_synthetic_eye(seed=555))
    assert enrolled_eye.success and stranger_eye.success

    enrolled_db = {"FA23-BSE-001": enrolled_eye.template}
    outcome = recognize_against_enrolled(stranger_eye.template, enrolled_db, threshold=0.32)

    assert outcome.is_known is False
    assert outcome.matched_id is None


def test_recognize_against_enrolled_matches_correct_student():
    student_eye = process_image(make_synthetic_eye(seed=202))
    other_eye = process_image(make_synthetic_eye(seed=303))
    probe = process_image(make_synthetic_eye(seed=202))  # same identity, fresh "capture"
    assert student_eye.success and other_eye.success and probe.success

    enrolled_db = {
        "FA23-BSE-001": other_eye.template,
        "FA23-BSE-002": student_eye.template,
    }
    outcome = recognize_against_enrolled(probe.template, enrolled_db, threshold=0.32)

    assert outcome.is_known is True
    assert outcome.matched_id == "FA23-BSE-002"


def test_segmentation_fails_gracefully_on_blank_image():
    blank = np.full((300, 300, 3), 200, dtype=np.uint8)  # no pupil/iris structure at all
    result = process_image(blank)
    assert result.success is False
    assert result.template is None
    assert "segmentation failed" in result.reason
