# Kraken Compiler Architecture

**Status**: Phase 1 Complete — Self-Hosted Foundation

## Pipeline Overview

```
Source (.kr) → Lexer → Parser → Type Checker → Code Generator → C Source → cc → Binary
```

## Phase 1: Lexer (`src/lexer.kr`)

- Character-by-character scanning with `Lexer` state struct
- Immutable state advancement (functional style — returns new `Lexer` on each step)
- 80+ token kinds defined in `src/token.kr` via constant functions
- Keyword lookup via sequential string comparison (no hash table needed at bootstrap)
- Handles: identifiers, integer/float literals, string literals (with escapes), line/block comments, all Kraken operators and delimiters
- Two-character operator disambiguation (`==`, `!=`, `<=`, `>=`, `&&`, `||`, `<<`, `>>`, `+=`, `-=`, `->`, `::`, `..`)

## Phase 2: Parser (`src/parser.kr`)

- Recursive-descent parser producing a flat arena-based AST
- `Parser` state struct tracks position, node count, and error count
- All Kraken constructs: module/import, fn, struct, enum, trait, impl, type alias, class, interface, union
- Statement parsing: let, const, if/else, while, for (C-style), for-in, match, return, break, continue, defer, unsafe
- Expression parsing with operator precedence: assignment → or → and → equality → comparison → addition → multiplication → unary → postfix → primary
- AST nodes use flat `AstNode` struct with integer-based kind, parent/child/sibling links, and bitfield flags

## Phase 3: Type Checker (`src/typechecker.kr`)

- Two-pass analysis:
  1. **Declaration pass** — collect all top-level symbols (forward references)
  2. **Body pass** — validate function bodies, expressions, and type constraints
- Symbol table with scope depth tracking (enter/exit scope)
- 10 symbol kinds: variable, function, struct, enum, trait, type_alias, module, parameter, field, method
- Complete operator type rules:
  - Arithmetic (`+`, `-`, `*`, `/`, `%`): numeric operands, float promotion, string concatenation for `+`
  - Comparison (`==`, `!=`, `<`, `<=`, `>`, `>=`): same-type operands, returns bool
  - Logical (`&&`, `||`): bool operands, returns bool
  - Bitwise (`&`, `|`, `^`, `<<`, `>>`): int operands only
  - Unary (`-`, `!`, `~`): negation on numeric, not on bool, bitwise not on int

## Phase 4: Code Generator (`src/codegen.kr`)

- C code emission backend for bootstrapping
- Type mapping: `int`→`kr_int` (int64_t), `float`→`kr_float` (double), `bool`→`kr_bool`, `str`→`kr_str` (const char*)
- C preamble with runtime stubs (`kr_puts`, `kr_strlen`, `kr_abs`)
- Struct forward declarations and definitions
- Function forward declarations and bodies
- Name mangling: `kr_` prefix, module-qualified (`kr_module_name`)
- Struct/enum mangling: `KrStruct_Name`, `KrEnum_Name`

## Error System (`src/error.kr`)

- `Diagnostic` struct: severity, KRA-prefixed code, message, file, line, column, hint
- 14 diagnostic codes (KRA0001–KRA0014): unexpected char, unterminated string, expected/unexpected token, type mismatch, undefined variable, duplicate declaration, missing return, invalid assignment, unknown type, argument count, unreachable, codegen failure, IO error
- 4 severity levels: error, warning, info, hint

## Design Principles

- **Immutable State** — Compiler passes return new state structs (no mutation, pure functional flow)
- **Flat Arena AST** — Integer-linked nodes, cache-friendly, no recursive heap allocation
- **Bootstrapping First** — C backend exists solely to bootstrap; LLVM backend planned for Phase 2
- **Zero Dependencies** — Self-hosted compiler uses only Kraken stdlib primitives
- **Comprehensive Testing** — 47 tests across all compiler phases
