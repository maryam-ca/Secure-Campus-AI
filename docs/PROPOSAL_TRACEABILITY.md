# Proposal → Code Traceability

Compares the **supervisor-approved proposal** (SecureCampus_Final.pdf, supervisor Dr. Yaser Ali Shah) with the code as of 2026-10-13. The proposal is the contract: anything in it that is missing is a gap, anything built that is not in it is a deviation to explain in the report.

Legend: ✅ done in code · 🟡 partly · ❌ missing · ❓ unverified on real hardware/accounts (code exists but never demonstrated)

## 4.1 Attendance & Gate Entry
| Requirement | Status | Notes |
|---|---|---|
| Mobile camera captures images | ❓ | RTSP from iPhone coded, never tested live |
| Iris features + Hamming distance, no pretrained model | ✅ / ❓ | Pipeline matches the proposal exactly; accuracy unmeasured (I-15) |
| Verified → entry + "Present" | ✅ | gate entry and attendance records |
| Unmatched → not marked present, access denied, **security alert** | ✅ | `create_unknown_alert` |
| **Only students verified at the gate can be marked present in class** | ❌ | `record_attendance` never checks `gateEntries` (I-22) |
| Hough circle segmentation / Daugman / Log-Gabor | ✅ | |
| "YOLO-based model for detecting multiple students' eyes" (§8 tools) | ❌ | Not used. Either add eye detection or remove from report (I-29) |

## 4.2 QR Library
| Requirement | Status | Notes |
|---|---|---|
| Scan book QR → details; enter student ID; issue date auto; return date manual | ✅ | `librarian_scan_screen.dart` |
| Record shown on student portal; status | ✅ | |
| **Student can "Report unauthorized issue" → alerts librarian + security** | ❌ | No such feature anywhere in the app (I-23) |
| **Notification when return date is near** | 🟡 | Only an *overdue* notice is sent, not a "due soon" one (I-24) |
| Return management | ✅ | verify on device |

## 4.3 Bus
| Requirement | Status | Notes |
|---|---|---|
| Driver shares live GPS | ✅ / ❓ | |
| Compare with stops; "arrives in 10 min" notification, once per trip | ✅ / ❓ | |
| Admin assigns bus to students | ✅ | |
| **Students with assigned bus can access bus tracking** | 🟡 | Student sees assignment only; the live map is admin-only by design. Proposal wording needs a decision (I-25) |

## 4.4 Security & Monitoring
| Requirement | Status | Notes |
|---|---|---|
| RBAC | ✅ | router + Firestore + RTDB rules |
| **Activity logs for attendance, library, bus** | ❌ | No log collection or screen (I-26) |
| Alerts for suspicious activity; security dashboard | ✅ | unknown-person only |
| "Reports" (admin dashboard, report generation) | ❌ | No reports/export screen (I-27) |

## 4.5 Card Recovery
| Requirement | Status | Notes |
|---|---|---|
| Any user captures card image + submits report form | 🟡 | `found_card_report_screen.dart` exists; confirm image upload works |
| **System extracts name + reg. number from the image (OCR)** | ❌ | No OCR; methodology page says "report form + registration-number verification", so manual entry may be acceptable — confirm with supervisor (I-28) |
| Match with DB; student notified; admin tracks reports | ✅ / ❓ | |

## 4.6 / 4.7 Dashboards
| Requirement | Status | Notes |
|---|---|---|
| Student: **Campus Entry Status (ENTERED / NOT ENTERED + last entry)** | ❌ | Not on the student dashboard (I-30). Note: earlier spec forbade students seeing gate history; a single derived status field is compatible with that |
| Student: course-wise attendance (total, attended, %) | ✅ | |
| Student: bus info, library info | ✅ | |
| Security dashboard with real-time alerts | ✅ | alert images broken (I-01) |

## Roles & login
| Item | Status | Notes |
|---|---|---|
| Student, Librarian, Driver, Security/Admin dashboards (Scope §6) | ✅ | Built as 5 roles: admin, student, security, librarian, driver |
| **Teacher role / Teacher dashboard (mockups p.19, login p.20)** | ❌ (by decision) | Appears only in mockups, *not* in Scope or Methodology; code deliberately has no teacher. Get written supervisor confirmation that Teacher is out of scope, and list it as a deviation (D-1) |
| Admin-created accounts, no self-registration | ✅ | |
| "Continue with University Account" button (mockup) | ❌ | Not in Scope; ignore, mention as mockup-only |

## Tech stack & constraints
| Item | Status | Notes |
|---|---|---|
| Flutter / Firebase Auth / Firestore / RTDB / FCM / FastAPI / OpenCV | ✅ | |
| Free-tier only | ✅ | Supabase + local overdue loop were added to stay free. Report must mention Supabase as a deviation |
| "AI models trained on Google Colab" | ✅ (n/a) | Classical method, no training. Proposal contradicts itself (§8 vs §7.8); state in report that no training was needed |
| Dataset preparation + performance evaluation of iris recognition (WBS 8.1, 8.6, 13.3) | ❌ | No dataset, no FAR/FRR/accuracy results (I-15) |
| Testing: functional, integration, security, performance (WBS 13) | ❌ | Only 12 unit tests exist |

## Deviations to declare in the final report
1. Supabase Storage for alert images (Firebase Storage needs billing).
2. `overdue_checker` Python loop instead of Cloud Functions (billing).
3. Five roles; no Teacher.
4. No YOLO/Colab (classical pipeline only).
5. RGB iPhone camera instead of NIR iris sensor → expect lower accuracy than the literature.
