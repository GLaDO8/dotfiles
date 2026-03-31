---
paths:
  - "**/*.yaml"
  - "**/*.yml"
  - "**/*.toml"
  - "**/*.xml"
  - "**/docker-compose*"
  - "**/Chart.yaml"
  - "**/values*.yaml"
  - "**/.github/workflows/*"
---

# Config File Processing

- Use `yq` for querying and editing YAML/TOML/XML. Preserves comments and formatting.
- Use `comby` for structural search/replace in config files when patterns span multiple lines.
- Never hand-parse YAML with grep/sed — use `yq` expressions instead.
