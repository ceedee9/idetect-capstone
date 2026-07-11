# iDetect OCR — Complete Guide

### Everything you need to know, including the small stuff

---

## Table of Contents

1. [What the OCR Actually Does](#1-what-the-ocr-actually-does)
2. [The Full Pipeline — Step by Step](#2-the-full-pipeline--step-by-step)
3. [Image Preprocessing](#3-image-preprocessing)
4. [OCR Engines: Tesseract vs ML Kit](#4-ocr-engines-tesseract-vs-ml-kit)
5. [Field Extraction — How Each Field is Found](#5-field-extraction--how-each-field-is-found)
6. [Confidence Scores — What They Actually Mean](#6-confidence-scores--what-they-actually-mean)
7. [OCR Error Correction](#7-ocr-error-correction)
8. [Layout-Based Extraction (Zonal OCR)](#8-layout-based-extraction-zonal-ocr)
9. [Fuzzy Fallback](#9-fuzzy-fallback)
10. [Hybrid Merging Logic](#10-hybrid-merging-logic)
11. [Timeout Fallback (ML Kit Only Mode)](#11-timeout-fallback-ml-kit-only-mode)
12. [Verification Cross-Validation](#12-verification-cross-validation)
13. [Accuracy Numbers — Real vs Claimed](#13-accuracy-numbers--real-vs-claimed)
14. [Processing Time](#14-processing-time)
15. [What Kills Accuracy](#15-what-kills-accuracy)
16. [The Threshold — When Scans Go to Manual Review](#16-the-threshold--when-scans-go-to-manual-review)
17. [Database Storage of OCR Data](#17-database-storage-of-ocr-data)

---

## 1. What the OCR Actually Does

iDetect scans **Philippine Senior Citizen IDs** and **PWD IDs** issued by Valenzuela City. The goal is to extract 5 fields:

| Field          | Example          |
| -------------- | ---------------- |
| Full Name      | `Juan Dela Cruz` |
| Date of Birth  | `01/15/1960`     |
| Sex            | `M` or `F`       |
| Date Issued    | `03/20/2024`     |
| Control Number | `2024-0001`      |

The app does NOT use a server for OCR — everything runs **on the phone, offline**. No image is sent to the cloud for text reading. Only the extracted fields and confidence score are sent to the API.

---

## 2. The Full Pipeline — Step by Step

```
📱 Camera Capture
        ↓
🔬 OpenCV Image Preprocessing   (~200–400ms)
        ↓
📍 ML Kit — Extract text WITH bounding boxes (original image)
        ↓
📐 Get image pixel dimensions
        ↓
🗺️  Layout-Based Extraction (Zonal OCR)
        ├── Template validated? Confidence ≥ 70%?
        │       YES → skip fuzzy, go straight to merge
        │       NO  → also run fuzzy fallback
        ↓
🔍 Fuzzy Fallback (if needed)
        ↓
🔀 Merge best result per field
        ↓
📊 Calculate final confidence
        ↓
🚦 Compare against threshold (75)
        ├── ≥ 75 → send to API for database cross-validation
        └── < 75 → route to manual_review
```

The main service that runs all of this is `HybridParserService` in
`lib/services/hybrid_parser_service.dart`.

---

## 3. Image Preprocessing

**File:** `lib/services/opencv_image_processor.dart` (primary),
`lib/services/advanced_image_processor.dart` (fallback)

Before any OCR engine sees the image, it goes through a quality gate and an
enhancement pipeline.

### Quality Gate

The app first checks two quick metrics:

| Metric     | What it measures                         | Rejection threshold             |
| ---------- | ---------------------------------------- | ------------------------------- |
| Blur score | Laplacian variance (how sharp edges are) | Too low = rejected              |
| Brightness | Mean pixel intensity                     | Too dark or washed out = warned |

If quality is unacceptable, the pipeline still continues (it just logs a warning
instead of hard-failing) — a bad image is better than no scan at all.

### Enhancement Steps (in order)

| #   | Step                       | What it does                                            | Why                                                   |
| --- | -------------------------- | ------------------------------------------------------- | ----------------------------------------------------- |
| 1   | **Resize**                 | Scale to max 2000px on longest side                     | Balance speed vs detail                               |
| 2   | **Border removal**         | Sobel edge detection → crop to content                  | Cut off background noise                              |
| 3   | **Perspective correction** | Detect ID corners, warp flat                            | Fix angled shots                                      |
| 4   | **Deskew**                 | Hough transform → rotate to horizontal                  | Fix tilted IDs                                        |
| 5   | **Grayscale**              | Remove color information                                | Color adds noise, not value                           |
| 6   | **Bilateral filter**       | Edge-preserving denoise                                 | Smooth sensor noise without blurring text edges       |
| 7   | **CLAHE**                  | Local contrast equalization (8×8 tiles, clip=2.0)       | Handle uneven lighting (shadow on one side)           |
| 8   | **Sharpen**                | Unsharp mask 3×3 kernel `[-1,-1,-1; -1,9,-1; -1,-1,-1]` | Crisp character edges                                 |
| 9   | **Adaptive threshold**     | Local binarize (block=25, C=10)                         | Convert to black text on white regardless of lighting |
| 10  | **Morphological closing**  | Dilate then erode                                       | Close gaps in broken characters                       |
| 11  | **Noise removal**          | Remove isolated pixels / tiny blobs                     | Clean final output                                    |

> **Important:** The preprocessed image is used for Tesseract OCR, but ML Kit
> layout extraction always uses the **original** image. OpenCV can shift/merge
> bounding boxes, which breaks the zone math.

---

## 4. OCR Engines: Tesseract vs ML Kit

The system uses two engines and picks the winner per scan.

### Tesseract OCR

- **Package:** `flutter_tesseract_ocr`
- **Language:** `eng` (English; Filipino uses the Roman alphabet)
- **PSM (Page Segmentation Mode):** `6` = assume uniform block of text
- **Config:** `preserve_interword_spaces=1`
- **Field-specific mode:** For individual field re-extraction, PSM changes:
  - Names / Address → PSM 6 (block)
  - Dates, Control No → PSM 7 (single line)
  - Sex → PSM 10 (single character)
- **Character whitelisting** (used when re-extracting specific fields):
  - Name: `A-Z a-z - ñÑ .` (no digits)
  - Date: `0-9 / -` only
  - Sex: `M F m f` only
  - Control No: `0-9 A-Z -` only

### Google ML Kit

- **Package:** `google_mlkit_text_recognition`
- **Script:** Latin
- **Special capability:** Returns **bounding boxes** per word/line/block.
  This is what enables layout-based (zonal) extraction.
- **Used for:**
  1. Fast full-text extraction
  2. Position-aware layout extraction (always runs on original image)
  3. Card type sniffing (quick pre-scan)
  4. Timeout fallback (runs alone if Tesseract times out)

### Which One Wins?

Both engines run. The system compares their heuristic confidence scores:

```
if tesseractConfidence >= mlkitConfidence:
    use Tesseract
else:
    use ML Kit
```

Tesseract is preferred when equal.

---

## 5. Field Extraction — How Each Field is Found

Every field goes through multiple strategies in priority order. The first one
that returns a result above its minimum confidence wins.

### Full Name

| Priority | Strategy              | How                                                                          | Confidence       |
| -------- | --------------------- | ---------------------------------------------------------------------------- | ---------------- |
| 1        | **Zone** (layout)     | Read text from the name zone (24%–38% height, left 65% width)                | 85–97%           |
| 2        | **Keyword proximity** | Find text near labels: `NAME`, `NOMBRE`, `PANGALAN`, `FULL NAME`             | 95% × validation |
| 3        | **Fuzzy match**       | Match 2–4 word sequences against 300+ Filipino first names + 500+ last names | 70–90%           |
| 4        | **Pattern match**     | Regex: 2–4 Title Case words                                                  | 50–70%           |

Name validation bonuses/penalties applied to every found name:

- Length 5–40 chars → keep full confidence
- Length outside range → ×0.5
- 2–4 words → keep; outside → ×0.7
- Contains digits → ×0.3
- Contains special chars (not ñ, `-`) → ×0.5
- At least one word matches a common Filipino name → ×1.1 bonus

### Date of Birth

| Priority | Strategy                     | Confidence                                                         |
| -------- | ---------------------------- | ------------------------------------------------------------------ | ---------------------- |
| 1        | **Zone** (layout)            | Left column of the three-column band (58%–72% height, 0–30% width) | Based on date validity |
| 2        | **Keyword proximity**        | Text near `BIRTH`, `DATE OF BIRTH`, `IPINANGANAK`                  | 90–95%                 |
| 3        | **Pattern + age validation** | `\d{1,2}[/-]\d{1,2}[/-]\d{2,4}` + check age is 60+ (senior)        | 60%                    |

Date confidence is also calculated from the year:

- Year within last 5 years → 97% (recent issue)
- Year 5–10 years ago → 88%
- Older → 70%

### Sex

| Priority | Strategy              | Confidence                                                            |
| -------- | --------------------- | --------------------------------------------------------------------- | ------ |
| 1        | **Zone** (layout)     | Middle column of the three-column band (58%–72% height, 30–55% width) | 90–95% |
| 2        | **Keyword same line** | `M` or `F` on the same line as `SEX` / `KASARIAN`                     | 95%    |
| 3        | **Pattern**           | Standalone `M` or `F` near sex labels                                 | 70%    |

Only valid outputs are `M` or `F`. Everything else is rejected.

### Date Issued

| Priority | Strategy                    | Confidence                                                           |
| -------- | --------------------------- | -------------------------------------------------------------------- | ---------------------- |
| 1        | **Zone** (layout)           | Right column of the three-column band (58%–72% height, 55–95% width) | Based on date validity |
| 2        | **Keyword proximity**       | Text near `ISSUED`, `PETSA`, `DATE ISSUED`                           | 90–95%                 |
| 3        | **Pattern + recency check** | Date pattern + year within last 10 years                             | 60%                    |

### Control Number

| Priority | Strategy              | Confidence                                             |
| -------- | --------------------- | ------------------------------------------------------ | ------ |
| 1        | **Zone** (layout)     | Bottom right zone (75%–85% height, 65–100% width)      | 85–95% |
| 2        | **Keyword proximity** | Text near `CONTROL NO`, `CTRL NO`, `NUMERO NG KONTROL` | 90–95% |
| 3        | **Pattern**           | `\d{2,4}-\d{4}` format, year must be ≥ 2000            | 60–85% |

Control number OCR correction (applied before parsing):

```
O → 0
I → 1
l → 1
Z → 2
S → 5
B → 8
```

---

## 6. Confidence Scores — What They Actually Mean

### IMPORTANT: These Are NOT Statistical Character Accuracy

Confidence scores in iDetect are **heuristic quality indicators**, not the
Tesseract internal per-character probability scores. The `flutter_tesseract_ocr`
plugin does not expose per-character confidence values.

What confidence _actually_ measures:

**Tesseract heuristic:**

```
Base: 0.50
+ 0.20 if text length is 100–1000 chars   (reasonable ID length)
+ 0.15 if text has both letters and numbers
+ 0.15 if special character ratio < 10%
Max: 1.00
```

**ML Kit heuristic (averaged per line):**

```
Per line:
  Base: 0.50
  + 0.20 if line length ≥ 5 chars
  + 0.15 if has letters
  + 0.15 if has numbers
Average across all lines
Max: 1.00
```

**Post-processing bonuses (added after cleanup):**

```
+ 0.10 if ID keywords found ("SENIOR"/"CITIZEN"/"OSCA" or "PWD"/"DISABILITY"/"PDAO")
+ 0.05 if name pattern found (Title Case, 2+ words)
+ 0.05 if ID number pattern found (\d{2,4}-\d{4})
+ 0.05 if date pattern found (\d{1,2}/\d{1,2}/\d{2,4})
+ 0.05 if template match (layout extractor)
+ 0.03 if zone-optimized OCR used
Max after bonuses: clamped to 1.00 (100%)
```

### Per-Field Confidence

The overall confidence is a **weighted average** of individual field scores:

| Field          | Weight |
| -------------- | ------ |
| Full Name      | 25%    |
| Date of Birth  | 20%    |
| Sex            | 15%    |
| Date Issued    | 20%    |
| Control Number | 20%    |

So if every field comes back at 90%, overall is 90%. If name fails (0%) and
everything else is 90%, overall drops to ~67%.

### Confidence Scale

| Score   | Meaning                                                 |
| ------- | ------------------------------------------------------- |
| 90–100% | Excellent extraction, high reliability                  |
| 75–89%  | Good extraction, meets threshold, sent to API           |
| 60–74%  | Below threshold → manual review                         |
| 0–59%   | Poor extraction or OCR timeout fallback (capped at 60%) |

### Timeout Fallback Penalty

If the full hybrid pipeline exceeds 20 seconds, Tesseract is skipped and only
ML Kit runs. In this case, confidence is **capped at 60%** regardless of content:

```dart
cappedConfidence = (parsedConfidence * 0.75).clamp(0.0, 0.60)
```

This ensures timeout-degraded results always route to manual review.

### Forced Scan Penalty (Bypassing Quality Check)

If a user forces a scan past a failed quality check:

```dart
confidence = confidence * 0.8   // 20% penalty
```

---

## 7. OCR Error Correction

After raw text is extracted, these fixes are applied automatically.

### Character Substitution (Context-Aware)

Not globally — only in the right context:

| Error      | Fix                    | Context                  |
| ---------- | ---------------------- | ------------------------ |
| `O` → `0`  | `(\d[/-])O(\d)`        | Date/number context only |
| `I` → `1`  | `(\d)I(\d)`            | Between digits only      |
| `\|` → `I` | `([a-z])\|([a-z])`     | Between letters only     |
| `!` → `1`  | `(\d)!(\d)` or `!(\d)` | Near digits only         |

**Examples:**

- `2O24-OOO1` → `2024-0001`
- `Age: 7I` → `Age: 71`
- `HE|LO` → `HEILO` (only when between letters)

### Line Breaks & Spacing

- Remove 3+ consecutive blank lines → replace with double newline
- Join words broken across lines by a hyphen (`word-\nword` → `wordword`)
- Collapse multiple spaces/tabs to single space
- Trim whitespace from every line

### Date Normalization

All dates standardized to `MM/DD/YYYY`:

- Accepts `/`, `-`, or `.` as separators
- Pads single-digit months/days: `1/5/2024` → `01/05/2024`
- Converts 2-digit years: `>50` → 1900s, `≤50` → 2000s

### ID Number Normalization

- `2024 - 0001` → `2024-0001`
- `2024–0001` (em dash) → `2024-0001`
- Removes stray spaces around the hyphen

### Name Normalization

- Convert all-caps to Title Case: `JUAN DELA CRUZ` → `Juan Dela Cruz`
- Trim extra spaces
- Preserve `ñ`/`Ñ` correctly

### Noise Removal

- Remove lines shorter than 3 characters (unless it's a standalone letter/digit)
- Remove lines where >50% of characters are special characters
- Remove runs of 3+ identical special characters (e.g., `---` from scan artifacts)

---

## 8. Layout-Based Extraction (Zonal OCR)

**File:** `lib/services/layout_based_field_extractor.dart`

This is the **primary extraction method**. Instead of searching all text for
a field, it looks in a specific rectangular zone based on where that field
appears on the Valenzuela Senior Citizen ID template.

### Zones (as % of image dimensions)

```
┌─────────────────────────────────────────┐  0%
│           HEADER ZONE (0–15%)           │
│     Template validation keywords        │
├────────────────────────┬────────────────┤  15%
│                        │                │
│    NAME ZONE           │   PHOTO ZONE   │  24–38%
│    (8–65% wide)        │  (68–100% wide)│
├────────────────────────┤                │  38%
│    ADDRESS ZONE        │                │
│    (0–68% wide)        │                │  38–56%
├────────────────────────┴────────────────┤  58%
│  LEFT COL  │  MID COL   │  RIGHT COL   │
│   DOB      │   Sex      │  Date Issued │  58–72%
│  (0–30%)   │  (30–55%)  │  (55–95%)   │
├────────────┴────────────┴──────────────┤  72%
│                              CTRL ZONE │
│                              (65–100%) │  75–85%
└─────────────────────────────────────────┘  100%
```

### Template Validation

Before extracting anything, the system counts how many of these keywords appear
in the header zone:

```
REPUBLIC, PHILIPPINES, VALENZUELA, SENIOR, CITIZEN, AFFAIRS, OSCA
```

**Minimum required: 4 out of 7.**

If fewer than 4 are found, `templateMatched = false`, and the fuzzy fallback
is activated automatically.

### How Zone Extraction Works

1. ML Kit returns all text blocks with pixel coordinates (bounding boxes).
2. Each bounding box is converted to relative position: `x / imageWidth`,
   `y / imageHeight`.
3. Any text block whose center falls within a zone's boundaries is extracted
   for that zone.
4. The collected text from that zone is then parsed for the specific field.

### Zone-Optimized Tesseract Re-extraction

After layout identifies which region to look at, it can optionally crop just
that zone from the image and run Tesseract on the crop with a character
whitelist — this is more accurate than running on the full image.

---

## 9. Fuzzy Fallback

**File:** `lib/services/senior_citizen_field_extractor.dart`,
`lib/services/parser_service.dart`

Used when:

- Template match fails (< 4 header keywords found)
- Layout confidence < 70%
- Layout extraction returns a critical field empty

### How Fuzzy Name Matching Works

1. Take all words from the OCR text.
2. Try every sequence of 2–4 consecutive words as a candidate name.
3. For each word in the sequence, check it against:
   - 500+ common Filipino **last names**
   - 300+ common Filipino **first names**
4. Scoring per candidate:
   - Each word matching a last name: +0.30
   - Each word matching a first name: +0.30
   - ≥ 2 words matched: +0.40 bonus
5. The sequence with the highest score wins.
6. Minimum score to accept: 0.60

This uses `fuzzywuzzy` (`partialRatio`): a sequence must score ≥ 80% partial
match against a known name to be counted as a match.

### Other Fuzzy Field Strategies

For dates and control numbers, the fuzzy parser uses:

- Multiple regex patterns covering format variations
- Keyword proximity (search within 5 lines of a label)
- Fallback to any matching pattern anywhere in the text

---

## 10. Hybrid Merging Logic

**File:** `lib/services/hybrid_parser_service.dart` — `_mergeResults()`

After layout and fuzzy both run, the system merges on a **per-field basis**:

```
For each field (fullName, dateOfBirth, sex, dateIssued, controlNumber):
    Pick whichever has higher per-field confidence
    (Layout confidence vs Fuzzy confidence)
```

**Special rule for Full Name:**

If layout found a valid name (≥ 2 words, no digits, no address keywords like
"STREET", "ST.", "VALENZUELA") AND layout confidence ≥ 70%, the layout value is
always preferred regardless of fuzzy confidence. This prevents fuzzy from
accidentally choosing an address line as a name.

**Final overall confidence** = average of all 5 field confidences after merging.

**PWD IDs** use a different weighting at the merge stage:

```
overallConfidence = (layoutConfidence × 0.70) + (fuzzyConfidence × 0.30)
```

PWD layout anchors are strong, so layout is trusted more.

---

## 11. Timeout Fallback (ML Kit Only Mode)

If the full hybrid pipeline (OpenCV → ML Kit positions → layout → Tesseract
→ fuzzy → merge) exceeds **20 seconds**, the app activates a degraded fallback:

- Skip Tesseract entirely (it's usually the bottleneck)
- Run ML Kit once on the original image
- Parse with fuzzy parser only
- Cap confidence at **60%** (forces manual review)
- Set `extractionMethod = 'ml-kit-only (ocr-timeout)'`

---

## 12. Verification Cross-Validation

OCR output is not the final word. After extraction, the API cross-validates
against the database:

### 3-Layer Validation

| Layer | Check                                                                    | Fail result  |
| ----- | ------------------------------------------------------------------------ | ------------ |
| 1     | ID number must exist in the LGU database                                 | `NOT_FOUND`  |
| 2     | Extracted name must match database name at ≥ 80% Jaro-Winkler similarity | `SUSPICIOUS` |
| 3     | Extracted date of birth must exactly match the database record           | `SUSPICIOUS` |

### Jaro-Winkler Similarity

Measures string similarity from 0.0 (completely different) to 1.0 (identical).
Gives extra weight to matching characters at the start of the string.

Example:

- `Juan Dela Cruz` vs `Juan Dela Cruz` → 1.00 ✅
- `Juan De La Cruz` vs `Juan Dela Cruz` → ~0.93 ✅ (passes)
- `Juan Santos` vs `Juan Dela Cruz` → ~0.72 ❌ (below 0.80 → SUSPICIOUS)

Why Jaro-Winkler: OCR commonly produces minor one-character errors. This
algorithm handles those tolerantly while still catching genuinely wrong names.

### Verification Results

| Result          | Meaning                                             |
| --------------- | --------------------------------------------------- |
| `VALID`         | All 3 layers passed                                 |
| `SUSPICIOUS`    | Name or DOB mismatch                                |
| `NOT_FOUND`     | ID number not in database                           |
| `MANUAL_REVIEW` | OCR confidence below 75, or flagged for human check |
| `SUSPENDED`     | Beneficiary account suspended                       |
| `EXPIRED`       | ID past expiry                                      |

---

## 13. Accuracy Numbers — Real vs Claimed

These are the numbers from the codebase comments and documentation.

| Condition                             | Claimed accuracy |
| ------------------------------------- | ---------------- |
| Perfect lighting, flat ID, full frame | 95–98%           |
| Good conditions                       | 90–95%           |
| Fair conditions                       | 80–90%           |
| Poor conditions                       | 60–80%           |
| Tesseract (document-optimized)        | ~95–98%          |
| ML Kit (general)                      | ~85–90%          |
| Layout-based extraction (zonal)       | ~97%             |
| Fuzzy-only fallback                   | ~93%             |

**Critical caveat:** These are heuristic estimates, not bench-tested on a labeled
dataset. The confidence score itself is a proxy, not a measured per-character
accuracy. Treat all percentages as relative indicators, not absolute guarantees.

---

## 14. Processing Time

| Stage                                  | Typical time |
| -------------------------------------- | ------------ |
| OpenCV preprocessing                   | 200–400ms    |
| ML Kit (full text + bounding boxes)    | 1–2s         |
| Image dimension fetch                  | <100ms       |
| Layout-based extraction                | ~200ms       |
| Fuzzy fallback (if triggered)          | ~300ms       |
| Tesseract (if used)                    | 3–5s         |
| Post-processing & merge                | <100ms       |
| **Total (layout path, no Tesseract)**  | **~2–3s**    |
| **Total (full hybrid with Tesseract)** | **7–12s**    |
| **Timeout cutoff**                     | **20s**      |

---

## 15. What Kills Accuracy

Ranked from most damaging to least:

| Problem                             | Impact       | Fix                                                   |
| ----------------------------------- | ------------ | ----------------------------------------------------- |
| Dark / low-light image              | Catastrophic | CLAHE helps but can't fix severe darkness             |
| Blurry / shaky capture              | Catastrophic | Quality gate rejects; user needs to reshoot           |
| Extreme angle (>30°)                | Severe       | Perspective correction partially helps                |
| Shadow across part of ID            | Severe       | CLAHE adaptive contrast helps                         |
| Worn/faded ID text                  | Severe       | Sharpening + morphological closing help               |
| Dirty camera lens                   | Severe       | Nothing the app can do                                |
| ID on patterned/light background    | Moderate     | Border removal crops it out                           |
| Very small text                     | Moderate     | Morphological dilation helps                          |
| Handwritten fields                  | Moderate     | No specific fix; ML Kit handles better than Tesseract |
| Laminate glare (reflective surface) | Moderate     | Exposure bracketing would help; not implemented       |
| Non-Valenzuela ID layout            | Moderate     | Template match fails, fuzzy takes over                |

---

## 16. The Threshold — When Scans Go to Manual Review

**Set in:** `apps/api/.env`

```
OCR_CONFIDENCE_THRESHOLD=75
```

This is a 0–100 scale. The confidence score from the app (0.0–1.0 float) is
multiplied by 100 before comparison.

- **Score ≥ 75** → OCR result is trusted, sent to cross-validation against database
- **Score < 75** → Result goes to `manual_review`, staff must manually confirm

This threshold is configurable. Raising it catches more bad scans but creates
more manual review burden. Lowering it reduces manual reviews but risks bad data
slipping through.

---

## 17. Database Storage of OCR Data

**Table:** `verification_logs`

Key OCR-related columns:

| Column                 | Type           | What it stores                                                 |
| ---------------------- | -------------- | -------------------------------------------------------------- |
| `ocr_confidence_score` | `NUMERIC(5,2)` | 0.00 to 100.00 — the heuristic quality score                   |
| `ocr_raw_text`         | `TEXT`         | Full raw OCR output (all text extracted, before field parsing) |
| `image_path`           | `VARCHAR(500)` | Path/URL to the stored ID card photo (Cloudinary)              |
| `manually_entered`     | `BOOLEAN`      | TRUE if staff typed the ID number instead of scanning          |
| `result`               | `ENUM`         | `VALID`, `SUSPICIOUS`, `NOT_FOUND`, `MANUAL_REVIEW`, etc.      |

The comment on `ocr_confidence_score` in the schema itself says:

> "Extraction quality score (0-100): heuristic indicator based on text length,
> character ratios, and keyword presence. Not a true statistical OCR confidence.
> Below OCR_CONFIDENCE_THRESHOLD triggers manual_review."

Rows in `verification_logs` are **never deleted** — they form an immutable audit
trail of every scan ever made, good or bad.

---

## Quick Reference

### Files

| File                                               | Role                                        |
| -------------------------------------------------- | ------------------------------------------- |
| `lib/services/hybrid_parser_service.dart`          | Main orchestrator: runs the full pipeline   |
| `lib/services/enhanced_ocr_service.dart`           | Tesseract + ML Kit engines, post-processing |
| `lib/services/layout_based_field_extractor.dart`   | Zonal OCR for Senior Citizen IDs            |
| `lib/services/pwd_layout_field_extractor.dart`     | Zonal OCR for PWD IDs                       |
| `lib/services/senior_citizen_field_extractor.dart` | Fuzzy field extraction, name DB             |
| `lib/services/opencv_image_processor.dart`         | Image preprocessing (OpenCV)                |
| `lib/services/advanced_image_processor.dart`       | Image preprocessing (pure Dart fallback)    |
| `lib/services/parser_service.dart`                 | General fuzzy parser                        |
| `lib/services/zone_optimized_ocr.dart`             | Tesseract on cropped zones                  |
| `apps/api/.env`                                    | `OCR_CONFIDENCE_THRESHOLD=75`               |

### Key Numbers to Remember

| Thing                           | Number                    |
| ------------------------------- | ------------------------- |
| Confidence threshold (API)      | 75 (out of 100)           |
| Template match minimum keywords | 4 out of 7                |
| Fuzzy fallback trigger          | layout confidence < 70%   |
| Jaro-Winkler name match minimum | 0.80 (80%)                |
| Fraud auto-suspend threshold    | 3 distinct establishments |
| Timeout cutoff                  | 20 seconds                |
| Timeout confidence cap          | 60%                       |
| Forced scan confidence penalty  | ×0.80                     |
| PWD merge weighting             | layout 70% + fuzzy 30%    |
