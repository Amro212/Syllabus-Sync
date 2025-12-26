---
trigger: model_decision
description: This rule guides the agent when building or editing SwiftUI UI in this repo.
---

# Rule: UI/UX + SwiftUI (Syllabus Sync)

## 1) Design consistency is non-negotiable
- Match the app’s established theme, spacing, typography, and components.
- Reuse existing view components and styles before creating new ones.
- If a reusable component does not exist, create it once and use it everywhere.

## 2) No hallucinations
- Do not invent:
  - design tokens that aren’t in the repo
  - custom fonts we don’t ship
  - assets that do not exist
  - colors that are not defined, unless the user explicitly asks to add new ones
- If the theme is defined in a file (Colors, Theme, DesignSystem), treat it as the only truth.

## 3) “Medium creativity” means
- You can improve layout and micro-interactions, but you cannot change the visual identity.
- Do not redesign the whole screen.
- Avoid trendy UI gimmicks unless the current app already uses them.

## 4) SwiftUI correctness rules
- Prefer native SwiftUI components, no UIKit bridging unless necessary.
- Navigation:
  - Use the navigation approach already used in the repo (NavigationStack or NavigationView).
  - Do not mix navigation patterns in the same flow.
- State:
  - Use @State / @StateObject / @ObservedObject correctly.
  - Do not create multiple sources of truth for the same data.
- Performance:
  - Avoid heavy work in body.
  - Use computed properties and view models for non-trivial logic.
- Accessibility:
  - All tappable controls must have clear labels.
  - Support Dynamic Type where possible.
  - Ensure color contrast is reasonable.
- Layout:
  - Avoid magic numbers. Prefer consistent spacing constants.
  - Test on small screens and large screens.
  - Respect safe areas.

## 5) Placement and file organization
- Put views where the repo expects them.
  - Example: Views/Auth, Views/Dashboard, Components, etc.
- Put reusable UI pieces in Components.
- Put theme and tokens in a single place (Theme/DesignSystem).

## 6) UI testing mindset
For any new screen or significant change, include a quick manual QA list:
- Light mode and dark mode (if supported)
- Small and large text sizes
- Offline or slow network states if applicable
- Loading, empty state, error state
- Navigation back and forth, state persists correctly

## 7) Required UI deliverable format when responding
When the agent proposes a UI change, it must include:
- screen purpose
- main layout structure (sections)
- states (loading, empty, error, success)
- which files will be created/edited
- how it matches the existing theme

## 8) Avoid common SwiftUI mistakes
- Don’t bind directly to optional values without safe handling.
- Don’t create infinite update loops by mutating state inside body.
- Don’t use onAppear for network calls if the screen can reappear frequently without guards.
- Don’t rebuild heavy view models every render.

## 9) Animations
- Only add animations if:
  - they already exist in the app’s style
  - they improve clarity (loading, transitions, feedback)
- Keep animation subtle and short.
