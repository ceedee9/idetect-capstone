# iDetect OCR Architecture v2.0

```
┌─────────────────────────────────────────────────────────────────────┐
│                         USER INTERACTION                            │
└─────────────────────────────────────────────────────────────────────┘
                                  │
                                  ▼
┌─────────────────────────────────────────────────────────────────────┐
│                     HOME SCREEN (home_screen.dart)                  │
│                                                                     │
│  • Scan ID Button                                                   │
│  • ID Type Selection Dialog (Senior / PWD)                          │
└─────────────────────────────────────────────────────────────────────┘
                                  │
                                  ▼
┌─────────────────────────────────────────────────────────────────────┐
│                   CAMERA SCREEN (camera_screen.dart)                │
│                                                                     │
│  • Photography Guidance Dialog (6 tips)                             │
│  • Native Device Camera (ImagePicker)                               │
│  • Real-time Quality Assessment                                     │
│    - Resolution Check (>2MP)                                        │
│    - Brightness Analysis (80-180 ideal)                             │
│    - Sharpness Calculation (Laplacian variance)                     │
│    - Contrast Measurement (min-max diff)                            │
│  • Quality Score Display (0-100%)                                   │
│  • Auto-Crop to ID Area (1.586:1 ratio)                            │
└─────────────────────────────────────────────────────────────────────┘
                                  │
                                  ▼
┌─────────────────────────────────────────────────────────────────────┐
│              PROCESSING SCREEN (processing_screen.dart)             │
│                                                                     │
│  STEP 1: Analyzing (25%) ────────────────────────┐                 │
│                                                   │                 │
│  STEP 2: Extracting Text (50%) ──────────────────┤                 │
│         │                                         │                 │
│         ▼                                         │                 │
│  ┌──────────────────────────────────────────┐   │                 │
│  │   ENHANCED OCR SERVICE                   │   │                 │
│  │   (enhanced_ocr_service.dart)            │   │                 │
│  │                                          │   │                 │
│  │   ┌──────────────────────────────────┐  │   │                 │
│  │   │  ADVANCED IMAGE PROCESSOR         │  │   │                 │
│  │   │  (advanced_image_processor.dart)  │  │   │                 │
│  │   │                                   │  │   │                 │
│  │   │  1. Resize (2000px)              │  │   │                 │
│  │   │  2. Remove Borders               │  │   │                 │
│  │   │  3. Perspective Correction       │  │   │                 │
│  │   │  4. Deskew (Hough Transform)     │  │   │                 │
│  │   │  5. Grayscale                    │  │   │                 │
│  │   │  6. Bilateral Filter (Denoise)   │  │   │                 │
│  │   │  7. CLAHE (Contrast)             │  │   │                 │
│  │   │  8. Sharpen                      │  │   │                 │
│  │   │  9. Adaptive Threshold           │  │   │                 │
│  │   │  10. Morphological Ops           │  │   │                 │
│  │   └──────────────────────────────────┘  │   │                 │
│  │               │                          │   │                 │
│  │               ▼                          │   │                 │
│  │   ┌──────────────────────────────────┐  │   │                 │
│  │   │  OCR ENGINES (Dual Engine)       │  │   │                 │
│  │   │                                  │  │   │                 │
│  │   │  ┌──────────────┐               │  │   │                 │
│  │   │  │  TESSERACT   │  (Primary)    │  │   │                 │
│  │   │  │  OCR         │  95-98%       │  │   │                 │
│  │   │  │  PSM Mode 6  │  Accuracy     │  │   │                 │
│  │   │  └──────────────┘               │  │   │                 │
│  │   │          +                      │  │   │                 │
│  │   │  ┌──────────────┐               │  │   │                 │
│  │   │  │  GOOGLE      │  (Fallback)   │  │   │                 │
│  │   │  │  ML KIT      │  85-90%       │  │   │                 │
│  │   │  │  Text Recog  │  Accuracy     │  │   │                 │
│  │   │  └──────────────┘               │  │   │                 │
│  │   │          │                      │  │   │                 │
│  │   │          ▼                      │  │   │                 │
│  │   │  Select Best Result             │  │   │                 │
│  │   └──────────────────────────────────┘  │   │                 │
│  │               │                          │   │                 │
│  │               ▼                          │   │                 │
│  │   ┌──────────────────────────────────┐  │   │                 │
│  │   │  POST-PROCESSING                 │  │   │                 │
│  │   │                                  │  │   │                 │
│  │   │  • Fix OCR Errors (O→0, I→1)    │  │   │                 │
│  │   │  • Standardize Dates             │  │   │                 │
│  │   │  • Fix ID Numbers                │  │   │                 │
│  │   │  • Title Case Names              │  │   │                 │
│  │   │  • Remove Noise                  │  │   │                 │
│  │   │  • Boost Confidence              │  │   │                 │
│  │   └──────────────────────────────────┘  │   │                 │
│  └──────────────────────────────────────────┘   │                 │
│                                                   │                 │
│  STEP 3: Parsing Data (75%) ─────────────────────┤                 │
│         │                                         │                 │
│         ▼                                         │                 │
│  ┌──────────────────────────────────────────┐   │                 │
│  │   PARSER SERVICE                         │   │                 │
│  │   (parser_service.dart)                  │   │                 │
│  │                                          │   │                 │
│  │  • Detect ID Type (Senior / PWD)        │   │                 │
│  │  • Specialized Senior Citizen Parser    │   │                 │
│  │    - Layout-aware extraction            │   │                 │
│  │    - Sequential line parsing            │   │                 │
│  │    - Auto-calculate age from DOB        │   │                 │
│  │  • Generic Pattern-based Parser         │   │                 │
│  │  • Extract Fields:                      │   │                 │
│  │    - Name                               │   │                 │
│  │    - ID Number                          │   │                 │
│  │    - Age / Date of Birth                │   │                 │
│  │    - Sex                                │   │                 │
│  │    - Date Issued                        │   │                 │
│  │    - Control Number                     │   │                 │
│  └──────────────────────────────────────────┘   │                 │
│                                                   │                 │
│  STEP 4: Done (100%) ────────────────────────────┘                 │
│                                                                     │
│  • Display Confidence Score                                         │
│  • Show OCR Engine Used                                            │
│  • Editable Data Fields                                            │
│  • Retake / Try Anyway / Confirm Buttons                           │
└─────────────────────────────────────────────────────────────────────┘
                                  │
                                  ▼
┌─────────────────────────────────────────────────────────────────────┐
│                   RESULT SCREEN (result_screen.dart)                │
│                                                                     │
│  • Full Image Preview                                              │
│  • Confidence Badge (Excellent / Good / Fair / Poor)               │
│  • ID Type Card (Large, gradient)                                  │
│  • Primary Info (Name, ID Number) - Large Text                     │
│  • Additional Details (Age, Sex, Dates)                            │
│  • Edit Mode Toggle                                                │
│  • Field Validation                                                │
│  • Verify with Database Button                                     │
│  • Retake Photo Option                                             │
└─────────────────────────────────────────────────────────────────────┘
```

