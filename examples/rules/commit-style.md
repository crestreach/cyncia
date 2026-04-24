---
description: Commit message and PR hygiene that applies to the whole repository.
always-apply: true
---

# Commit and PR style

- Write commit subjects in the imperative mood: "Add X", not "Added X" or
  "Adds X". Keep the subject under ~72 characters.
- Use a blank line between the subject and the body. The body explains the
  "why" and non-obvious trade-offs, not a restatement of the diff.
- Group related changes into one commit; do not mix refactors with feature
  work unless the refactor is strictly required for the feature.
- Never commit secrets, credentials, or access tokens. If something was
  committed by mistake, rotate it first, then remove it from history.
- PR descriptions include a short rationale, a summary of user-visible
  changes, and explicit notes for anything risky (migrations, breaking
  API changes, performance-sensitive hot paths).
- Do not force-push to shared branches (`main`, `release/*`) without
  explicit agreement.
