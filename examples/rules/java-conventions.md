---
description: Java coding conventions for source and test files.
applies-to: "**/*.java"
always-apply: false
---

# Java conventions

- Prefer `final` for fields and local variables that do not change.
- Target Java 21+ language features when the project's build allows.
- Use `Optional<T>` for return types that may be absent; never return `null`
  from a method that a caller is expected to dereference.
- Collections: return immutable views (`List.copyOf`, `Map.copyOf`) from
  public APIs unless the caller is expected to mutate.
- Tests: use JUnit 5 (`@Test`, `@ParameterizedTest`). Each assertion should
  fail with a message that identifies the input, not just the output.
- Logging: use Log4j 2 with parameterised messages (`log.info("x={}", x)`),
  not string concatenation. Never log secrets, tokens, or full request
  bodies at `INFO` or above.
- Exceptions: throw specific types (`IllegalArgumentException`,
  `IllegalStateException`, or a domain exception). Do not catch-and-rethrow
  as `RuntimeException` without adding context.
