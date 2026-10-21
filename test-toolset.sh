#!/usr/bin/env bash
# Test script to validate all video processing tools
# Tests help output, argument validation, and basic functionality

set -uo pipefail  # Don't use -e since we're testing for failures

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="$SCRIPT_DIR/bin"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

PASSED=0
FAILED=0

test_pass() {
    echo -e "${GREEN}✓${NC} $1"
    ((PASSED++))
}

test_fail() {
    echo -e "${RED}✗${NC} $1"
    ((FAILED++))
}

test_info() {
    echo -e "${YELLOW}ℹ${NC} $1"
}

echo "========================================"
echo "Video Toolset Validation Tests"
echo "========================================"
echo ""

# Test 1: Check all scripts exist and are executable
test_info "Test 1: Checking script files..."
for script in video-trim video-combine video-crop video-normalize video-prepare video-info; do
    if [[ -f "$BIN_DIR/$script" && -x "$BIN_DIR/$script" ]]; then
        test_pass "$script exists and is executable"
    else
        test_fail "$script missing or not executable"
    fi
done
echo ""

# Test 2: Check library file exists
test_info "Test 2: Checking library file..."
if [[ -f "$SCRIPT_DIR/lib/video-utils.sh" && -r "$SCRIPT_DIR/lib/video-utils.sh" ]]; then
    test_pass "video-utils.sh exists and is readable"
else
    test_fail "video-utils.sh missing or not readable"
fi
echo ""

# Test 3: Test help output for all scripts
test_info "Test 3: Testing help output..."
for script in video-trim video-combine video-crop video-normalize video-prepare video-info; do
    if "$BIN_DIR/$script" --help >/dev/null 2>&1; then
        test_pass "$script --help works"
    else
        test_fail "$script --help failed"
    fi
done
echo ""

# Test 4: Test error handling (missing arguments)
test_info "Test 4: Testing error handling..."
for script in video-trim video-combine video-crop video-normalize video-prepare video-info; do
    if ! "$BIN_DIR/$script" >/dev/null 2>&1; then
        test_pass "$script correctly errors on missing arguments"
    else
        test_fail "$script did not error on missing arguments"
    fi
done
echo ""

# Test 5: Test invalid file handling
test_info "Test 5: Testing invalid file handling..."
NONEXISTENT="/tmp/nonexistent-video-file-$$.mp4"
if ! "$BIN_DIR/video-info" "$NONEXISTENT" >/dev/null 2>&1; then
    test_pass "video-info correctly handles nonexistent file"
else
    test_fail "video-info did not handle nonexistent file"
fi
echo ""

# Test 6: Check shellcheck (if available)
test_info "Test 6: Running shellcheck..."
if command -v shellcheck >/dev/null 2>&1; then
    SHELLCHECK_ERRORS=0
    for script in video-trim video-combine video-crop video-normalize video-prepare video-info; do
        # Check shellcheck exit code; 0 = no issues, 1 = warnings/errors
        # Exclude SC1091 (info about not following sourced files)
        if ! shellcheck -e SC1091 "$BIN_DIR/$script" >/dev/null 2>&1; then
            test_fail "$script has shellcheck warnings/errors"
            ((SHELLCHECK_ERRORS++))
        fi
    done
    
    if ! shellcheck -e SC1091 "$SCRIPT_DIR/lib/video-utils.sh" >/dev/null 2>&1; then
        test_fail "video-utils.sh has shellcheck warnings/errors"
        ((SHELLCHECK_ERRORS++))
    fi
    
    if [[ $SHELLCHECK_ERRORS -eq 0 ]]; then
        test_pass "All scripts pass shellcheck"
    fi
else
    test_info "shellcheck not available, skipping"
fi
echo ""

# Test 7: Source library file
test_info "Test 7: Testing library sourcing..."
if bash -c "source '$SCRIPT_DIR/lib/video-utils.sh' && declare -F log_info >/dev/null"; then
    test_pass "video-utils.sh can be sourced and exports functions"
else
    test_fail "video-utils.sh cannot be sourced properly"
fi
echo ""

# Test 8: Check documentation
test_info "Test 8: Checking documentation..."
for doc in README.md docs/USAGE.md docs/CONTRIBUTING.md; do
    if [[ -f "$SCRIPT_DIR/$doc" && -r "$SCRIPT_DIR/$doc" ]]; then
        test_pass "$doc exists"
    else
        test_fail "$doc missing"
    fi
done
echo ""

# Test 9: Check example files
test_info "Test 9: Checking examples..."
for example in examples/workflow-youtube.sh examples/workflow-highlights.sh examples/segments-list.txt; do
    if [[ -f "$SCRIPT_DIR/$example" ]]; then
        test_pass "$example exists"
    else
        test_fail "$example missing"
    fi
done
echo ""

# Test 10: Verify scripts use proper shebang
test_info "Test 10: Checking shebangs..."
for script in video-trim video-combine video-crop video-normalize video-prepare video-info; do
    if head -n1 "$BIN_DIR/$script" | grep -q "^#!/usr/bin/env bash$"; then
        test_pass "$script has correct shebang"
    else
        test_fail "$script has incorrect shebang"
    fi
done
echo ""

# Summary
echo "========================================"
echo "Test Summary"
echo "========================================"
echo -e "${GREEN}Passed: $PASSED${NC}"
if [[ $FAILED -gt 0 ]]; then
    echo -e "${RED}Failed: $FAILED${NC}"
    echo ""
    echo "Some tests failed. Please review the output above."
    exit 1
else
    echo -e "${RED}Failed: $FAILED${NC}"
    echo ""
    echo "All tests passed!"
    exit 0
fi
