# CLAUDE.md — krakenc (Self-Hosted Compiler)

> Operating manual for any AI assistant working in this repository.
> Read this file in full before doing anything else.

## Required reading order

Before touching any code or generating any output, read in order:

1. **`.dev/REPS.md`** — the engineering standards. Authoritative. Non-negotiable.
2. **`.dev/DIRECTIVES.md`** — directives specific to this repo and to AI-assisted work.
3. **`.dev/AUDIT.md`** — current verifiable state of the repo. Read this to ground yourself in what exists vs. what is planned.
4. **`.dev/ROADMAP.md`** — what is next, what is out of scope.
5. **This file** — operating instructions, build commands, communication style.

If any of those files are missing, stop and tell the user. Do not improvise.

## What this repo is

This is the **self-hosted Kraken compiler** — written in Kraken itself (`.kr` source files) — that emits C code for bootstrapping. It is compiled by the sibling `kraken` repo (the Rust-based bootstrap compiler).

- Source language: Kraken
- Output: C source (compiled by gcc/clang/MSVC for native binaries)
- Status: self-hosting achieved (gen2 → gen3 byte-identical fixed point)
- Sibling repo: `kraken-lang/kraken` (the bootstrap Rust+LLVM compiler)

The C-emission backend exists solely for bootstrapping. The next major milestone is replacing it with a native LLVM backend so this compiler is fully independent.

## Source structure

```
src/
├── token.kr       — token types, keywords, operators, source locations
├── lexer.kr       — tokenizer with comment/string/number literal handling
├── ast.kr         — AST node types (legacy; current pipeline uses token-driven translator)
├── parser.kr      — token-driven translator (single-pass token-to-C emission). The heart of the compiler. ~4,800 lines.
├── platform.kr    — C runtime shims, type definitions, KrTuple/KrClosure/KrDyn fat pointers, hash maps
├── typechecker.kr — semantic analysis, scope management (legacy AST-based path)
├── codegen.kr     — legacy C codegen (predates token-driven translator)
├── error.kr       — diagnostic types (errors, warnings, hints)
└── main.kr        — CLI driver, import resolution, compilation pipeline

tests/
├── test_all.kr           — 37 tests across all language features
├── test_advanced.kr      — 31 tests on math, structures, vectors, strings
├── test_operators.kr     — 23 tests on operators
├── test_stress.kr        — 42 tests on deep nesting and complex expressions
├── test_lexer.kr         — lexer-specific tests
├── test_parser.kr        — parser-specific tests
├── test_typechecker.kr   — type-checker-specific tests
├── test_codegen.kr       — codegen-specific tests
└── run_tests.sh          — automated runner; verifies self-hosting fixed point
```

Note: the current pipeline goes **lexer → token-driven translator → C → native binary**. The AST-based `parser.kr` and `typechecker.kr` predate the token-driven approach and remain in the tree pending decision on whether to remove them or repurpose them.

## Build commands

```bash
# Compile krakenc using the bootstrap Rust compiler (from the sibling kraken repo)
kraken build src/main.kr -o krakenc

# Self-host: compile krakenc using the krakenc you just built
./krakenc src/main.kr -o krakenc_gen2
diff krakenc krakenc_gen2     # gen1 to gen2 should match (or close to it)

# Fixed-point check: gen2 compiles itself to gen3, gen3 must equal gen2 byte-for-byte
./krakenc_gen2 src/main.kr -o krakenc_gen3
diff krakenc_gen2 krakenc_gen3  # must produce no output

# Run the full test suite
cd tests && ./run_tests.sh
```

## What you may do without asking

- Read any file in the repo
- Run `./run_tests.sh`, individual test programs, or self-host build steps
- Propose patches as inline diffs
- Cross-reference REPS sections by name when explaining a recommendation
- Update `.dev/AUDIT.md` when verifiable state has changed

## What you must not do without explicit approval

- Modify `.dev/REPS.md` — only the user updates it
- Make changes to `src/parser.kr` larger than ~50 lines without proposing the diff first. This file is high-stakes; a regression here breaks the entire bootstrap chain.
- Modify `src/platform.kr` runtime shims without verifying the change against the test suite. C-runtime correctness is foundational.
- Commit or push — the user runs all git operations
- Modify CI configuration
- Touch `LICENSE`, `CHANGELOG.md` (user maintains the changelog), or release-related files
- Generate "AI-style" documentation (no "comprehensive", "robust", "seamless", "leverage", emoji, or "Phase X / Step Y" headers — see REPS — Documentation)

## Communication style

- Be concrete. Cite file paths, line numbers, and REPS section names.
- When proposing changes, explain the *why* by reference to a REPS clause.
- Match the user's energy.
- Do not generate filler or pad responses.
- If something is uncertain, say so explicitly.

## Critical invariant: self-hosting fixed point

Any change to `src/*.kr` must preserve the gen2 → gen3 byte-identical fixed point. This is the contract that the compiler is correct. If a proposed change breaks the fixed point, the change is broken — even if all functional tests pass.

When proposing changes that touch the compiler's emission logic (`parser.kr`, `platform.kr`, `main.kr`):

1. Describe the expected change in emitted C output.
2. State which test programs will exercise the change.
3. Confirm the gen2/gen3 fixed point will be re-verified after the change.

## Relationship to `kraken` (the bootstrap)

- `kraken` (sibling repo): Rust + LLVM 18, the bootstrap compiler, 2,115 tests passing.
- `krakenc` (this repo): self-hosted, 226/226 bootstrap programs passing, emits C.

When this repo gains a native LLVM backend (the next major milestone — see `ROADMAP.md`), the bootstrap dependency on `kraken` is severed. At that point, `krakenc` becomes the canonical compiler.

## When in doubt

Ask the user. The cost of one clarifying question is far lower than the cost of a confidently wrong implementation, especially in a self-hosted compiler where wrong code corrupts the next generation's compiler.
