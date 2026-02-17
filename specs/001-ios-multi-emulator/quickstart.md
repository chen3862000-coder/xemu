# Quickstart — iOS Multi-System Emulator Platform

## Prerequisites

- **Hardware**: Apple Silicon Mac with Xcode 16+, iOS 17.0+ devices (A12 Bionic or newer) for experimental cores.
- **Tooling**: Xcode command-line tools, Swift 5.10 toolchain, CocoaPods (for GoogleWebRTC), Node.js 20+ (backend scaffolding scripts), Terraform 1.7+ (infrastructure prototypes), Docker Desktop (local API mocks).
- **Accounts**: Apple Developer Program access for StoreKit testing, App Store Server API keys, Firebase/Crashlytics (optional) for crash reporting, TURN provider credentials (e.g., Twilio, Xirsys) for relay testing.

## Repository Setup

```bash
git clone <repo-url>
cd xemu
brew bundle   # once Brewfile is added
```

Bootstrap project directories (until code is generated):

```bash
mkdir -p ios/AppHost/Sources backend/services/{entitlements,community,multiplayer-signal}
```

Install Swift package dependencies once Package.swift is available:

```bash
cd ios/AppHost && swift package resolve
```

Install pods for WebRTC bindings when the Podfile lands:

```bash
cd ios/AppHost && pod install
```

## Running the iOS App (future state)

1. Open `ios/AppHost/AppHost.xcworkspace` in Xcode.
2. Select the `AppHost` scheme and target an iOS 17+ device/simulator. Experimental cores require physical hardware.
3. Add a `.env.local` (or Xcode build setting) with API base URLs, TURN credentials, and feature flags such as `EXPERIMENTAL_WHITELIST_VERSION`.
4. Build & run. On first launch:
   - Import a legal ROM via Files app.
   - Use the "Refresh Entitlements" button to call `/entitlements/refresh`.
   - Opt into Legit Mode to exercise telemetry flows.

## Running Backend Services (future state)

Each service will ship as a containerized TypeScript/Go/Rust process (TBD). For planning purposes:

```bash
cd backend/services/entitlements
cp .env.example .env
docker compose up --build
```

Expose mock endpoints at `http://localhost:8080/v1` mirroring `contracts/openapi.yaml` so the app can integrate before full infra exists. Provide seeded responses for entitlements, sessions, achievements, and multiplayer tickets.

## Testing Workflow

- **Client**: Run `xcodebuild test -scheme AppHost -destination 'platform=iOS Simulator,name=iPhone 15'` for deterministic host-layer tests. Enable the replay harness to validate emulator determinism and rollback.
- **Backend**: Execute upcoming unit suites via `npm test`, `go test ./...`, or `cargo test` per service once scaffolding lands. Add contract tests to ensure OpenAPI compatibility.
- **Integration**: Use TestFlight internal beta to validate StoreKit flows. Supply sandbox Apple IDs for QA to simulate purchases and refunds.

## Deployment Notes

- Configure App Store server notifications so entitlement revocations cascade quickly.
- Provision TURN servers in each region before enabling multiplayer beta; store credentials in secret management (e.g., AWS Secrets Manager) referenced by backend services.
- Document DMCA takedown contacts and ensure telemetry for compliance (entitlement revokes, device limit enforcement) is routed to observability stack before GA.
