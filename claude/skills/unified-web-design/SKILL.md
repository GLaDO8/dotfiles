---
name: unified-web-design
description: Comprehensive web design review combining accessibility (WCAG 2.1), visual design, and interface best practices. Use when asked to "review my UI", "check accessibility", "audit design", "review UX", "check my site", or apply design constraints.
metadata:
  author: Combined from vercel/web-interface-guidelines, rams.ai, ui-skills
  version: "1.0.0"
  argument-hint: <file-or-pattern>
---

# Unified Web Design Guidelines

A comprehensive review system combining accessibility compliance, visual design quality, and modern interface best practices.

## How to Use

- `/unified-web-design` - Apply these constraints to any UI work in this conversation
- `/unified-web-design <file>` - Review the specified file against all guidelines below
- `/unified-web-design <pattern>` - Review matching files (e.g., `src/components/**/*.tsx`)

If no files specified, ask the user which files to review or offer to scan the project for component files.

---

## 1. Accessibility (WCAG 2.1)

### Critical (Must Fix)

| Check | WCAG | What to look for |
|-------|------|------------------|
| Images without alt | 1.1.1 | `<img>` without `alt` attribute (use `alt=""` for decorative) |
| Icon-only buttons | 4.1.2 | `<button>` with only SVG/icon, no `aria-label` |
| Form inputs without labels | 1.3.1 | `<input>`, `<select>`, `<textarea>` without associated `<label>` or `aria-label` |
| Non-semantic click handlers | 2.1.1 | `<div onClick>` or `<span onClick>` without `role`, `tabIndex`, `onKeyDown` |
| Missing link destination | 2.1.1 | `<a>` without `href` using only `onClick` |
| Decorative icons exposed | 4.1.2 | Icons without `aria-hidden="true"` |

### Serious (Should Fix)

| Check | WCAG | What to look for |
|-------|------|------------------|
| Focus outline removed | 2.4.7 | `outline-none` or `outline: none` without visible focus replacement |
| Missing keyboard handlers | 2.1.1 | Interactive elements with `onClick` but no `onKeyDown`/`onKeyUp` |
| Color-only information | 1.4.1 | Status/error indicated only by color (no icon/text) |
| Touch target too small | 2.5.5 | Clickable elements smaller than 44x44px |
| Missing async announcements | 4.1.3 | Dynamic content updates without `aria-live="polite"` |
| No skip link | 2.4.1 | Page lacks skip navigation link |

### Moderate (Consider Fixing)

| Check | WCAG | What to look for |
|-------|------|------------------|
| Heading hierarchy | 1.3.1 | Skipped heading levels (h1 → h3) |
| Positive tabIndex | 2.4.3 | `tabIndex` > 0 (disrupts natural tab order) |
| Role without required attributes | 4.1.2 | `role="button"` without `tabIndex="0"` |
| Heading anchors | 2.4.1 | Anchor links missing `scroll-margin-top` |

---

## 2. Focus States

- MUST use visible focus using `focus-visible:ring-*`
- NEVER use `outline-none` without focus replacement
- SHOULD prefer `:focus-visible` over `:focus`
- SHOULD group focus with `:focus-within` for compound controls
- MUST ensure interactive states increase contrast

---

## 3. Forms

### Labels & Structure
- Inputs MUST have `<label>` with `htmlFor` or wrap the control
- Labels MUST be clickable
- Checkboxes/radios: label and control share single hit target

### Attributes
- MUST use `autocomplete` and meaningful `name` attributes
- MUST use semantic `type` (`email`, `tel`, `url`, `number`) and `inputmode`
- SHOULD use `autocomplete="off"` on non-auth fields to prevent password manager triggers
- SHOULD disable spellcheck on emails/codes/usernames

### Behavior
- NEVER block paste in `input` or `textarea` elements
- Submit button stays enabled until request starts; show spinner during request
- MUST display errors inline, next to where the action happens
- MUST focus first error field on submit failure
- SHOULD warn before navigation with unsaved changes

### Placeholders
- Placeholders SHOULD end with `…`
- Placeholders SHOULD show pattern examples where helpful

---

## 4. Animation

