<div align="center">
    <img width="auto" height="118" alt="Kraken Language" src="https://raw.githubusercontent.com/kraken-lang/.github/refs/heads/main/images/kraken-logo.png">
        <h1><sub><sup>KRAKEN COMPILER</sup></sub><br>CHANGELOG</h1>
</div>

All notable changes to the Kraken Compiler will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- **Token-Driven Translator** (`src/parser.kr`) — replaced AST-based parser with single-pass token-to-C translator
  - `Translator` struct with token position, output buffer, indent depth, error tracking, and source file context
  - Token access helpers: `tr_at_end`, `tr_kind`, `tr_lexeme`, `tr_line`, `tr_col`, `tr_advance`, `tr_skip`
  - Output emission: `tr_emit`, `tr_emit_indent`, `tr_emit_line` with indentation management (`tr_indent`, `tr_dedent`)
  - Error reporting: `tr_error` with file, line, column context
  - Forward declaration emission (`emit_forward_decls`) — two-pass: struct typedefs then function prototypes
  - Function prototype emission (`emit_fn_prototype`) with Kraken-to-C return type and parameter type mapping
  - Full expression translator with precedence climbing:
    - `translate_or` → `translate_and` → `translate_equality` → `translate_comparison` → `translate_addition` → `translate_multiplication` → `translate_unary` → `translate_postfix` → `translate_primary`
  - Statement translation: `translate_var_decl`, `translate_return`, `translate_if`, `translate_while`, `translate_for`, `translate_expr_stmt`, `break`/`continue`
  - Top-level declarations: `translate_fn` (with C prototype + body), `translate_struct` (with C struct emission)
  - Kraken-to-C type mapping: `type_to_c` (parameter/return types), `type_to_c_value` (default values)
  - Struct literal translation to C compound initializer syntax `(TypeName){.field = value}`
  - Function call translation with `kr_` prefix name mangling
  - Member access (`.`), array subscript (`[]`), and call (`()`) postfix operators
  - `TranslateResult` struct with error count and success flag
  - `join_output()` helper for concatenating `VecString` output into a single string
  - `skip_brace_block()` utility for skipping `{ ... }` blocks during forward declaration scanning

### Changed
- **Lexer** (`src/lexer.kr`)
  - Refactored `tokenize()` to use `VecInt`/`VecString` output parameters (3 params to avoid LLVM codegen limitation with 4+ params + struct returns)
  - Added `push_token()` helper for cleaner token storage into parallel vectors
  - Added `advance_n()` helper for multi-character token advancement
- **Codegen** (`src/codegen.kr`) — trimmed to minimal stubs; the translator now handles C emission directly
- **CLI Driver** (`src/main.kr`)
  - Integrated new translator pipeline: lex → translate → write C → invoke cc
  - Environment variable mode selection via `KRAKENC_MODE` (`emit-c`, `tokens`, `version`, `help`, `targets`)
  - Added `--tokens` mode with `dump_tokens()` for token stream inspection
  - Added `derive_c_path()` and `derive_exe_path()` helpers for output path derivation
  - Version bumped to `0.10.0-beta`

## [0.9.2] - 2026-02-06

### Added
- **Self-Hosted Compiler — Phase 1 Foundation**
  - Full compilation pipeline: Lex → Parse → Type Check → Code Generation
  - Written entirely in Kraken (`.kr` source files)
- **Token Module** (`src/token.kr`)
  - 80+ token kind constants (literals, keywords, operators, delimiters)
  - Keyword lookup table covering all Kraken keywords
  - Token kind classification helpers (`is_keyword`, `is_operator`, `is_delimiter`, `is_type_keyword`)
  - Source location tracking (line, column, offset)
- **Lexer** (`src/lexer.kr`)
  - Full tokenizer with character-by-character scanning
  - Identifier and keyword recognition
  - Integer and float literal parsing
  - String literal parsing with escape sequence handling
  - Line comment (`//`) and block comment (`/* */`) skipping
  - Whitespace normalization
  - Two-character operator disambiguation (e.g. `==`, `!=`, `<=`, `->`, `::`, `<<`)
