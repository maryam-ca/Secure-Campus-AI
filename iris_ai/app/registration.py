"""Registration numbers carry the program: FA23-BSE-011 is a BSE student, so a
student whose Program is BSE must not get FA23-BSI-011. This is checked here as
well as in the app, because this service is the one that really creates the
account."""

from __future__ import annotations

import re

# session + year, program letters, serial: FA23-BSE-011, FA23BSE011, fa23 bse 011
_REG = re.compile(r"^[A-Za-z]{2,4}\d{2}[-\s]?([A-Za-z]+)[-\s]?\d+$")


def _clean(value: str) -> str:
    return re.sub(r"[^A-Z0-9]", "", value.upper())


def program_in_registration_number(reg_no: str) -> str | None:
    """The program letters inside the number ("BSE"), or None if the number is
    not in that format (other formats are accepted unchecked)."""
    match = _REG.match(reg_no.strip())
    return match.group(1).upper() if match else None


def program_mismatch(reg_no: str, program: str) -> str | None:
    """A sentence if the registration number names a different program than the
    one given, otherwise None."""
    in_number = program_in_registration_number(reg_no)
    if in_number is None or not program.strip():
        return None
    if in_number == _clean(program):
        return None
    return (
        f"Registration number {reg_no.strip()} is for program {in_number}, but the program is "
        f"{program.strip().upper()}. The program in the registration number and the Program field must be the same."
    )
