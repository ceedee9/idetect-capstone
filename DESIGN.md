# iDetect Design System Documentation

## 📐 Figma Design File

**Live Design:** https://www.figma.com/design/MmFOx2QWDFwQLYZqaN905d/Untitled  
**Last Updated:** January 15, 2026  
**Design Dimensions:** 412 × 917 (Mobile)

**Team Access:**

- All members have view/comment access
- Use Dev Mode (toggle bottom right) for precise measurements
- When implementing: Match designs exactly first, iterate later

---

## 🎨 Color Palette

### Brand Colors

```
Primary Blue (Logo, Buttons):  #002E6B
Accent Red (Logo):              #E94444
Secondary Blue (Interactive):   #5170FF
```

### Status Colors

```
Valid (Green):      #13BB11
Invalid (Red):      #FF0000
Flagged (Orange):   #FF6B6B
```

### Background Colors

```
White:           #FFFFFF
Light Gray:      #F5F5F5
Dark:            #292D32
Dark Blue:       #002E6B
Light Blue:      #F1F4FF (input fields)
```

### Text Colors

```
Primary (Black):    #000000
Secondary (Gray):   #626262
Tertiary (Light):   #BDBDBD
On Dark (White):    #FFFFFF
```

### UI Elements

```
Border Light:   #E0E0E0
Border Medium:  #BDBDBD
Divider:        #EEEEEE
Icon Dark:      #404B52
Icon Light:     #757575
```

---

## Typography

**Font Family:** Roboto (System Default)

### Heading Styles

- **Display Large:** 40px, Bold (page titles)
- **Heading 1:** 32px, Bold (major sections)
- **Heading 2:** 28px, Bold, Letter-spacing 1.5 (screen titles like "SCAN ID CARD")
- **Heading 3:** 24px, Bold (section headers like "Create Account")
- **Heading 4:** 20px, Semi-bold (card titles like "PDAO", "OSCA")

### Body Text

- **Body Large:** 16px, Regular, Line height 1.5
- **Body Medium:** 14px, Regular, Line height 1.4
- **Body Small:** 12px, Regular, Line height 1.3

### Special Text

- **Button Large:** 18px, Semi-bold, Letter-spacing 0.5
- **Button Medium:** 16px, Semi-bold, Letter-spacing 0.3
- **Label:** 14px, Medium
- **Caption:** 12px, Regular
- **Status:** 14px, Semi-bold, Letter-spacing 0.5

---

## Spacing System

**Base Unit:** 8px

**Standard Spacing:**

- XXS: 4px
- XS: 8px
- SM: 16px
- MD: 24px
- LG: 32px
- XL: 40px
- XXL: 48px

**Component Spacing:**

- Screen padding horizontal: 20px
- Screen padding vertical: 16px
- Card padding: 16px
- Card spacing: 12px
- Button padding: 16px
- Input padding: 16px
- Section spacing: 32px

---

## Border Radius

- XS: 4px (small elements)
- SM: 8px (buttons)
- MD: 12px (input fields)
- LG: 16px (cards)
- XL: 24px (bottom sheets)
- Full: 999px (circular/pill)

**Component Defaults:**

- Buttons: 8px
- Input fields: 12px
- Cards: 16px
- Bottom sheets: 24px (top corners only)

---

## Shadows

**Small (Cards):**

```css
box-shadow: 0px 2px 4px rgba(0, 0, 0, 0.08);
```

**Medium (Buttons, Modals):**

```css
box-shadow: 0px 4px 8px rgba(0, 0, 0, 0.12);
```

**Large (Floating Elements):**

```css
box-shadow: 0px 8px 16px rgba(0, 0, 0, 0.16);
```

---

## Screen Specifications

### 1. Login Page

**Figma Frame:** LOG IN PAGE

**Layout:**

- Background: Dark overlay over ID card image
- Logo: "iDetect" (blue "ID", red "ETECT")
- Input fields: Email, Password
- Link: "Forgot your password?" (centered, white text)
- Primary button: "Sign in" (full width, dark blue)
- Link: "Create new account" (centered, white text)

**Spacing:**

- Logo to first input: 32px
- Between inputs: 16px
- Input to forgot link: 12px
- Link to button: 24px
- Button to bottom link: 16px

**Input Fields:**

