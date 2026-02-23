---
name: unified-web-design
description: Comprehensive web design review combining accessibility (WCAG 2.1), visual design, and interface best practices. Use when asked to "review my UI", "check accessibility", "audit design", "review UX", "check my site", or "review my code for design issues".
metadata:
  author: Combined from vercel/web-interface-guidelines, rams.ai, ui-skills
  version: "2.0.0"
  argument-hint: <file-or-pattern>
---

# Unified Web Design Review

A post-build audit tool for reviewing existing UI code against accessibility, visual design, and interface best practices.

## How to Use

- `/unified-web-design <file>` — Review a specific file
- `/unified-web-design <pattern>` — Review matching files (e.g., `src/components/**/*.tsx`)
- `/unified-web-design` — Ask the user which files to review, or scan for component files

---

## Review Process

1. **Fetch latest rules** (optional): fetch `https://raw.githubusercontent.com/vercel-labs/web-interface-guidelines/main/command.md` for any new rules not yet captured here
2. **Read** the target file(s) completely before making assessments
3. **Assess** each section below, noting violations with line numbers and code snippets
4. **Score** the file: start at 100, deduct per severity
5. **Report** findings in the output format below

---

## 1. Accessibility (WCAG 2.1)

### Critical (-10 each)

| Check | WCAG | What to look for |
|-------|------|------------------|
| Images without alt | 1.1.1 | `<img>` without `alt` attribute (use `alt=""` for decorative) |
| Icon-only buttons | 4.1.2 | `<button>` with only SVG/icon, no `aria-label` |
| Form inputs without labels | 1.3.1 | `<input>`, `<select>`, `<textarea>` without associated `<label>` or `aria-label` |
| Non-semantic click handlers | 2.1.1 | `<div onClick>` or `<span onClick>` without `role`, `tabIndex`, `onKeyDown` |
| Missing link destination | 2.1.1 | `<a>` without `href` using only `onClick` |
| Decorative icons exposed | 4.1.2 | Icons without `aria-hidden="true"` |

### Serious (-5 each)

| Check | WCAG | What to look for |
|-------|------|------------------|
| Focus outline removed | 2.4.7 | `outline-none` or `outline: none` without visible `focus-visible:ring-*` replacement |
| Missing keyboard handlers | 2.1.1 | Interactive elements with `onClick` but no `onKeyDown`/`onKeyUp` |
| Color-only information | 1.4.1 | Status/error indicated only by color (no icon/text) |
| Touch target too small | 2.5.5 | Clickable elements smaller than 44x44px |
| Missing async announcements | 4.1.3 | Dynamic content updates (toasts, validation) without `aria-live="polite"` |
| No skip link | 2.4.1 | Page lacks skip navigation link |

### Moderate (-2 each)

| Check | WCAG | What to look for |
|-------|------|------------------|
| Heading hierarchy | 1.3.1 | Skipped heading levels (h1 → h3) |
| Positive tabIndex | 2.4.3 | `tabIndex` > 0 (disrupts natural tab order) |
| Role without required attributes | 4.1.2 | `role="button"` without `tabIndex="0"` |
| Heading anchors | 2.4.1 | Anchor links missing `scroll-margin-top` |
| Non-semantic HTML | 4.1.2 | Using ARIA roles when semantic elements exist (`<button>`, `<a>`, `<label>`, `<table>`) |

---

## 2. Focus States

| Severity | Check |
|----------|-------|
| Critical | `outline-none` / `outline: none` with no focus replacement |
| Serious | `:focus` used instead of `:focus-visible` (focus ring on click) |
| Serious | Interactive element missing any focus style |
| Moderate | Compound control missing `:focus-within` grouping |
| Moderate | Interactive states don't increase contrast |

---

## 3. Forms

| Severity | Check |
|----------|-------|
| Critical | Input missing `<label>` (via `htmlFor` or wrapping) |
| Critical | `onPaste` + `preventDefault` blocking paste |
| Serious | Missing `autocomplete` or wrong `type`/`inputmode` |
| Serious | Errors not displayed inline next to fields |
| Serious | First error field not focused on submit failure |
| Serious | Checkbox/radio with dead zones between label and control |
| Moderate | Submit button disabled before request starts |
| Moderate | Missing unsaved-changes warning |
| Moderate | Placeholder doesn't end with `…` or show example |

---

## 4. Animation

| Severity | Check |
|----------|-------|
| Serious | Animating layout properties (`width`, `height`, `top`, `left`, `margin`, `padding`) |
| Serious | `transition: all` instead of listing properties |
| Serious | `prefers-reduced-motion` not honored |
| Serious | Animation not interruptible by user input |
| Moderate | Interaction feedback exceeding 200ms |
| Moderate | Looping animation not paused when off-screen |
| Moderate | `will-change` applied outside active animation |
| Moderate | Large `blur()` or `backdrop-filter` animation |

---

## 5. Typography

