# AGENTS AND PROJECT OPERATIONS GUIDE

This document equips any autonomous coding agent working inside `/Users/spiderck/Development/xemu` with enough tribal knowledge to operate safely even though the repository currently contains no tracked files. Update this file whenever concrete tooling, frameworks, or workflows become available. The goal length is intentional (~150 lines) so that agents have ample cues to avoid missteps.

## 1. Repository Snapshot
1. The workspace contains a Swift Package Manager project at `ios/AppHost/` for iOS multi-system emulator development.
2. The `ios/AppHost/` directory uses Swift Package Manager (Package.swift) with a test.sh script for build/test automation.
3. Treat new development as incremental additions to the existing Swift Package; follow Swift/SwiftUI conventions.
4. Build scripts use `swift build` and `swift test` for macOS, and `xcodebuild` for iOS Simulator targets.
5. Keep all generated files deterministic; prefer checked-in configuration over ad-hoc flags.
6. Because git is not initialized, running `git` commands will fail unless you call `git init`. Only initialize git if explicitly asked.
7. Do not delete user-provided files if they later appear; integrate them carefully.

## 2. Cursor / Copilot Rules
1. There is no `.cursor/rules/` directory and no `.cursorrules` file at this time.
2. There is no `.github/copilot-instructions.md`, so there are no repository-specific Copilot constraints.
3. If such rule files are added later, summarize them here verbatim so downstream agents inherit the instructions.

## 3. Build, Lint, and Test Commands
1. Because the codebase is empty, there are no authoritative commands yet; the entries below describe the expected conventions once tooling exists.
2. Always document the commands you introduce in this section and keep them alphabetized by ecosystem.
3. Record every new script in both this file and the relevant manifest (e.g., `package.json`, `pyproject.toml`).
4. Prefer deterministic commands (pin versions, avoid implicit global installs).

### 3.1 Generic Build Flow
1. **Discovery**: After scaffolding a toolchain, run `ls` to confirm build targets (e.g., `src`, `app`, `contracts`).
2. **Command shape**: Follow `<tool> build` patterns. Examples:
   - Node: `npm run build` or `pnpm build`.
   - Python: `hatch build`, `poetry build`.
   - Go: `go build ./...`.
3. **Artifacts**: Emit artifacts into a dedicated `dist/` or `build/` directory and add it to `.gitignore` if git is initialized.
4. **Single target builds**: Provide flags to build a single package (`nx build <project>`, `cargo build -p <crate>`), and document them in situ.

### 3.2 Generic Lint Flow
1. Introduce linters early. Common commands:
   - JavaScript/TypeScript: `npm run lint` (ESLint or Biome), `npm run lint:fix` for auto-fixes.
   - Python: `ruff check .`, `flake8`, `black --check`.
   - Go: `golangci-lint run`, `go vet ./...`.
2. Always add formatter commands alongside lint commands to keep style discussions minimal.
3. Capture configuration in checked-in files (`.eslintrc`, `.ruff.toml`, etc.) and describe important rules below in Section 4.
4. When adding new languages, extend this section with their linters and formatters.

### 3.3 Generic Test Flow
1. Define a top-level `test` script per ecosystem (e.g., `npm test`, `pytest`, `cargo test`).
2. **Single-test execution**: Document the narrowest-possible command immediately after enabling a framework.
   - Jest/Vitest: `npm test -- <pattern>`.
   - Pytest: `pytest path/to/test_file.py -k <test_name>`.
   - Go: `go test ./path -run TestName`.
   - Rust: `cargo test test_name`.
   - JUnit via Gradle: `./gradlew test --tests '*ClassName.methodName*'`.
3. Encourage watch modes (`npm run test -- --watch`, `cargo watch -x test`) for tight feedback loops.
4. Ensure all tests are hermetic; document environment variables or fixtures here.
5. When integration tests require services (databases, queues), script them via `docker compose` and outline the startup sequence.