- **AST** (`src/ast.kr`)
  - 28 statement node kinds (module, import, declarations, control flow, match, etc.)
  - 24 expression node kinds (literals, binary, unary, call, member access, etc.)
  - 14 type kinds (primitives, custom, array, reference, pointer, tuple, function, generic)
  - 8 pattern kinds (literal, identifier, wildcard, enum variant, tuple, range, or, struct)
  - Flat arena-friendly node representation with parent/child/sibling links
  - Node flag system (public, mutable, async, unsafe, variadic, reference)
  - Parameter, Field, MatchArm, TypeNode helper structs
- **Parser** (`src/parser.kr`)
  - Recursive-descent parser for all Kraken language constructs
  - Top-level declaration parsing (module, import, fn, struct, enum, trait, impl)
  - Statement parsing (let, const, if, while, for, for-in, match, return, break, continue, defer)
  - Expression parsing with precedence (assignment, or, and, equality, comparison, addition, multiplication, unary, postfix, primary)
  - Block parsing, parameter list parsing, field list parsing
  - Type annotation parsing
  - ParseResult with node count, error count, and success flag
- **Type Checker** (`src/typechecker.kr`)
  - Two-pass analysis (forward declaration collection, then body checking)
  - Symbol table with 10 symbol kinds (variable, function, struct, enum, trait, type alias, module, parameter, field, method)
  - Scope management (enter/exit scope with depth tracking)
  - Type equality comparison (primitive and custom type matching)
  - Binary operator type rules (arithmetic, comparison, logical, bitwise, string concatenation)
  - Unary operator type rules (negation, logical not, bitwise not)
  - Numeric/boolean/string/integer type classification helpers
  - Error and warning emission with KRA-prefixed diagnostic codes
- **Code Generator** (`src/codegen.kr`)
  - C code emission backend for bootstrapping
  - Kraken-to-C type mapping (`int`→`kr_int`, `float`→`kr_float`, `bool`→`kr_bool`, `str`→`kr_str`)
  - C preamble generation (includes, typedefs, runtime stubs)
  - Forward declaration emission for structs and functions
  - Binary and unary operator emission
  - C identifier name mangling (`kr_` prefix, module-qualified names)
  - Indent management for formatted output
- **Error System** (`src/error.kr`)
  - Diagnostic struct with severity, code, message, file, line, column, hint
  - 14 KRA-prefixed diagnostic codes (KRA0001–KRA0014)
  - Severity levels: error, warning, info, hint
  - Formatted diagnostic printing
- **CLI Driver** (`src/main.kr`)
  - 7 compilation modes: compile, emit-c, check, tokens, ast, version, help
  - Full pipeline orchestration with early-exit on mode
  - CompileResult with token count, node count, error count, warning count
  - ASCII banner and help text
- **Test Suite** (47 tests total)
  - `tests/test_lexer.kr` — 15 tests: empty source, identifiers, literals, keywords, operators, delimiters, comments, whitespace, full function tokenization, keyword lookup, classification
  - `tests/test_parser.kr` — 11 tests: empty parse, functions, structs, variables, module/import, enums, match, parse result, AST nodes, flags, node kind names
  - `tests/test_typechecker.kr` — 12 tests: numeric/boolean/string type checks, type equality, binary arithmetic/comparison/logical/bitwise ops, unary ops, scope management, symbol tracking, program check
  - `tests/test_codegen.kr` — 9 tests: type mapping, binary/unary op emission, name mangling, indent generation, state management, preamble, program generation, dedent floor

### Changed
- Updated README.md with full implementation details, source structure, architecture, CLI usage
- Updated docs/architecture.md with detailed phase descriptions
- Updated docs/roadmap.md with Phase 1 completion status

## [0.9.2] - 2026-02-05

### Added
- Initial repository structure
- README.md with project overview and status
- LICENSE (Apache-2.0)
- CONTRIBUTING.md with contribution guidelines
- Documentation structure in `docs/`
  - architecture.md outlining planned compiler architecture
  - roadmap.md detailing development phases
- .gitignore for Rust projects

### Note

This is a placeholder release to establish the repository. No compiler code is included yet. The actual compiler implementation will begin after v0.8.47 of the main Kraken project is complete.
