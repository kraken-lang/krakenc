#!/usr/bin/env bash
# tools/run-tests.sh - portable test runner for krakenc
#
# Compiles and runs the canonical test programs through krakenc, both via the
# C backend and the LLVM IR backend. Returns non-zero if any test fails.
#
# Assumes a working krakenc binary is on PATH or at $KRAKENC.
# Usage:   tools/run-tests.sh
#          KRAKENC=./krakenc_stage2.exe tools/run-tests.sh
#          BACKEND=ir tools/run-tests.sh        # IR only
#          BACKEND=c  tools/run-tests.sh        # C only
#          BACKEND=both tools/run-tests.sh      # default

set -euo pipefail

# -------- locate krakenc --------
KRAKENC="${KRAKENC:-}"
if [[ -z "$KRAKENC" ]]; then
    if command -v krakenc >/dev/null 2>&1; then
        KRAKENC="$(command -v krakenc)"
    elif [[ -x "./krakenc" ]]; then
        KRAKENC="./krakenc"
    elif [[ -x "./krakenc.exe" ]]; then
        KRAKENC="./krakenc.exe"
    elif [[ -x "./krakenc_stage2.exe" ]]; then
        KRAKENC="./krakenc_stage2.exe"
    else
        echo "FAIL: no krakenc found. set KRAKENC=/path/to/krakenc" >&2
        exit 1
    fi
fi

BACKEND="${BACKEND:-both}"

# -------- locate exe extension based on krakenc itself --------
case "$KRAKENC" in
    *.exe) exe_ext='.exe' ;;
    *)     exe_ext='' ;;
esac

# -------- canonical test set --------
TESTS=(
    test_minimal
    test_simple
    test_operators
    test_containers
    test_structs
)

# Expected first line of each test's stdout. Function rather than associative
# array so this works on bash 3.2 (macOS) — `declare -A` requires bash 4+.
expected_first_line() {
    case "$1" in
        test_minimal)   echo "hello from krakenc" ;;
        test_simple)    echo "result: 42" ;;
        test_operators) echo "=== krakenc Operator Tests ===" ;;
        test_containers) echo "v[0]=10" ;;
        test_structs)   echo "dist_sq: 25" ;;
        *) echo "" ;;
    esac
}

PASS=0
FAIL=0
FAILED_NAMES=()

run_one() {
    local name="$1"
    local mode="$2"
    local label="$3"
    local src="tests/${name}.kr"

    if [[ ! -f "$src" ]]; then
        echo "  SKIP ${label} ${name}: no source"
        return
    fi

    KRAKENC_INPUT="$src" KRAKENC_MODE="$mode" "$KRAKENC" >/dev/null 2>&1 || {
        echo "  FAIL ${label} ${name}: build failed"
        FAIL=$((FAIL + 1))
        FAILED_NAMES+=("${label}/${name}/build")
        return
    }

    local exe="tests/${name}${exe_ext}"
    if [[ ! -x "$exe" ]]; then
        echo "  FAIL ${label} ${name}: no exe at $exe"
        FAIL=$((FAIL + 1))
        FAILED_NAMES+=("${label}/${name}/exe-missing")
        return
    fi

    local got want
    got="$("$exe" 2>&1 | head -n1 | tr -d '\r')"
    want="$(expected_first_line "$name")"
    if [[ "$got" == "$want" ]]; then
        echo "  PASS ${label} ${name}"
        PASS=$((PASS + 1))
    else
        echo "  FAIL ${label} ${name}: got '$got' want '$want'"
        FAIL=$((FAIL + 1))
        FAILED_NAMES+=("${label}/${name}/output")
    fi
}

echo "krakenc: $KRAKENC"
echo "backend: $BACKEND"
echo

if [[ "$BACKEND" == "both" || "$BACKEND" == "c" ]]; then
    echo "[C backend]"
    for t in "${TESTS[@]}"; do
        run_one "$t" "compile" "C"
    done
    echo
fi

if [[ "$BACKEND" == "both" || "$BACKEND" == "ir" ]]; then
    echo "[IR backend]"
    for t in "${TESTS[@]}"; do
        run_one "$t" "compile-ir" "IR"
    done
    echo
fi

echo "passed: $PASS"
echo "failed: $FAIL"
if [[ $FAIL -gt 0 ]]; then
    echo "failures:"
    printf '  - %s\n' "${FAILED_NAMES[@]}"
    exit 1
fi
