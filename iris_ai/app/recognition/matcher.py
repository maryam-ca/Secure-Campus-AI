"""
Iris template matching.

Compares two iris codes with the fractional Hamming distance, excluding
bits that either template's noise mask marks as unusable, and searching
a small range of angular (column) shifts to tolerate head/eye rotation
between enrollment and a later capture. This mirrors Daugman's published
matching approach.

Distance is in [0.0, 0.5]: 0.0 = identical codes, ~0.5 = statistically
independent (i.e. different eyes / uncorrelated noise). A threshold
(IRIS_MATCH_THRESHOLD, configurable via environment) decides MATCH vs
NO MATCH. There is no "confidence" number invented beyond this distance
- the recognition score reported to the app is derived directly from it.
"""

from __future__ import annotations

from dataclasses import dataclass

import numpy as np

from app.recognition.encoding import IrisTemplate

MAX_SHIFT = 8  # columns (each column-pair = one angular sample of the code)


def _hamming_distance(a: IrisTemplate, b: IrisTemplate, shift: int) -> float | None:
    b_code = np.roll(b.code, shift, axis=1)
    b_mask = np.roll(b.mask, shift, axis=1)

    valid = a.mask & b_mask
    n_valid = int(valid.sum())
    if n_valid < 0.15 * a.mask.size:
        # Too few comparable bits (heavy occlusion on both sides) - the
        # comparison is not reliable enough to trust.
        return None

    disagreements = int(np.count_nonzero(a.code[valid] != b_code[valid]))
    return disagreements / n_valid


@dataclass
class MatchResult:
    distance: float | None  # None if comparison was not reliable
    is_match: bool
    score: float  # 0..1, higher = more similar; derived from distance


def compare_templates(a: IrisTemplate, b: IrisTemplate, threshold: float) -> MatchResult:
    if a.code.shape != b.code.shape:
        return MatchResult(distance=None, is_match=False, score=0.0)

    best_distance: float | None = None
    for shift in range(-MAX_SHIFT, MAX_SHIFT + 1):
        d = _hamming_distance(a, b, shift * 2)  # step by code-pair (angular sample)
        if d is not None and (best_distance is None or d < best_distance):
            best_distance = d

    if best_distance is None:
        return MatchResult(distance=None, is_match=False, score=0.0)

    score = max(0.0, 1.0 - best_distance / 0.5)  # 0.5 -> score 0, 0.0 -> score 1
    return MatchResult(distance=best_distance, is_match=best_distance <= threshold, score=score)
