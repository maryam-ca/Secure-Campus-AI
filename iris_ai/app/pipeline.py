"""
End-to-end pipeline orchestration, matching the flow specified in the
project brief:

    Frame -> Eye/Iris Detection -> Segmentation -> Normalization ->
    Feature Extraction -> Embedding -> Similarity Matching ->
    Threshold -> Known Student OR Unknown Person

`process_image` performs the first half (frame -> embedding) and is used
both for enrollment (store the resulting embedding) and for recognition
(compare the resulting embedding against enrolled embeddings).
"""

from __future__ import annotations

from dataclasses import dataclass

import cv2
import numpy as np

from app.config import settings
from app.recognition.encoding import IrisTemplate, encode_iris
from app.recognition.matcher import MatchResult, compare_templates
from app.recognition.normalization import normalize_iris
from app.recognition.segmentation import segment_iris


@dataclass
class PipelineResult:
    success: bool
    reason: str
    template: IrisTemplate | None = None


def process_image(bgr_image: np.ndarray) -> PipelineResult:
    """Run segmentation -> normalization -> encoding on a raw eye-region frame."""
    seg = segment_iris(bgr_image)
    if not seg.success:
        return PipelineResult(False, f"segmentation failed: {seg.reason}")

    gray = cv2.cvtColor(bgr_image, cv2.COLOR_BGR2GRAY) if bgr_image.ndim == 3 else bgr_image
    normalized, noise_mask = normalize_iris(gray, seg.pupil, seg.iris)
    template = encode_iris(normalized, noise_mask)
    return PipelineResult(True, "ok", template=template)


@dataclass
class RecognitionOutcome:
    matched_id: str | None
    best_score: float
    best_distance: float | None
    is_known: bool
    reason: str


def recognize_against_enrolled(
    probe: IrisTemplate,
    enrolled: dict[str, IrisTemplate],
    threshold: float | None = None,
) -> RecognitionOutcome:
    """Compare a freshly-captured template against every enrolled template
    and return the best match, applying the configured threshold.

    `enrolled` maps student_id -> IrisTemplate (already loaded from
    Firestore by the caller - this function has no knowledge of Firebase
    so it stays independently testable).
    """
    threshold = settings.IRIS_MATCH_THRESHOLD if threshold is None else threshold

    if not enrolled:
        return RecognitionOutcome(None, 0.0, None, False, "no enrolled students")

    best_id: str | None = None
    best: MatchResult | None = None
    for student_id, template in enrolled.items():
        result = compare_templates(probe, template, threshold)
        if result.distance is None:
            continue
        if best is None or result.distance < best.distance:  # type: ignore[operator]
            best = result
            best_id = student_id

    if best is None:
        return RecognitionOutcome(None, 0.0, None, False, "no reliable comparison possible")

    if best.is_match:
        return RecognitionOutcome(best_id, best.score, best.distance, True, "match above threshold")

    return RecognitionOutcome(None, best.score, best.distance, False, "best candidate below threshold")
