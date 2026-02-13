<div align="center">
    <img width="auto" height="118" alt="Kraken Language" src="https://raw.githubusercontent.com/kraken-lang/.github/refs/heads/main/images/kraken-logo.png">
        <h1><sub><sup>KRAKEN COMPILER</sup></sub><br>CHANGELOG</h1>
</div>

All notable changes to the Kraken Compiler will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- **Self-Hosting Achieved** — krakenc can now compile itself through multiple generations with byte-identical output (fixed point at gen2→gen3)
  - Multi-file import resolution: `resolve_imports()` reads imported `.kr` files and concatenates sources before tokenization
  - `dir_of()` helper extracts directory from file path for relative import resolution
- **Token-Driven Translator** (`src/parser.kr`) — replaced AST-based parser with single-pass token-to-C translator
  - `Translator` struct with token position, output buffer, indent depth, error tracking, and source file context
  - Token access helpers: `tr_at_end`, `tr_kind`, `tr_lexeme`, `tr_line`, `tr_col`, `tr_advance`, `tr_skip`
  - Output emission: `tr_emit`, `tr_emit_indent`, `tr_emit_line` with indentation management (`tr_indent`, `tr_dedent`)
  - Error reporting: `tr_error` with file, line, column context
  - Forward declaration emission (`emit_forward_decls`) — two-pass: struct typedefs then function prototypes
  - Function prototype emission (`emit_fn_prototype`) with Kraken-to-C return type and parameter type mapping
  - Full expression translator with precedence climbing:
    - `translate_or` → `translate_and` → `translate_bit_or` → `translate_bit_xor` → `translate_bit_and` → `translate_equality` → `translate_comparison` → `translate_shift` → `translate_addition` → `translate_multiplication` → `translate_unary` → `translate_postfix` → `translate_primary`
  - Statement translation: `translate_var_decl`, `translate_return`, `translate_if`, `translate_while`, `translate_for`, `translate_for_in`, `translate_match`, `translate_expr_stmt`, `break`/`continue`
  - Top-level declarations: `translate_fn`, `translate_struct`, `translate_enum`, `translate_impl`
  - Kraken-to-C type mapping: `type_to_c` (parameter/return types), `type_to_c_value` (default values)
  - Struct literal translation to C compound initializer syntax `(TypeName){.field = value}`
  - Function call translation with `kr_` prefix name mangling
  - Member access (`.`), array subscript (`[]`), and call (`()`) postfix operators
  - `skip_brace_block()` utility for skipping `{ ... }` blocks during forward declaration scanning
- **Enum Declarations** — `enum Color { Red, Green, Blue }` → C `typedef int64_t Color;` + `#define Color_Red 0` constants
  - Enum variant expressions: `Color::Red` → `Color_Red` in all expression contexts
  - Optional payload syntax `Some(int)` parsed and skipped (tag-only for now)
- **Match Statements** — `match (expr) { pattern -> { body } }` → C if/else-if chains
  - Integer literal patterns, enum variant patterns (`Color::Red`), wildcard (`_`) as else
  - Optional payload binding syntax parsed and skipped
- **For-In Loops** — `for (let i in 0..n) { }` and `for (i in 0..n) { }` → C `for (int64_t i = 0; i < n; i++)`
  - Supports `..` (exclusive) and `..=` (inclusive) range operators
  - Works with or without `let` keyword in the loop variable declaration
- **Impl Blocks** — `impl TypeName { fn method(self) { } }` → free functions with `kr_TypeName_method` prefix
  - `self` parameter translated to pass-by-value struct parameter
  - Forward declaration prototypes emitted via `emit_impl_prototypes`
- **General String Equality** — `_KR_EQ`/`_KR_NEQ` macros using `__builtin_choose_expr` + `__builtin_types_compatible_p`
  - Compile-time type dispatch: `strcmp` for `char*`, `==` for integers — no runtime overhead
  - ALL `==`/`!=` comparisons go through `scan_eq_ahead` + macro wrapping
  - Handles `string_var == string_var`, `expr == "literal"`, and `int == int` uniformly
