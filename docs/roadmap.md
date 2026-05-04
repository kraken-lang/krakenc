# krakenc Roadmap

This file is a high-level summary of what's planned. The detailed, frequently-updated version lives in [`.dev/ROADMAP.md`](../.dev/ROADMAP.md). What's already done is in [`CHANGELOG.md`](../CHANGELOG.md) and [`.dev/AUDIT.md`](../.dev/AUDIT.md).

## Where we are (v0.9.3)

- Self-hosted compiler in Kraken with byte-identical gen2 → gen3 fixed point on the C backend
- Two backends: C emission (the bootstrap path) and LLVM IR emission
- 226 bootstrap test programs compile cleanly, 135 unit tests pass
- Cross-platform CI on Windows, Linux, macOS (verified end-to-end on first two; macOS via the sibling kraken repo's matrix)
- Release pipeline: tag a `v*` and GitHub Actions builds a per-platform archive (krakenc + bundled clang) and drafts a GitHub Release

## Near-term (`0.9.4` – `0.9.8`)

Smoothing-and-filling work, no major architectural shifts. Expected cadence: small focused releases.

- Verify all three platforms end-to-end on every push, not just on tag
- Documentation pass: cover language features that exist but aren't documented well, especially around traits, generics, and dyn dispatch
- Examples folder for `krakenc` (the compiler-side examples; language examples live in the sibling `kraken` repo)
- Investigate the IR backend gaps that show up when self-hosting the compiler itself — most are resolved as of `0.9.3` but more edge cases will surface as more programs are exercised
- Tighten error diagnostics: source context lines, better suggestions on common mistakes
- Performance: profile compilation and find the obvious wins. The token-driven translator is already pretty fast but hasn't been benchmarked rigorously

## Beta (`0.9.9`)

Feature-complete pre-release. Final pieces before tagging `1.0.0-RC-1`. Scope to be locked in based on what `0.9.4`–`0.9.8` reveals; current candidates:

- Native object-file emitter (skip the `clang` round-trip)
- Initial package manager design — likely just a manifest format and a Git-based fetch story for `1.0`; full registry and resolver behavior post-1.0
- LSP feature parity with the basics (go-to-definition, hover, diagnostics-on-save) via the sibling [`kraken-lsp`](https://github.com/kraken-lang/kraken-lsp) project
- Stability commitment: define what `1.0` promises and what it doesn't

## Post-1.0 (not on the near-term radar)

These are valuable but explicitly not blocking 1.0:

- Own linker (skip `lld-link` / `ld.lld`). Only matters if the linker becomes a real friction point
- Own libc / direct-syscall layer where possible. On Windows the syscall ABI isn't stable, so this is permanently capped at "depend only on `kernel32.dll` / `ntdll.dll`" rather than "no system deps"
- Incremental compilation
- Parallel codegen
- Debugger story (DWARF / PDB emission tied to a real debugger UX)
- WASM target maturity (the wasm32-wasi triple is wired up but not heavily exercised)

## What's deliberately out of scope

- Custom IDE. Kraken targets standard editors via LSP.
- Domain-specific extensions (a separate "Kraken for X" dialect). The base language is general-purpose.
- A web service or hosted package registry beyond what GitHub Releases provides for binary distribution. Hosted registries can come post-1.0 if there's user demand.

## Honest disclaimer

The roadmap above is what's currently believed reasonable. Compiler projects routinely discover that the next thing turns out to be either much easier or much harder than expected. Versions and dates are not commitments; the milestone names are checkpoints, not delivery dates.