- Height: 56px
- Border radius: 12px
- Background: Light blue (#F1F4FF)
- Padding: 16px
- Placeholder color: Gray (#BDBDBD)

### 2. Create Account Page

**Figma Frame:** CREATE ACCOUNT (OPTIONAL)

**Similar to login, with additions:**

- Heading: "Create Account" (24px, bold, white)
- Subtitle: "Create an account so you can explore all the existing jobs"
- Three input fields: Email, Password, Confirm Password
- Primary button: "Sign up"
- Link: "Already have an account" (bottom)

### 3. Main Page (Home/Dashboard)

**Figma Frame:** MAIN PAGE

**Layout:**

- Top bar: Logo (left), Profile icon (right)
- Large banner: VALID portal image with text overlay
  - "LOREM IPSUM" heading
  - Descriptive paragraph text
- Two-column grid: News/update cards (blue backgrounds)
- Bottom navigation: HOME (active), SCAN ID, HISTORY

**News Cards:**

- Background: Dark blue (#002E6B)
- Image: Top
- Title and description: Below image
- Border radius: 8px
- Spacing between cards: 12px

**Bottom Navigation:**

- Height: 70px
- Icons: 28px
- Active state: Blue circle background
- Inactive: Gray icons

### 4. Scan Page

**Figma Frame:** SCAN PAGE

**Layout:**

- Dark overlay background
- Top bar: Back arrow (left), Refresh icon (right), Flash icon (right)
- Heading: "SCAN ID CARD" (28px, bold, white, centered, letter-spacing wide)
- Instructions: "Please point the camera at the ID card..." (14px, white)
- Camera frame: White border showing ID card preview
- Section label: "EXTRACTED DETAILS" (16px, semi-bold, white)
- Details display:
  - NAME: [Extracted name]
  - AGE: [Age]
  - SEX: [Gender]
  - DATE ISSUED: [Date]
  - CONTROL ID: [ID number]
- Bottom actions:
  - Edit button (left, small circle)
  - Large scan button (center, light blue circle, 80-100px)
  - History button (right, small circle)

**Camera Frame:**

- White border: 3px
- Rounded corners: 8px
- Shows real-time camera preview or captured image

**Scan Button:**

- Size: 80-100px diameter
- Background: Light blue gradient
- Icon: Camera or scan symbol
- Shadow: Large, prominent

### 5. Database Pages (PDAO & OSCA)

**Figma Frames:** PDAO DATABASE, OSCA DATABASE

**Layout:**

- Top: Logo, Settings icon (right)
- Blue card header:
  - Title: "PDAO" or "OSCA" (white, bold)
  - Year: "2025" (white)
  - Search bar: White background, search icon
  - Sort dropdown: "Short by: Newest"
- Data table:
  - Headers: Control ID, Name, Status
  - Rows: Alternating white backgrounds
  - Status badges:
    - Valid: Green (#13BB11), bold
    - Invalid: Red (#FF0000), bold
    - Flagged: Red (#FF6B6B), bold
- Pagination: Bottom, numbered pages
- Bottom stats: "Showing data 1 to 6 of 256K entries"
- Bottom navigation: Same as Main Page

**Blue Header Card:**

- Background: Dark blue (#002E6B)
- Border radius top: 16px
- Padding: 20px
- Search input: White background, 12px radius

**Table Styling:**

- Row height: 48px
- Text: 14px, regular
- Padding: 12px horizontal
- Status badges: Padding 8px horizontal, 4px vertical, 20px radius

---

## Component Library

### Primary Button

```dart
ElevatedButton(
  style: AppDesignSystem.primaryButton,
  onPressed: () {},
  child: Text('Button Text'),
)
```

**Specs:**

- Background: #002E6B
- Text: White, 16-18px, Semi-bold
- Padding: 32px horizontal, 16px vertical
- Border radius: 8px
- Minimum height: 56px
- Full width by default

### Input Field

```dart
TextField(
  decoration: AppDesignSystem.inputDecoration(
    hintText: 'Email',
    prefixIcon: Icons.email,
  ),
)
```

**Specs:**

- Background: #F1F4FF
- Border: None (filled style)
- Border radius: 12px
- Padding: 16px
- Height: 56px
- Focus border: 2px, #002E6B

### Status Badge

```dart
Container(
  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
  decoration: BoxDecoration(
    color: AppDesignSystem.getStatusColor(status),
    borderRadius: BorderRadius.circular(20),
  ),
  child: Text(
    status,
    style: AppDesignSystem.getStatusTextStyle(status),
  ),
)
```

### Card

```dart
Container(
  padding: EdgeInsets.all(AppDesignSystem.cardPadding),
  decoration: BoxDecoration(
    color: AppDesignSystem.backgroundWhite,
    borderRadius: AppDesignSystem.cardRadius,
    boxShadow: AppDesignSystem.shadowMD,
  ),
  child: YourContent(),
)
```

### Bottom Navigation

**Active item:**

- Background: Blue circle (#5170FF)
- Icon: White
- Label: Blue text, bold

**Inactive item:**

- Icon: Gray (#757575)
- Label: Gray text

---

## Assets Needed

### Icons (Export from Figma)

- [ ] Logo (iDetect) - PNG @2x, @3x
- [ ] Home icon
- [ ] Scan/Camera icon
- [ ] History/Clock icon
- [ ] Profile/User icon
- [ ] Settings/Gear icon
- [ ] Back arrow
- [ ] Refresh icon
- [ ] Flash/Lightning icon
- [ ] Edit/Pencil icon
- [ ] Search icon
- [ ] Check circle (valid)
- [ ] Cancel circle (invalid)
- [ ] Flag (flagged)

### Logos (Already in design)

- [ ] PDAO logo (circular, colorful)
- [ ] OSCA logo (circular, red/blue)

### Background Images

- [ ] ID cards background (for login/create account)
- [ ] VALID portal banner image

---

## Implementation Checklist

### Setup Phase

- [x] Extract color codes from Figma
- [x] Create `app_design_system.dart` with constants
- [ ] Export all icons from Figma
- [ ] Add assets to `assets/` folder
- [ ] Update `pubspec.yaml` with asset paths
- [ ] Run `flutter pub get`

### Component Phase

- [ ] Create reusable PrimaryButton widget
- [ ] Create reusable InputField widget
- [ ] Create StatusBadge widget
- [ ] Create BottomNavigation widget
- [ ] Create custom AppBar widget

### Screen Phase

- [ ] Implement Login screen
- [ ] Implement Create Account screen
- [ ] Implement Main/Home screen
- [ ] Implement Scan screen
- [ ] Implement Database screens (PDAO, OSCA)
- [ ] Implement History screen

### Polish Phase

- [ ] Add page transitions (300ms)
- [ ] Test on different screen sizes
- [ ] Verify all colors match Figma
- [ ] Verify all spacing matches Figma
- [ ] Get design approval from team

---

## 💻 Code Usage Examples

### Using Design System

```dart
import 'package:idetect/core/constants/app_design_system.dart';

// COLORS
Container(
  color: AppDesignSystem.primaryBlue,
  child: Text(
    'iDetect',
    style: TextStyle(color: AppDesignSystem.textOnPrimary),
  ),
)

// TYPOGRAPHY
Text('Welcome', style: AppDesignSystem.heading1)
Text('Subtitle', style: AppDesignSystem.bodyMedium)

// SPACING
Padding(
  padding: EdgeInsets.all(AppDesignSystem.spaceMD),
  child: Column(
    children: [
      Widget1(),
      SizedBox(height: AppDesignSystem.spaceSM),
      Widget2(),
    ],
  ),
)

// BUTTONS
ElevatedButton(
  style: AppDesignSystem.primaryButton,
  onPressed: () {},
  child: Text('Sign In'),
)

// STATUS INDICATORS
Container(
  color: AppDesignSystem.getStatusColor('valid'),
  child: Icon(AppDesignSystem.getStatusIcon('valid')),
)
```

---

## Design Update Process

When designs change in Figma:

1. **Designer updates Figma** and notifies team
2. **Developers check** what changed (colors, spacing, components)
3. **Update `app_design_system.dart`** if values changed
4. **Update affected screens**
5. **Hot reload** to see changes immediately
6. **Commit** with message: "Update UI to match Figma [date]"

---

## Screen Implementation Checklist

Before marking a screen as "complete":

- [ ] All colors match Figma (use color picker to verify)
- [ ] All spacing matches Figma (measure with Figma dev mode)
- [ ] All text styles match Figma
- [ ] All icons/images match Figma
- [ ] Responsive on phone (test on real device)
- [ ] Animations implemented (if designed)
- [ ] No hardcoded values (uses AppDesignSystem)
- [ ] Screenshot compared side-by-side with Figma
- [ ] Designer has reviewed and approved
- [ ] Works with real data (not just placeholders)

---

## Quick Reference

**Design System File:** `lib/core/constants/app_design_system.dart`  
**Figma Link:** https://www.figma.com/design/MmFOx2QWDFwQLYZqaN905d/Untitled  
**Screen Dimensions:** 412 × 917 px  
**Base Spacing Unit:** 8px  
**Primary Color:** #002E6B  
**Font Family:** Roboto

---

**Remember:** Always use `AppDesignSystem` constants. Never hardcode colors, spacing, or text styles!
