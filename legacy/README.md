# legacy/

Historical artifacts from the krakenc rewrite. Kept for reference; not built or shipped.

## Files

| File | What it is | When to delete |
|---|---|---|
| `parser.kr.fat`, `parser.kr.fat2` | Snapshots of `src/parser.kr` from intermediate states during the AST-to-token-driven-translator rewrite. ~231 KB each. | When you're confident the new parser is stable across multiple released versions. |
| `platform.kr.fat`, `platform.kr.fat2` | Snapshots of `src/platform.kr` from the same rewrite period. ~60 KB each. | Same. |

## Why this folder exists

These were originally in `src/` next to the live `*.kr` sources, marked "pending disposition" in `.dev/AUDIT.md`. Moving them here gets them out of the active source path while preserving them visibly, in case the rewrite needs to be revisited or compared.

If you decide to delete them: git history preserves them at the commits where they were last live in `src/`. Nothing is permanently lost by `rm`'ing them.
