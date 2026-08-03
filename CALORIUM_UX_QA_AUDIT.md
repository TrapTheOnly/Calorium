# Calorium UX, UI, Accessibility, and Functional QA Audit

Audit date: 19 July 2026  
Audited build: current workspace debug build  
Scope: all 15 application screens, shared widgets/services, Android configuration, phone-sized visual rendering, static analysis, widget tests, and Android build verification

## Executive summary

Calorium has a useful feature set and a workable Material 3 foundation, but it is not release-ready yet. The most urgent issue is a nutrition-calculation inconsistency: portion-based logs can represent different calorie and macro totals depending on which page or service reads them. That undermines the app's core promise and should be fixed before visual polish.

The main design issue is information architecture. The home page behaves like a menu of large, equally weighted buttons. Core actions, setup prompts, AI tools, history, and settings compete for attention, while several destinations repeat back and home controls. A persistent navigation model and a single global "Add" flow would make the app feel much faster and more coherent.

The visual language is functional but not yet a system. Material You can change most of the palette according to the device, while many individual widgets use hard-coded colors and small fixed type. As a result, screens can feel like separate features rather than one product, and contrast/readability will vary by theme.

### Priority order

1. Fix log amount/portion semantics and add calculation regression tests.
2. Correct release signing, remove exposed credentials, and protect the Gemini key.
3. Replace the home button stack and redundant navigation with a stable app structure.
4. Add validation, loading/error/empty states, and recovery to every data and AI flow.
5. Establish design, accessibility, and responsive-layout tokens and test them systematically.

## Method and limitations

### Completed

- Inventoried and reviewed all 15 screen files and their principal supporting services/widgets.
- Rendered representative screens at a phone-like 432 × 920 logical viewport on Windows:
  - Home
  - Daily Log
  - Select Date
  - Inventory
  - AI Recipe Generator
  - AI Quick Scan
  - Add Food
- Exercised initial, empty, disabled, and form states where the desktop-compatible code path allowed it.
- Ran `dart analyze`.
- Ran `flutter test`.
- Built the Android debug APK successfully.
- Reviewed the Android manifest, Gradle release configuration, permissions, startup behavior, data persistence, theming, and AI configuration.

### Device limitation

Both installed Android Virtual Devices were attempted. The Android Emulator reported:

> Android Emulator hypervisor driver is not installed

Consequently, camera capture, barcode scanning, Health Connect, runtime Android permissions, notifications, keyboard behavior on Android, and process-restoration behavior could not be honestly device-verified in this pass. Windows rendering was useful for layout review but is not a substitute for those Android checks. The final section gives the exact retest matrix to run after virtualization is enabled.

## Release-blocking findings

### P0 — Portion-based nutrition totals are inconsistent

This is the most serious finding.

When an existing food is logged in portion mode, the code converts the portion count into grams and also stores the portion count:

