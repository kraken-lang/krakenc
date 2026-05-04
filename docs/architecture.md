# krakenc Architecture

This document describes how `krakenc` actually works as of `v0.9.3`. For a higher-level overview of what the project is and how to use it, see the top-level [README](../README.md).

## Pipeline at a glance

```
.kr source
  ├── (resolve_imports) → concatenated source
  └── lexer.tokenize  → SOA token stream (int_data + lexemes vecs)
       ├── parser.translate (C backend)         → C source → clang → native binary
       └── llvm_ir.translate_to_ir (IR backend) → LLVM IR text + runtime.c → clang → native binary
```

The lexer is shared between both backends. The parser/translator is single-pass and token-driven — it walks the token stream and emits target code directly without building a conventional AST in between. This is intentional and is what made bootstrap-quality self-hosting tractable.

The legacy AST-based files (`src/ast.kr`, `src/typechecker.kr`, `src/codegen.kr`) are kept in the repo for reference but are not on the build path.

## Lexer (`src/lexer.kr`, ~320 lines)

Character-by-character scanner. The `Lexer` struct (`source`, `pos`, `line`, `column`, `length`) is functional / immutable: `advance(lex)` returns a new `Lexer` rather than mutating. Output is a structure-of-arrays token stream — interleaved `[kind0, line0, col0, kind1, line1, col1, ...]` in `int_data: VecInt` plus parallel `lexemes: VecString`. SOA layout instead of an array-of-Token avoids a per-token heap allocation and keeps tokenization tight.

Handles:
- Identifiers and keywords (lookup via the table in `src/token.kr`)
- Integer and float literals (with `.` and `..` disambiguation so `1..5` lexes as int / range / int)
- String literals with escape sequences
- Line comments (`//`) and block comments (`/* */`)
- Single- and two-character operators (`==`, `!=`, `<=`, `>=`, `&&`, `||`, `<<`, `>>`, `+=`, `-=`, `->`, `::`, `..`, `..=`)

## Token-driven translator (`src/parser.kr`, ~4,800 lines)

This is the heart of the compiler and the largest file in the repo. It walks the token stream once and emits C directly. The `Translator` struct carries the token cursor, output buffer, indent depth, error count, source file context, and a `MapStringString` "sema registry" used for cross-cutting concerns (struct field offsets, fn return types, hoisted lets, current loop labels, etc.).

### Top-level passes

1. `build_sema_registry` — scan the token stream for `struct`, `enum`, `trait`, `impl`, and `fn` declarations to populate the sema map. Subsequent emission can look up "what fields does Foo have" or "what does fn bar return" without a separate AST.
2. `emit_forward_decls` — typedefs first, then function prototypes. Avoids ordering issues in the emitted C.
3. `translate_program` — walks the tokens, dispatching each top-level declaration through `translate_fn`, `translate_struct`, `translate_enum`, `translate_impl`, etc.

### Expression precedence

A precedence-climbing parser with the standard chain:

```
or → and → bit_or → bit_xor → bit_and → equality → comparison → shift
   → addition → multiplication → unary → postfix → primary
```

Each level is its own `translate_*` function. Unary operators (`!`, `-`, `~`, `&`) call into `translate_primary`, not the full expression chain — important for getting precedence right (e.g. `!a && b` must parse as `(!a) && b`, not `!(a && b)`).

### Statement kinds

`let`, `const`, `if/else`, `while`, `for` (C-style), `for-in` (range and array), `match`, `return`, `break`, `continue`, `unsafe { ... }`, expression statements, plus the various assignment forms.

### Notable lowerings

- **Closures** — extracted into top-level static C functions during `emit_closure_statics`. Captures lowered to a fat closure value `KrClosure { fn, env }`. Method-style invocation goes through `_KR_CL_FN(cl)(_KR_CL_ENV(cl), args...)`.
- **`dyn Trait`** — represented at runtime as a fat pointer `KrDyn { void* data; void* vtable; }`. `emit_vtables` generates per-trait vtable structs and per-impl wrappers; method calls dispatch through `((Trait_VT*)obj.vtable)->method(obj.data)`.
- **Generics** — type-erased translation: `T` becomes `int64_t`. Function bodies are translated normally; calls cast through fat-pointer types where needed. The `_KR_LEN` and `_KR_TO_STRING` macros use `__builtin_choose_expr` for compile-time type-dispatched method calls.
- **Tuples** — `KrTuple1`–`KrTuple8` typedefs in the runtime preamble. `(a, b)` lowers to a struct compound initializer; `t.0` lowers to `t.f0`; destructuring lowers to per-element assignments. Nested tuple patterns flatten with depth tracking.
- **String equality** — `==` / `!=` on `i8*` operands routes through the `_KR_EQ` / `_KR_NEQ` macros (compile-time type dispatch via `__builtin_choose_expr` and `__builtin_types_compatible_p`). Zero runtime overhead vs. plain `==` for non-string operands.

## LLVM IR backend (`src/llvm_ir.kr`, ~2,200 lines)

Parallel translator that emits LLVM IR text instead of C. Same token stream input, different emission target. The `IrTranslator` struct mirrors the C translator but tracks SSA temporaries, label counters, and the current function's return type.

