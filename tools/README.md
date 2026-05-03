# tools/

Vendored build tooling. Scripts here are committed; the vendored binaries under `tools/llvm/` are gitignored — each contributor runs the vendor script locally to populate them from a system LLVM install.

## Bundling clang

Two equivalent scripts, one per OS family. Each copies a minimal clang toolchain (clang + linker + resource headers) from a system LLVM 18 install into `tools/llvm/`.

### Windows

```powershell
# Default: pulls from C:\Program Files\LLVM
pwsh tools\vendor-clang.ps1

# Custom source / overwrite:
pwsh tools\vendor-clang.ps1 -Source 'D:\portable\LLVM'
pwsh tools\vendor-clang.ps1 -Force
```

### Linux / macOS

```bash
# Default: auto-detects /usr/lib/llvm-18, /opt/homebrew/opt/llvm, etc.
tools/vendor-clang.sh

# Custom source / overwrite:
tools/vendor-clang.sh --source /opt/homebrew/opt/llvm@18
tools/vendor-clang.sh --force
```

If detection fails (no `clang` on PATH, no recognized install dir), pass `--source` explicitly. On macOS the script does NOT bundle a linker — clang shells out to the system `ld64`, which ships with Xcode Command Line Tools.

### Resulting layout

```
tools/llvm/
├── bin/
│   ├── clang(.exe)
│   ├── lld-link.exe         (Windows only)
│   └── ld.lld, lld          (Linux only; macOS uses system ld64)
├── lib/clang/18/include/    (stddef.h, stdint.h, etc.)
├── LICENSE.TXT              (Apache 2.0 with LLVM exceptions)
└── VERSION.txt
```

Approximate sizes per platform (clang dominates):

| Platform | clang | linker | headers | total |
|---|---|---|---|---|
| Windows | 114 MB | 84 MB (lld-link) | 45 MB | ~243 MB |
| Linux | varies (~100-150 MB) | ~80 MB (ld.lld) | 45 MB | ~225-275 MB |
| macOS | varies (~100-150 MB) | — (system ld64) | 45 MB | ~145-195 MB |

## Why it exists

krakenc currently shells out to `clang` from PATH for both backends:
- C backend: `clang -o out.exe in.c`
- IR backend: `clang -x ir in.ll -x c runtime.c -o out.exe`

End-users without clang on PATH get `error: C compilation failed` / `error: IR compilation failed`. Bundling clang into the project (and eventually into the release zip) removes that friction — same model as Rust shipping LLVM with rustup.

## What's not done yet

The vendor script populates `tools/llvm/`, but `krakenc` itself still calls `clang` from PATH. The CC choice happens in [`src/platform.kr:226`](../src/platform.kr#L226) (`default_cc`), and the actual `system()` call is in [`src/main.kr`](../src/main.kr) at the two `let cc = default_cc(target);` sites (lines ~356 and ~413).

A minimal proposed change set (not applied autonomously since it touches the build pipeline and per `.dev/DIRECTIVES.md` `main.kr`/`platform.kr` changes need explicit review):

1. In [`src/main.kr`](../src/main.kr), read an env override at startup:
   ```
   let env_cc = getenv("KRAKENC_CC");
   ```
   and pass it down (or stash it in `target` / a global). When set, use it instead of `default_cc(target)`.

2. Optionally have `default_cc` itself prefer a bundled relative path when one exists. This requires a "does file exist" runtime probe, which `kr_file_read_string` can fake (open + check non-empty), or add a small `kr_file_exists` shim to `platform.kr`.

3. Once that's in, set `KRAKENC_CC=tools\llvm\bin\clang.exe` in your shell, or add a wrapper script `kc.ps1` that exports it before invoking `krakenc.exe`.

Either change preserves the C self-host fixed point as long as the emitted code's tokens don't depend on the cc string (they don't — `default_cc`'s output is only used at `system()` invocation time, after emission).

You can verify the bundle works today with no source changes:

```powershell
$env:PATH = "$pwd\tools\llvm\bin;" + $env:PATH
.\krakenc_stage2.exe   # picks up bundled clang via PATH precedence
```

## Cross-platform status

- Windows: ✅ `vendor-clang.ps1` works against the standard LLVM Windows installer.
- Linux: ✅ `vendor-clang.sh` works against `apt install llvm-18` and similar.
- macOS: ✅ `vendor-clang.sh` works against `brew install llvm@18`. Bundles only clang; expects Xcode Command Line Tools on the user's machine for `ld64` and the SDK.

`src/platform.kr` already handles target detection / linker flags / exe extension for all three (it was written cross-platform from day one). krakenc's emitted C is portable — no Windows-specific runtime tricks. So once you've vendored on a given OS, krakenc should build native binaries there with no source changes.

## License

The bundled LLVM binaries fall under the upstream LLVM license (Apache 2.0 with LLVM exceptions). `vendor-clang.ps1` copies `LICENSE.TXT` from the source install into the bundle so redistribution is properly attributed. If your source install doesn't have one, fetch it from the corresponding LLVM release on GitHub before shipping anything that includes the bundle.
