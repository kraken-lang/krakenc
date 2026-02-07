# Kraken Compiler Roadmap

**Status**: Phase 1 Complete

## Phase 1: Self-Hosted Compiler Foundation ✅

**Goal**: Implement a self-hosted compiler with full pipeline

- [x] Establish compiler diagnostic code system (KRA0001–KRA0014)
- [x] Implement lexer in Kraken (`src/lexer.kr`) — 80+ token kinds, full tokenization
- [x] Implement parser in Kraken (`src/parser.kr`) — recursive descent, all constructs
- [x] Build semantic analysis framework (`src/typechecker.kr`) — two-pass, scope management
- [x] Create type checking system — operator type rules, type equality, classification
- [x] Implement C code generation for bootstrapping (`src/codegen.kr`)
- [x] Build CLI driver (`src/main.kr`) — 7 modes (compile, emit-c, check, tokens, ast, version, help)
- [x] Comprehensive test suite — 47 tests across 4 test files

**Deliverables**:
- 7 source modules in `src/` (token, lexer, ast, parser, typechecker, codegen, error, main)
- 4 test files in `tests/` (test_lexer, test_parser, test_typechecker, test_codegen)
- Updated documentation (architecture.md, README.md, CHANGELOG.md)

## Phase 2: Optimization and Performance

**Goal**: Improve compilation speed and generated code quality

- [ ] Implement constant folding optimization pass
- [ ] Implement dead code elimination
- [ ] Add incremental compilation support
- [ ] Improve parser error recovery
- [ ] Enhance diagnostic quality with source context display
- [ ] Profile and optimize compiler performance
- [ ] Implement LLVM backend (replace C emission)

## Phase 3: Advanced Features

**Goal**: Add advanced compiler features

- [ ] Language server protocol (LSP) integration
- [ ] Debugger support (DWARF emission)
- [ ] Cross-compilation support
- [ ] Compile-time evaluation (const fn)
- [ ] Macro expansion

## Phase 4: Tooling Integration

**Goal**: Build comprehensive development tooling

- [ ] Package manager integration
- [ ] Build system improvements
- [ ] IDE plugin support
- [ ] Documentation generator
- [ ] Profiling tools

## Bootstrap Milestone

The ultimate goal is for `krakenc` to compile itself:
```
krakenc src/main.kr → krakenc_stage1 (compiled by Rust compiler)
krakenc_stage1 src/main.kr → krakenc_stage2 (compiled by stage 1)
diff krakenc_stage1 krakenc_stage2 → identical = bootstrap complete
```
