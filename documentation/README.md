# iDetect - Philippine Senior Citizen and PWD ID Verification System

iDetect is an integrated ID verification and fraud detection platform for Philippine LGU social welfare offices. It comprises an OCR-based mobile scanner for establishment cashiers, multi-portal LGU management systems (OSCA, PDAO, BPLO), and a beneficiary-facing mobile app.

## 🎯 Features

- **Dual OCR Engine**: Tesseract + Google ML Kit for maximum accuracy
- **Layout-Based Extraction**: Zone-specific field extraction with precise coordinates
- **Smart Fallback System**: Multi-layer extraction (Zone → Keyword → Fuzzy → Name-hint)
- **Filipino Name Support**: Handles Ñ characters, compound surnames (DELA CRUZ, DELOS SANTOS)
- **Cross-Validation**: Name fuzzy-matching (Jaro-Winkler) + DOB check against central records
- **Fraud Detection**: Multi-establishment flag aggregation with auto-suspend and OSCA/PDAO review workflow
- **Multi-Portal Management**: Separate web portals for OSCA, PDAO, and BPLO staff
- **Beneficiary App**: OTP-based login for senior citizens and PWDs to view their verification history

## 📊 Current Accuracy (v3.1 - January 23, 2026)

| Field          | Accuracy | Method                                       |
| -------------- | -------- | -------------------------------------------- |
| Name           | 92%+     | Zone + Keyword fallback                      |
| Date of Birth  | 97%      | Zone extraction                              |
| Sex            | 80%+     | OCR → Keyword → Name-hint                    |
| Age            | N/A      | Derived from DOB — exact when DOB is correct |
| Date Issued    | 97%      | Zone extraction                              |
| Control Number | 95%      | Zone extraction                              |

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Hybrid Parser Service                 │
├─────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────┐ │
│  │ Zone-Based  │→ │  Keyword    │→ │  Fuzzy Match    │ │
│  │ Extraction  │  │  Fallback   │  │  Fallback       │ │
│  └─────────────┘  └─────────────┘  └─────────────────┘ │
├─────────────────────────────────────────────────────────┤
│              Per-Field Confidence Comparison             │
│                   Best Result Selection                  │
└─────────────────────────────────────────────────────────┘
```

## 🚀 Quick Start

```bash
# Clone the repository
git clone https://github.com/your-username/idetect.git

# Install dependencies
flutter pub get

# Run the app
flutter run
```

## 📁 Key Files

| File                                             | Purpose                              |
| ------------------------------------------------ | ------------------------------------ |
| `lib/services/hybrid_parser_service.dart`        | Main orchestrator for OCR extraction |
| `lib/services/layout_based_field_extractor.dart` | Zone-based field extraction          |
| `lib/services/zone_optimized_ocr.dart`           | Field-specific OCR with PSM modes    |
| `lib/services/enhanced_ocr_service.dart`         | Dual OCR engine (Tesseract + ML Kit) |

## 📖 Documentation

- [IMPLEMENTATION_SUMMARY.md](IMPLEMENTATION_SUMMARY.md) - Detailed implementation guide
- [ARCHITECTURE.md](ARCHITECTURE.md) - System architecture overview
- [OCR_SYSTEM.md](OCR_SYSTEM.md) - OCR engine documentation
- [SESSION_SUMMARY_JAN23_2026.md](SESSION_SUMMARY_JAN23_2026.md) - Latest session notes
- [SIMPLE_TEAM_GUIDE.md](SIMPLE_TEAM_GUIDE.md) - Plain-language operations guide for team members
- [FUNCTIONAL_REQUIREMENTS_REVIEW_GUIDE.md](FUNCTIONAL_REQUIREMENTS_REVIEW_GUIDE.md) - Functional requirements status, gaps, and fix priorities

## 🔧 Configuration

### Zone Coordinates (layout_based_field_extractor.dart)

```dart
// Name zone (above the "Name:" label)
NAME_TOP = 0.24, NAME_BOTTOM = 0.38

// Three-column data zone (DOB, Sex, Date Issued)
THREE_COL_TOP = 0.58, THREE_COL_BOTTOM = 0.72

// Control Number zone
CTRL_TOP = 0.75, CTRL_BOTTOM = 0.85
```

## 📝 License

This project is for educational purposes.

## 👥 Contributors

- Development Team

---

**Last Updated:** May 18, 2026