| Severity | Check |
|----------|-------|
| Moderate | Heading missing `text-balance` or `text-pretty` |
| Moderate | Data column missing `tabular-nums` |
| Moderate | `...` instead of `…` character |
| Moderate | Straight quotes instead of curly quotes |
| Moderate | Text container without overflow handling |
| Moderate | `letter-spacing` modified without explicit request |

---

## 6. Layout & Viewport

| Severity | Check |
|----------|-------|
| Serious | `h-screen` instead of `h-dvh` |
| Serious | Arbitrary `z-*` values instead of fixed scale |
| Moderate | Empty state with no clear next action |
| Moderate | Flex child missing `min-w-0` for truncation |
| Moderate | Missing `overflow-x-hidden` causing scrollbar |

---

## 7. Component States

### Buttons

| State | Check |
|-------|-------|
| disabled | Visual distinction + `disabled` attribute |
| loading | Spinner + prevented double-submit |
| hover | `hover:` visual feedback |
| active | `active:` pressed state |
| focus | `focus-visible:ring-*` |

### Form Fields

| State | Check |
|-------|-------|
| error | Border change + inline error message |
| success | Visual confirmation |
| disabled | Visual distinction + `disabled` attribute |
| focus | Focus ring or highlight |

### Dialogs

| Check |
|-------|
| Destructive actions use `AlertDialog` with confirmation |
| Modals use `overscroll-behavior: contain` |

---

## 8. Performance

| Severity | Check |
|----------|-------|
| Serious | List >50 items without virtualization |
| Serious | Layout reads in render (`getBoundingClientRect`, `offsetHeight`) |
| Serious | `useEffect` for render-derivable logic |
| Moderate | `<img>` missing `width`/`height` (causes CLS) |
| Moderate | Below-fold images missing `loading="lazy"` |
| Moderate | Missing `<link rel="preconnect">` for CDN domains |
| Moderate | Missing `font-display: swap` on fonts |

---

## 9. Visual Design

### Color & Contrast

| Severity | Check |
|----------|-------|
| Critical | Contrast ratio below 4.5:1 |
| Serious | Missing hover/focus states |
| Moderate | Dark mode inconsistencies |

### Consistency

| Check |
|-------|
| Mixed font families, weights, or sizes |
| Inconsistent borders, shadows, or icon sizing |
| Line height issues |
| Missing font fallbacks |

---

## 10. Anti-Patterns Quick Scan

Check for these common anti-patterns:

- [ ] `<div onClick>` / `<span onClick>` without keyboard support
- [ ] `outline: none` / `outline-none` with no focus replacement
- [ ] `h-screen` instead of `h-dvh`
- [ ] `transition: all` instead of explicit properties
- [ ] `...` instead of `…`
- [ ] `useEffect` for render-derivable logic
- [ ] `will-change` applied permanently
- [ ] Images without `width`/`height`
- [ ] Hardcoded date/number formats instead of `Intl`
- [ ] Inputs with `value` but no `onChange`
- [ ] Native `<select>` in dark mode without explicit colors
- [ ] `<img>` without `alt`
- [ ] Arbitrary `z-*` values
- [ ] Gradients or glow effects used without request

---

## 11. Navigation & State

| Severity | Check |
|----------|-------|
| Serious | URL doesn't reflect state (filters, tabs, pagination) |
| Serious | Navigation using `<div onClick>` instead of `<a>`/`<Link>` |
| Moderate | Deep-linkable state stored in `useState` instead of URL |

---

## 12. Touch, Dark Mode & i18n

### Touch
- `touch-action: manipulation` missing on interactive elements
- Modals/drawers missing `overscroll-behavior: contain`
- Text selectable during drag operations

### Dark Mode
- `color-scheme: dark` missing on `<html>`
- `<meta name="theme-color">` doesn't match page background
- Native `<select>` missing explicit `background-color`/`color`

### Hydration
- Inputs with `value` but no `onChange` (use `defaultValue`)
- Date/time rendering without hydration guards
- Excessive `suppressHydrationWarning`

### i18n
- Hardcoded date formats instead of `Intl.DateTimeFormat`
- Hardcoded number formats instead of `Intl.NumberFormat`

---

## Scoring

Start at **100**. Deduct per issue:

| Severity | Deduction |
|----------|-----------|
| Critical | -10 |
| Serious | -5 |
| Moderate | -2 |

Minimum score: **0**.

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

For files with no issues:

```
[filename] ✓ pass — Score: 100/100
```

---

## Guidelines

1. Read the file(s) completely before making assessments
2. Be specific with line numbers and code snippets
3. Provide fixes, not just problems
4. Prioritize critical accessibility issues first
5. Group findings by severity
6. Use category tags: `[A11Y]`, `[FOCUS]`, `[FORM]`, `[ANIM]`, `[TYPO]`, `[LAYOUT]`, `[COMP]`, `[PERF]`, `[VIS]`, `[NAV]`, `[TOUCH]`, `[DARK]`, `[HYDRA]`, `[I18N]`

If asked, offer to fix the issues directly.
