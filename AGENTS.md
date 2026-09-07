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
  - Given an initial multi-line ASCII seed pattern, each character is replaced by its corresponding normalized block.
  - The blocks are stitched horizontally across pattern columns and vertically across pattern rows to produce the next iteration's output grid.
- **Output Cropping**:
  - Optional viewport bounds (width and height) to truncate the rendered pattern grid horizontally and vertically.

---

## 2. Current Project State

Key components in `src/Main.elm`:
- **TEA Lifecycle & State**: `Browser.sandbox` setup with `Model`, `Msg` (`EditRules`, `EditSeed`, `Step`, `ToggleCrop`, `EditCropWidth`, `EditCropHeight`), `init`, `update`, and `view`.
  - `Model` tracks:
    - `rules : Result String Rules`: Parsed and normalized rule map and dimensions.
    - `rulesInput : String`: Raw text for rule definitions.
    - `seedInput : String`: Raw initial pattern input.
    - `dirty : Bool`: Indicates when rules or seed changed, requiring re-seeding on the next `Step`.
    - `pattern : List String`: Current 2D pattern grid.
    - `cropEnabled : Bool`, `cropWidth : Int`, `cropHeight : Int`: Cropping configuration.
- **Parser & Normalizer**:
  - `rulesP`, `ruleP`, `ruleKeyP`, `lineP`, and `blankLines` using `dasch/parser`.
  - `normalizeRules : Dict Char (List String) -> Rules` computes `blockWidth` and `blockHeight`, padding all replacement blocks to uniform dimensions and returning a `Rules` record (`{ blockWidth : Int, blockHeight : Int, mapping : Dict Char (List String) }`).
- **Rendering Engine & Cropping**:
  - `render : Rules -> List String -> List String` performs 2D character-to-block expansion using `stitchRow` and falls back to blank blocks for unmapped characters.
  - `crop : Int -> Int -> List String -> List String` and `applyCrop : Model -> List String -> List String` truncate pattern lines and characters according to crop settings.
- **Update Logic**:
  - `EditRules` and `EditSeed` update inputs, re-parse rules, and mark `dirty = True`.
  - `ToggleCrop`, `EditCropWidth`, and `EditCropHeight` adjust cropping parameters without resetting the `dirty` state.
  - `Step` executes an iteration: if `dirty = True`, it pads `seedInput` to uniform rectangle, renders the initial pattern, and clears `dirty`; if `dirty = False`, it advances from the previous `pattern`. The rendered grid is cropped if `cropEnabled = True`.
- **View**:
  - Interactive UI with textareas for `rulesInput` and `seedInput`.
  - Cropping controls (checkbox toggle, numeric width and height inputs).
  - "Step" button to advance evaluation.
  - Monospace `<pre>` displaying the rendered pattern.
- **Test Suite**: Embedded `suite : Test` with 33 unit tests covering rule parsing, normalization, 2D rendering (including canonical README example), TEA update logic (dirty/clean stepping), and cropping behavior.

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
- Line 1 of a rule: single character key (e.g., `\` or `/`).
- Subsequent lines: block representation lines (e.g. `\/` then ` \`).
- Rules separated by one or more blank lines (`\n\n`).

### 4.2 Normalization & Padding
1. Find `maxHeight` = maximum number of lines among all rule blocks.
2. Find `maxWidth` = maximum line length (string length) among all lines in all rule blocks.
3. For each block:
   - Pad every existing line on the right with spaces up to `maxWidth`.
   - If line count < `maxHeight`, append full lines consisting of `maxWidth` spaces until line count reaches `maxHeight`.
4. Define default block: `maxHeight` lines, each containing `maxWidth` spaces.
5. Store in `Rules` record: `{ blockWidth = maxWidth, blockHeight = maxHeight, mapping = Dict Char (List String) }`.

### 4.3 2D Iterative Grid Replacement
For a 2D pattern (list of strings `patternLines`):
1. For each line in `patternLines`, map each character `c` to its normalized block (list of `maxHeight` strings of length `maxWidth`), defaulting to the space block for unmapped characters.
2. Transpose / stitch each row of blocks using `stitchRow`:
   - Horizontally concatenate matching line indices across blocks in the row (`List.map2 (++)`).
3. Concatenate all generated rows vertically (`List.concatMap`) to form the new list of strings.

### 4.4 Output Cropping
1. Truncate pattern height: take up to `max 0 cropHeight` lines.
2. Truncate line widths: take up to `max 0 cropWidth` characters per line (`String.left`).
3. Applied after rendering when `cropEnabled` is active.

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
  - TEA update messages and dirty state lifecycle (`EditRules`, `EditSeed`, `Step`).
  - Cropping functions and message handlers (`ToggleCrop`, `EditCropWidth`, `EditCropHeight`).
- **UI & UX**: Provide controls for rules, seed pattern, stepping, cropping parameters, and formatted output display in `<pre>`.
