# Tasks: iOS Multi-System Emulator Platform

**Input**: Design documents from `/specs/001-ios-multi-emulator/`
**Prerequisites**: plan.md (required), spec.md (required for user stories), research.md, data-model.md, contracts/

**Tests**: Tests are optional; current focus is client-side delivery. QA validation relies on story-specific independent tests.

**Organization**: Tasks are grouped by user story so each slice can be implemented, tested, and demoed independently. Backend/cloud services are deferred until later phases; all networking surfaces consume local mock data while preparing for an Azure deployment in future iterations.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Maps task to a user story (US1, US2, etc.)
- Include exact file paths in each description

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Establish client workspace and Azure-aligned documentation without implementing backend services.

- [X] T001 Create client-first repo structure (`ios/AppHost`, `Packages/SharedKit`, `docs/cloud`, `qa/scenarios`) with placeholder README files
- [X] T002 [P] Initialize Swift package + Xcode workspace in `ios/AppHost` (Package.swift, AppHost.xcodeproj, Podfile referencing GoogleWebRTC)
- [X] T003 [P] Draft Azure preference + service boundaries in `docs/cloud/azure-readiness.md` (outline Service Bus, App Service, Cosmos DB assumptions)
- [X] T004 [P] Configure root developer tooling (`.editorconfig`, `.gitignore`, `Brewfile`, `scripts/bootstrap.sh`) for Swift, CocoaPods, and QA harnesses

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core client architecture that all user stories depend upon; no backend services are built yet.

- [X] T005 Define host-layer protocols (video/audio/input/save-state) in `Packages/SharedKit/Sources/HostServices/HostProtocols.swift`
- [X] T006 [P] Implement Core Data + FileManager persistence stack in `ios/AppHost/Sources/Persistence/PersistenceController.swift`
- [X] T007 [P] Implement SaveState storage with async compression in `ios/AppHost/Sources/Host/SaveStates/SaveStateStorage.swift`
- [X] T008 [P] Build input routing bus supporting touch/MFi/Bluetooth controllers in `ios/AppHost/Sources/Host/Input/InputBus.swift`
- [X] T009 Configure compliance/localization strings (BYO ROM, DMCA messaging, controller guidance) in `ios/AppHost/Resources/Localized/Compliance.strings`
- [X] T010 Create Azure API abstraction + mock provider in `ios/AppHost/Sources/Services/AzureApiStub.swift` (returns deterministic mock payloads)
- [X] T011 Document deterministic replay harness + QA instructions in `qa/scenarios/replay_harness.md`

**Checkpoint**: Foundation ready—user stories can now rely on stable host services and Azure-ready stubs.

---

## Phase 3: User Story 1 - Play Stable Retro Titles (Priority: P1) 🎯 MVP

**Goal**: Deliver ROM import, library management, controller support, save states, and offline grace handling purely on-device with entitlement UI tied to mock data.

**Independent Test**: Import a ROM, view metadata in the library, launch gameplay with controller + save-state cycle, and resume offline while entitlement UI reflects cached status from the mock Azure stub.

### Implementation for User Story 1

- [X] T012 [P] [US1] Implement ROM import flow (Files picker, hash detection, metadata enrichment) in `ios/AppHost/Sources/Features/Import/RomImportCoordinator.swift`
- [X] T013 [US1] Build ROM library UI with filters/artwork in `ios/AppHost/Sources/Features/Library/LibraryView.swift`
- [X] T014 [P] [US1] Wire stable emulator cores into host layer in `ios/AppHost/Sources/Host/StableSystemsCoordinator.swift`
- [X] T015 [P] [US1] Implement controller configuration overlay in `ios/AppHost/Sources/Features/Controls/ControllerOverlayView.swift`
- [X] T016 [US1] Enforce ad placement policy (library banner + pre-launch interstitial) in `ios/AppHost/Sources/Features/Library/AdsPolicyController.swift`
- [X] T017 [US1] Create entitlement UI + cache manager consuming `AzureApiStub` responses in `ios/AppHost/Sources/Features/Settings/EntitlementStatusView.swift`
- [X] T018 [US1] Implement offline grace + alerting logic in `ios/AppHost/Sources/Services/OfflineGraceManager.swift`
- [X] T019 [US1] Add session reliability logging hooks in `ios/AppHost/Sources/Telemetry/StableSessionTracker.swift`