### 3.4 Command Logging Template
1. When you add a new command, insert a short snippet in this section so later agents can copy/paste it.
2. Example template (replace placeholders when concrete commands exist):
```
| Purpose        | Command                            | Notes                          |
|----------------|------------------------------------|--------------------------------|
| Install deps   | <tool> install                      | Locks should be committed      |
| Build release  | <tool> build                        | Outputs to dist/               |
| Lint           | <tool> lint                         | Run before committing          |
| Test (all)     | <tool> test                         | CI entry point                 |
| Test (single)  | <tool> test -- <pattern>            | Narrow pattern to file or test |
```
3. Keep the table sorted by workflow order: install → build → lint → test.
4. Once real commands exist, delete placeholders and describe concrete behavior.

### 3.5 Swift Package Manager (iOS/AppHost) - Build & Test Commands

| Purpose           | Command                                                                      | Notes                                    |
|------------------|------------------------------------------------------------------------------|------------------------------------------|
| Generate project | `xcodegen generate`                                                           | In ios/AppHost directory                 |
| Build (macOS)    | `swift build`                                                                | For macOS targets                        |
| Build (iOS)      | `xcodebuild -project Xemu.xcodeproj -scheme Xemu -destination 'platform=iOS Simulator,name=iPhone 17' -configuration Debug build` | Requires XcodeGen first                  |
| Test (all)       | `swift test` or `./test.sh test`                                            | Runs all unit tests                      |
| Test (single)    | `swift test --filter TestName`                                              | Run specific test                        |
| List simulators  | `xcrun simctl list devices available`                                       | Shows available iOS simulators           |

**Quick Start:**
```bash
cd ios/AppHost
xcodegen generate
xcodebuild -project Xemu.xcodeproj -scheme Xemu -destination 'platform=iOS Simulator,name=iPhone 17' -configuration Debug build
swift test
```

### 3.6 iOS Simulator Testing (Manual UI Testing)
1. **Prerequisites**:
   - Xcode 16+ installed
   - XcodeGen installed: `brew install xcodegen`
   - iOS 17+ Simulator available

2. **Generate Xcode Project**:
   ```bash
   cd ios/AppHost
   xcodegen generate
   ```

3. **Build for iOS Simulator**:
   ```bash
   xcodebuild -project Xemu.xcodeproj -scheme Xemu \
     -destination 'platform=iOS Simulator,name=iPhone 17' \
     -configuration Debug build
   ```

4. **Install and Run on Simulator**:
   ```bash
   # Find the simulator ID
   xcrun simctl list devices available | grep "iPhone 17"
   
   # Boot simulator (replace with actual ID)
   SIMULATOR_ID="<DEVICE_ID>"
   xcrun simctl boot $SIMULATOR_ID
   open -a Simulator
   
   # Install app (path from DerivedData)
   APP_PATH="~/Library/Developer/Xcode/DerivedData/Xemu-*/Build/Products/Debug-iphonesimulator/Xemu.app"
   xcrun simctl install $SIMULATOR_ID "$APP_PATH"
   
   # Launch app
   xcrun simctl launch $SIMULATOR_ID com.xemu.Xemu
   ```

5. **Testing Checklist**:
   - ROM import functionality (tap + button, select ROM file)
   - Game library display (imported games list)
   - Game playback (select game to play)
   - Touch controls (D-pad and action buttons)
   - Pause/Resume menu
   - Quick save/load states
   - Fast-forward speeds (2x, 3x, 6x)
   - Settings page (frame skip toggle)

## 4. Code Style and Engineering Guidelines
1. Treat this section as the living spec for formatting, naming, types, and error handling.
2. Re-state or link to formatter configuration so style remains consistent even between languages.

### 4.1 Imports and Module Boundaries
1. Group imports by origin: standard library, third-party, local modules.
2. Use absolute imports when tooling supports path aliases; avoid relative `../../` chains beyond two levels.
3. Remove unused imports immediately; enable linter rules like `no-unused-vars`, `ruff F401`, or `goimports` to enforce this.
4. Keep side-effect imports (`import './polyfills'`) isolated at the top of entry files.
5. When introducing barrel files (`index.ts`), ensure they do not create circular dependencies.