### Core Rules
- NEVER add animation unless explicitly requested
- MUST honor `prefers-reduced-motion` with reduced variants
- MUST animate only compositor props (`transform`, `opacity`)
- NEVER animate layout properties (`width`, `height`, `top`, `left`, `margin`, `padding`)
- SHOULD avoid animating paint properties (`background`, `color`) except for small UI

### Timing & Behavior
- SHOULD use `ease-out` on entrance
- NEVER exceed `200ms` for interaction feedback
- MUST pause looping animations when off-screen
- Animations MUST be interruptible by user input
- NEVER use `transition: all`; list properties explicitly

### Technical
- MUST set correct `transform-origin`
- SVG transforms on `<g>` wrapper with proper CSS
- NEVER introduce custom easing curves unless explicitly requested
- SHOULD avoid animating large images or full-screen surfaces
- NEVER animate large `blur()` or `backdrop-filter` surfaces

---

## 5. Typography

### Text Wrapping
- MUST use `text-balance` for headings
- MUST use `text-pretty` for body/paragraphs
- SHOULD use `truncate` or `line-clamp` for dense UI
- Text containers MUST handle overflow via `truncate`, `line-clamp-*`, or `break-words`

### Numeric Display
- MUST use `tabular-nums` (font-variant-numeric) for data columns

### Punctuation
- MUST use ellipsis character `…` not `...`
- SHOULD use curly quotes `"` `"` not straight quotes
- SHOULD use non-breaking spaces for units, commands, brand names
- Loading states SHOULD end with `…`

### Spacing
- NEVER modify `letter-spacing` (`tracking-*`) unless explicitly requested

---

## 6. Layout & Content

### Spacing & Structure
- MUST use consistent spacing values
- MUST use a fixed `z-index` scale (no arbitrary `z-*`)
- SHOULD use `size-*` for square elements instead of `w-*` + `h-*`
- Check for overflow issues and alignment problems

### Viewport
- NEVER use `h-screen`, use `h-dvh`
- Prevent unwanted scrollbars with `overflow-x-hidden`
- Prefer Flex/Grid over JS measurement

### Content Handling
- Flex children need `min-w-0` for truncation to work
- MUST handle empty states gracefully with one clear next action
- Anticipate short, average, and very long user inputs

---

## 7. Components

### Primitives
- MUST use accessible component primitives for keyboard/focus behavior (`Base UI`, `React Aria`, `Radix`)
- MUST use the project's existing component primitives first
- NEVER mix primitive systems within the same interaction surface
- SHOULD prefer `Base UI` for new primitives if compatible with the stack
- NEVER rebuild keyboard or focus behavior by hand unless explicitly requested

### Button States
- MUST include all states: disabled, loading, hover, active, focus
- MUST use `<button>` for actions
- MUST use `<a>`/`<Link>` for navigation (with Cmd/Ctrl+click support)
- Interactive elements MUST have `hover:` state visual feedback

### Form Field States
- MUST include states: error, success, disabled, focus

### Dialogs
- MUST use `AlertDialog` for destructive or irreversible actions
- MUST include confirmation or undo window for destructive actions

### Loading
- SHOULD use structural skeletons for loading states

---

## 8. Performance

### Rendering
- NEVER use `useEffect` for anything that can be expressed as render logic
- NEVER apply `will-change` outside an active animation
- Avoid layout reads during render (`getBoundingClientRect`, `offsetHeight`, etc.)
- Batch DOM reads/writes

### Lists & Inputs
- MUST virtualize lists exceeding 50 items
- Prefer uncontrolled inputs; controlled inputs must be performant per keystroke

### Assets
- Add `<link rel="preconnect">` for CDN/asset domains
- Preload critical fonts with `font-display: swap`

### Images
- `<img>` MUST have explicit `width` and `height`
- Below-fold images MUST use `loading="lazy"`
- Critical above-fold images MUST use `priority` or `fetchpriority="high"`

---

## 9. Navigation & State

- URL MUST reflect state (filters, tabs, pagination, panels as query params)
- Deep-link stateful UI; sync state to URL
- MUST use `<a>`/`<Link>` for navigation with Cmd/Ctrl+click support

---

## 10. Touch & Interaction

