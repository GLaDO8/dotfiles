---
name: build
description: Run the build pipeline with type checking and error fixing. Use when building the project, checking for errors, or preparing for deployment.
---

# Build Command

Run the full build pipeline and fix any errors that occur.

## Workflow

1. **Type Check First**
   Run `npx tsc --noEmit` to catch type errors before building.
   If errors found, analyze all errors first before fixing.

2. **Run Linter**
   Run `npm run lint` to catch linting issues.
   Auto-fix with `npm run lint -- --fix` if possible.

3. **Run Build**
   Run `npm run build` for the production build.

4. **Error Resolution Strategy**
   When errors occur:
   - Analyze ALL errors first (don't fix one at a time)
   - Group errors by type/cause
   - Fix root causes, not symptoms
   - Re-run tsc/build after fixes to verify

5. **Success Verification**
   After all fixes:
   - Run final `npm run build` to confirm
   - Report success with any warnings

## Error Prioritization

1. **TypeScript errors** - Fix these first, they often cause build failures
2. **Import/module errors** - Check for missing exports or circular deps
3. **React/JSX errors** - Component prop issues, hook rules
4. **Build errors** - Webpack/Next.js specific issues

## Output Format

```
[1/4] Type checking... ✓ (or ✗ with error count)
[2/4] Linting... ✓ (or ✗ with issue count)
[3/4] Building... ✓ (or ✗ with error details)
[4/4] Verification... ✓ Build successful!
```

## Never

- Don't suppress TypeScript errors with `// @ts-ignore`
- Don't use `any` type to bypass errors
- Don't delete code just to make build pass
- Don't skip the final verification step