- [`add_food_screen.dart`](lib/screens/add_food_screen.dart#L141) stores `amount = portions × defaultPortionSize`.
- [`log_service.dart`](lib/services/log_service.dart#L31) later calculates nutrients as `nutrient × amount × portions / 100`.
- [`daily_log_screen.dart`](lib/screens/daily_log_screen.dart#L84) and [`home_screen.dart`](lib/screens/home_screen.dart#L52) ignore `portions` and calculate from `amount` only.

Example: two 100 g portions are stored as `amount = 200` and `portions = 2`.

- Home and Daily Log interpret that as 200 g.
- `getTotalMacros` interprets it as 400 g.

Custom recipes have the inverse inconsistency. [`custom_recipe_detail_screen.dart`](lib/screens/custom_recipe_detail_screen.dart#L786) stores `amount = 100` and the requested servings in `portions`; Home and Daily Log then display one serving regardless of the requested serving count, while `getTotalMacros` applies the servings.

Editing adds another failure mode: [`log_service.dart`](lib/services/log_service.dart#L57) updates only `amount`, leaving a previous `portions` value behind.

**Recommendation:** choose one canonical model and migrate existing data:

- Preferred: store canonical `amountGrams`; use portion count and portion size only as display metadata.
- Alternative: store `portionCount` and `portionSizeGrams`, then derive grams in one shared calculation function.

Every screen and analysis service must call that same calculation function. Add tests for gram entry, fractional portions, multiple portions, custom-recipe servings, edited entries, zero/invalid values, and historical migration.

### P0 — A credential is embedded in the client

[`main.dart`](lib/main.dart#L24) contains an Open Food Facts username/password pair. Anything embedded in a mobile client can be extracted.

**Recommendation:** rotate the exposed credential, remove it from source and Git history where appropriate, and avoid shipping a reusable account password. If authenticated calls are needed, use an appropriate server-side or provider-supported client authentication design.

### P1 — Release builds use the debug signing key

[`android/app/build.gradle.kts`](android/app/build.gradle.kts#L31) assigns the debug signing configuration to the release build. This is a production distribution blocker. Gradle also declares version `1.1.0` / code `2`, while `pubspec.yaml` declares `1.0.0+1`, creating release metadata drift.

**Recommendation:** establish a protected release keystore/CI signing path and derive version metadata from one source.

### P1 — The Gemini API key is stored as ordinary preferences

[`settings_service.dart`](lib/services/settings_service.dart#L24) stores the user's Gemini key in `SharedPreferences`. It is not an appropriate secret store.

**Recommendation:** use platform-backed secure storage, mask/reveal the value intentionally, provide a remove-key action, and explain what images/text are sent to the AI provider before the first upload.

### P1 — Automated smoke coverage is currently broken

`flutter test` fails before validating the UI:

- Sqflite reports that the database factory is not initialized in the test environment.
- `HealthPermissionProvider` is missing from the test wrapper.

The only widget test checks that a `MaterialApp` exists, so core user journeys and the nutrition math have no effective regression protection.

**Recommendation:** inject database, health, AI, notification, clock, and scanner abstractions. Use fakes in tests. Create navigation and calculation tests before redesign work so visual refactoring does not introduce silent data regressions.

## Product-wide UX and design findings

### 1. Navigation and hierarchy

The Home screen is a vertical stack of similarly styled full-width actions. "Select Date," "Quick Add," "Inventory," "AI Recipe Generator," "Weekly Analysis," and "Settings" all compete at approximately the same visual level. A large Health Connect card further pushes daily logging below setup UI.

Recommended structure:

- Bottom navigation: **Today**, **History**, **Foods**, **Insights**, **Profile**
- Central or persistent **Add** action:
  - Search foods
  - Scan barcode
  - AI photo
  - Manual food
  - Recipe/mixed food
- Settings inside Profile
- Standard back behavior; remove repeated Home icons from child app bars

This reduces the Home screen to today's progress, recent meals, one next-best action, and optional setup reminders.

### 2. Theming and visual consistency

[`main.dart`](lib/main.dart#L51) adopts the device's dynamic color scheme whenever available. That makes Calorium look turquoise, lavender, green, or another system-derived color depending on the phone. At the same time, the codebase contains extensive direct `Colors.*` usage and custom status/category colors. The product therefore lacks a stable brand and a predictable semantic palette.

The theme currently configures only Material 3 and the color scheme. The apparent theme/style files do not define a meaningful component system.

Recommended design foundation:

- Keep the current blue-violet seed (`#4B68FF`) as a recognizable brand anchor.
- Make Material You harmonization optional instead of replacing the entire brand palette.
- Define semantic tokens for surface levels, borders, success, warning, error, AI, health, and nutrition categories.
- Define one typography scale, spacing scale, corner-radius scale, field style, card style, and primary/secondary/quiet button variants.
- Use elevation sparingly; prefer surface tone and border hierarchy.
- Standardize labels such as `kcal`, `g`, `per 100 g`, dates, and decimal precision.

### 3. Accessibility

Source review found no explicit `Semantics` widgets. Built-in Material controls provide some semantics, but custom tappable cards, tags, category chips, and icon actions need intentional labels and states.

Key issues:

- Many icon buttons do not have tooltips or clear accessible names.
- Some interactive controls are much smaller than a 48 × 48 logical-pixel target; the recipe tag remove action uses a 14 px close icon inside a `GestureDetector`.
- A substantial number of text styles use fixed 10–12 px sizes.
- Disabled Weekly Analysis text is extremely low contrast.
- The enabled "Scan Barcode" secondary action can look disabled.
- AI categories and difficulty/status states rely heavily on color.
- Several dense `Row` layouts are likely to overflow at large text sizes.
- The entire app is locked to portrait in [`main.dart`](lib/main.dart#L16).

Accessibility acceptance criteria:

- Test TalkBack traversal and announcements.
- Provide labels, roles, values, selected/disabled states, and hints for custom controls.
- Meet at least 4.5:1 contrast for normal text and 3:1 for large text and essential UI graphics.
- Support Android font sizes through 200% without clipping or loss of function.
- Use 48 × 48 minimum interactive targets.
- Never communicate state by color alone.
- Respect reduced motion and avoid surprise focus changes after async operations.

### 4. Responsive behavior and scaling

The code has many fixed rows and very little responsive branching. Only a small number of screens use `MediaQuery`, and just one layout uses `LayoutBuilder`. Settings limits content width, but most screens simply stretch or compress.

Likely failure points:

- Four macro values in a single row
- Long page titles plus several app-bar icons
- Paired photo buttons
- Servings field plus log action
- Three inventory tabs
- Horizontal recipe filters
- Settings controls and profile fields

The Android manifest also sets `android.max_aspect` to `2.1`, which can constrain presentation on unusual tall displays, while the app locks portrait orientation.

**Recommendation:** define compact, medium, and expanded breakpoints; use wrapping/adaptive grids; constrain readable content width; support landscape/tablet/foldable postures; and remove the aspect-ratio cap unless a verified compatibility issue requires it.

### 5. Loading, empty, error, and offline states

Several screens jump directly from async work to content or show a blank area on failure. Select Date, for example, has no distinct loading/error/empty presentation. AI flows often collapse failures into a snackbar and restart the workflow, losing context.

Every async surface should have:

- Skeleton/progress state that preserves layout
- Specific error message in plain language
- Retry action
- Offline explanation where relevant
- Safe back/cancel behavior
- Preserved user inputs after failure
- Empty state that explains how to create the first item

### 6. Language, units, and regional behavior

The UI is English-only, foods use metric grams, and Open Food Facts is globally configured for English/USA. Dates and decimals are manually formatted in several places.

**Recommendation:** centralize localized strings, dates, numbers, and units. Let users choose metric/imperial display where relevant, but keep canonical storage unambiguous. Use the device locale or a selected market for Open Food Facts instead of globally fixing USA.

### 7. Privacy, permissions, and trust

The manifest requests camera, notifications, activity recognition, Health Connect data, coarse/fine location, and two exact-alarm permissions. Location is not visibly justified by the core food-tracking experience. Exact-alarm access is sensitive and should be requested only if the notification behavior genuinely requires exact delivery.

The app also prompts for notification permission during scheduler initialization before the UI is shown: [`scheduler_service.dart`](lib/services/scheduler_service.dart#L14). Permissions are more understandable when requested at the moment a user enables a feature.

Recommended changes:

- Do not block first paint on scheduler setup.
- Ask for notification permission only when the user enables reminders/analysis.
- Audit and remove unused location permissions.
- Request Health Connect scopes progressively and explain the benefit before the system dialog.
- Add data export, delete-all-data, AI-data disclosure, privacy policy, and clear local/cloud storage descriptions.

## Screen-by-screen audit

### Home

**What works**

- Today's calories and current date are immediately visible.
- Major features are discoverable without hidden gestures.
- The Material 3 cards are visually clean in both themes.

**Gaps**

- It reads as a developer menu, not a daily dashboard.
- The large Health Connect prompt dominates repeat use.
- Every action looks equally important.
- Weekly Analysis is disabled with almost no explanation. Because the button is disabled, it cannot execute an explanatory callback.
- Recent meals, goal progress, remaining calories, and the most common add action are not the primary hierarchy.

**Improve**

- Make daily progress and meals the main content.
- Use one compact dismissible setup checklist for target/health setup.
- Show "Log 3 more days to unlock weekly insights" as an active explainer.
- Move secondary destinations to persistent navigation.

Evidence: [`01_home_phone_view.png`](audit_evidence/01_home_phone_view.png)

### Daily Log

**What works**

- The date, target summary, entries, and add action are logically grouped.
- The empty state is understandable.

**Gaps**

- Back and Home actions are redundant.
- Health setup is repeated after already appearing on Home.
- "Set Targets" and the health prompt compete with the log itself.
- The large full-width bottom action resembles a navigation bar.
- Error/loading states are not given persistent recovery UI.

**Improve**

- Use standard back navigation and a single floating/sticky Add action.
- Collapse setup prompts after first dismissal.
- Add meal groups, totals per meal, copy-yesterday, and swipe/edit affordances with undo.

Evidence: [`02_daily_log_empty.png`](audit_evidence/02_daily_log_empty.png)

### Add Entry options

**Gaps**

- Entry methods are spread across the app under different names.
- "Quick Add," AI scan, barcode scan, inventory selection, manual food, and recipes should feel like one task.

**Improve**

- Use one bottom sheet with icon, title, one-line explanation, and recent/frequent foods.
- Keep the user's selected log date visible in the sheet.
- Return consistently to that day's log after completion.

### Select Date

**Gaps**

- The recent-day list has no loading, failure, or true empty state.
- The empty body can look broken while data is unavailable.
- A full-screen destination is heavy for a simple date choice.

**Improve**

- Prefer a calendar bottom sheet with recent dates and calorie indicators.
- Show today, yesterday, and days with entries clearly.
- Announce the selected date to accessibility services.

Evidence: [`04_date_picker.png`](audit_evidence/04_date_picker.png)

### Inventory

**What works**

- Search, category switching, empty-state guidance, and creation actions are discoverable.

**Gaps**

- "Simple," "Compound," and "AI Recipes" mix food structure with creation source.
- "Compound" is technical language.
- The secondary scanner action has low visual emphasis and can appear disabled.
- Empty-state Refresh is rarely useful beside search.
- Search, filters, favorites, recent items, and sort do not form a complete retrieval system.

**Improve**

- Rename to **Foods & Recipes**.
- Use tabs such as **Foods**, **Recipes**, **Favorites**; represent AI provenance as a badge, not a top-level type.
- Add Recent, Frequently logged, sort, and filter controls.
- Use undo after deletion and avoid placing destructive actions near common logging actions.

Evidence: [`05_inventory_empty.png`](audit_evidence/05_inventory_empty.png)

### Add Food

**What works**

- Captures the necessary macro and portion fields.
- Sections distinguish food information from portion information.

**Gaps**

- It is a long manual form with little assistance.
- Required fields and validation are not visibly communicated.
- Labels such as "Calories/100g" are compressed and jargon-like.
- Save/log actions can be far below the fold.
- Blank numeric fields provide no examples or acceptable range.
- Manual parsing needs locale-aware decimal handling.

**Improve**

- Use "Calories (per 100 g)" and consistent units.
- Add inline validation, numeric ranges, examples, and error focus.
- Keep the primary Save/Log action sticky.
- Offer paste/import from a nutrition label.
- Allow switching between per-100-g and per-serving entry while showing the normalized result.

Evidence: [`08_add_food_form_top.png`](audit_evidence/08_add_food_form_top.png)

### Log Entry

**Gaps**

- Editing amount without synchronizing portion metadata contributes to the calculation defect.
- Users need an explicit choice between grams and portions, with a live nutrition preview.

**Improve**

- Show `2 portions × 75 g = 150 g` and the resulting calories/macros before save.
- Preserve the original entry mode but store one canonical amount.
- Provide delete with confirmation/undo and keep the chosen date visible.

### Add Compound / recipe builder

**Gaps**

- "Compound" is implementation language and does not explain the task.
- Component search, amounts, recipe totals, servings, and save behavior create a cognitively dense form.
- Search-driven ingredient addition needs debounce, progress, no-result, and error behavior.

**Improve**

- Call it **Create recipe** or **Mixed food**.
- Use a step or progressive form: Basics → Ingredients → Servings → Review.
- Show live per-recipe and per-serving nutrition.
- Make ingredient rows editable, reorderable, and accessible.

### Barcode Scanner

**What works**

- Successful scans route to a review form before saving.

**Gaps**

- No visible scanning frame, concise instruction, detected-code feedback, or manual barcode fallback.
- Permission-denied and permanently-denied states are not designed.
- "Product not found" is only transient feedback.
- The async completion path can call `setState` after the screen is disposed.

**Improve**

- Add a scan frame, torch label, gallery/manual-code fallback, permission recovery, vibration/visual feedback, and a persistent not-found screen with manual creation.
- Guard every async UI update with `mounted`.

### AI Quick Scan

**What works**

- Camera and gallery choices are obvious.
- Amount and inventory-save choices appear later in the flow.

**Gaps**

- The instruction is repeated in the title, description, illustration, and buttons.
- The large camera illustration appears tappable but is not.
- The first screen has excessive empty space.
- AI-derived name and nutrition need clear review/edit controls, confidence, and limitations.
- A failed request should not discard the image and user-entered values.

**Improve**

- Make the image area itself the primary capture action.
- After analysis, present an editable review form with source, confidence, and "not correct?" actions.
- Preserve the photo and allow retry, manual entry, or cancel.

Evidence: [`07_ai_quick_add.png`](audit_evidence/07_ai_quick_add.png)

### AI Recipe Generator

**What works**

- A staged flow reduces the complexity of image recognition and recipe generation.
- Camera/gallery entry choices are clear.

**Gaps**

- The stepper has numbered circles but no step names and is not useful for orientation.
- The opening headline wraps awkwardly and leaves substantial unused space.
- Users cannot manually add, remove, correct, or quantify detected ingredients before generation.
- "P" represents both Produce and Pantry in the category legend.
- Category meaning relies strongly on color.
- Back exits the flow rather than moving to the previous step; Start Over discards work without confirmation.
- AI failures can reset the process rather than preserving state.

**Improve**

- Name the steps: **Photo**, **Ingredients**, **Preferences**, **Recipes**.
- Make detected ingredients editable with quantity and confidence.
- Add dietary/allergy exclusions before generation.
- Preserve a draft across errors and app backgrounding.
- Confirm destructive restart and support previous-step navigation.

Evidence: [`06_ai_meal_planner.png`](audit_evidence/06_ai_meal_planner.png)

### Custom Recipes

**What works**

- Search, favorites, tags, difficulty, and meal-type concepts are present.

**Gaps**

- A single horizontal chip row hides overflow and provides no scroll affordance.
- Filters are mutually exclusive, so a user cannot combine Favorite + Easy + Dinner.
- User-created tags are not promoted into a complete filter system.
- Fixed filters and AI recipe provenance are mixed with content taxonomy.

**Improve**

- Use a filter sheet with multi-select sections, applied-filter chips, and clear-all.
- Add sorting by recent, frequently logged, calories, and name.
- Make recipe-card primary actions unambiguous: open, log, favorite.

### Custom Recipe Detail

**Gaps**

- The recipe name appears both in the app bar and first card.
- A long title plus favorite, delete, and home icons can crowd small screens.
- Four nutrition values in one row are fragile under text scaling.
- The tag-remove target is too small and lacks explicit semantics.
- "Log to Food Journal" always targets today; users cannot choose another date.
- Editable values do not consistently look editable.

**Improve**

- Use a collapsible title/header and an overflow menu for destructive/secondary actions.
- Use a wrapping 2 × 2 nutrition grid on compact screens.
- Log through the shared date-aware Add flow.
- Make edit mode explicit and enlarge all tag controls.

### Weekly Analysis

**Gaps**

- The Home entry is simply disabled until enough data exists.
- Users are not shown progress toward eligibility in a useful, actionable way.
- AI-generated insights need freshness, source period, limitations, and retry states.

**Improve**

- Keep the screen accessible with a seven-day completion timeline.
- Show which days need data and let users open those days.
- Distinguish deterministic trends from AI commentary.
- Show generated time, date range, and refresh behavior.

### Settings

**Gaps**

- "Settings" appears in both the app bar and the page content.
- Theme, profile, fasting, nutrition targets, AI configuration, and debug tools form one very long page.
- There is no visible data export/delete, privacy, units, language, notification management, or About area.
- API-key handling does not meet secret-storage expectations.
- Debug testing controls must never appear in a release build.

**Improve**

- Use a settings index with separate detail pages:
  - Profile & goals
  - Nutrition targets
  - Fasting
  - Reminders
  - AI & privacy
  - Appearance
  - Units & language
  - Data export/delete
  - About/support
- Explain consequences before recalculating targets or enabling AI analysis.
- Validate profile fields together and show the calculated target source.

## Engineering quality observations

### Static analysis

`dart analyze --format machine` produced 491 findings:

- 8 warnings
- 483 informational findings
- 254 deprecated-member uses
- 196 `avoid_print` findings
- 31 async `BuildContext` findings

There were no analyzer errors, but the async-context findings and deprecations should be resolved before a broad UI refactor. Replace prints with structured, redacted logging.

### Android build

`flutter build apk --debug` completed successfully. The generated artifact was:

`build/app/outputs/flutter-apk/app-debug.apk`

The successful debug build confirms compilation, not runtime correctness or release readiness.

### Startup and platform behavior

The app awaits scheduler initialization and notification setup before `runApp`. This can delay first paint and causes notification permission to appear without feature context. Move nonessential initialization after first render and make it failure-isolated.

The repository declares desktop targets, but the Windows run exposed unsupported database/health/notification plugin paths. If Calorium is Android-only, remove or clearly de-prioritize unsupported targets. If desktop is intended, add platform implementations and tests.

## Recommended delivery plan

### Phase 0 — Correctness and release safety

- Normalize amount/portion storage and migrate old logs.
- Add calculation tests across every food/recipe logging path.
- Rotate/remove the embedded credential.
- Move the Gemini key to secure storage.
- Configure real release signing and unify version metadata.
- Repair widget tests and add service fakes.
- Audit manifest permissions and notification timing.

### Phase 1 — Usability foundation

- Implement persistent navigation and the shared Add flow.
- Redesign Home around today's progress and meals.
- Standardize loading/error/empty/retry states.
- Rework Add Food and recipe creation validation.
- Add AI review/correction and preserved retry.
- Consolidate terminology: Foods, Recipes, Daily Log, Insights.

### Phase 2 — Visual and accessible polish

- Build semantic color, type, spacing, radius, and component tokens.
- Stabilize brand color behavior across Material You devices.
- Add semantics, tooltips, adequate touch targets, and contrast checks.
- Support 200% text, landscape, tablets, foldables, and split screen.
- Localize strings, dates, numbers, units, and food-market configuration.
- Add motion/haptic polish only after usability and accessibility pass.

## Android device retest matrix

After installing/enabling the Android Emulator hypervisor driver, run these checks before release:

### Devices and presentation

- Small phone around 360 × 640
- Pixel 7 / common modern phone
- Tall phone
- 7–8 inch tablet
- 10–12 inch tablet
- Foldable folded and unfolded
- Portrait, landscape, split screen
- Light, dark, and several Material You palettes
- Font sizes 100%, 130%, 160%, 200%
- Display sizes default and largest
- TalkBack with switch/accessibility navigation

### Core nutrition

- Log grams, one portion, multiple portions, and fractional portions.
- Edit between grams and portions.
- Log multiple custom-recipe servings.
- Compare totals on Home, Daily Log, Weekly Analysis, AI analysis, and any export.
- Change/delete foods that already have historical logs.
- Verify decimals, large values, zero, negatives, and invalid pasted text.
- Verify timezone and day-boundary behavior.

### Permissions and hardware

- Camera: allowed, denied, permanently denied, interrupted, no camera.
- Barcode: valid product, unknown product, multiple codes, duplicate detection, offline.
- Health Connect: unavailable, no data, partial scopes, denied, revoked, historical limit.
- Notifications: allowed, denied, exact-alarm unavailable, timezone/DST change, reboot.
- Photo picker: large image, unsupported image, corrupt file, metadata rotation.

### AI and network

- Missing/invalid/revoked API key.
- Offline, timeout, server error, malformed response, quota exceeded.
- App backgrounded/killed during upload.
- Incorrect ingredient/food detection and user correction.
- Allergy/dietary exclusions.
- Privacy disclosure and consent before first image upload.
- No secret or personal image data in logs.

### Lifecycle and data

- Fresh install and onboarding.
- Upgrade from the existing database schema.
- Process death on every multi-step form.
- Low storage and database failure.
- Export, restore, and delete-all-data.
- Large inventory and several years of logs.

## Visual evidence index

- [`01_home_phone_view.png`](audit_evidence/01_home_phone_view.png)
- [`02_daily_log_empty.png`](audit_evidence/02_daily_log_empty.png)
- [`04_date_picker.png`](audit_evidence/04_date_picker.png)
- [`05_inventory_empty.png`](audit_evidence/05_inventory_empty.png)
- [`06_ai_meal_planner.png`](audit_evidence/06_ai_meal_planner.png)
- [`07_ai_quick_add.png`](audit_evidence/07_ai_quick_add.png)
- [`08_add_food_form_top.png`](audit_evidence/08_add_food_form_top.png)

## Definition of “ready for visual polish”

Calorium is ready for a final visual-polish pass when:

- All pages agree on nutrition totals for the same logs.
- Core flows have passing automated tests.
- Release signing/secrets/permissions are corrected.
- The shared navigation and Add model are stable.
- Every async flow has designed loading, error, retry, and offline states.
- Large text and TalkBack do not lose information or actions.

At that point, detailed animation, illustrations, icon refinement, and surface polish will improve an already coherent product instead of masking structural issues.
