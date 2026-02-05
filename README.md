<div align="center">
    <img width="auto" height="118" alt="Kraken Language" src="https://raw.githubusercontent.com/kraken-lang/.github/refs/heads/main/images/kraken-logo.png">
    <h1>Kraken Compiler</h1>
</div>

**Status**: In Development (Placeholder Repository)

The Kraken Compiler (`krakenc`) will be the self-hosted compiler for the Kraken programming language, written in Kraken itself. This repository is currently a placeholder and will be populated after the completion of milestone v0.8.47.

## Overview

The Kraken compiler is responsible for:
- Lexical analysis and parsing of Kraken source code
- Semantic analysis and type checking
- Code generation and optimization
- Producing executable binaries or intermediate representations

## Current Status

The compiler is currently being developed in the main [Kraken monorepo](https://github.com/kraken-lang/kraken) under the `compiler/` directory. Once the self-hosted compiler implementation is complete and stable (milestone v0.8.47), the code will be migrated to this repository.

## CLI Tool

The compiler produces the `kraken` command-line tool, which provides:
- Compilation of Kraken source files
- Build system integration
- Package management
- Development tools and utilities

## Architecture

The compiler follows a traditional multi-pass architecture:

1. **Lexical Analysis**: Tokenization of source code
2. **Parsing**: Construction of abstract syntax trees (AST)
3. **Semantic Analysis**: Type checking and validation
4. **Intermediate Representation**: Lowering to IR
5. **Optimization**: Code optimization passes
6. **Code Generation**: Target-specific code emission

Detailed architecture documentation will be added as the self-hosted implementation progresses.

## Development Timeline

- **v0.8.47**: Self-hosted compiler implementation begins
- **v0.8.48+**: Compiler migration to this repository
- **Future**: Continued compiler development and optimization

## Building from Source

Building instructions will be provided once the repository contains the compiler source code.

## Contributing

Contributions are welcome once the repository is populated. Please refer to CONTRIBUTING.md for guidelines.

## License

The Kraken Compiler is licensed under the Apache License 2.0. See LICENSE for details.

## Links

- [Main Kraken Repository](https://github.com/kraken-lang/kraken)
- [Documentation](https://github.com/kraken-lang/kraken)
- [Issue Tracker](https://github.com/kraken-lang/kraken/issues)
