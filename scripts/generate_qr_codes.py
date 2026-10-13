"""
Generates real, scannable QR codes for the initial library book set and a
printable sheet (title + book ID + QR image) to attach to the physical
books for the demo.

Usage:
    python scripts/generate_qr_codes.py

Reads book definitions from BOOKS below (matching the 5 seed records the
Admin also creates in Firestore's `books` collection - see
firebase/README.md for the seeding script). Each QR encodes exactly the
book ID string (e.g. "BOOK-001"), which is what the Librarian portal's
scanner looks up in Firestore - nothing fancier is encoded, and nothing
here is faked: every PNG produced actually decodes back to its book ID
(verified at the bottom of this script).
"""

from __future__ import annotations

import os

import qrcode
from PIL import Image, ImageDraw, ImageFont

OUTPUT_DIR = os.path.join(os.path.dirname(__file__), "..", "qr_codes")

BOOKS = [
    {"id": "BOOK-001", "title": "Introduction to Algorithms", "author": "Cormen, Leiserson, Rivest, Stein"},
    {"id": "BOOK-002", "title": "Computer Networking: A Top-Down Approach", "author": "Kurose & Ross"},
    {"id": "BOOK-003", "title": "Database System Concepts", "author": "Silberschatz, Korth, Sudarshan"},
    {"id": "BOOK-004", "title": "Artificial Intelligence: A Modern Approach", "author": "Russell & Norvig"},
    {"id": "BOOK-005", "title": "Software Engineering", "author": "Ian Sommerville"},
]


def _load_font(size: int) -> ImageFont.FreeTypeFont:
    for candidate in (
        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
        "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
    ):
        if os.path.exists(candidate):
            return ImageFont.truetype(candidate, size)
    return ImageFont.load_default()


def generate_single_qr(book_id: str, out_path: str) -> None:
    qr = qrcode.QRCode(version=1, error_correction=qrcode.constants.ERROR_CORRECT_M, box_size=10, border=4)
    qr.add_data(book_id)
    qr.make(fit=True)
    img = qr.make_image(fill_color="black", back_color="white").convert("RGB")
    img.save(out_path)


def generate_printable_sheet(books: list[dict], out_path: str) -> None:
    card_w, card_h = 420, 480
    cols, rows = 2, 3
    sheet = Image.new("RGB", (card_w * cols, card_h * rows), "white")
    draw = ImageDraw.Draw(sheet)
    title_font = _load_font(20)
    small_font = _load_font(15)

    for i, book in enumerate(books):
        row, col = divmod(i, cols)
        x0, y0 = col * card_w, row * card_h

        qr = qrcode.QRCode(version=1, error_correction=qrcode.constants.ERROR_CORRECT_M, box_size=8, border=2)
        qr.add_data(book["id"])
        qr.make(fit=True)
        qr_img = qr.make_image(fill_color="black", back_color="white").convert("RGB")
        qr_img = qr_img.resize((300, 300))
        sheet.paste(qr_img, (x0 + (card_w - 300) // 2, y0 + 20))

        draw.rectangle([x0 + 10, y0 + 10, x0 + card_w - 10, y0 + card_h - 10], outline="#1565C0", width=2)
        draw.text((x0 + card_w // 2, y0 + 335), book["id"], font=title_font, fill="#0D2B4E", anchor="mm")

        title = book["title"]
        if len(title) > 34:
            title = title[:31] + "..."
        draw.text((x0 + card_w // 2, y0 + 365), title, font=small_font, fill="#333333", anchor="mm")
        draw.text((x0 + card_w // 2, y0 + 390), book["author"], font=small_font, fill="#666666", anchor="mm")

    sheet.save(out_path)


def verify_qr_decodes_correctly(png_path: str, expected_id: str) -> bool:
    """Real verification, not an assumption: decode the PNG we just wrote
    and confirm it reads back the exact book ID."""
    try:
        import cv2
        import numpy as np

        img = cv2.imread(png_path)
        detector = cv2.QRCodeDetector()
        data, points, _ = detector.detectAndDecode(img)
        return data == expected_id
    except Exception as exc:
        print(f"  ! could not verify {png_path}: {exc}")
        return False


def main() -> None:
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    print(f"Generating QR codes into {os.path.abspath(OUTPUT_DIR)}")

    all_verified = True
    for book in BOOKS:
        out_path = os.path.join(OUTPUT_DIR, f"{book['id']}.png")
        generate_single_qr(book["id"], out_path)
        verified = verify_qr_decodes_correctly(out_path, book["id"])
        all_verified &= verified
        print(f"  {book['id']}.png  ->  decodes to '{book['id']}'  [{'OK' if verified else 'FAILED'}]")

    sheet_path = os.path.join(OUTPUT_DIR, "printable_sheet.png")
    generate_printable_sheet(BOOKS, sheet_path)
    print(f"  printable_sheet.png written ({len(BOOKS)} books, ready to print and cut out)")

    if not all_verified:
        raise SystemExit("One or more generated QR codes failed to verify - see output above.")
    print("All QR codes generated and verified successfully.")


if __name__ == "__main__":
    main()
