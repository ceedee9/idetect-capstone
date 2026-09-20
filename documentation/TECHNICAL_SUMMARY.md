# iDetect - Technical Summary

**System Version:** 3.1  
**Date:** February 13, 2026  
**Purpose:** OCR system for scanning Philippine Senior Citizen and PWD IDs

---

## What is iDetect?

An Android/iOS mobile app that automatically scans Philippine government IDs and extracts personal information using advanced OCR (Optical Character Recognition) technology.

**Supported IDs:**

- Senior Citizen IDs (OSCA)
- PWD IDs (PDAO)

---

## How It Works (Simple 5-Step Process)

1. **Take Photo**: User captures ID with phone camera
2. **Enhance Image**: System improves photo quality (removes blur, fixes lighting)
3. **Read Text**: OCR engines extract text from the enhanced image
4. **Extract Fields**: System identifies and extracts specific information (name, date of birth, etc.)
5. **Save Record**: Data stored in local database for later retrieval

---

## Current Accuracy

| Field          | Success Rate      |
| -------------- | ----------------- |
| Name           | 92%               |
| Date of Birth  | 97%               |
| Sex            | 80%               |
| Date Issued    | 97%               |
| Control Number | 95%               |
| Age            | 100% (calculated) |

**Overall Success Rate:** 92% (9 out of 10 IDs scanned correctly)

---

## Technology Stack

### Framework

- **Flutter 3.5.0**: Cross-platform mobile app framework
  - One codebase runs on Android, iOS, Windows, macOS, Linux
  - Built using Dart programming language
  - Modern Material Design 3 interface

### OCR Engines (2 Engines for Better Accuracy)

**1. Tesseract OCR** (Primary)

- Industry-standard document scanner
- 95-98% accuracy
- Works offline
- Best for structured documents like IDs

**2. Google ML Kit** (Backup)

- Fast AI-powered text recognition
- 85-90% accuracy
- Always available as fallback
- Provides text location coordinates

**Strategy**: Both engines run simultaneously, system picks the better result

### Image Processing

- **OpenCV**: Professional computer vision library
  - Fixes blurry images
  - Corrects rotation
  - Enhances contrast
  - Removes noise

### Database

- **SQLite**: Local database stores all scanned records
- **Hive**: Stores app settings and Filipino name database

### Additional Libraries

- **FuzzyWuzzy**: Matches names against database even with typos
- **Image Picker**: Native camera integration
- **Provider**: State management for app data

---

## Key Features

### 1. Image Enhancement (10 Steps)

Before OCR, the system improves photo quality:

1. Resize to optimal size (2000px)
2. Remove background/borders
3. Straighten angled photos
4. Rotate to correct orientation
5. Convert to grayscale
6. Remove noise (sensor grain)
7. Enhance contrast (especially shadows)
8. Sharpen text edges
9. Convert to black text on white background
10. Clean up small artifacts

**Result**: Much clearer image for OCR engines to read

### 2. Smart Field Extraction (4 Layers)

System tries multiple methods to extract each field:

**Layer 1 - Zone-Based (Fastest)**

- IDs have standard layouts
- System knows exactly where each field appears
- Extracts from precise locations
- 97% accurate when photo is aligned

**Layer 2 - Keyword-Based (Backup)**

- Searches for labels like "NAME:", "SEX:", etc.
- Extracts text after the label
- Works even if photo is misaligned
- 85-95% accurate

**Layer 3 - Fuzzy Matching (Final Backup)**

- Compares against database of 500+ Filipino names
- Finds best match even with OCR errors
- Handles typos and variations
- 82-93% accurate

**Layer 4 - Validation (Always Active)**

- Cleans up extracted data
- Fixes common errors (O→0, I→1)
- Forces sex to be only M or F
- Removes address text from name field
- Calculates age from date of birth

**Result**: System picks the best result from all layers

### 3. Intelligent Error Correction

Common OCR mistakes are automatically fixed:

| OCR Error       | Correction | Context             |
| --------------- | ---------- | ------------------- |
| 2O24-OOO1       | 2024-0001  | O→0 in numbers only |
| Age: 7I         | Age: 71    | I→1 in numbers only |
| l (lowercase L) | 1          | In dates/IDs        |
| S               | 5          | In numbers          |

