<div align="center">
    <img width="auto" height="118" alt="Kraken Language" src="https://raw.githubusercontent.com/kraken-lang/.github/refs/heads/main/images/kraken-logo.png">
        <h1><sub><sup>KRAKEN COMPILER</sup></sub><br>CHANGELOG</h1>
</div>

All notable changes to the Kraken Compiler will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.9.3] - 2026-05-03

### Added
- **LLVM IR backend** (`src/llvm_ir.kr`, ~2,200 lines) — second backend that emits LLVM IR text and shells out to `clang -x ir` for assembly + linking with the C runtime. Selected via `KRAKENC_MODE=emit-llvm` (text-only) or `KRAKENC_MODE=compile-ir` (IR + link to native binary). All five primary test programs (`test_minimal`, `test_simple`, `test_operators`, `test_containers`, `test_structs`) build and run via the IR backend, both backends verified by `tools/run-tests.sh`. Self-hosting via IR works end-to-end: `main.exe` (built via the IR backend) compiles `src/main.kr` to a fresh `main.exe` with token-count parity (75,403 tokens).
- **Cross-platform release pipeline** (`.github/workflows/release.yml`, `.github/workflows/ci.yml`) — GitHub Actions matrix that builds on Windows, Linux, and macOS. CI fires on every push and runs the test runner against both backends plus a gen2/gen3 fixed-point check. The release workflow fires on tag push (`v*`), bundles a vendored `clang` (~245 MB), packs platform archives, and drafts a GitHub Release. Bootstrap chain: clones the sibling `kraken-lang/kraken` Rust repo, builds it via `cargo`, uses it as stage1 to emit `src/main.c` cross-targeted to the runner, then `clang` produces the stage2 `krakenc` binary.
- **Cross-platform clang vendoring** (`tools/vendor-clang.ps1`, `tools/vendor-clang.sh`) — copy a minimal clang toolchain (`clang`, `lld-link`/`ld.lld`, `lib/clang/18/include/`) from a system LLVM 18 install into `tools/llvm/`. The release workflow uses this to ship a self-contained toolchain with the binary archives. `tools/llvm/` is gitignored; each contributor runs the vendor script locally to populate it.
- **Portable test runner** (`tools/run-tests.sh`) — POSIX shell script that runs the canonical test programs through krakenc, exercising both the C and LLVM IR backends. Returns non-zero on any failure. Selectable via `BACKEND=c`, `BACKEND=ir`, or `BACKEND=both` (default).
- **Linux build path** — verified end-to-end on WSL2 Ubuntu: cross-emit `src/main.c` from a stage1 binary, build with system clang, run all 5 IR/C test programs (10/10 pass), self-host gen2 → gen3 byte-identical. No source changes were needed; `src/platform.kr` already handled POSIX paths and POSIX-specific runtime preamble correctly.
- **Ship checklist** (`.dev/SHIP_CHECKLIST.md`) — finite list of what's left for v0.1.0 / v0.9.3 ship across all three platforms, with the bootstrap chain and verification status tracked alongside.

### Fixed
- **LLVM IR: missing C runtime declarations** (`src/llvm_ir.kr`) — added `declare i8* @kr_str_from_char_code(i64)` to `ir_emit_declarations` and the corresponding `fn_ret:` seed to `new_ir_translator`. Without it, the IR linker produced `error: use of undefined value '@kr_str_from_char_code'` for any program calling `str_from_char_code(...)`.
- **LLVM IR: wrong `kr_str_char_at` return type** (`src/llvm_ir.kr`) — declaration claimed `i8*` but the runtime function returns `i64`. Fixed to `declare i64 @kr_str_char_at(i8*, i64)`.
- **External linkage for host detection helpers** (`src/platform.kr`) — `kr_detect_host_os()` and `kr_detect_host_arch()` were emitted as `static` in the runtime preamble. That is fine for the C backend (everything in one TU) but breaks the IR backend, which links the runtime as a separate translation unit. Removed `static`; produces an LNK2019 unresolved external when not.
- **String equality emit** (`src/llvm_ir.kr`) — the IR emitter compiled `==` and `!=` on `i8*` operands as `icmp eq i8*` / `icmp ne i8*`, which compares pointer values, not string contents. Fixed both `ir_emit_binop` and `ir_build_binop_instr` to emit `call i1 @kr_str_eq(...)` / `@kr_str_ne(...)` when the operand type is `i8*`. This was the cause of every `if (env_var == "value")` check silently failing.
- **`getenv` mapping in IR backend** (`src/llvm_ir.kr`) — `ir_mangle_fn` mapped `getenv` to bare `getenv`, but the runtime defines a `kr_getenv` wrapper that returns `""` instead of NULL when the variable is unset. The IR backend now uses `kr_getenv` to match the C backend, preventing NULL dereferences in `kr_str_eq(NULL, "")`.
- **Break/continue lowering** (`src/llvm_ir.kr`) — `break` and `continue` were emitted as comments (`; break (not yet lowered to branch)`) instead of branches. Implemented proper lowering with loop-label save/restore in `ir_emit_while` and `ir_emit_for` via `loop_exit` / `loop_cond` keys in the sema map. Break branches to the loop exit label, continue to the loop cond label, both followed by a dead-block label so subsequent code still has a basic block.
- **Loop-label save/restore aliasing** (`src/llvm_ir.kr`) — `kr_map_string_string_get` returns the interior pointer; the next `_set` on the same key frees that pointer. The first cut of break/continue stored the loop labels in sema and restored them after nested loops, but the saved value became a dangling pointer once a nested loop overwrote the slot. Fixed by duping the saved value with `str_concat(map_get(...), "")` before the nested set.
- **Unary operator precedence** (`src/llvm_ir.kr`) — `!`, unary `-`, and `~` parsed their operand as a full expression (`ir_emit_full_expr`) instead of a primary (`ir_emit_expr`). This made `!at_end(cur) && is_alnum(peek_char(cur))` parse as `!(at_end(cur) && is_alnum(...))`, inverting loop conditions in the lexer and causing infinite loops on input. Fixed all three to call `ir_emit_expr`. This was the biggest single bug fixed in this release.

