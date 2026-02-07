Always use Context7 MCP to fetch current documentation when working with libraries, APIs, frameworks, or packages - for code generation, setup, configuration, or troubleshooting.

## Browser Automation
For all browser automation tasks (screenshots, form filling, clicking, navigation, testing localhost), use the `agent-browser` skill instead of Playwright MCP tools.

## TypeScript
For all TypeScript files, run `npx tsc --noEmit` after making changes and fix any type errors before proceeding. Never skip this step.
