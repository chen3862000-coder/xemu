# Feature Specification: iOS Multi-System Emulator Platform

**Feature Branch**: `[001-ios-multi-emulator]`  
**Created**: 2026-02-17  
**Status**: Draft  
**Input**: User description: "Build an iOS Multi-System Emulator. For more product details and blueprint, please refer to the doc under docs/iOS_Emulator_Platform_Blueprint.md."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Play Stable Retro Titles (Priority: P1)

Players import their legally sourced ROMs for NES/FC, GB/GBC, GBA, Genesis/Mega Drive, Nintendo DS, and PS1, then launch sessions with controller support, per-game settings, and instant save states even when offline.

**Why this priority**: Stable consoles are the launch-critical experience that validates App Store compliance and grows the daily active base needed for any monetization.

**Independent Test**: Import a ROM, confirm it appears with metadata, start a session with a physical controller, make and restore save states, and resume offline without connecting to entitlement services for up to 7 days.

**Acceptance Scenarios**:

1. **Given** a player imports a supported ROM, **When** the library refreshes, **Then** the title appears with detected art, platform tagging, and Launch button enabled.
2. **Given** a player is in gameplay, **When** they trigger a save state and later reload it, **Then** progress resumes exactly where saved with no crashes or controller disconnects.
3. **Given** the device loses connectivity, **When** the player reopens the app within the offline grace window, **Then** stable systems still launch using the last validated entitlements.

---

### User Story 2 - Unlock Experimental Consoles (Priority: P2)

High-end device owners choose to purchase the Experimental Pack to access PS2 and 3DS emulation that is clearly labeled "Experimental Beta," guided by compatibility lists, resolution scaling, and performance safeguards.

**Why this priority**: Experimental systems create an upsell path and differentiate from single-system emulators while protecting reviews by filtering to capable hardware.

**Independent Test**: Simulate a qualifying device, purchase the Experimental Pack, verify entitlement delivery, enforce device compatibility gates, and ensure unsupported devices keep experimental toggles disabled.

**Acceptance Scenarios**:

1. **Given** a player on a whitelisted device buys the Experimental Pack, **When** entitlements refresh, **Then** PS2/3DS entries unlock with resolution controls and warning copy displayed before launch.
2. **Given** a player on an unsupported or low-end device attempts to launch an experimental ROM, **When** hardware checks fail, **Then** the app blocks launch and surfaces compatibility guidance without processing payment.
3. **Given** a player has not renewed entitlements beyond the offline grace window, **When** they open experimental titles, **Then** access is revoked until the device reconnects for validation.

---

### User Story 3 - Earn Legit Progress & Achievements (Priority: P2)

Players who care about community credibility enable Legit Mode, track playtime/completion stats, and earn achievements that require server-confirmed sessions without save-state abuse, unlocking eligibility for global leaderboards and seasonal rankings.

**Why this priority**: Legit tracking and achievements create long-term engagement loops, provide non-monetary rewards, and underpin upcoming social competitions.

**Independent Test**: Play a session with Legit Mode enabled, observe telemetry heartbeat packets, trigger an achievement condition, and confirm the leaderboard reflects the run only when server validation succeeds.

**Acceptance Scenarios**:

1. **Given** Legit Mode is on, **When** a player pauses or loads disallowed save states, **Then** the session is flagged and excluded from leaderboards with a clear notification.
2. **Given** a player completes the defined criteria for an achievement (e.g., beating a game without rewinds), **When** the session ends cleanly, **Then** the achievement unlocks and metrics update in the profile timeline.
3. **Given** a player reviews global leaderboards, **When** they filter by season or console, **Then** only Legit sessions that passed integrity checks appear.

---

### User Story 4 - Invite Friends to Multiplayer Sessions (Priority: P3)

Players start a multiplayer lobby for supported systems (initially NES and GBA), exchange invites, pass latency checks, and enjoy synchronized gameplay with post-match stats while the service enforces fair play and handles disconnects gracefully.

**Why this priority**: Multiplayer is a differentiator that motivates retention, but it is gated as P3 because the foundation (stable emulation, entitlement integrity, community signals) must exist first.

**Independent Test**: Create a lobby, send an invite, complete a multiplayer session including mid-game pause/recovery, and audit match history plus anomaly detection records afterward.

**Acceptance Scenarios**:

1. **Given** Host A opens a multiplayer lobby, **When** Friend B accepts the invite, **Then** both clients validate matching ROM hashes and the lobby starts only if bandwidth and latency thresholds pass.
2. **Given** a multiplayer session is in progress, **When** a participant disconnects briefly, **Then** the system attempts resync within a grace period or records a forfeiture with corresponding leaderboard impact.
3. **Given** post-match review occurs, **When** suspicious input timing is detected, **Then** the match is flagged for soft enforcement (shadow ban, exclusion from rankings) without exposing technical jargon to users.

### Edge Cases

