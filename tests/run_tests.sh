#!/bin/bash
# krakenc automated test runner
# Usage: ./krakenc/tests/run_tests.sh [bootstrap|self]
#   bootstrap — use bootstrap compiler (cargo run) to compile krakenc, then test
#   self      — use pre-built krakenc_self binary directly

set -euo pipefail
cd "$(dirname "$0")/../.."

MODE="${1:-bootstrap}"
PASS=0
FAIL=0
ERRORS=""

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

compile_and_run() {
    local name="$1"
    local input="krakenc/tests/${name}.kr"
    local exe="krakenc/tests/${name}"

    if [ "$MODE" = "self" ]; then
        KRAKENC_INPUT="$input" KRAKENC_MODE=compile ./krakenc/build/krakenc_self 2>/dev/null
    else
        KRAKENC_INPUT="$input" cargo run --quiet -- run krakenc/src/main.kr 2>/dev/null
    fi

    if [ $? -ne 0 ]; then
        echo "  COMPILE FAIL: $name"
        FAIL=$((FAIL + 1))
        ERRORS="${ERRORS}  compile: ${name}\n"
        return 1
    fi

    local output
    output=$("./$exe" 2>&1) || true

    local fail_count
    fail_count=$(echo "$output" | grep -c "FAIL:" || true)
    local pass_count
    pass_count=$(echo "$output" | grep -c "PASS:" || true)

    if [ "$fail_count" -gt 0 ]; then
        echo "  ✗ $name — ${pass_count} passed, ${fail_count} FAILED"
        FAIL=$((FAIL + fail_count))
        PASS=$((PASS + pass_count))
        ERRORS="${ERRORS}  runtime: ${name} (${fail_count} failures)\n"
        return 1
    else
        echo "  ✓ $name — ${pass_count} passed"
        PASS=$((PASS + pass_count))
        return 0
    fi
}

# ---------------------------------------------------------------------------
# Run all test files
# ---------------------------------------------------------------------------

echo "=== krakenc Test Runner (mode: ${MODE}) ==="
echo ""

TESTS=(
    test_all
    test_advanced
    test_operators
    test_stress
    test_enum
    test_forin
    test_impl
    test_structs
    test_containers
)

for t in "${TESTS[@]}"; do
    if [ -f "krakenc/tests/${t}.kr" ]; then
        compile_and_run "$t" || true
    fi
done

# ---------------------------------------------------------------------------
# Self-hosting verification
# ---------------------------------------------------------------------------

echo ""
echo "--- Self-hosting verification ---"

if [ "$MODE" = "self" ]; then
    KRAKENC_INPUT=krakenc/src/main.kr KRAKENC_MODE=emit-c ./krakenc/build/krakenc_self 2>/dev/null
else
    KRAKENC_INPUT=krakenc/src/main.kr KRAKENC_MODE=emit-c cargo run --quiet -- run krakenc/src/main.kr 2>/dev/null
fi

WARNINGS=$(cc -fsyntax-only krakenc/src/main.c 2>&1 | grep -c "warning:" || true)
C_ERRORS=$(cc -fsyntax-only krakenc/src/main.c 2>&1 | grep -c "error:" || true)

if [ "$C_ERRORS" -eq 0 ] && [ "$WARNINGS" -eq 0 ]; then
    echo "  ✓ C output: 0 errors, 0 warnings"
    PASS=$((PASS + 1))
else
    echo "  ✗ C output: ${C_ERRORS} errors, ${WARNINGS} warnings"
    FAIL=$((FAIL + 1))
fi

cc -o krakenc/build/krakenc_gen2 krakenc/src/main.c -lm 2>/dev/null
KRAKENC_INPUT=krakenc/src/main.kr KRAKENC_MODE=emit-c ./krakenc/build/krakenc_gen2 2>/dev/null
cc -o krakenc/build/krakenc_gen3 krakenc/src/main.c -lm 2>/dev/null

GEN2_OUT=$(KRAKENC_INPUT=krakenc/src/main.kr KRAKENC_MODE=emit-c ./krakenc/build/krakenc_gen2 2>/dev/null && cat krakenc/src/main.c)
GEN3_OUT=$(KRAKENC_INPUT=krakenc/src/main.kr KRAKENC_MODE=emit-c ./krakenc/build/krakenc_gen3 2>/dev/null && cat krakenc/src/main.c)

if [ "$GEN2_OUT" = "$GEN3_OUT" ]; then
    echo "  ✓ Fixed point: gen2 == gen3"
    PASS=$((PASS + 1))
else
    echo "  ✗ Fixed point FAILED: gen2 != gen3"
    FAIL=$((FAIL + 1))
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

echo ""
TOTAL=$((PASS + FAIL))
echo "=== Results: ${PASS}/${TOTAL} passed, ${FAIL} failed ==="

if [ "$FAIL" -gt 0 ]; then
    echo ""
    echo "Failures:"
    echo -e "$ERRORS"
    exit 1
fi

exit 0