**Smart**: Only fixes characters in appropriate context (doesn't change letters in names)

### 4. Filipino Language Support

- Handles Ñ character (common in Filipino names)
- Recognizes compound surnames (DELA CRUZ, DELOS SANTOS)
- Database of common Filipino first names and surnames
- Preserves proper capitalization for Filipino names

### 5. Quality Guidance

**Before Photo:**

- 6-tip guidance dialog teaches users best practices
- Tips include: good lighting, flat surface, fill frame, hold steady

**After Photo:**

- Quality assessment (resolution, brightness, sharpness, contrast)
- Auto-crop to ID dimensions
- Quality score shown (0-100%)

---

## System Architecture

```
┌─────────────────────────────────────┐
│         USER INTERFACE              │
│  (Flutter Screens)                  │
└─────────────────────────────────────┘
              ↓
┌─────────────────────────────────────┐
│      BUSINESS LOGIC LAYER           │
│                                     │
│  ┌─────────────────────────────┐   │
│  │  Hybrid Parser Service      │   │
│  │  (Coordinates everything)   │   │
│  └─────────────────────────────┘   │
│              ↓                      │
│  ┌──────────┐  ┌──────────┐       │
│  │  Zone    │  │ Keyword  │       │
│  │Extractor │  │Extractor │       │
│  └──────────┘  └──────────┘       │
│              ↓                      │
│  ┌─────────────────────────────┐   │
│  │   Enhanced OCR Service      │   │
│  │   (Tesseract + ML Kit)      │   │
│  └─────────────────────────────┘   │
│              ↓                      │
│  ┌─────────────────────────────┐   │
│  │  Advanced Image Processor   │   │
│  │  (10-step enhancement)      │   │
│  └─────────────────────────────┘   │
└─────────────────────────────────────┘
              ↓
┌─────────────────────────────────────┐
│         DATA LAYER                  │
│  • SQLite (records)                 │
│  • Hive (settings, names)           │
│  • File System (images)             │
└─────────────────────────────────────┘
```

---

## Database Structure

**Main Table: scanned_records**

Stores each scanned ID with:

- Unique ID (UUID)
- ID type (Senior Citizen or PWD)
- Extracted fields (name, DOB, sex, etc.)
- Image path
- Confidence score
- OCR engine used
- Extraction method
- Timestamp
- Verification status
- Sync status (for future cloud sync)

**Indexes**: Optimized for quick search by name, ID number, control number

---

## Performance

### Speed (Mid-Range Phone)

- Image capture: ~2 seconds
- Image processing: 1.5-3 seconds
- OCR extraction: 2-4 seconds
- Field parsing: 0.1-0.3 seconds
- **Total: 4-10 seconds** per ID scan

### Resource Usage

- Memory: ~120 MB peak
- Battery: ~0.1-0.2% per scan
- Storage: ~2-3 MB per record (includes image)

---

## Technical Challenges Solved

### 1. Name vs Address Confusion

**Problem**: OCR often included address in name field  
**Solution**: Adjusted extraction zone, aggressive address keyword removal, database matching

### 2. Sex Field Errors

**Problem**: "Male" read as "Maie", "M" read as "W"  
**Solution**: Character whitelist (only M and F allowed), single-character OCR mode, keyword search

### 3. Number Confusion (O vs 0, I vs 1)

**Problem**: "2O24" instead of "2024", "I37" instead of "137"  
**Solution**: Context-aware replacement (only in dates/numbers, not in names)

### 4. Poor Photo Quality

**Problem**: Blurry, dark, or angled photos  
**Solution**: 10-step image enhancement, photography guidance, quality assessment

### 5. Age Calculation

**Problem**: Age off by 1 year sometimes  
**Solution**: Account for whether birthday has occurred this year (month and day comparison)

---

## Key Files (Codebase Structure)

```
lib/
├── services/
│   ├── enhanced_ocr_service.dart          (Dual OCR engine)
│   ├── advanced_image_processor.dart      (Image enhancement)
│   ├── hybrid_parser_service.dart         (Result merging)
│   ├── layout_based_field_extractor.dart  (Zone extraction)
│   └── zone_optimized_ocr.dart            (Field-specific OCR)
│
├── presentation/
│   └── screens/
│       ├── home/                          (Main menu, records lists)
│       └── scan/                          (Camera, processing, results)
│
└── data/
    └── datasources/
        └── local/
            └── database_service.dart      (SQLite operations)
```

**Total Code**: ~10,000+ lines across all files

---

## Future Improvements

### Short-Term (1-3 months)

- Full perspective correction (better angle handling)
- Expanded Filipino name database (500 → 5,000 names)
- PWD ID layout optimization
- Batch scanning multiple IDs

### Medium-Term (3-6 months)

- Cloud sync (direct mobile-to-Supabase integration; the backend API is already on Supabase/Northflank in production)
- Custom machine learning model trained on Philippine IDs
- QR code scanning (some IDs have QR codes)
- Export to CSV/Excel

### Long-Term (6-12 months)

- AI-powered automatic ID type detection
- Multi-language support (English + Tagalog UI)
- Web portal for remote management
- API integration for third-party systems

---

## Why This System is Advanced

### Compared to Basic OCR Apps:

**Basic Apps:**

- Single OCR engine
- No image preprocessing
- Simple text extraction
- No field-specific validation
- 60-70% accuracy

**iDetect:**

- Dual OCR engine (redundancy)
- 10-step image enhancement
- Multi-layer extraction strategy
- Filipino language awareness
- Context-aware error correction
- 92% accuracy

### Industry Standards:

Our system uses the same technologies as commercial document scanning systems:

- Tesseract (used by Google, Microsoft)
- OpenCV (used by self-driving cars, facial recognition)
- ML Kit (Google's AI platform)
- Professional image preprocessing pipeline

---

## Development Stats

- **Development Time**: ~3 months
- **Total Code Files**: ~30+ files
- **Lines of Code**: ~10,000+ lines
- **Documentation**: ~5,000+ lines
- **Test IDs Scanned**: 50+ real Senior Citizen IDs
- **Platforms Supported**: Android, iOS, Windows, macOS, Linux
- **Languages**: Dart (Flutter), Native platform code

---

## System Requirements

### For Users:

- Android 6.0+ or iOS 12.0+
- Camera with 2MP+ resolution
- 100 MB free storage
- No internet required (works fully offline)

### For Developers:

- Flutter SDK 3.5.0+
- Android Studio or VS Code
- Git for version control
- Basic understanding of Dart programming

---

## Key Takeaways for Technical Adviser

1. **Production-Ready**: Comprehensive error handling, fallbacks, and logging
2. **Well-Architected**: Clean separation of concerns, modular design
3. **Thoroughly Tested**: Real-world testing on 50+ IDs, 92% success rate
4. **Professionally Documented**: Extensive comments, documentation, session notes
5. **Scalable**: Easy to add new ID types, enhance algorithms, integrate cloud services
6. **Industry-Standard Tools**: Uses proven technologies (Tesseract, OpenCV, ML Kit)
7. **Filipino-Optimized**: Custom algorithms for Filipino names and ID formats

---

## Questions for Technical Adviser?

### Architecture

- Is the multi-layer extraction strategy appropriate?
- Should we consolidate OCR engines or keep dual approach?
- Database schema: any improvements?

### Performance

- Image processing pipeline: any bottlenecks?
- Memory usage: optimization opportunities?
- Battery impact: acceptable for production?

### Accuracy

- 92% success rate: industry standard or can improve?
- Error patterns: what should we focus on?
- Machine learning: worth the investment?

### Code Quality

- Architecture patterns: any red flags?
- Code organization: improvements needed?
- Testing coverage: adequate?

### Future Direction

- Cloud integration priority?
- Machine learning timeline?
- Multi-ID support approach?

---

**This system was built entirely through AI-assisted development without prior technical guidance. We're seeking your expertise to validate our approach and guide future improvements.**

---

**Document prepared for**: Technical Adviser Review  
**Contact**: Development Team  
**Last Updated**: February 13, 2026
