# Agent Guidelines: Elm L-trees

## 1. Project Overview

**Elm L-trees (kinda)** is an Elm application that performs iterative 2D ASCII character-to-block substitutions on text patterns based on configurable replacement rules. The visual evolution of patterns over successive iterations resembles Lindenmayer systems (L-systems / L-trees).

### Core Mechanics
- **Replacement Rules**: Maps individual characters to multi-line ASCII "blocks".
  - Each rule begins with a single character key on its own line.
  - The subsequent lines define the replacement block.
  - Multiple rules are delimited by empty lines.
- **Uniform Block Normalization**:
  - All replacement blocks are padded with spaces to match the maximum width and maximum height across all defined rule blocks.
  - Any character without an explicit rule (including whitespace in the pattern) is replaced by a blank block of spaces matching the normalized dimensions.
- **Iterative 2D Substitution**:
  - Given an initial multi-line ASCII pattern, each character is replaced by its corresponding normalized block.
  - The blocks are stitched horizontally across pattern columns and vertically across pattern rows to produce the next iteration's output grid.

---

## 2. Current Project State

Key components in `src/Main.elm`:
- **TEA Lifecycle**: `Browser.sandbox` setup with `Model`, `Msg` (`EditRules`, `EditPattern`, `Tick`), `init`, `update`, and `view`. Initial model sets up sample rules and parses them.
- **Parser**: Implemented `rulesP`, `ruleP`, `ruleKeyP`, and `lineP` using `dasch/parser`. Successfully parses single-character rule keys and multi-line ASCII replacement blocks separated by blank lines into `Rules` (`Dict Char (List String)`).
- **View**: Interactive `<textarea>` bound to `model.rulesInput` that triggers `EditRules` on change, along with a `<pre>` tag displaying `Debug.toString model.rules`.
- **Rendering / Engine**: Stubbed `render : List String -> Rules -> List String` returning `[]` (2D grid block normalization and iterative replacement pending implementation).
- **Test Suite**: Embedded `suite : Test` covering rule parsing (canonical README example, single rule, whitespace handling, blank lines, error cases) and TEA message updates.

---

## 3. Project Structure & Key Files

```
elm-l-trees/
├── README.md          # Specification, rule syntax, and evaluation examples
├── AGENTS.md          # Guide and instructions for AI agents working on this repo
├── Makefile           # Task definitions (e.g. `make test`)
├── elm.json           # Elm project definition and package dependencies
├── package.json       # Node package manager config (contains elm-test)
├── pnpm-lock.yaml     # Lockfile for pnpm dependencies
└── src/
    └── Main.elm       # Single-module application containing TEA app, parser, engine, and tests
```

### Dependencies
- **Elm packages**:
  - `dasch/parser` (v3.0.0): Parser combinators for parsing rule definitions.
  - `elm/core` (v1.0.5), `elm/html` (v1.0.1), `elm/browser` (v1.0.2): Standard Elm runtime and UI.
  - `elm-explorations/test` (v2.2.1): Testing framework.
- **Node tools**:
  - `elm-test` (v0.19.2-1 via pnpm): Test runner executing embedded tests in `src/Main.elm`.

---

## 4. Domain & Algorithm Specifications

### 4.1 Rule Syntax
Rules input string format:
```
\
\/
 \

/
 /
/
```
- Line 1 of a rule: single character (e.g., `\` or `/`).
- Subsequent lines: block representation lines (e.g. `\/` then ` \`).
- Rules separated by one or more blank lines (`\n\n`).

### 4.2 Normalization & Padding
1. Find `maxHeight` = maximum number of lines among all rule blocks.
2. Find `maxWidth` = maximum line length (string length) among all lines in all rule blocks.
3. For each block:
   - Pad every existing line on the right with spaces up to `maxWidth`.
   - If line count < `maxHeight`, append full lines consisting of `maxWidth` spaces until line count reaches `maxHeight`.
4. Define default block: `maxHeight` lines, each containing `maxWidth` spaces.

### 4.3 2D Iterative Grid Replacement
For a 2D pattern (list of strings `patternLines`):
1. For each line in `patternLines`, map each character `c` to its normalized block (list of `maxHeight` strings of length `maxWidth`).
2. Transpose / stitch the row of blocks:
   - For row index `r` from 0 to `maxHeight - 1`, concatenate the `r`-th line from each block in the row horizontally.
3. Concatenate all generated rows vertically to form the new list of strings.

---

## 5. Development & Testing Workflow

### Running Tests
Execute the test suite using `make`:
```bash
make test
```
Or directly via pnpm:
```bash
pnpm exec -- elm-test src/Main.elm
```

### Development Guidelines
- **Pure Functional Elm**: Adhere to standard Elm idioms and The Elm Architecture (TEA). Keep state transformations pure and predictable.
- **Parser Combinators**: Use `dasch/parser` for grammar parsing (rule headers, block lines, line breaks).
- **Test-Driven Implementation**: Write unit tests inside `suite` in `src/Main.elm` (or separate test modules if refactored) to verify:
  - Rule parsing (valid rules, empty inputs, edge cases with trailing whitespace or blank lines).
  - Block padding and dimension normalization.
  - Single-step and multi-step pattern evaluation matching `README.md` examples.
  - TEA update messages (`EditRules`, `EditPattern`, `Tick`).
- **UI & UX**: When implementing `view`, provide inputs for rules and initial pattern, controls for stepping/ticking, and formatted output display (e.g. `<pre>` or monospace code element).