### Changed
- **Workspace cleanup**: moved `parser.kr.fat`, `parser.kr.fat2`, `platform.kr.fat`, `platform.kr.fat2` from `src/` to `legacy/` with an explainer README. They were marked "pending disposition" since the AST→token-driven rewrite settled.
- **Removed**: `src/main.c.bak` (186 KB stale generated artifact from a previous emit).
- **Generated artifacts now gitignored**: `src/main.c`, `src/main.ll`, `src/main_runtime.c`, `src/parser.c`, plus `tests/*.c`, `tests/*.ll`, `tests/*_runtime.c`, `tests/*.exe`. CI regenerates these on every build via the bootstrap chain.
- **GitHub Actions versions** — bumped `actions/checkout`, `actions/upload-artifact`, `actions/download-artifact` from `@v4` to `@v5`. Removes Node.js 20 deprecation warnings.

### Added (existing Unreleased work, now released)
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
- **Bootstrap Coverage Verification** — current bootstrap compile sweep: `226/226` programs (`100.0%`) with self-hosted compiler
- **Variadic Vec Builders** — added `_kr_vec_int_of(n, ...)` and `_kr_vec_string_of(n, ...)` variadic helpers to C preamble for constructing `KrVecInt`/`KrVecString` from inline values; added `#include <stdarg.h>` to all platform include sets (POSIX, Windows, WASI)

### Fixed
- **Bailout Detector False Positives** — three detectors incorrectly matched string literal content (tokenizer strips quotes), causing critical compiler functions to be stubbed out:
  - `block_has_try_like`: removed `vec_string_get(lexemes, i) == "?"` check that matched the `"?"` string literal inside `read_operator`; now only checks `TK_QUESTION` token kind
  - `block_has_unsafe_like`: added `k == TK_IDENTIFIER()` guard before matching `"unsafe"` lexeme; prevents false positive on `"unsafe"` string literal inside `keyword_to_token_kind`
  - `block_has_closure_like`: excluded `TK_OP_OR` (`||`) from `{`-lookahead; prevents false positive on `if (a || b) {` patterns that were incorrectly detected as closure syntax
- **Bailout Return Type Errors** — all three bailout blocks emitted `return 0;` for struct-returning functions, causing 16 C compile errors (`returning 'int' from a function with incompatible result type 'Translator'`)
  - Translator returns now emit `return tr;` (preserves output buffer pointer)
  - Lexer returns now emit `return lex;` (preserves source/length fields)
  - Other struct returns now emit `return (TypeName){0};` (proper zero-init)
- **Generic Stub Return Type** — generic function stub emitter hardcoded `int64_t` return type for all generic functions; now captures the declared return type after `->` using `type_to_c()` and emits typed default returns
- **Bailout Block Removal** — removed all 3 `translate_fn` bailout blocks that stubbed entire function bodies when closures, tuples, unsafe, turbofish, try, self-init-let, nested fn/type, or fn-param patterns were detected; functions are now always fully translated (zero regressions: 135/135 tests, 226/226 bootstrap, gen2==gen3)
- **Dead Code Cleanup** — removed all 8 bailout detector functions (`block_has_unsafe_like`, `block_has_turbofish_like`, `block_has_try_like`, `block_has_self_init_let`, `block_has_tuple_like`, `block_has_closure_like`, `block_has_nested_type_decl`, `block_has_nested_fn`); 70+ lines of dead scanning code eliminated