**Checkpoint**: US1 is independently demoable with full client functionality and mock entitlements.

---

## Phase 4: User Story 2 - Unlock Experimental Consoles (Priority: P2)

**Goal**: Surface Experimental Pack purchase UX, device gating, and compatibility messaging while still relying on local configs and Azure stubs.

**Independent Test**: Toggle a whitelisted device profile, purchase the Experimental Pack via StoreKit sandbox, view compatibility data loaded from local config, and ensure unsupported devices display actionable guidance without backend calls.

### Implementation for User Story 2

- [ ] T020 [P] [US2] Build compatibility data store seeded from `ios/AppHost/Resources/Configs/compatibility.json`
- [ ] T021 [US2] Implement Experimental gating manager (hardware checks, entitlement flag evaluation) in `ios/AppHost/Sources/Features/Experimental/ExperimentalGatingManager.swift`
- [ ] T022 [P] [US2] Create experimental launch UI (warning copy, resolution scaling, frame-skip controls) in `ios/AppHost/Sources/Features/Experimental/ExperimentalLaunchView.swift`
- [ ] T023 [US2] Wire StoreKit purchase flow + entitlement refresh using Azure stub receipts in `ios/AppHost/Sources/Features/Store/PurchaseFlowController.swift`
- [ ] T024 [US2] Surface compatibility diagnostics + refund guidance sheet in `ios/AppHost/Sources/Features/Experimental/CompatibilityDiagnosticsSheet.swift`

**Checkpoint**: Experimental consoles are monetized/gated entirely on-device, ready for real Azure services later.

---

## Phase 5: User Story 3 - Earn Legit Progress & Achievements (Priority: P2)

**Goal**: Enable Legit Mode, local telemetry storage, achievement evaluation, and leaderboard views backed by mock data destined for Azure services later.

**Independent Test**: Run a Legit-enabled session, observe local heartbeat logging, trigger an achievement, and view profile + leaderboard updates driven by mock datasets.

### Implementation for User Story 3

- [ ] T025 [P] [US3] Implement Legit Mode session manager (rewind detection, telemetry capture) in `ios/AppHost/Sources/Telemetry/LegitModeManager.swift`
- [ ] T026 [US3] Persist heartbeat + session summaries to Core Data for later Azure sync in `ios/AppHost/Sources/Telemetry/SessionStore.swift`
- [ ] T027 [P] [US3] Seed achievement definitions + evaluation engine in `ios/AppHost/Sources/Features/Achievements/AchievementEngine.swift`
- [ ] T028 [US3] Build achievements timeline UI in `ios/AppHost/Sources/Features/Profile/ProfileTimelineView.swift`
- [ ] T029 [P] [US3] Create leaderboard view consuming mock data from `AzureApiStub` in `ios/AppHost/Sources/Features/Leaderboards/LeaderboardsView.swift`
- [ ] T030 [US3] Surface enforcement + Legit status banners in `ios/AppHost/Sources/Features/Profile/LegitStatusBannerView.swift`
- [ ] T031 [US3] Add manual sync/export controls for telemetry bundles (future Azure upload) in `ios/AppHost/Sources/Features/Settings/DataExportView.swift`

**Checkpoint**: Legit progress loop functions entirely client-side and stores data ready for future Azure syncing.

---

## Phase 6: User Story 4 - Invite Friends to Multiplayer Sessions (Priority: P3)

**Goal**: Implement client-side multiplayer lobby, WebRTC session management, rollback hooks, and quality reporting using peer-to-peer flows plus mock signaling tokens destined for Azure.

**Independent Test**: Start a lobby, share an invite code, connect via local peer-to-peer WebRTC using mock signaling data, play with rollback enabled, and review on-device quality stats.

### Implementation for User Story 4

- [ ] T032 [P] [US4] Build multiplayer lobby + invite UI (codes/links) in `ios/AppHost/Sources/Features/Multiplayer/LobbyView.swift`
- [ ] T033 [US4] Implement peer-to-peer signaling client consuming mock Azure tokens in `ios/AppHost/Sources/Features/Multiplayer/SignalingClient.swift`
- [ ] T034 [P] [US4] Integrate rollback/prediction engine hooks into host layer in `ios/AppHost/Sources/Host/Multiplayer/RollbackEngine.swift`
- [ ] T035 [US4] Create latency/quality overlay + diagnostics logging in `ios/AppHost/Sources/Features/Multiplayer/QualityOverlayView.swift`
- [ ] T036 [US4] Persist multiplayer match summaries + enforcement flags locally in `ios/AppHost/Sources/Telemetry/MultiplayerMatchStore.swift`