- MUST apply `touch-action: manipulation` to prevent double-tap delay
- SHOULD set `-webkit-tap-highlight-color` intentionally
- MUST use `overscroll-behavior: contain` in modals/drawers
- Disable text selection and use `inert` during drag
- SHOULD use `autoFocus` sparingly on desktop; avoid on mobile
- MUST respect `safe-area-inset` for fixed elements

---

## 11. Safe Areas & Dark Mode

### Safe Areas
- Full-bleed layouts MUST use `env(safe-area-inset-*)`

### Dark Mode
- MUST set `color-scheme: dark` on `<html>` (fixes scrollbars/inputs)
- `<meta name="theme-color">` MUST match page background
- Native `<select>` needs explicit `background-color` and `color`
- Check for dark mode inconsistencies

---

## 12. Hydration Safety

- Inputs with `value` need `onChange`; use `defaultValue` for uncontrolled
- Guard date/time rendering against hydration mismatch
- Limit `suppressHydrationWarning` usage

---

## 13. Locale & i18n

- MUST use `Intl.DateTimeFormat` for dates/times
- MUST use `Intl.NumberFormat` for numbers/currency
- Detect language via `Accept-Language` / `navigator.languages`

---

## 14. Content & Copy

- Use active voice
- Title Case for headings and buttons
- Use numerals for counts
- Use specific button labels
- Error messages MUST include fix or next step
- Use second person voice
- Use `&` when space-constrained

---

## 15. Visual Design Quality

### Color & Contrast
- Contrast ratio MUST be at least 4.5:1
- MUST include hover/focus states
- Check for dark mode inconsistencies

### Design Constraints
- NEVER use gradients unless explicitly requested
- NEVER use purple or multicolor gradients
- NEVER use glow effects as primary affordances
- SHOULD use Tailwind CSS default shadow scale unless explicitly requested
- SHOULD limit accent color usage to one per view
- SHOULD use existing theme or Tailwind CSS color tokens before introducing new ones

### Consistency
- Check for mixed font families, weights, or sizes
- Check for inconsistent borders, shadows, or icon sizing
- Check for line height issues
- MUST include missing font fallbacks

---

## 16. Stack Preferences

When building new interfaces:

- MUST use Tailwind CSS defaults unless custom values already exist
- MUST use `motion/react` (formerly `framer-motion`) when JavaScript animation is required
- SHOULD use `tw-animate-css` for entrance and micro-animations in Tailwind CSS
- MUST use `cn` utility (`clsx` + `tailwind-merge`) for class logic

---

## Output Format

```
═══════════════════════════════════════════════════
UNIFIED DESIGN REVIEW: [filename]
═══════════════════════════════════════════════════

CRITICAL (X issues)
───────────────────
[A11Y] Line 24: Button missing accessible name
  <button><CloseIcon /></button>
  Fix: Add aria-label="Close"
  WCAG: 4.1.2

[FOCUS] Line 45: Focus outline removed without replacement
  className="outline-none"
  Fix: Add focus-visible:ring-2

SERIOUS (X issues)
──────────────────
[FORM] Line 67: Input missing label
  <input type="email" name="email" />
  Fix: Add <label htmlFor="email"> or aria-label

[PERF] Line 120: Layout read during render
  const height = ref.current.offsetHeight
  Fix: Move to useLayoutEffect or resize observer

MODERATE (X issues)
───────────────────
[TYPO] Line 89: Using ... instead of …
  Loading...
  Fix: Use ellipsis character (…)

[ANIM] Line 102: Animating layout property
  transition: height 200ms
  Fix: Use transform: scaleY() instead

═══════════════════════════════════════════════════
SUMMARY: X critical, X serious, X moderate
Score: XX/100

Priority: Fix critical issues first, then serious.
═══════════════════════════════════════════════════
```

For files with no issues, output:

```
[filename] ✓ pass
```

---

## Review Process

1. Read the file(s) first before making assessments
2. Be specific with line numbers and code snippets
3. Provide fixes, not just problems
4. Prioritize critical accessibility issues first
5. Group findings by severity
6. Calculate score: Start at 100, deduct 10 for critical, 5 for serious, 2 for moderate

If asked, offer to fix the issues directly.