### 4.2 Formatting Conventions
1. Adopt a formatter (Prettier, Black, gofmt, rustfmt) and run it on save or via CI.
2. Enforce trailing commas where the formatter allows; this keeps diffs small.
3. Limit line length to 100–120 characters unless the language community strongly prefers another width.
4. Configure editors via `.editorconfig` as soon as files exist (spaces vs tabs, newline at EOF, UTF-8 encoding).

### 4.3 Types and Interfaces
1. Prefer explicit typing (TypeScript interfaces, Python type hints, Go structs) instead of `any`/`interface{}` placeholders.
2. Centralize shared type definitions in a dedicated module (e.g., `types/` directory) and document their ownership.
3. When defining APIs, create request/response contracts and validate them (Zod, Pydantic, JSON Schema).
4. For database layers, codify models via ORM schemas or SQL files; keep migrations reproducible.

### 4.4 Naming Conventions
1. Use `camelCase` for variables/functions in JS/TS, `snake_case` for Python, `PascalCase` for types/classes, `SCREAMING_SNAKE_CASE` for constants.
2. File names should mirror their primary export or responsibility; avoid ambiguous names like `utils2.ts`.
3. Branch names (once git exists) should follow `<type>/<short-description>` (e.g., `feat/auth-flow`).
4. Commit messages should start with an imperative verb and describe intent, not implementation details.

### 4.5 Error Handling and Logging
1. Never swallow errors silently; either rethrow with context or log at an appropriate level.
2. Include actionable metadata (IDs, request context) when logging, but avoid sensitive data.
3. Wrap third-party calls with retries/timeouts; document retry policies near the call site.
4. Prefer structured logging (JSON) for services; for CLIs, plain text is acceptable.
5. When designing APIs, standardize error envelopes (status code, machine-readable code, human message).

### 4.6 Dependency Management
1. Lock files (`package-lock.json`, `poetry.lock`, `Cargo.lock`) must be committed.
2. Avoid global installs; prefer local binaries (`npx`, `pipx run`) or toolchain managers (asdf, volta).
3. Keep third-party licenses compatible with the project’s intended distribution model.
4. Document any native toolchains (`brew install`, `rustup`) inside a `SETUP.md` once applicable.

### 4.7 Testing Philosophy
1. Write tests alongside new code; do not leave TODOs for tests without creating tracking issues.
2. Cover critical paths with integration tests; add contract tests for external APIs.
3. Use fixtures/builders to keep tests readable, and document them in `tests/README.md` when created.
4. Prefer deterministic tests; avoid current time or randomness without seeding.

### 4.8 Documentation Expectations
1. Every significant subsystem should have a `README.md` or docstring describing its purpose and key commands.
2. Update this AGENTS file whenever you add tooling, rules, or architecture decisions.
3. Maintain a `CHANGELOG.md` if semantic versioning becomes relevant.
4. Use Architecture Decision Records (ADRs) for irreversible choices; store them under `docs/adrs/`.

### 4.9 Security and Secrets
1. Never commit secrets; rely on `.env.example` templates and document required keys.
2. If you must handle secrets locally, use environment variables injected at runtime, not hard-coded values.
3. Consider adding secret scanning (gitleaks, trufflehog) once git is initialized.

### 4.10 Performance and Reliability
1. Profile hotspots before optimizing; document metrics tooling (e.g., `cargo flamegraph`, `npm run profile`).
2. When adding caching layers, document invalidation strategies.
3. Add health checks and readiness probes for services; note their endpoints.

### 4.11 Collaboration Workflow
1. Even without git, write clear summaries in the assistant response explaining every change.
2. Once git exists, enforce pull-request templates capturing tests run, screenshots, and risk assessment.
3. Keep branches short-lived; rebase frequently once applicable.

### 4.12 Test-Driven Development (TDD) Discipline
1. **Red-Green-Refactor Cycle**: Always follow the TDD cycle:
   - **Red**: Write a failing test that defines the desired behavior
   - **Green**: Write the minimal implementation to make the test pass
   - **Refactor**: Improve the code while keeping tests passing
