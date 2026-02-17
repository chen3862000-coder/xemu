# Implementation Plan: iOS Multi-System Emulator Platform

**Branch**: `[001-ios-multi-emulator]` | **Date**: 2026-02-17 | **Spec**: [specs/001-ios-multi-emulator/spec.md](./spec.md)  
**Input**: Feature specification from `/specs/001-ios-multi-emulator/spec.md`

## Summary

Launch an iOS 17+ emulator that unifies multiple console cores inside a SwiftUI/Metal host layer, enforces StoreKit-driven entitlements (Remove Ads, Experimental Pack, Pro bundle), tracks Legit Mode telemetry, and introduces rollback-based multiplayer over WebRTC. The plan prioritizes compliance (BYO ROM copy, DMCA process), revenue (server-validated IAP tiers), and quality-of-service (60 fps stable cores, <120 ms multiplayer latency) using the Phase 0 research decisions.

## Technical Context

**Language/Version**: Swift 5.10 (Xcode 16) plus limited C/C++ bridges for existing emulator cores  
**Primary Dependencies**: SwiftUI, Combine, MetalKit, GameController, GoogleWebRTC, StoreKit 2, URLSession, Core Data  
**Storage**: Core Data for ROM metadata and telemetry caches; FileManager sandbox for ROMs/save states with checksum metadata; Keychain for device entitlement keys  
**Testing**: XCTest + XCUITest plus deterministic replay harness for emulator cores and multiplayer sync simulations  
**Target Platform**: iOS/iPadOS 17+ on A12 Bionic or newer devices  
**Project Type**: Mobile client with companion backend services (entitlements, community telemetry, multiplayer signaling/TURN)  
**Performance Goals**: Stable cores at locked 60 fps, experimental cores ≥45 fps with configurable frame skip, entitlement refresh round trips ≤5 s p95, multiplayer input-to-sim latency ≤120 ms, 95% session reliability  
**Constraints**: App Store compliance (Guidelines 3.1.1, 4.7, 5.2); no bundled ROM/BIOS; offline grace 5–7 days; gameplay sessions must remain ad-free; multiplayer limited to whitelisted systems until telemetry proves quality  
**Scale/Scope**: 500k MAU target in 12 months, 50k paid conversions (8% MAU), 5k concurrent multiplayer sessions, compatibility catalog for ~2k ROM hashes at launch

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

`.specify/memory/constitution.md` currently only contains placeholder headings (no named principles, constraints, or governance). With no ratified directives to verify, this plan records **PASS (no constitution requirements defined yet)**. Future plans must update this section once the constitution is authored.

## Project Structure

### Documentation (this feature)

```text
specs/001-ios-multi-emulator/
├── plan.md              # Implementation plan (this file)
├── research.md          # Phase 0 findings
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 onboarding
├── contracts/           # OpenAPI / schema contracts
└── tasks.md             # Delivery breakdown (/speckit.tasks)
```

### Source Code (repository root)

```text
ios/
├── AppHost/                # SwiftUI + Metal application, feature modules
│   ├── Sources/
│   ├── EmulatorCore/       # Core host protocols + adapters
│   ├── Features/           # Library, achievements, multiplayer UI
│   └── Tests/
└── Packages/
    └── SharedKit/         # Swift package for input bus, save service, telemetry SDK

backend/
├── services/
│   ├── entitlements/      # Receipt validation + entitlement JWT service
│   ├── community/         # Legit tracking, achievements, leaderboards APIs
│   └── multiplayer-signal/# Matchmaking/signaling, STUN/TURN config
└── shared/
    └── proto/             # Generated contracts shared across services/clients

infrastructure/
└── terraform/             # CDN, API Gateway, STUN/TURN deployments

qa/
└── scenarios/             # Deterministic replay scripts, regression fixtures
```

**Structure Decision**: Adopt a mobile-plus-services topology so responsibilities map cleanly to runtime domains: `ios/AppHost` hosts all emulator UX and leverages shared Swift packages, while `backend/services/*` isolates network responsibilities (entitlements, community telemetry, multiplayer signaling). Shared contracts reside in `backend/shared/proto`, infra-as-code lives under `infrastructure/`, and QA automation assets are centralized in `qa/` for determinism.

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| *None* | — | — |

## Phase 0 – Research Outcomes

- Stored findings in `specs/001-ios-multi-emulator/research.md`; all potential ambiguities now have actionable defaults (StoreKit 2 + backend validation, BYO-ROM legal messaging, deterministic rollback strategy, save-state storage model).
- No open **NEEDS CLARIFICATION** tags remain; research confirmed we must build DMCA workflows, a reusable host-services layer, and TURN-backed WebRTC signaling before exposing multiplayer.

## Phase 1 – Design & Contracts

### Data Model

- `data-model.md` enumerates six core entities (ROMLibraryEntry, EntitlementRecord, DeviceProfile, GameplaySession, AchievementDefinition, MultiplayerMatch) including key fields, state transitions, and data volume assumptions for 500k MAU.
- Relationships reflect FR-001…FR-015 traces: e.g., `EntitlementRecord.device_bindings` enforces 3-device limit; `GameplaySession.verdict` supports Legit Mode enforcement.

### API Contracts

- `contracts/openapi.yaml` defines REST contracts for entitlements, device binding, session telemetry, achievements, leaderboards, and multiplayer signaling (matchmaking, SDP exchange, ICE relay, quality reports).
- Security defaults to JWT bearer tokens minted by `/entitlements/refresh`; endpoints document error states (422 invalid receipt, 409 device limit, etc.) to align with FR-005/FR-006/FR-012.

### Quickstart & Agent Context

- `quickstart.md` now documents prerequisites, repo bootstrap commands, local backend expectations, and test workflows so future contributors can stand up the stack.
- Ran `.specify/scripts/bash/update-agent-context.sh opencode`, updating `AGENTS.md` with Swift/Metal/WebRTC tooling so future AI agents inherit the same context.

### Constitution Re-check

- Constitution remains undefined (placeholders only). Post-design review therefore still evaluates as **PASS**, with a note to author governing principles before implementation begins.

## Phase 2 – Implementation Preparation (Next Steps)

- Finalize project scaffolding: generate Swift packages, create backend service skeletons, and add infra IaC baselines per the structure defined above.
- Derive `/speckit.tasks` work items from FR-001…FR-015, tagging monetization, telemetry, and multiplayer epics separately.
- Stand up mock services that satisfy `contracts/openapi.yaml` to unblock client-side development before full backend readiness.
- Establish automated test harnesses (deterministic replay, WebRTC soak tests) plus observability baselines (entitlement refresh latency, multiplayer quality metrics) ahead of code delivery.
