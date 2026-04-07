---
name: ui-skills
description: Opinionated constraints for building better interfaces with agents.
---

# UI Skills

When invoked, apply these opinionated constraints for building better interfaces.

## How to use

- `/ui-skills`
  Apply these constraints to any UI work in this conversation.

- `/ui-skills <file>`
  Review the file against all constraints below and output:
  - violations (quote the exact line/snippet)
  - why it matters (1 short sentence)
  - a concrete fix (code-level suggestion)

---

## Stack

- MUST use Tailwind CSS defaults unless custom values already exist or are explicitly requested
- MUST use `motion/react` (formerly `framer-motion`) when JavaScript animation is required
- SHOULD use `tw-animate-css` for entrance and micro-animations in Tailwind CSS
- MUST use `cn` utility (`clsx` + `tailwind-merge`) for class logic

## Components

- MUST use accessible component primitives for anything with keyboard or focus behavior (`Base UI`, `React Aria`, `Radix`)
- MUST use the project's existing component primitives first
- NEVER mix primitive systems within the same interaction surface
- SHOULD prefer [`Base UI`](https://base-ui.com/react/components) for new primitives if compatible with the stack
- MUST add `aria-label` to icon-only buttons
- MUST add `aria-hidden="true"` to decorative icons
- NEVER rebuild keyboard or focus behavior by hand unless explicitly requested
- MUST use `<button>` for actions, `<a>`/`<Link>` for navigation
- MUST include all button states: disabled, loading, hover, active, focus
- Interactive elements MUST have `hover:` state visual feedback
- Interactive states MUST increase contrast (hover/active/focus more prominent)

## Forms

- Inputs MUST have `<label>` with `htmlFor` or wrap the control; labels MUST be clickable
- Checkboxes/radios: label and control share single hit target (no dead zones)
- MUST use `autocomplete` and meaningful `name` attributes
- MUST use semantic `type` (`email`, `tel`, `url`, `number`) and `inputmode`
- SHOULD use `autocomplete="off"` on non-auth fields to prevent password manager triggers
- SHOULD disable spellcheck on emails, codes, usernames
- NEVER block paste in `input` or `textarea` elements
- Submit button stays enabled until request starts; show spinner during request
- MUST display errors inline, next to where the action happens
- MUST focus first error field on submit failure
- SHOULD warn before navigation with unsaved changes
- Placeholders SHOULD end with `…` and show example pattern

## Focus

- MUST use visible focus: `focus-visible:ring-*` or equivalent
- NEVER use `outline-none` without visible focus replacement
- SHOULD prefer `:focus-visible` over `:focus`
- SHOULD group focus with `:focus-within` for compound controls
- MUST ensure interactive states increase contrast

## Animation

- NEVER add animation unless explicitly requested
- MUST honor `prefers-reduced-motion` (provide reduced variant or disable)
- MUST animate only compositor props (`transform`, `opacity`)
- NEVER animate layout properties (`width`, `height`, `top`, `left`, `margin`, `padding`)
- SHOULD avoid animating paint properties (`background`, `color`) except for small, local UI
- SHOULD use `ease-out` on entrance
- NEVER exceed `200ms` for interaction feedback
- MUST pause looping animations when off-screen
- MUST make animations interruptible by user input
- NEVER use `transition: all`; list properties explicitly
- MUST set correct `transform-origin`
- SVG: transforms on `<g>` wrapper with `transform-box: fill-box; transform-origin: center`
- NEVER introduce custom easing curves unless explicitly requested
- SHOULD avoid animating large images or full-screen surfaces
- NEVER animate large `blur()` or `backdrop-filter` surfaces

## Typography

- MUST use `text-balance` for headings and `text-pretty` for body/paragraphs
- MUST use `tabular-nums` for data columns
- SHOULD use `truncate` or `line-clamp` for dense UI
- Text containers MUST handle overflow via `truncate`, `line-clamp-*`, or `break-words`
- MUST use ellipsis character `…` not `...`
- SHOULD use curly quotes `"` `"` not straight quotes
- SHOULD use non-breaking spaces for units (`10 MB`), commands (`⌘ K`), brand names
- Loading states SHOULD end with `…`
- NEVER modify `letter-spacing` (`tracking-*`) unless explicitly requested

## Layout

- MUST use a fixed `z-index` scale (no arbitrary `z-*`)
- SHOULD use `size-*` for square elements instead of `w-*` + `h-*`
- NEVER use `h-screen`, use `h-dvh`
- Prevent unwanted scrollbars with `overflow-x-hidden`
- Prefer Flex/Grid over JS measurement
- Flex children need `min-w-0` for truncation to work
- MUST handle empty states with one clear next action
- Anticipate short, average, and very long user inputs

## Performance

- NEVER apply `will-change` outside an active animation
- NEVER use `useEffect` for anything that can be expressed as render logic
- No layout reads in render (`getBoundingClientRect`, `offsetHeight`)
- Batch DOM reads/writes; avoid interleaving
- MUST virtualize lists exceeding 50 items
- Prefer uncontrolled inputs; controlled inputs must be cheap per keystroke
- Add `<link rel="preconnect">` for CDN/asset domains
- Preload critical fonts with `font-display: swap`
- `<img>` MUST have explicit `width` and `height`
- Below-fold images MUST use `loading="lazy"`
- Critical above-fold images MUST use `priority` or `fetchpriority="high"`

## Design

- NEVER use gradients unless explicitly requested
- NEVER use purple or multicolor gradients
- NEVER use glow effects as primary affordances
- SHOULD use Tailwind CSS default shadow scale unless explicitly requested
- SHOULD limit accent color usage to one per view
- SHOULD use existing theme or Tailwind CSS color tokens before introducing new ones

## Navigation & State

- URL MUST reflect state (filters, tabs, pagination, panels as query params)
- Deep-link stateful UI; sync state to URL
- MUST use `<a>`/`<Link>` for navigation with Cmd/Ctrl+click support
- Destructive actions need `AlertDialog` confirmation or undo window

## Touch & Interaction

- MUST apply `touch-action: manipulation` to prevent double-tap delay
- SHOULD set `-webkit-tap-highlight-color` intentionally
- MUST use `overscroll-behavior: contain` in modals/drawers
- Disable text selection and use `inert` during drag
- SHOULD use `autoFocus` sparingly on desktop; avoid on mobile
- MUST respect `safe-area-inset` for fixed elements
- Full-bleed layouts MUST use `env(safe-area-inset-*)`
- SHOULD use structural skeletons for loading states

## Dark Mode

- MUST set `color-scheme: dark` on `<html>` (fixes scrollbars/inputs)
- `<meta name="theme-color">` MUST match page background
- Native `<select>` needs explicit `background-color` and `color`

## Hydration Safety

- Inputs with `value` need `onChange`; use `defaultValue` for uncontrolled
- Guard date/time rendering against hydration mismatch
- Limit `suppressHydrationWarning` usage

## i18n

- MUST use `Intl.DateTimeFormat` for dates/times
- MUST use `Intl.NumberFormat` for numbers/currency
- Detect language via `Accept-Language` / `navigator.languages`

## Content & Copy

- Use active voice
- Title Case for headings and buttons
- Use numerals for counts
- Use specific button labels (`Save API Key` not `Continue`)
- Error messages MUST include fix or next step
- Use second person voice
- Use `&` when space-constrained