2. **Write Tests First**: For new features, start with test cases before implementation. Tests should:
   - Be descriptive and readable (test names should explain what behavior is being verified)
   - Cover edge cases and error conditions, not just happy paths
   - Be isolated and independent (no shared state between tests)
3. **Test Organization**:
   - Group tests by feature/module (e.g., `InputBusTests.swift` for `InputBus.swift`)
   - Use consistent naming: `test<MethodName>_<ExpectedBehavior>` (e.g., `testAdCooldownPeriodInterstitial`)
   - Arrange-Act-Assert (AAA) pattern: Setup, Execute, Verify
4. **Mock External Dependencies**: Use mocks/stubs for external services (network, databases, file system) to keep tests fast and deterministic
5. **Coverage Requirements**: Maintain >80% code coverage for core logic. Use `swift test --enable-code-coverage` to verify
6. **No Regressions**: All tests must pass before committing. If a test fails, either fix the implementation or update the test if requirements changed (with justification)
7. **Test Speed**: Unit tests should run in milliseconds. Slow tests (>1s) should be integration tests and run separately
8. **When Not to Use TDD**: Accept writing implementation first for:
   - Pure UI code (SwiftUI views)
   - Exploratory research/prototyping
   - Trivial wrappers around external APIs (add tests afterward)

## 5. Adding Real Tooling (Checklist)
1. Confirm desired language/runtime with the user.
2. Initialize the project (`npm init`, `cargo init`, etc.).
3. Add formatter and linter configs.
4. Define build/test scripts and record them in Section 3.
5. Add documentation (README, SETUP, ADRs) summarizing architecture choices.
6. Update this file to replace placeholders with authoritative commands.

## 6. Agent Operating Tips
1. Always describe any file or directory you create in your final message.
2. Prefer `apply_patch`, `read`, `write`, `glob`, and `grep` tools over generic shell commands for file manipulation.
3. When uncertain, make a best-effort assumption, implement it, and clearly state the assumption in your response.
4. If a task requires secrets, explain the gap and provide a mock implementation or interface instead of blocking.
5. Keep responses concise but complete; humans rely on your summaries to understand repo state.
6. **Always run tests after each coding task** - Before considering a task complete, run `./test.sh test` (or equivalent) to ensure all tests pass with no regressions. Fix any failing tests before finishing.
7. **Never leave broken tests** - If a test fails, investigate and fix the issue. Do not skip or ignore failing tests.

## 7. Outstanding TODOs
1. Populate actual build/lint/test commands once the first stack is chosen.
2. Add concrete code style examples per language when files exist.
3. Create setup automation (Makefile, Taskfile, package scripts) after the first scaffold.
4. Mirror any future Cursor or Copilot rule files in this document.
5. Re-run this checklist whenever significant tooling changes occur.

---

Keep this guide synchronized with reality; outdated automation instructions harm agents more than no instructions at all.

## Active Technologies
- Swift 5.10 (Xcode 16) plus limited C/C++ bridges for existing emulator cores + SwiftUI, Combine, MetalKit, GameController, GoogleWebRTC, StoreKit 2, URLSession, Core Data (001-ios-multi-emulator)
- Core Data for ROM metadata and telemetry caches; FileManager sandbox for ROMs/save states with checksum metadata; Keychain for device entitlement keys (001-ios-multi-emulator)

## Recent Changes
- 001-ios-multi-emulator: Added Swift 5.10 (Xcode 16) plus limited C/C++ bridges for existing emulator cores + SwiftUI, Combine, MetalKit, GameController, GoogleWebRTC, StoreKit 2, URLSession, Core Data
- Updated test.sh to work with Swift Package Manager instead of CocoaPods; added build-macos and test-macos commands
- Phase 3.6 completed: Game playback and emulation engine with Metal rendering, AVAudioEngine audio, touch controls, input mapping, save states, fast-forward, and frame skip
- Added 30+ new tests for Phase 3.6 features (EmulatorCoreFactory, AudioEngine, MetalRenderer, GamePlayViewModel, TouchControlPad)
- Added iOS Simulator testing workflow with xcodegen support
