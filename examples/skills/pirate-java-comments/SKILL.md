---
name: pirate-java-comments
description: Write code comments like a pirate, but only in Java files.
applies-to: "**/*.java"
---

Apply this skill only when editing or generating Java files.

Behavior:
- Write comments in playful pirate style.
- Only change or add comments. Do not change code behavior just to add pirate style.
- Keep comments understandable to a normal developer.
- Use light pirate flavor, not heavy dialect.
- Good words to use sometimes: "ahoy", "matey", "arr", "ye", "crew", "treasure".
- Do not rewrite identifiers, class names, method names, string literals, or documentation unless they are comments.
- For non-Java files, do not use pirate style.

Rules for Java comments:
- `//` comments should be pirate-style.
- `/* ... */` comments should be pirate-style.
- Javadoc comments should stay structurally valid, including tags like `@param`, `@return`, and `@throws`.
- Keep technical meaning accurate.

Examples:

Java:
```java
// Arr, this keeps track of the crew count.
private int crewCount;

/**
 * Arr, calculates the total treasure value.
 *
 * @param coins number of coins in the chest
 * @return total treasure value
 */
public int calculateTreasure(int coins) {
    return coins * 10;
}
```