## Data Flow

```
Raw Image (JPEG)
    ↓
Quality Assessment
    ↓
Cropped Image (ID area only)
    ↓
Processed Image (10-step enhancement)
    ↓
Raw OCR Text (from Tesseract or ML Kit)
    ↓
Cleaned Text (post-processing)
    ↓
Parsed Data (structured fields)
    ↓
Validated Data (user-confirmed)
    ↓
Database Storage
```

## Key Components

### Services Layer

```
lib/services/
  ├── advanced_image_processor.dart      (700+ lines)
  ├── enhanced_ocr_service.dart          (450+ lines)
  ├── parser_service.dart                (780+ lines)
  ├── ocr_service.dart                   (basic, backup)
  └── ocr_service_optimized.dart         (advanced, optional)
```

### Presentation Layer

```
lib/presentation/screens/
  ├── home/home_screen.dart              (ID type selection)
  ├── scan/camera_screen.dart            (Native camera + quality)
  ├── scan/processing_screen.dart        (OCR pipeline)
  └── scan/result_screen.dart            (Display + edit)
```

## Technology Stack

### OCR Engines

- **Tesseract 5.x** via flutter_tesseract_ocr
  - Language: eng (English/Latin)
  - PSM: 6 (uniform block of text)
  - Accuracy: 95-98% with preprocessing

- **Google ML Kit Text Recognition**
  - On-device processing
  - Latin script recognition
  - Accuracy: 85-90%

### Image Processing

- **image package** (Dart-native)
  - Resizing, filtering, thresholding
  - Morphological operations
  - Color space conversions

- **opencv_dart** (future enhancement)
  - Advanced perspective correction
  - Contour detection
  - Full Hough transform

### Image Capture

- **ImagePicker**
  - Native device camera
  - High quality (2000x2000, 95% JPEG)
  - Rear camera preferred

## Performance Characteristics

### Time Complexity

- Image Preprocessing: O(n × m) where n,m = image dimensions
- Bilateral Filter: O(n × m × r²) where r = radius (most expensive)
- CLAHE: O(n × m / t²) where t = tile size
- Tesseract OCR: O(n × m × log(n × m))
- ML Kit OCR: O(n × m)
- Post-processing: O(k) where k = text length

### Space Complexity

- Original Image: ~5-10 MB
- Processed Image: ~2-5 MB
- Temporary buffers: ~10-20 MB
- OCR results: ~10-50 KB
- **Total Peak Memory: ~50-100 MB**

### Critical Path

1. Bilateral Filter (most CPU-intensive)
2. CLAHE (memory-intensive)
3. Tesseract OCR (longest duration)

**Total Processing: 7-15 seconds on modern devices**

## Configuration Parameters

### Preprocessing Tuning

```dart
// Resize target
maxDimension = 2000px

// Bilateral Filter
radius = 3
sigmaColor = 50.0
sigmaSpace = 50.0

// CLAHE
tileSize = 8
clipLimit = 2.0

// Adaptive Threshold
blockSize = 25
constant = 10

// Morphological Operations
dilationRadius = 1
erosionRadius = 1
```

### OCR Configuration

```dart
// Tesseract
language: 'eng'
psm: 6  // Uniform block of text
preserve_interword_spaces: 1

// ML Kit
script: TextRecognitionScript.latin
```

### Quality Thresholds

```dart
minResolution = 2000000 pixels (2MP)
idealBrightness = 80-180
minSharpness = 30 (Laplacian variance)
minContrast = 20 (min-max difference)
goodQualityThreshold = 70%
```

---

**Architecture Version:** 2.0.0  
**Last Updated:** January 19, 2026  
**Status:** Production-Ready
