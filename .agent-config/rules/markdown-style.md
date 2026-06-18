---
description: Markdown authoring conventions for docs and rule files.
applies-to: "**/*.md,**/*.mdc,**/*.mdx"
always-apply: false
---

# Markdown style

- Use ATX-style headings (`# Heading`, not underline).
- Use **semantic line breaks**: start a new line at sentence boundaries (and optionally at major clause boundaries), instead of hard-wrapping prose at a fixed column.
  This keeps diffs small and avoids reflow churn when editing.
  Do not hard-wrap mid-sentence to a character limit.
- Prefer fenced code blocks with a language tag over indented blocks.
- Use backticks for file paths, commands, identifiers, and option names.
