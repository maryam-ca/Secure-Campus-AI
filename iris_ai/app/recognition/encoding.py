"""
Iris feature encoding.

Applies a bank of 1-D Log-Gabor filters along each row of the normalized
iris image and phase-quantizes the response into a binary "iris code" -
this is the standard encoding scheme from Daugman's work (and the
well-known open-source Masek implementation). The binary code plus its
noise mask together form the iris "embedding" referenced elsewhere in
this project as `IrisTemplate`.

No neural-network weights are required for this stage, which matters in
this project: it means enrollment/matching is fully self-contained and
does not depend on downloading a proprietary pretrained model whose
license or availability we cannot guarantee (see docs/IRIS_MODEL.md for
the reasoning behind choosing a classical pipeline over a deep model).
"""

from __future__ import annotations

from dataclasses import dataclass

import numpy as np

# Log-Gabor filter parameters (standard values used in Masek's iris coder).
WAVELENGTH = 18.0
SIGMA_ON_F = 0.5


@dataclass
class IrisTemplate:
    code: np.ndarray   # bool array, shape (radial_res, angular_res * 2)
    mask: np.ndarray   # bool array, same shape - True = usable bit

    def to_bytes(self) -> tuple[bytes, bytes, tuple[int, int]]:
        return (
            np.packbits(self.code).tobytes(),
            np.packbits(self.mask).tobytes(),
            self.code.shape,
        )

    @staticmethod
    def from_bytes(code_bytes: bytes, mask_bytes: bytes, shape: tuple[int, int]) -> "IrisTemplate":
        n = shape[0] * shape[1]
        code = np.unpackbits(np.frombuffer(code_bytes, dtype=np.uint8))[:n].astype(bool).reshape(shape)
        mask = np.unpackbits(np.frombuffer(mask_bytes, dtype=np.uint8))[:n].astype(bool).reshape(shape)
        return IrisTemplate(code=code, mask=mask)


def _log_gabor_1d(n: int, wavelength: float, sigma_on_f: float) -> np.ndarray:
    """1-D Log-Gabor filter in the frequency domain, length n."""
    freqs = np.fft.fftfreq(n)
    freqs[0] = 1e-6  # avoid log(0) at DC
    f0 = 1.0 / wavelength
    filt = np.exp(-(np.log(np.abs(freqs) / f0)) ** 2 / (2 * np.log(sigma_on_f) ** 2))
    filt[0] = 0.0  # zero out DC component
    return filt


def encode_iris(normalized: np.ndarray, noise_mask: np.ndarray) -> IrisTemplate:
    """Row-wise 1-D Log-Gabor phase encoding.

    Each row of the normalized image is filtered; the complex response's
    phase is quantized into 2 bits (Gray-coded quadrant), doubling the
    column count of the output code relative to the input row length.
    """
    radial_res, angular_res = normalized.shape
    gabor = _log_gabor_1d(angular_res, WAVELENGTH, SIGMA_ON_F)

    code = np.zeros((radial_res, angular_res * 2), dtype=bool)
    mask = np.zeros((radial_res, angular_res * 2), dtype=bool)

    for r in range(radial_res):
        row = normalized[r, :].astype(np.float64)
        row = row - row.mean()
        spectrum = np.fft.fft(row)
        filtered = np.fft.ifft(spectrum * gabor)

        real = filtered.real
        imag = filtered.imag

        # Gray-coded 2-bit phase quadrant quantization (standard Daugman
        # encoding): bit0 = sign(real), bit1 = sign(imag).
        bit0 = real >= 0
        bit1 = imag >= 0

        code[r, 0::2] = bit0
        code[r, 1::2] = bit1

        row_valid = noise_mask[r, :] == 0
        mask[r, 0::2] = row_valid
        mask[r, 1::2] = row_valid

    return IrisTemplate(code=code, mask=mask)