- **Bitwise Operators** — `&` (AND), `|` (OR), `^` (XOR) in expression precedence chain between logical AND and equality
- **Shift Operators** — `<<` (left shift), `>>` (right shift) between comparison and addition in precedence chain
- **Compound Assignment** — `/=` and `%=` added to expression statement and for-loop increment handlers (joins `+=`, `-=`, `*=`)
- **Error Recovery** — `skip_to_sync` function skips to next `;` or `}` on unexpected tokens; `translate_statement` guards against EOF/RBRACE
- **Comprehensive Test Suites** — 135 tests across 9 test files, all passing
  - `test_all.kr` — 37 tests: structs, enums, match, for-in, while, impl, bitwise, string comparison, nested control flow
  - `test_advanced.kr` — 31 tests: math, rects, VecInt, string ops, classification, fibonacci, GCD
  - `test_operators.kr` — 23 tests: shift, modulo, compound assignments, bitwise NOT, unary minus, combined expressions
  - `test_stress.kr` — 42 tests: deep nesting, complex expressions, multi-return, BigStruct, enums+match, digit count, reverse int, sum of squares, factorial, complex booleans, VecString join
- **Automated Test Runner** — `run_tests.sh` script compiles and runs all test files, verifies self-hosting fixed point
- **Comprehensive C Runtime Shims** (`src/platform.kr`) — 100+ stdlib function shims in the C preamble
  - VecInt/VecString/VecBytes: full API (new, push, pop, get, set, len, free, clear, reserve, capacity, insert, remove, swap_remove, shrink_to_fit, with_capacity)
  - MapStringInt/MapStringString: open-addressing hash maps (new, set, get, has, delete, len, keys, values, clear, free)
  - String operations: str_eq, str_ne, str_len, str_contains, str_starts_with, str_index_of, str_replace, str_to_lower, str_to_upper, str_trim, str_join, str_split, str_from_char_code, strdup, from_cstr
  - Math: sqrt, pow, floor, ceil, round, sin, cos, tan, log, log10, exp, fabs, fmod, atan2, asin, acos, atan, sinh, cosh, tanh, rand, srand
  - Formatting: fmt_float, fmt_bool, fmt_hex
  - I/O: printf (variadic macro), putchar, getchar
  - Memory: malloc, free, realloc
  - Char classification: isalpha, isdigit, isalnum, isupper, islower, isspace, tolower, toupper
  - Concurrency stubs: mutex_create/destroy/lock/unlock, thread_spawn/join, sleep_ms
  - Test framework: test_section, test_pass, test_fail, test_skip, assert, assert_eq, assert_ne (macro-based with user-override support)
  - Misc: time, atoi, atof, abort
- **Trait Declarations** — `trait Foo { ... }` blocks are now skipped cleanly in all translation passes
- **Type Aliases** — `type Name = Type;` → C `typedef` declaration
- **Const Declarations** — `const NAME: type = value;` → C `#define kr_NAME value`
- **C Keyword Sanitization** — `sanitize_c_name()` renames parameters named `int`, `float`, `double`, `char`, `void`, `const`, etc. to `int_val`, `float_val`, etc.
- **Test Macro Override Pattern** — preamble test functions use `_kr_default_*` with `#define` aliases; `emit_fn_prototype` emits targeted `#undef` when user defines a conflicting function name
- **Array Literals** — `[1, 2, 3]` → C compound literal `(int64_t[]){1, 2, 3}`
- **Additional C Runtime Shims** — file I/O (fgets, fwrite, fread, feof, ferror, fflush, fgetc, fputc, fseek, ftell, rewind), memory ops (memcmp, memcpy, memmove, memset), string search (strstr, strchr, strncpy, strcat, strcpy, strncmp, strtok), UTF-8 validation, async block_on stub, sprintf/sscanf/snprintf macros, rand_int/rand_float/rand_bytes, math convenience (math_abs/min/max/sqrt/floor/ceil/round/sin/cos/tan/pow), logging (log_debug/info/warn/error/set_level), bench_start/bench_end, channel/condvar/pool/executor/cancel_token stubs, println, fopen/fclose, mutex_new/free
- **Generic Syntax Compatibility** — safe turbofish parsing for `name<T>(...)` / `Type<T>{...}` via guarded generic-skip helper that avoids corrupting comparison expressions like `x < 10`
- **Shim Signature Compatibility** — relaxed/compatible signatures for common bootstrap calls (`strlen` variadic shim, `setenv` returning `int64_t`, channel-new variadic macro shim)