Key passes:

- `ir_emit_preamble` — module triple, target data layout, the "Kraken runtime functions" `declare` block.
- `ir_prescan_lets` — walks each function body to hoist all `let`-bound variables to entry-block `alloca`s. Avoids re-allocation on loop iterations.
- `translate_to_ir` (pass 2) — main loop that walks top-level declarations and emits IR for each.

The IR backend reuses the same sema-driven information as the C translator (struct layouts, fn return types, etc.). Loop-label tracking for `break`/`continue` lives in the same sema map under `loop_exit` / `loop_cond`.

The LLVM IR file is written to `<input>.ll`; the runtime preamble is also written separately to `<input>_runtime.c`. Final linking goes through `clang -x ir <file>.ll -x c <runtime>.c -o <exe>`.

## Runtime preamble (`src/platform.kr`, ~930 lines)

Functions that emit the C runtime preamble used by both backends. Selection happens via `c_runtime_shims_for_target(t)` and `c_includes_for_target(t)` so Windows targets get the Windows-specific shims (e.g. `Sleep` for `kr_sleep_ms`, `_putenv_s` for `kr_setenv`) while POSIX targets get `usleep` and `setenv`.

What the preamble provides:

- Type definitions: `KrTuple1`–`KrTuple8`, `KrClosure`, `KrDyn`, `kr_str` (`char*`), `kr_int` (`int64_t`)
- String runtime: `kr_str_concat`, `kr_str_eq`, `kr_str_ne`, `kr_str_slice`, `kr_str_starts_with`, `kr_str_ends_with`, `kr_str_to_lower/upper`, `kr_str_trim`, `kr_str_replace`, `kr_str_split`, `kr_str_join`, etc.
- Containers: `VecInt`, `VecString`, `VecBytes`, `MapStringInt`, `MapStringString` (open-addressing, auto-resize at 70% load)
- File I/O: `kr_file_read_string`, `kr_fopen`, `kr_fread`, `kr_fwrite`, `kr_fclose`, `kr_fputs`
- Math, time, memory, char classification — full POSIX surface plus Windows fallbacks
- Test framework: `_kr_test_count`, `_kr_test_pass/fail/skip`, `assert_eq`, `assert_ne`
- Compile-time host detection: `kr_detect_host_os()` and `kr_detect_host_arch()` use `#ifdef _WIN32 / __linux__ / __APPLE__` etc. so the runtime can return the host integer constants without a syscall

## CLI driver (`src/main.kr`, ~440 lines)

Reads its inputs from environment variables (`KRAKENC_INPUT`, `KRAKENC_MODE`, `KRAKENC_TARGET`) rather than positional CLI arguments. Modes:

| Value | Behavior |
|---|---|
| `compile` (default) | C backend: emit C, run clang, produce executable |
| `emit-c` | Emit C source only, no clang invocation |
| `emit-llvm` | Emit LLVM IR text (`.ll`), no link |
| `compile-ir` | LLVM IR backend: emit IR + runtime, run clang to link |
| `emit-runtime` | Emit only the C runtime preamble (`_kr_runtime.c`) |
| `tokens` | Dump the token stream |
| `version` | Print version and exit |
| `help` | Print usage and exit |
| `targets` | List supported targets |

`resolve_imports()` walks the source for `import a.b.c;` lines, reads each `a/b/c.kr` from disk relative to the source directory, and prepends the contents before tokenization. This is how `main.kr`'s `import token; import lexer;` pulls in the rest of the compiler at compile time.

## Diagnostics (`src/error.kr`, ~95 lines)

Structured `Diagnostic` type with severity, KRA-prefixed code, message, file, line, column, hint. Codes KRA0001–KRA0014 cover lex/parse/type-check/codegen failures. `skip_to_sync` provides simple recovery: on an unexpected token, skip forward until the next `;` or `}` and resume.

## Bootstrap chain

There is no Kraken-side compiler executable until you have one. The chain is:

1. The sibling [`kraken`](https://github.com/kraken-lang/kraken) Rust+LLVM compiler (the "stage1" bootstrap)
2. stage1 emits `src/main.c` cross-targeted to your host
3. `clang` compiles that C to a stage2 native binary — this is `krakenc`
4. stage2 can rebuild itself (and emit the same `src/main.c`, byte-identical → gen2/gen3 fixed point)

CI in `.github/workflows/ci.yml` automates step 1–3 on every push across Windows, Linux, and macOS. The release workflow does the same plus the bundling and packaging step.

## Why two backends

The C backend was the path to self-hosting. C's portability and the existence of a stable system C compiler everywhere meant the bootstrap problem reduced to "write enough Kraken to emit valid C."

The LLVM IR backend exists to start moving off the C round-trip. It still depends on `clang` for the assembler/linker step, but it removes one layer (the C compiler proper). The next step on this trajectory is a native object-file emitter that talks directly to PE/COFF, ELF, or Mach-O — at which point only a system linker is needed. See [`.dev/ROADMAP.md`](../.dev/ROADMAP.md).
