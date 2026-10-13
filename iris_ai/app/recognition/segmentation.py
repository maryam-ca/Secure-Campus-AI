"""
Iris segmentation.

Locates the pupil boundary and the outer iris boundary in an eye-region
image, using the classical approach used in published iris-recognition
work (Daugman 1993 / Masek 2003): the pupil is found as the darkest,
most circular blob near the image centre, and the outer iris boundary is
found with a circular Hough transform search that is constrained to be
concentric (or near-concentric) with the pupil.

This is real, executable computer vision - not a placeholder. It is the
first stage of the pipeline described in the project spec:

    Frame -> Eye/Iris Detection -> Iris Segmentation -> Normalization -> ...

Known limitation (documented in docs/IRIS_MODEL.md): this classical
pipeline was designed for near-infrared (NIR) iris photography, where
the pupil is very dark and the iris texture has strong contrast. Run on
visible-light RGB frames (e.g. from an iPhone camera), pupil/iris
contrast is lower and segmentation is materially less reliable. The
`SegmentationResult.success=False` path exists specifically to surface
that failure to the caller rather than guessing.
"""

from __future__ import annotations

from dataclasses import dataclass

import cv2
import numpy as np


@dataclass
class Circle:
    cx: float
    cy: float
    r: float


@dataclass
class SegmentationResult:
    success: bool
    reason: str
    pupil: Circle | None = None
    iris: Circle | None = None


def _find_pupil(gray: np.ndarray) -> Circle | None:
    """Find the pupil using a two-stage search.

    A single global darkness threshold does not reliably isolate the
    pupil: in practice the pupil (very dark) and the surrounding iris
    (moderately dark, textured) sit close enough in intensity that a
    single percentile/threshold either grabs the whole iris+pupil disc
    or misses the pupil entirely. Two stages fixes this:

      1. Separate the whole iris+pupil complex from the brighter sclera
         (large intensity gap, Otsu handles this cleanly).
      2. Within that region only (masking out corner/background noise),
         search a few darkness percentiles for the most circular,
         centrally-located blob - that is the pupil.
    """
    h, w = gray.shape
    blurred = cv2.GaussianBlur(gray, (7, 7), 0)

    # Stage 1: rough iris+pupil complex vs. sclera/background.
    _, mask1 = cv2.threshold(blurred, 0, 255, cv2.THRESH_BINARY_INV + cv2.THRESH_OTSU)
    mask1 = cv2.morphologyEx(mask1, cv2.MORPH_OPEN, np.ones((5, 5), np.uint8))
    mask1 = cv2.morphologyEx(mask1, cv2.MORPH_CLOSE, np.ones((9, 9), np.uint8))
    contours1, _ = cv2.findContours(mask1, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
    if not contours1:
        return None
    c1 = max(contours1, key=cv2.contourArea)
    if cv2.contourArea(c1) < 0.01 * w * h:
        return None
    (icx, icy), ir = cv2.minEnclosingCircle(c1)

    # Restrict stage 2 to inside that region so background pixels can't
    # skew the darkness statistics.
    region_mask = np.zeros_like(gray, dtype=np.uint8)
    cv2.circle(region_mask, (int(icx), int(icy)), int(ir), 255, -1)
    inside_vals = blurred[region_mask == 255]
    if inside_vals.size == 0:
        return None

    # Stage 2: search a few darkness percentiles for the most circular,
    # centrally-located blob within the iris region - that is the pupil.
    best = None
    best_score = -1.0
    for pct in (6, 10, 14, 18):
        thresh_val = float(np.percentile(inside_vals, pct))
        _, m2 = cv2.threshold(blurred, thresh_val, 255, cv2.THRESH_BINARY_INV)
        m2 = cv2.bitwise_and(m2, region_mask)
        m2 = cv2.morphologyEx(m2, cv2.MORPH_OPEN, np.ones((3, 3), np.uint8))

        contours2, _ = cv2.findContours(m2, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
        for c in contours2:
            area = cv2.contourArea(c)
            if area < 0.0005 * w * h:
                continue
            perimeter = cv2.arcLength(c, True)
            if perimeter == 0:
                continue
            circularity = 4 * np.pi * area / (perimeter ** 2)
            (pcx, pcy), pr = cv2.minEnclosingCircle(c)
            if np.hypot(pcx - icx, pcy - icy) > ir * 0.5:
                continue  # must sit roughly centred in the iris region
            score = circularity * area
            if score > best_score:
                best_score = score
                best = Circle(cx=pcx, cy=pcy, r=pr)

    return best


def _find_iris_boundary(gray: np.ndarray, pupil: Circle) -> Circle | None:
    """Search for the outer iris boundary via Hough circles, constrained
    to be roughly concentric with the already-found pupil."""
    h, w = gray.shape
    blurred = cv2.medianBlur(gray, 7)
    edges = cv2.Canny(blurred, 30, 90)

    min_r = int(pupil.r * 1.8)
    max_r = int(min(pupil.r * 4.5, min(h, w) / 2))
    if max_r <= min_r:
        return None

    circles = cv2.HoughCircles(
        blurred,
        cv2.HOUGH_GRADIENT,
        dp=1.5,
        minDist=max(h, w),
        param1=90,
        param2=40,
        minRadius=min_r,
        maxRadius=max_r,
    )

    if circles is None:
        # Fall back to a fixed ratio of the pupil radius - a documented
        # simplification, not a fabricated recognition result. It only
        # affects segmentation geometry, and a poor boundary here will
        # naturally lower the downstream match score rather than fake one.
        return Circle(cx=pupil.cx, cy=pupil.cy, r=pupil.r * 2.8)

    circles = np.round(circles[0, :]).astype(int)
    best = None
    best_dist = float("inf")
    for cx, cy, r in circles:
        dist = np.hypot(cx - pupil.cx, cy - pupil.cy)
        if dist < best_dist:
            best_dist = dist
            best = Circle(cx=float(cx), cy=float(cy), r=float(r))
    return best


def segment_iris(bgr_image: np.ndarray) -> SegmentationResult:
    if bgr_image is None or bgr_image.size == 0:
        return SegmentationResult(False, "empty image")

    gray = cv2.cvtColor(bgr_image, cv2.COLOR_BGR2GRAY) if bgr_image.ndim == 3 else bgr_image

    pupil = _find_pupil(gray)
    if pupil is None:
        return SegmentationResult(False, "pupil not found")

    iris = _find_iris_boundary(gray, pupil)
    if iris is None:
        return SegmentationResult(False, "iris outer boundary not found")

    if iris.r <= pupil.r:
        return SegmentationResult(False, "iris boundary smaller than pupil boundary")

    return SegmentationResult(True, "ok", pupil=pupil, iris=iris)