**Checkpoint**: Multiplayer invite experience works against mock signaling, primed for future Azure services.

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Documentation, observability, and Azure readiness items that span stories without building cloud services yet.

- [ ] T037 Update DMCA + controller-support documentation in `docs/DMCA_POLICY.md` and `ios/AppHost/Resources/OnboardingStrings.strings`
- [ ] T038 [P] Add client-side observability dashboards (metrics export scripts) and Azure ingestion notes in `docs/cloud/azure-observability.md`
- [ ] T039 Validate quickstart instructions by running `scripts/validate-quickstart.sh` (build app, execute replay harness, document results)

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: Start immediately; establishes repo + Azure planning docs.
- **Foundational (Phase 2)**: Depends on Setup; BLOCKS all user stories because host services and Azure stubs must exist first.
- **User Stories (Phase 3–6)**: Depend on Foundational completion. Stories can proceed sequentially (recommended P1 → P2 → P2 → P3) or in parallel once shared components stabilize.
- **Polish (Phase 7)**: Depends on desired user stories being complete.

### User Story Dependencies

- **US1 (P1)**: First deliverable; no dependencies beyond Phase 2.
- **US2 (P2)**: Requires US1 entitlement UI/stubs; can start after US1 reaches functional baseline.
- **US3 (P2)**: Depends on telemetry storage foundation from Phase 2 but not on US2; can run after US1.
- **US4 (P3)**: Requires host multiplayer hooks + telemetry from earlier phases, so begin after US3 stabilizes session logging.

### Within Each User Story

- Prefer implementing UI + services that touch different files in parallel (tasks marked [P]).
- Since backend services are deferred, ensure all remote calls share the AzureApiStub for consistent mock data.
- Run the story’s Independent Test before moving to the next priority.

---

## Parallel Examples

### User Story 1

```bash
# Parallel track 1
T012 (ROM import) and T013 (library UI) can progress simultaneously because they touch different files.

# Parallel track 2
T014 (host integration) and T015 (controller overlay) can run concurrently.
```

### User Story 2

```bash
# Data + UI
T020 (compatibility data store) and T022 (launch UI) can proceed simultaneously.

# Purchases vs diagnostics
T023 (StoreKit purchase flow) can run alongside T024 (diagnostics sheet).
```

### User Story 3

```bash
# Telemetry vs achievements
T025 (Legit manager) and T027 (achievement engine) run in parallel once data models exist.

# Surfaces
T028 (timeline) and T029 (leaderboards view) can progress concurrently using mock data.
```

### User Story 4

```bash
# Networking vs rollback
T033 (signaling client) and T034 (rollback engine) can proceed in tandem while sharing stub tokens.

# UI vs storage
T032 (lobby UI) can move forward alongside T036 (match store).
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1 (Setup) and Phase 2 (Foundational).
2. Execute all US1 tasks to deliver stable retro play with entitlement UI using mock data.
3. Run the US1 Independent Test and share via TestFlight as the MVP.

### Incremental Delivery

1. US1 establishes ROM import and save states.
2. US2 introduces monetizable experimental consoles with on-device gating.
3. US3 adds retention loops (Legit Mode, achievements) still using mock Azure data.
4. US4 enables invite-based multiplayer once telemetry proves stable.

### Parallel Team Strategy

1. Entire team collaborates on Setup + Foundational tasks.
2. After US1 stabilizes, split efforts:
   - Developer A: US2 experimental gating.
   - Developer B: US3 achievements/leaderboards.
   - Developer C: US4 multiplayer (once US3 telemetry components are ready).
3. QA uses `qa/scenarios/replay_harness.md` to regress each story before merging.

---

## Notes

- Backend/cloud services are intentionally deferred; Azure preferences are captured in documentation and mock layers.
- [P] tasks denote safe parallel execution (different files, isolated responsibilities).
- Story labels ensure traceability from spec → plan → implementation tasks.
- Each story ships with an Independent Test so QA can validate increments even without real backend services.