- Entitlement refresh service is unreachable while the offline grace period has already elapsed; stable systems must keep working while experimental systems lock with actionable copy.
- A user exceeds the maximum allowed device registrations (three installs); UI must prompt to revoke an older device before granting access on the new one.
- Imported ROM metadata fails to match the compatibility database; the app must still allow play but flag unknown titles and bypass leaderboard eligibility until verified.
- Multiplayer invite is accepted on a ROM with mismatched regional hashes; lobby must refuse to start and share remediation steps.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST allow users to import their own ROMs/BIOS (never distributing copyrighted content) and automatically categorize them under the correct console family with editable metadata.
- **FR-002**: System MUST provide stable emulation for NES/FC, GB/GBC, GBA, Genesis/Mega Drive, Nintendo DS, and PS1 with configurable input, audio, video, and save-state support delivered per title.
- **FR-003**: System MUST enforce App Store-safe ad placements limited to the library banner and pre-game interstitial, never during active gameplay or multiplayer sessions.
- **FR-004**: System MUST offer in-app purchases for Remove Ads, Experimental Pack, and (optional) Pro bundle, each mapped to server-side feature flags so entitlements can be remotely revoked or updated.
- **FR-005**: System MUST validate purchases via a backend flow that exchanges the device receipt for short-lived JWT entitlements, binds them to a device key, honors up to three active devices per account, and enforces a 5–7 day offline grace window.
- **FR-006**: System MUST block experimental consoles on devices that fail capability checks (e.g., RAM/SoC whitelist) and provide compatibility guidance plus refund escalation messaging when gating occurs.
- **FR-007**: System MUST expose resolution scaling, frame skip, and "Experimental Beta" labeling for PS2 and 3DS launches, along with a published compatibility list managed via remote config.
- **FR-008**: System MUST maintain a ROM library experience with artwork, completion status, playtime stats, per-game configuration overrides, and quick filters for Stable vs Experimental content.
- **FR-009**: System MUST capture gameplay sessions through start/heartbeat/end events, detect rewinds/save-state abuse when Legit Mode is active, and exclude non-compliant runs from leaderboards automatically.
- **FR-010**: System MUST deliver achievements (initially time-based, completion, and no-save-state badges) plus profile timelines summarizing milestones across consoles.
- **FR-011**: System MUST provide Legitimacy Profiles with toggleable Legit Mode, enforcement feedback (warnings, suspensions, shadow bans), and appeals instructions to sustain trust.
- **FR-012**: System MUST offer multiplayer lobbies for targeted systems with invite codes/links, bandwidth & latency checks, ROM hash verification, mid-session resync, and post-match stats storage.
- **FR-013**: System MUST implement compliance workflows: clear messaging that ROMs must be user-supplied, DMCA takedown contact from the settings menu, and detection/removal of flagged content from cloud backups.
- **FR-014**: System MUST capture monetization analytics (conversion to Remove Ads, Experimental Pack uptake, multiplayer engagement) while remaining privacy-compliant and exposing trends to product stakeholders.
- **FR-015**: System MUST surface in-app support for troubleshooting (compatibility FAQ, entitlement refresh button, contact links) to deflect App Store review complaints.

### Key Entities *(include if feature involves data)*

- **ROM Library Entry**: Player-imported title with platform, region hash, artwork, compatibility tier, custom control/layout overrides, and completion stats.
- **Entitlement Record**: Represents purchases (Remove Ads, Experimental Pack, Pro bundle) with activation date, expiry/grace window, device bindings, and allowed consoles/features.
- **Device Profile**: Stores device hardware identifiers, performance tier, entitlement keys, and last validation timestamp used for gating experimental systems.
- **Gameplay Session**: Tracks console, ROM hash, Legit Mode flags, telemetry heartbeats, achievement triggers, and leaderboard eligibility state.
- **Achievement Definition**: Named objectives with trigger conditions, validation rules (e.g., forbid rewinds), and rewards surfaced in profiles.
- **Multiplayer Match**: Records lobby host, participants, verified ROM hash, latency metrics, final result, and enforcement signals for anomaly reviews.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 95% of stable-console sessions run for at least 60 minutes without a crash or controller disconnect across the supported device matrix.
- **SC-002**: 90% of entitlement refreshes (purchase validation plus device binding) complete within 5 seconds, and no more than 2% of users encounter an offline lockout shorter than 5 days.
- **SC-003**: At least 30% of weekly active users engage with achievements or Legit Mode tracking, and 80% of recorded achievements pass server validation on first submission.
- **SC-004**: Multiplayer lobby creation-to-start success rate reaches 85% for supported titles, with average end-to-end latency under 120 ms for ranked matches in the same region.
- **SC-005**: Combined Remove Ads + Experimental Pack conversion reaches 8% of MAU within 90 days while maintaining an App Store rating of 4.6 or higher (measured via review scraping).

## Assumptions

- Apple permits distributed functionality so long as no ROM/BIOS files are bundled or linked, and wording about legal ownership remains visible in onboarding and settings.
- High-end device gating relies on a centrally maintained whitelist of SoC and RAM thresholds that product ops can update without shipping code.
- Offline grace enforcement targets 6 days by default, adjustable between 5–7 days via remote config as compliance requirements evolve.
- Multiplayer rollouts begin as invite-only betas per console so capacity can scale gradually before launching ranked ladders.
