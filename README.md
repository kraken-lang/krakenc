<div align="center">
    <img width="auto" height="118" alt="Kraken Language" src="https://raw.githubusercontent.com/kraken-lang/.github/refs/heads/main/images/kraken-logo.png">
    <h1>Kraken Compiler (krakenc)</h1>
</div>

`krakenc` is the self-hosted compiler for the Kraken programming language. It is written entirely in Kraken (`.kr` source files in `src/`) and compiles itself through multiple generations with byte-identical output (gen2 → gen3 fixed point).

It ships two backends:

- **C backend** (`--emit-c` / default) — emits portable C source, then shells out to `clang` to produce a native binary. The bootstrap path; what made self-hosting possible.
- **LLVM IR backend** (`--emit-llvm` / `--compile-ir`) — emits LLVM IR text, then shells out to `clang` to assemble and link with a small C runtime.

Both backends are exercised by the test suite and produce working binaries today. The next major direction is reducing what gets shelled out to clang — see the roadmap section below.

Current version: `v0.9.3`.

## Status

- **Self-hosting**: gen2 → gen3 byte-identical for the C backend. Verified locally on Windows and Linux this release; macOS is structurally identical and verified through CI on the sibling [`kraken`](https://github.com/kraken-lang/kraken) bootstrap repo.
- **Bootstrap dependency**: Building `krakenc` from a clean clone requires a stage1 compiler. Today that comes from the sibling Rust+LLVM `kraken` repo; CI handles this automatically (see [`.github/workflows/ci.yml`](.github/workflows/ci.yml)).
- **Test programs**: 226 bootstrap programs compile cleanly with zero C warnings; 135 unit tests across 9 test files pass.
- **Targets**: x86_64 Windows (MSVC and MinGW ABIs), x86_64 / aarch64 Linux (glibc and musl), x86_64 / aarch64 macOS, x86_64 FreeBSD, wasm32 WASI. Selection happens at compile time via `KRAKENC_TARGET` or via the runtime host detection in [`src/platform.kr`](src/platform.kr).

## Source layout

```
src/
├── token.kr       — token kinds, keyword tables, source location types
├── lexer.kr       — tokenizer (comments, string/number literals, operators)
├── parser.kr      — token-driven translator (single-pass token-to-C emitter, ~4,800 lines)
├── platform.kr    — C runtime preamble, target detection, OS/arch/ABI helpers
├── llvm_ir.kr     — LLVM IR backend (~2,200 lines)
├── error.kr       — diagnostic types (KRA-prefixed codes)
├── main.kr        — CLI driver and import resolution
├── ast.kr         — legacy AST node types (predates the token-driven translator)
├── typechecker.kr — legacy AST-based type checker
└── codegen.kr     — legacy AST-based C codegen

tests/
├── test_minimal.kr, test_simple.kr, test_operators.kr,
├── test_containers.kr, test_structs.kr  — small fixtures used by the cross-platform runner
├── test_all.kr, test_advanced.kr, test_stress.kr  — broader bootstrap test suites
├── test_lexer.kr, test_parser.kr, test_typechecker.kr, test_codegen.kr
└── run_tests.sh
```

The current pipeline is **lexer → token-driven translator → C (or LLVM IR) → native binary**. The AST-based files (`ast.kr`, `typechecker.kr`, `codegen.kr`) predate the token-driven approach and are kept for reference; they are not on the build path. The `legacy/` directory holds intermediate snapshots from the rewrite (`*.kr.fat`, `*.kr.fat2`).

## Usage

`krakenc` reads its inputs from environment variables rather than positional CLI arguments:

| Variable | Purpose | Example values |
|---|---|---|
| `KRAKENC_INPUT` | Source file to compile | `src/main.kr`, `tests/test_minimal.kr` |
| `KRAKENC_MODE` | What to emit | `compile` (default), `emit-c`, `emit-llvm`, `compile-ir`, `emit-runtime`, `tokens`, `version`, `help`, `targets` |
| `KRAKENC_TARGET` | Override target triple or shortcut | `linux`, `macos`, `windows`, `wasm`, or any full triple |

Examples:

```bash
# Compile to a native binary using the C backend (default)
KRAKENC_INPUT=examples/hello.kr ./krakenc

# Emit C source only, no clang invocation
KRAKENC_INPUT=src/main.kr KRAKENC_MODE=emit-c ./krakenc

# Build via LLVM IR backend
KRAKENC_INPUT=tests/test_minimal.kr KRAKENC_MODE=compile-ir ./krakenc

# Cross-emit C targeting a different platform
KRAKENC_INPUT=src/main.kr KRAKENC_MODE=emit-c KRAKENC_TARGET=linux ./krakenc

# Show the version
KRAKENC_MODE=version ./krakenc
```

## Building from source

The chicken-and-egg of self-hosted compilers: to build `krakenc` from `.kr` source, you need an existing `krakenc`. Three ways forward:

### 1. Use a pre-built release (easiest)

Download the platform archive from the GitHub Releases page, extract, and run `bin/krakenc`. The release ships a bundled `clang` so no extra toolchain install is required beyond the OS-provided libc/linker layer (Xcode CLT on macOS, system libc on Linux, kernel32/ucrt on Windows).

### 2. Bootstrap from the sibling Rust compiler

The sibling [`kraken`](https://github.com/kraken-lang/kraken) repository contains a Rust+LLVM compiler that can compile any `.kr` file. Use it as stage1:

```bash
git clone https://github.com/kraken-lang/kraken
cd kraken
cargo build --release -p kraken     # produces target/release/kraken (the stage1 binary)

# Use stage1 to emit krakenc's C source
cd ../krakenc
KRAKENC_INPUT=src/main.kr KRAKENC_MODE=emit-c ../kraken/target/release/kraken

# Compile that C with clang
clang -o krakenc src/main.c -Wno-int-conversion \
    $([ "$(uname)" = "Linux" ] && echo "-lm -lpthread") \
    $([ "$(uname)" = "Darwin" ] && echo "-lm")
```

Both [`.github/workflows/ci.yml`](.github/workflows/ci.yml) and [`.github/workflows/release.yml`](.github/workflows/release.yml) automate this on every push.

### 3. Use an existing krakenc to rebuild itself

Once you have a working `krakenc` binary on your machine:

```bash
KRAKENC_INPUT=src/main.kr KRAKENC_MODE=emit-c ./krakenc
clang -o krakenc src/main.c -Wno-int-conversion -D_CRT_SECURE_NO_WARNINGS

# Verify the gen2 == gen3 fixed point
KRAKENC_INPUT=src/main.kr KRAKENC_MODE=emit-c ./krakenc
# Compare the new src/main.c to the previous one - should be byte-identical
```

## Bundled clang (optional)

`tools/vendor-clang.ps1` (Windows) and `tools/vendor-clang.sh` (Linux/macOS) copy a minimal clang toolchain into `tools/llvm/` from a system LLVM 18 install. The release pipeline uses this to ship a self-contained toolchain. See [`tools/README.md`](tools/README.md) for details.

## Tests

The cross-platform test runner exercises both backends:

```bash
KRAKENC=./krakenc tools/run-tests.sh           # both backends (default)
KRAKENC=./krakenc BACKEND=c   tools/run-tests.sh   # C backend only
KRAKENC=./krakenc BACKEND=ir  tools/run-tests.sh   # LLVM IR backend only
```

The legacy bash harness in `tests/run_tests.sh` covers the broader bootstrap programs and the gen2/gen3 fixed-point check.

## Roadmap

Near-term (`0.9.x`):
- Verify all three platforms in CI on every push, not just on tag (release workflow exists; CI workflow also runs on push as of this release)
- Resolve the remaining test programs that still need attention in the LLVM IR backend
- More example programs, more documentation

Medium-term (`0.9.9` / `1.0.0-RC-1`):
- Native object-file emitter (skip the clang round-trip; see notes in [`.dev/ROADMAP.md`](.dev/ROADMAP.md))
- Package manager design and prototype
- Editor integration story (LSP lives in the sibling [`kraken-lsp`](https://github.com/kraken-lang/kraken-lsp) repo)

## Related repositories

- [`kraken-lang/kraken`](https://github.com/kraken-lang/kraken) — Rust + LLVM 18 bootstrap compiler. Required for first-time builds of `krakenc`.
- [`kraken-lang/kraken-lsp`](https://github.com/kraken-lang/kraken-lsp) — language server.
- [`kraken-lang/kraken-vscode`](https://github.com/kraken-lang/kraken-vscode) — VS Code extension.
- [`kraken-lang/tree-sitter-kraken`](https://github.com/kraken-lang/tree-sitter-kraken) — tree-sitter grammar.

## License

Apache License 2.0. See [LICENSE](LICENSE).

<!-- footer -->
<div align="center">
    <br>
    <sup>Copyright <small>&copy;</small> 2026 James Gober</sup>
</div>