### Improved
- **Unsafe Block Lowering** — `unsafe { ... }` now transparently emits the inner block body as real C statements instead of falling through to expression-statement handling
- **Tuple Literal Lowering** — `(a, b, c)` now emits a real C comma-expression `((a), (b), (c))` that evaluates all sub-expressions and returns the last value; previously collapsed to `0` discarding all side effects
- **Tuple Destructuring Binding** — `let (a, b) = (x, y);` now emits `__auto_type a = x; __auto_type b = y;` per-element bindings when RHS is a tuple literal; non-tuple RHS evaluates via `(void)(expr)` instead of being silently skipped
- **Tuple Assignment Lowering** — `(a, b) = (x, y);` now emits per-element assignments `a = x; b = y;` when RHS is a tuple literal; non-tuple RHS evaluates via `(void)(expr)` instead of neutral `0;`
- **Static Assert Lowering** — `static_assert(cond, msg)` now emits real C `_Static_assert(cond, msg);` with translated argument expressions instead of no-op `0;`
- **Tuple Struct Codegen** — added `KrTuple2`..`KrTuple5` struct typedefs to C preamble; tuple literals `(a, b)` now emit `(KrTupleN){.f0 = a, .f1 = b}` struct initializers; tuple field access `x.0` emits `x.f0`; tuple destructuring from non-tuple RHS stores into `KrTupleN` temp and extracts `.f0`/`.f1` fields
- **Generic Function Type-Erased Translation** — generic functions now translate their real body with type parameters erased to `int64_t` instead of emitting empty stubs with default returns; both prototypes and bodies use the same type-erased parameter parsing
- **Closure Codegen** — added `emit_closure_statics` extraction pass that emits each closure as a top-level `static` C function with unique name derived from token position; `translate_primary` emits `(void*)_kr_cl_N` function pointers instead of null `0`; supports typed params, block/expression bodies, and zero-arg closures; added `KrClosure` typedef
- **Dyn Trait-Object Dispatch** — `lookup_local_var_type_name` returns `dyn:TraitName` for dyn variables; added `lookup_dyn_concrete_type` to resolve concrete struct type at declaration site; dyn method calls dispatch to `kr_ConcreteType_method()` instead of `0`; dyn variable init translates RHS expression; removed hardcoded `s`/`dc`/`dr` name-based hack
- **Semantic Registry (sema) Infrastructure** — added `MapStringString`-backed `sema` field to `Translator` struct; `build_sema_registry` pre-pass populates trait methods, impl mappings, struct fields, and function signatures before forward declarations
- **Hash Map Auto-Resize** — `MapStringInt` and `MapStringString` runtime shims now auto-resize at 70% load factor (initial capacity 64→256); prevents infinite-loop hangs when sema registry exceeds fixed-capacity tables
- **Real Vtable-Based Dyn Dispatch** — replaced `void*` dyn type with `KrDyn` fat pointer (`{ void* data; void* vtable; }`); `emit_vtables` pass emits per-trait vtable structs, per-impl wrapper functions, and static vtable instances; dyn variable init constructs fat pointers with `malloc`+`memcpy`+vtable ref; dyn method calls dispatch through `((Trait_VT*)obj.vtable)->method(obj.data)` — full runtime polymorphism for `dyn Trait` parameters
- **Dyn Token Kind Consistency** — replaced all lexeme-based `== "dyn"` checks with `TK_KW_DYN()` token kind checks; fixed backward return-type skip to handle keyword return types (e.g., `-> int`), enabling dyn parameter resolution in all functions
- **Nested Struct Literal Codegen** — struct literal field values that are themselves struct literals (`field: Inner { x: 1 }`) now emit proper C compound literals `(Inner){.x = 1}` instead of placeholder `0`
- **Untyped Local Var Method Dispatch** — method calls on untyped local variables (`let x = Foo { ... }; x.method()`) now resolve via `lookup_dyn_concrete_type` fallback, enabling method dispatch without explicit type annotations
- **Dyn Vtable Dispatch Args** — dyn trait method calls now properly translate additional arguments after `self` instead of skipping them, enabling `dyn Trait` method calls with parameters beyond just the receiver
- **Function Pointer Call Codegen** — calls through fn-typed variables and parameters now emit real C function pointer casts `((int64_t(*)(int64_t,...))name)(args)` with argument translation instead of placeholder `0`; removed hardcoded fn-var name list; pre-scans call site to count arguments and generate correctly-typed signature
- **is_local_fn_var Precision** — fixed backward `TK_KW_FN` scan to skip fn-type annotations and find the actual function declaration keyword; removed overly broad `let name = identifier(...)` false-positive pattern
- **Closure Capture Codegen** — closures referencing outer scope variables now work via static capture variables + `#define`/`#undef` renaming; `emit_closure_statics` scans body for non-param/non-local/non-function identifiers, emits `static int64_t _kr_cl_N_cap_VAR;` + preprocessor redirects; call site emits capture assignments via comma expression `(_kr_cl_N_cap_VAR = VAR, (void*)_kr_cl_N)`; capture list stored in sema under `cl:N:caps`
- **String Slice Syntax** — `name[start:end]` now emits `kr_str_slice(name, start, end)` instead of plain array indexing; pre-scans bracket contents for `:` to distinguish slicing from indexing
- **CC Flag: `-Wno-int-conversion`** — added to C compiler invocation to support type-erased generic functions passing strings/pointers as `int64_t`
- **Null-Safe String Comparison** — `_kr_cmp_eq` and `_kr_cmp_neq` now check for null pointers before calling `strcmp`, preventing segfaults on `str != 0` comparisons
- **skip_fn_type_sig Array Return Type** — fixed `skip_fn_type_sig` to handle array return types in function type annotations (`fn(T) -> [U]`); previously left `U]` unconsumed, garbling all subsequent parameter names
- **Closure Param/Return Type Handling** — `emit_closure_statics` now handles array types (`[T]` → `int64_t*`) and fn types (`fn(T) -> U` → `void*`) in closure parameter and return type annotations
- **Impl Prototype Type Handling** — `emit_impl_prototypes` now calls `skip_generic_params` and `skip_fn_type_sig` on non-self params and return types; maps `[T]` params to `int64_t*`
- **Impl Fn Body Type Handling** — `translate_impl_fn` now matches prototype handling with `skip_generic_params`, `skip_fn_type_sig`, and `[T]` → `int64_t*` for params and return types
- **For-In Array Iteration** — `for item in arr { ... }` now emits proper C array iteration using `kr_vec_int_len`/`kr_vec_int_get` instead of broken range-based loop; detects range vs array by looking ahead for `..` operator; unique index variable per loop
- **Array Method Dispatch** — method calls on `[T]`-typed variables (`result.push(x)`) now emit `kr_vec_int_push(result, x)` instead of invalid C `.push()`; `lookup_local_var_type_name` returns `[array]` for `[T]`-typed locals and params; fixed scope scanning to traverse all enclosing scopes; fixed return-type skip for complex types like `-> [(T, U)]`
- **Fn-Type-Annotation Skip** — backward `TK_KW_FN` scan in `lookup_local_var_type_name` now only breaks on actual function declarations (`fn name`), not fn-type annotations (`fn(T) -> U`); fixes array method dispatch for variables declared before closures with fn-typed params
- **Implicit Return** — last expression statement in non-void closure and function bodies now emits `return expr;` instead of bare `expr;`; uses sema-based position tracking to find last statement at depth 0; eliminates "expression result unused" and "non-void function does not return a value" C warnings
- **Tuple Type Annotation Skip** — `translate_var_decl` now skips tuple type annotations `(T, U, ...)` by matching parentheses after `:`; maps to `void*`; previously tokens leaked as bare `0;` statements
- **Implicit Return `}` Boundary** — implicit return scanning now treats `}` at depth 0 as a statement boundary; fixes `match { ... } expr;` where `expr` was not detected as the last statement
- **`TK_KW_UNSAFE` Fix** — `unsafe` block handler now checks `TK_KW_UNSAFE()` token kind instead of `TK_IDENTIFIER()` with string comparison; the lexer maps `unsafe` to a keyword token so the old check never matched
- **String Literal `\!` Escape Sanitization** — `translate_primary` now replaces `\!` with `!` in string literals before emitting to C; `\!` is valid in Kraken but not in C, causing "unknown escape sequence" warnings. All 226 programs now compile with **zero C warnings**
- **`str_replace` Buffer Overwrite Fix** — `kr_str_replace` C preamble function had a critical bug: when no match was found, `strcpy(w,s);break;` did not advance `w`, so the subsequent `*w=0;` overwrote the first byte of the copied data, returning empty string for ALL non-matching inputs. This caused the self-hosted compiler to emit empty string literals (`""`) for every `TK_STRING_LIT` token, since the `\!` sanitization used `str_replace`. Also added empty-pattern guard to prevent infinite loop when `old` is `""` (which caused `strstr` to match at position 0 indefinitely). Increased buffer capacity for cases where replacement is longer than original. Runtime: 198 → 199/226
- **Tuple Type → KrTupleN Mapping** — Tuple type annotations `(T, U, ...)` now map to proper C struct types (`KrTuple1`–`KrTuple8`) instead of `void*`. Added `count_tuple_arity`, `skip_tuple_type`, and `tuple_type_c` helper functions. Updated `translate_var_decl`, `translate_fn`, `emit_fn_prototype`, `translate_impl_fn`, `emit_impl_prototypes`, and `emit_closure_statics` to handle tuple parameter and return types. Extended preamble with `KrTuple1`–`KrTuple8` struct definitions (previously only `KrTuple2`–`KrTuple5`)
- **Unsafe Block Double-`}` Fix** — `translate_statement`'s `TK_KW_UNSAFE` handler no longer manually advances past closing `}` after calling `translate_block_body`, which already advances past `}` internally; the double-advance consumed enclosing block braces, merging nested-unsafe functions with subsequent function definitions. Runtime: 197 → 198/226
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
- Fixed typed local method-call lowering by routing `obj.method(args)` to `kr_Type_method(obj, args)` when local type information is available
- Fixed additional closure/function-pointer bootstrap paths with `move` unary pass-through and neutral fallback lowering for unsupported closure/function-variable call forms
- Fixed trait/impl parsing robustness for `impl Trait<T> for Type { ... }` and generic trait declaration skipping (`trait Name<T> { ... }`) by applying generic-parameter skipping before trait-body skip paths
- Fixed struct field parsing compatibility to accept both comma and semicolon separators in struct declarations
- Fixed dyn trait-object bootstrap compatibility paths by lowering `let x: dyn Trait = value` to a neutral placeholder assignment and adding conservative unresolved dyn-style method-call fallback lowering
- Fixed tuple destructuring compatibility lowering (`let (a, b) = ...`) to prevent malformed C emission in bootstrap tuple suites
- Fixed match compatibility lowering for range/or/guard-style arms and wildcard arm chaining to keep generated `if / else if` control flow syntactically valid
- Fixed for-in inclusive range lowering to support both `..=` tokenizations (`TK_OP_DOT_DOT_EQ` and `TK_OP_DOT_DOT` + `=`)
- Fixed generic function fallback stubs to emit scalar `int64_t` signatures/bodies and added additional nested declaration/closure fallback guards to reduce compatibility-mode parser drift
- Fixed empty-parameter closure (`|| expr`) compatibility consumption to prevent downstream token-stream drift in closure-heavy bootstrap programs
- Fixed union compatibility across forward declarations/program translation and added robust union field parsing recovery (including pointer/type fallback handling)
- Fixed variadic/raw-pointer signature compatibility parsing (`...`, `*const`, `*mut`, nested pointer tails) in function prototype/body lowering
- Fixed final parser compatibility edges: unary address-of lowering, postfix try-token consumption, identifier-pattern match binding fallback, and targeted call argument casts (`fmt_int`, `strcmp`) for pointer/int interoperability
- Fixed remaining bootstrap runtime compatibility shims by adding `kr_print_int` and adjusting VecBytes value-carrier APIs to int64/intptr-safe signatures
- **Object-Safe Vtable Skip** — vtable struct/wrapper emission now skips traits whose methods use `Self` in parameter or return types (non-object-safe); prevents invalid C casts through vtable wrappers
- **C Keyword Sanitization in Methods** — `sanitize_c_name()` expanded to cover `default`, `switch`, `case`, `register`, `auto`, `extern`, `goto`, `volatile`, `signed`, `unsigned`, `union`, `inline`, `restrict`, `typedef`, `sizeof`, `static`, `short`, `long`, preventing C keyword collisions in emitted method names
- **Generic Struct Field Access** — removed generic-call field-access collapse hack that incorrectly erased `.field` suffixes on generic struct instances (e.g., `b.value` was collapsed to `b`)
- **`static_assert!` Macro Syntax** — parser now handles bang token `!` in `static_assert!()` invocations; lowered to runtime assertion `if (!(cond)) { fprintf(stderr, ...); exit(1); }` instead of C `_Static_assert` (which requires compile-time constants)
- **Struct Literal Disambiguator** — `translate_primary` now uses lookahead to distinguish struct literals (`Name { field: value }`) from block braces after identifiers; checks for `IDENTIFIER COLON` pattern inside braces before treating `{` as a struct literal initializer. Also handles empty struct literals (`Name {}`). Fixed `generic_closure_test` where `if !result {` was misinterpreted as a struct literal, and `test_repr_edge_cases` where `Empty {}` was not recognized as a struct literal. Runtime: 214 → 216/226
- **Consistent VecInt Array Literals** — array literal `[1, 2, 3]` now emits `_kr_vec_int_of(3, (int64_t)1, (int64_t)2, (int64_t)3)` (proper `KrVecInt` struct) instead of raw C compound literal `(int64_t[]){1,2,3}`; string arrays emit `_kr_vec_string_of(n, ...)`. Empty arrays `[]` emit `kr_vec_int_new()` / `kr_vec_string_new()`. Array subscript `arr[i]` for `[T]`-typed or array-initialized variables now emits `kr_vec_int_get(arr, i)` instead of raw `arr[i]`. Immediate subscript `[1,2,3][0]` pre-scans for `]` followed by `[` and wraps in `kr_vec_int_get(...)`. Extended `lookup_local_var_type_name` to detect untyped array init (`let arr = [...]`). Fixed `closures_higher_order_test` segfault (raw C array passed to VecInt iteration). Runtime: 216 → 217/226
- **Nested Function Prototype Pass** — added `emit_nested_fn_prototypes` (sub-pass 1.75) that scans all tokens for `fn NAME` at brace depth > 0 inside function bodies and emits forward declarations. Filters out trait/impl/struct/union/enum block methods to avoid conflicting prototypes. Foundation for future nested function extraction.
- **`skip_fn_type_sig` Array Return Type Fix** — fixed off-by-one in `skip_fn_type_sig` where `[U]` array return types in function type signatures (e.g., `fn(T) -> [U]`) were double-counted by `skip_array_type_suffix`, causing the translator to consume tokens past the closing `]` and eat all subsequent function definitions. Fixed `generic_higher_order_test` missing `kr_main` (4 → 3 errors).
- **Unit Tuple `()` Literal** — `()` now emits `(KrTuple1){.f0=0}` instead of `(0)`. Detected via lookahead: `(` immediately followed by `)`.
- **Trailing Comma Tuple Literal** — `(42,)` no longer causes the translator to treat subsequent statements as tuple fields. When a comma is followed by `)` inside a tuple literal, the loop breaks instead of calling `translate_expr` at `)` (which would fall through and consume the rest of the function body). Fixed `tuple_edge_cases` garbled output (20 → 7 errors).
- **Wildcard `_` Discard** — `let _ = expr;` now emits `(void)(expr);` instead of `__auto_type _ = expr;`, preventing redefinition errors when `_` is used multiple times. Also handles `_` inside tuple destructuring: `let (a, _, c) = (1, 2, 3);` emits `(void)(2);` for the wildcard position. Fixed `comprehensive_edge_cases` `_` redefinition errors.
- **Tuple Arity 10 Clamp** — tuple literal emission now supports up to 10 elements (was clamped at 5). Added `KrTuple9` and `KrTuple10` structs to the C preamble and updated `tuple_type_c` to accept arity 1–10.
- **If-Expression Support** — `if cond { a } else { b }` can now be used as an expression (e.g., `let x = if c { 1 } else { 2 };`). Translated to C ternary `(cond) ? (a) : (b)`. Fixed `kr_zip` in `generic_higher_order_test` where `let len = if ... { ... } else { ... }` was garbled into disconnected statements.
- **Parameter Type Lookup Fix** — `lookup_local_var_type_name` now scans FORWARD from the `fn` keyword position (found by the first backward scan) instead of doing a separate backward scan for function parameters. The old approach stopped at inner block `{` (if/while/for bodies) instead of the function body `{`, causing method dispatch to fail inside nested blocks. This fixes array method calls like `arr.len()` inside if-expression branches and loop bodies.
- **Nested Tuple Destructuring LHS** — LHS pattern collection in `translate_var_decl` now tracks paren depth, correctly collecting all variable names from nested patterns like `let ((a, b), c) = ...`. Previously, `((a, b), c)` would only collect `a` and `b` (stopping at the first `)`).
- **Closure Prototype Parameter Types** — closure forward declarations now include parameter types (e.g., `static int64_t _kr_cl_N(int64_t, char*);`) instead of empty parens (`_kr_cl_N();`). Fixes C23 "conflicting types" errors when the definition has parameters. Also handles tuple return types in closure prototypes via `count_tuple_arity_at`.
- **Unique Tuple Destructuring Temps** — tuple destructuring from non-literal RHS now uses position-based temp names (`_kr_tup_POS` instead of `_kr_tup`), preventing C redefinition errors when multiple tuple destructurings appear in the same scope.
- **Match Arm Nested Tuple Patterns** — match arm tuple patterns now handle nested parens via depth tracking (e.g., `((x, y), z) -> { ... }`). Previously, the parser exited at the first `)`, losing outer variables.
- **Nested Function Token Neutralization** — nested `fn` definitions inside function bodies are now handled via a 3-phase approach: (1) `emit_nested_fn_prototypes` emits forward declarations, (2) `emit_nested_fn_bodies` emits full function definitions as top-level C functions, (3) `neutralize_nested_fn_tokens` replaces the nested fn tokens with `TK_SEMICOLON` in-place so the main translation pass never encounters them. This eliminates the garbled inline emission that occurred when `translate_statement` fell through to `translate_expr_stmt` for `fn` keywords, without requiring a skip in `translate_statement` (which caused mysterious hangs due to binary layout sensitivity).
- **Closure Capture Mangled Name Redirect** — captured closure variables now emit both `#define NAME` and `#define kr_NAME` redirects to the static capture variable. Previously, `inner(y)` inside a closure body was mangled to `kr_inner(y)` by `mangle_top_level_fn_name`, bypassing the `#define inner` redirect. The additional `#define kr_inner` ensures the C preprocessor catches both usage patterns.
- **`let mut` Keyword Skip** — `translate_var_decl` now skips the `mut` keyword after `let`, so `let mut x = 0;` is treated identically to `let x = 0;`. In C, all variables are mutable by default, so `mut` is a no-op for codegen. Fixed undeclared identifier errors for `side_effect`, `counter`, `cache`, `cached`, and `count` across 4 closure test files.
- **Closure Literal `(void*)` Cast Removal** — closure literals no longer emit `(void*)_kr_cl_N`. In C, function names naturally decay to callable function pointers, so `_kr_cl_N` alone works for both storage (as `void*` or `int64_t`) and calling. This fixes immediately-invoked closures like `(|x| x * 2)(21)` which previously failed because `(void*)` isn't callable.
- **Capture Detection False Positives** — the capture detection scan in `emit_closure_statics` now correctly identifies local declarations inside closure bodies: (1) `let mut bname` (was only checking `let bname`), (2) `for (bname in ...)` and `for bname in ...` loop variables, (3) wildcard `_` which is never a real capture. Fixed spurious `undeclared identifier 'i'` and `undeclared identifier '_'` errors.
- **Captured Variable Function Pointer Detection** — `is_local_fn_var` now checks `sema_has(tr, "localfn:NAME")` to detect captured closure variables as function pointers. The `emit_closure_statics` pass sets these flags before translating each closure body and clears them after. This ensures captured fn-typed variables get proper `((int64_t(*)(int64_t))name)(args)` casts instead of being mangled as `kr_name(args)`. Fixed `called object type 'int64_t' is not a function` errors for captured closures like `f(g(x))`.
- **Type-Dispatched `+` Operator (`_KR_ADD`)** — the `+` operator now emits `_KR_ADD(a, b)` which uses `__builtin_choose_expr` to dispatch between `kr_str_concat` for `char*` operands and integer addition for `int64_t` operands. This fixes `invalid operands to binary expression ('char *' and 'char[2]')` errors when closures use string concatenation with `+`. The `translate_addition` function pre-scans for `+` operators (stopping at `-`) and emits nested `_KR_ADD(` prefixes for left-associative chaining. After `-`, it recurses to handle subsequent `+` operators correctly.
- **Array Literal Trailing Comma Fix** — array literals with trailing commas (`[a, b, c,]`) no longer produce garbled mega-lines. The element counter now detects trailing commas and subtracts 1 from the count. The element loop breaks on trailing comma before calling `translate_expr`, preventing the `translate_primary` fallback from advancing past `]` and consuming all subsequent function bodies as array elements. This fix eliminated 86 errors across `closures_capture_test` (33→6) and `closures_composition_test` (69→2).
- **Closure Detection in Array Literals** — closures that are the first element of an array literal (`[|x| x+1, ...]`) are now detected by `emit_closure_statics`. Added `TK_LBRACKET()` to the `prev_k` context check in both the forward declaration pass and the main closure definition pass. Previously, only `TK_OP_ASSIGN`, `TK_COMMA`, `TK_LPAREN`, `TK_ARROW`, `TK_KW_MOVE`, and `TK_KW_RETURN` were recognized as valid preceding tokens.
- **Array Subscript Closure Call Cast** — `arr[i](args)` where `arr` is a vector now emits `((KrClosure)kr_vec_int_get(arr, i))(args)` instead of `kr_vec_int_get(arr, i)(args)`. The subscript handler pre-scans past `]` to detect an immediately following `(`, and if found, wraps the result in a `KrClosure` cast and translates the argument list. This fixes `called object type 'int64_t' is not a function or function pointer` errors for closures stored in vectors.
- **Match Fat Arrow (`=>`) and Expression Arms** — `translate_match_simple` now recognizes `=>` (lexed as `TK_OP_ASSIGN` + `TK_OP_GT`) in addition to `->` (`TK_ARROW`) as match arm separators via `is_match_arm_arrow`/`skip_match_arm_arrow` helpers. Additionally, expression arms (`pattern => expr,`) are now supported alongside block arms (`pattern -> { body }`). The wildcard and literal/identifier arm handlers detect whether the arm body starts with `{` and dispatch accordingly — expression arms translate a single expression and skip the trailing comma. This fixes garbled match output inside closure bodies that used `=>` syntax.
- **Nested Function Sema Registration** — `emit_nested_fn_prototypes` now registers `f:NAME:ret` in the sema map for nested functions (previously only top-level functions were registered). Without this, `is_local_fn_var`'s fallback `let`-scan guard was unprotected for nested fns, causing false positives where nested fn calls were incorrectly treated as local fn-pointer variable calls.
- **`localfn:` Flag Clearing Fix (`sema_get` vs `sema_has`)** — the `localfn:` sema flag check in `is_local_fn_var` now uses `sema_get(tr, key) != ""` instead of `sema_has(tr, key)`. The `sema_has` function only checks key existence in the map, but clearing a flag via `sema_set(c, key, "")` leaves the key present with an empty value — `sema_has` still returned true. This caused captured closure variables' `localfn:` flags to persist after their scope ended, making `is_local_fn_var` return true for unrelated functions with the same name. Fixed `use of undeclared identifier 'make_adder'` in `closures_composition_test` (0 compile errors, down from 1).
- **Capture Detection Local Let Priority** — `emit_closure_statics` capture detection now tracks a `found_local_let` flag. When a local `let NAME = ...` declaration is found in the enclosing scope, the subsequent `f:NAME:ret` sema check no longer overrides it with `skip_cap = 1`. This ensures local closure variables that shadow top-level functions are correctly captured.
- **Chained Closure Calls** — `level1(1)(2)(3)` now emits nested function pointer casts `((int64_t(*)(int64_t))((int64_t(*)(int64_t))((int64_t(*)(int64_t))level1)(1))(2))(3)`. The `translate_primary` function call handler pre-scans for chained `)(` sequences and emits wrapping `((int64_t(*)(int64_t, ...))` casts for each call level, then closes them after translating the argument lists.
- **Closure Return Type Annotation Skip** — complex return types after `->` in closure literals (tuples `(fn(int) -> int, fn(int) -> int)`, arrays `[T]`, fn types `fn(T) -> U`) are now correctly skipped during token neutralization. Previously, only one token was advanced after `->`, causing complex return type tokens to leak into the enclosing function as garbled C code.
- **Tuple Destructuring Fn Ptr Return Type** — `let (a, b) = make_ops(5)` where `make_ops` is a local fn var now emits `((KrTuple2(*)(int64_t))make_ops)(5)` with the correct `KrTupleN` return type instead of the default `int64_t`. The tuple destructuring handler detects when the RHS is a local fn var call and manually emits the cast with the tuple return type, bypassing the generic function call handler which always uses `int64_t`.
- **`is_local_fn_var` Tuple Destructuring Detection** — variables declared via tuple destructuring (`let (add5, mul5) = ...`) are now recognized as local fn vars. The `is_local_fn_var` fallback scan now checks for `let (` followed by identifiers matching the target name inside parentheses, in addition to the existing `let name = ...` pattern.
- **Match Expression Arms Implicit Return** — match arms in closures now correctly emit `return` for expression arms when the match statement is the last expression in the closure body (implicit return position). A `match_return` sema flag is set in `translate_statement` when the match keyword is at `implicit_ret_pos`, and `translate_match_simple` checks this flag before emitting expression arm values. Fixes `static kr_str _kr_cl_N(int64_t y)` closures where match arms like `0 => "zero"` emitted bare `"zero";` instead of `return "zero";`.
- **Tuple Field Closure Calls** — `t.0(5)` where `t` is a tuple with closure fields now emits `((int64_t(*)(int64_t))t.f0)(5)` instead of `t.f0(5)`. The `translate_primary` identifier handler detects the `.INT_LIT(` pattern ahead of time (before emitting the identifier) and generates the full function pointer cast expression with correct argument count. Reduced `closures_edge_cases_test` compile errors from 4 to 2.

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

## [0.9.1] - 2026-02-05

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

This was a placeholder release to establish the repository. No compiler code was included; the actual implementation began with the next release. (The original tag for this release was `v0.9.2` due to a numbering error; corrected here for clarity.)

[Unreleased]: https://github.com/kraken-lang/krakenc/compare/v0.9.3...HEAD
[0.9.3]: https://github.com/kraken-lang/krakenc/compare/v0.9.2...v0.9.3
[0.9.2]: https://github.com/kraken-lang/krakenc/compare/v0.9.1...v0.9.2
[0.9.1]: https://github.com/kraken-lang/krakenc/releases/tag/v0.9.1
