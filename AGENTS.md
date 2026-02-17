# AGENTS AND PROJECT OPERATIONS GUIDE

This document equips any autonomous coding agent working inside `/Users/spiderck/Development/xemu` with enough tribal knowledge to operate safely even though the repository currently contains no tracked files. Update this file whenever concrete tooling, frameworks, or workflows become available. The goal length is intentional (~150 lines) so that agents have ample cues to avoid missteps.

## 1. Repository Snapshot
1. The workspace is presently empty: no git metadata, no package manifests, no build artifacts.
2. Treat every action as greenfield development; assume you own the entire tree unless told otherwise.
3. Before adding dependencies or scaffolding, confirm with the user whether a particular stack (Node, Python, Go, etc.) is expected.
4. If you create a project structure (e.g., `npm init`, `cargo init`), log it in this file and mention it in your summary so humans stay in sync.
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

## 7. Outstanding TODOs
1. Populate actual build/lint/test commands once the first stack is chosen.
2. Add concrete code style examples per language when files exist.
3. Create setup automation (Makefile, Taskfile, package scripts) after the first scaffold.
4. Mirror any future Cursor or Copilot rule files in this document.
5. Re-run this checklist whenever significant tooling changes occur.

---

Keep this guide synchronized with reality; outdated automation instructions harm agents more than no instructions at all.
