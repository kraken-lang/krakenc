<div align="center">
    <img width="auto" height="118" alt="Kraken Language" src="https://raw.githubusercontent.com/kraken-lang/.github/refs/heads/main/images/kraken-logo.png">
    <h1>Kraken Compiler</h1>
</div>

**Status**: Phase 1 — Self-Hosted Compiler Foundation

The Kraken Compiler (`krakenc`) is the self-hosted compiler for the Kraken programming language, **written entirely in Kraken**. It implements a full compilation pipeline that bootstraps through C code generation.

## Overview

The self-hosted compiler implements:
- **Lexer** — Full tokenization of Kraken source (keywords, operators, literals, delimiters)
- **Parser** — Recursive-descent parser producing a flat arena-based AST
- **Type Checker** — Semantic analysis with scope management, type inference, and operator validation
- **Code Generator** — C code emission backend for bootstrapping (AST → C → native binary)
- **Diagnostics** — Structured error system with KRA-prefixed diagnostic codes

## Source Structure

```
src/
├── token.kr          Token types, keywords, operators, source locations
├── lexer.kr          Tokenizer with comment handling, string/number literals
├── ast.kr            AST node types (flat arena representation)
├── parser.kr         Recursive-descent parser (all Kraken constructs)
├── typechecker.kr    Semantic analysis, scope management, type validation
├── codegen.kr        C code emission for bootstrapping
├── error.kr          Diagnostic types (errors, warnings, hints)
└── main.kr           CLI driver and compilation pipeline orchestration

tests/
├── test_lexer.kr         15 lexer tests (tokenization, keywords, comments, operators)
├── test_parser.kr        11 parser tests (declarations, expressions, AST nodes)
├── test_typechecker.kr   12 type checker tests (types, operators, scopes, symbols)
└── test_codegen.kr        9 codegen tests (type mapping, mangling, emission)
```

## Architecture

The compiler follows a four-phase pipeline:

1. **Lexing** — Source text → token stream (identifiers, keywords, operators, literals, delimiters)
2. **Parsing** — Token stream → AST (recursive descent, arena-allocated flat nodes)
3. **Type Checking** — AST → validated AST (name resolution, type inference, constraint checking)
4. **Code Generation** — AST → C source (bootstrapping backend, compiles with gcc/clang/MSVC)

### Bootstrapping Strategy

```
Kraken source (.kr) → krakenc → C source (.c) → cc → native binary
```

The C backend exists solely for bootstrapping. Once `krakenc` can compile itself, a native LLVM backend will replace it.

## CLI Usage

```
krakenc <source.kr>              Compile to executable
krakenc --emit-c <source.kr>     Emit C source (bootstrap mode)
krakenc --check <source.kr>      Type-check only (no codegen)
krakenc --tokens <source.kr>     Dump token stream
krakenc --ast <source.kr>        Dump AST
krakenc --version                Print version
krakenc --help                   Print usage
```

## Building from Source

The self-hosted compiler is compiled using the Rust-based Kraken compiler from the main monorepo:

```bash
# From the main Kraken repository
kraken build krakenc/src/main.kr -o krakenc
```

## Contributing

Contributions are welcome once the repository is populated. Please refer to CONTRIBUTING.md for guidelines.

## License

The Kraken Compiler is licensed under the Apache License 2.0. See LICENSE for details.

## Links

- [Main Kraken Repository](https://github.com/kraken-lang/kraken)
- [Documentation](https://github.com/kraken-lang/kraken)
- [Issue Tracker](https://github.com/kraken-lang/kraken/issues)



<!--// FOOTER
================================================= -->

<div align="center"><!--// COPYRIGHT  -->
    <br>
    <h2></h2>
    <sup>Copyright <small>&copy;</small> 2026 <strong></strong></sup>
</div>
<!-- ============================================ -->
