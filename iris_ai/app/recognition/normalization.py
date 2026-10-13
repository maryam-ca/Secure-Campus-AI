"""
Iris normalization (Daugman's rubber-sheet model).

Unwraps the annular iris region (between the pupil boundary and the
outer iris boundary) into a fixed-size rectangular image, so that two
iris images captured at different pupil dilation / distance / rotation
can be compared like-for-like. This is the standard second stage of a
classical iris-recognition pipeline.

For each (radius, angle) sample in the fixed-size output grid, we map
back to Cartesian coordinates on the line between the pupil boundary and
the iris boundary at that angle, and bilinearly sample the source image.
"""

from __future__ import annotations

import cv2
import numpy as np

from app.recognition.segmentation import Circle

# Output size of the normalized ("unrolled") iris image.
RADIAL_RESOLUTION = 64   # rows
ANGULAR_RESOLUTION = 512  # columns


def normalize_iris(
    gray: np.ndarray,
    pupil: Circle,
    iris: Circle,
    radial_res: int = RADIAL_RESOLUTION,
    angular_res: int = ANGULAR_RESOLUTION,
) -> tuple[np.ndarray, np.ndarray]:
    """Returns (normalized_image, noise_mask) both shaped (radial_res, angular_res).

    noise_mask is 1 where the sample fell outside the source image bounds
    (i.e. no real pixel data - must be excluded from matching) and, as a
    simplified eyelid/eyelash occlusion heuristic, in the top and bottom
    angular bands where eyelids most commonly intrude. This is a
    documented simplification (see docs/IRIS_MODEL.md); a production
    system would run dedicated eyelid/eyelash detectors.
    """
    h, w = gray.shape
    thetas = np.linspace(0, 2 * np.pi, angular_res, endpoint=False)
    radii = np.linspace(0.0, 1.0, radial_res, endpoint=False)

    normalized = np.zeros((radial_res, angular_res), dtype=np.float32)
    noise_mask = np.zeros((radial_res, angular_res), dtype=np.uint8)

    cos_t = np.cos(thetas)
    sin_t = np.sin(thetas)

    # Precompute inner (pupil) and outer (iris) boundary points per angle.
    inner_x = pupil.cx + pupil.r * cos_t
    inner_y = pupil.cy + pupil.r * sin_t
    outer_x = iris.cx + iris.r * cos_t
    outer_y = iris.cy + iris.r * sin_t

    for ri, r_frac in enumerate(radii):
        xs = inner_x + r_frac * (outer_x - inner_x)
        ys = inner_y + r_frac * (outer_y - inner_y)

        valid = (xs >= 0) & (xs <= w - 1) & (ys >= 0) & (ys <= h - 1)
        noise_mask[ri, ~valid] = 1

        xs_c = np.clip(xs, 0, w - 1)
        ys_c = np.clip(ys, 0, h - 1)

        # Bilinear sample
        x0 = np.floor(xs_c).astype(int)
        y0 = np.floor(ys_c).astype(int)
        x1 = np.clip(x0 + 1, 0, w - 1)
        y1 = np.clip(y0 + 1, 0, h - 1)
        dx = xs_c - x0
        dy = ys_c - y0

        v00 = gray[y0, x0].astype(np.float32)
        v01 = gray[y0, x1].astype(np.float32)
        v10 = gray[y1, x0].astype(np.float32)
        v11 = gray[y1, x1].astype(np.float32)

        top = v00 * (1 - dx) + v01 * dx
        bot = v10 * (1 - dx) + v11 * dx
        normalized[ri, :] = top * (1 - dy) + bot * dy

    # Heuristic eyelid/eyelash occlusion bands: the top ~12% and bottom
    # ~12% of angular columns (i.e. near theta=90deg / 270deg, "up" and
    # "down" from the eye centre) are most commonly occluded by eyelids.
    band = int(angular_res * 0.12)
    up_centre = angular_res // 4          # theta ~ 90deg
    down_centre = (3 * angular_res) // 4  # theta ~ 270deg
    for centre in (up_centre, down_centre):
        lo = max(0, centre - band // 2)
        hi = min(angular_res, centre + band // 2)
        noise_mask[:, lo:hi] = 1

    normalized = cv2.equalizeHist(normalized.astype(np.uint8)).astype(np.float32)
    return normalized, noise_mask
