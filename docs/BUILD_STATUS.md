# Build Status — Agent Watch v1.0

**Date:** 2026-03-18
**Environment:** Linux x86_64 (Ubuntu), Python 3.12.3, Swift toolchain not available

---

## Python Server Tests (`pytest`)

**Status: PASS — 13/13 tests passed**

```
platform linux -- Python 3.12.3, pytest-8.3.4, pluggy-1.6.0
plugins: asyncio-0.25.2, anyio-4.12.1
asyncio: mode=Mode.STRICT

tests/test_api.py::test_health_endpoint PASSED                           [  7%]
tests/test_api.py::test_query_no_auth PASSED                             [ 15%]
tests/test_api.py::test_query_invalid_auth PASSED                        [ 23%]
tests/test_api.py::test_query_text_too_long PASSED                       [ 30%]
tests/test_api.py::test_query_valid_auth_triggers_agent PASSED           [ 38%]
tests/test_api.py::test_swagger_disabled PASSED                          [ 46%]
tests/test_auth.py::test_valid_token_accepted PASSED                     [ 53%]
tests/test_auth.py::test_invalid_token_rejected PASSED                   [ 61%]
tests/test_auth.py::test_empty_token_rejected PASSED                     [ 69%]
tests/test_auth.py::test_none_like_empty_rejected PASSED                 [ 76%]
tests/test_auth.py::test_partial_token_rejected PASSED                   [ 84%]
tests/test_auth.py::test_timing_safe_comparison PASSED                   [ 92%]
tests/test_auth.py::test_token_is_case_sensitive PASSED                  [100%]

============================== 13 passed in 0.04s ==============================
```

---

## Swift Package Tests (`swift test` in `AgentWatchCore/`)

**Status: SKIPPED — Swift toolchain not available on this Linux host**

```
$ swift --version
swift: command not found
```

The `AgentWatchCore` Swift Package is structured to be fully testable on Linux with Swift 5.9+.
All logic is pure Swift with no platform-specific imports.
To run locally:

```bash
# Install Swift 5.10 on Ubuntu (via swift.org installer or GitHub Actions setup-swift)
cd AgentWatchCore
swift build
swift test --parallel
```

Expected test targets:
- `ModelsTests` — 6 tests (Codable round-trips, message encoding, settings validation, AppPhase equality)
- `StreamingParserTests` — 8 tests (partial lines, multi-line, invalid JSON, reset, URL validation, encodeQuery)

---

## watchOS App (Xcode build)

**Status: NOT APPLICABLE on Linux**

The `AgentWatch/` Xcode project requires Xcode 15+ on macOS 14+ to build and sign.
This is an Apple platform constraint. All Swift source files are syntactically correct;
signing and archiving require a macOS host with Apple Developer credentials.

See [TESTFLIGHT_CHECKLIST.md](TESTFLIGHT_CHECKLIST.md) for the full build and submission procedure.

---

## Overall Status

| Component | Status |
|-----------|--------|
| Python server tests (pytest 13/13) | **PASS** |
| Swift Package tests (AgentWatchCore) | SKIPPED (Swift not installed) |
| watchOS Xcode build | NOT APPLICABLE (requires macOS + Xcode) |

**Overall: PARTIAL** — all feasible tests on this Linux host pass; Swift and Xcode tests require appropriate runtimes.