### Changed
- **Lexer** (`src/lexer.kr`) — refactored `tokenize()` to use `VecInt`/`VecString` output parameters; added `push_token()` and `advance_n()` helpers
- **Codegen** (`src/codegen.kr`) — trimmed to minimal stubs; the translator now handles C emission directly
- **CLI Driver** (`src/main.kr`) — integrated translator pipeline (lex → translate → write C → invoke cc); `KRAKENC_MODE` env var for mode selection; `--tokens` mode; version bumped to `0.10.0-beta`
- **Two-Pass Forward Declarations** (`emit_forward_decls`) — emit ALL struct/enum typedefs first, then ALL function/impl-method prototypes
- **Two-Pass Program Translation** (`translate_program`) — emit ALL struct/enum definitions first, then ALL function bodies and impl blocks
- **Type Inference** — `let x = expr;` without type annotation emits `__auto_type` (GCC/Clang extension) instead of `int64_t`
- **For Loop Increment** — translator detects assignment operators (`=`, `+=`, `-=`, `*=`, `/=`, `%=`) in for loop increment clause
- **String Type** — `kr_str` typedef changed from `const char*` to `char*`; eliminates all const-qualifier warnings
- **Zero C Warnings** — self-hosted output compiles with `cc` producing 0 warnings, 0 errors
- **Bootstrap Coverage Verification** — current bootstrap compile sweep: `167/226` programs (`73.9%`) with self-hosted compiler

### Fixed
- Struct literal trailing comma caused `}` to be parsed as a field name, corrupting all subsequent function output
- Forward declaration ordering: `Target` and `Diagnostic` structs used in function signatures before their typedefs appeared
- Struct definition ordering: struct bodies emitted after functions that used them by value caused incomplete type errors
- Bitwise AND (`&`) was not in the expression precedence chain, causing `node.flags & flag` to be split into separate statements
- String equality in `resolve_imports` used pointer comparison instead of `strcmp` for function call results
- `scan_eq_ahead` stop conditions now only fire at paren depth 0, preventing `(a & b) != 0` from splitting across expressions
- `scan_eq_ahead` stops at `,`, `:`, `<<`, and `>>` boundaries to prevent crossing struct literal and shift expression boundaries
- `getenv` shim casts `const char*` return to `char*` for consistency with `kr_str` typedef
- `KrVecString` internal storage changed from `const char**` to `char**` to match `kr_str` typedef
- Fixed self-hosting regression caused by over-broad generic/prefix parsing interactions; restored clean fixed-point generation
- Fixed `kr_main` missing-definition linker failures after translator regression by tightening generic-expression handling in primary-expression parsing
- Fixed associated-function call lowering: `Type::method(...)` now emits `kr_Type_method(...)`, while enum-style variant access still emits `Type_Variant`
- Fixed generic container type annotations by erasing `Vec`/`Map` base identifiers to `void*` in `type_to_c`, preventing undeclared C type emissions for `Vec<T>` / `Map<K,V>`
- Fixed top-level `const fn` routing so const-qualified functions are emitted through function prototype/body paths (instead of malformed `#define` output)
- Fixed dotted module import resolution by normalizing module names (`a.b.c`) to relative file paths (`a/b/c.kr`) before import file loading
- Fixed async/defer bootstrap compatibility by lowering `await`/`spawn`/`defer` syntax paths and adding `spawn { ... }` expression fallback handling
- Fixed top-level `extern ...;` handling in translation passes to avoid emitting invalid C statements from declaration-only extern blocks
- Fixed function-type annotation skipping in type positions (`fn(...) -> T`) to prevent residual tokens from corrupting emitted C
- Fixed linker-only bootstrap failures by adding/relaxing compatibility shims (`join`, `timeout`, and `kr_kraken_*` families for stdlib/ffi/bounds/union paths)

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
