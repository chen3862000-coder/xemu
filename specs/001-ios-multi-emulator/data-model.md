# Data Model — iOS Multi-System Emulator Platform

## Entity Overview

| Entity | Purpose | Relationships |
|--------|---------|---------------|
| ROMLibraryEntry | Represents a user-imported ROM/BIOS with metadata, per-game settings, and compatibility tiering. | Linked to `DeviceProfile` (availability) and `GameplaySession` (usage stats). |
| EntitlementRecord | Tracks purchases (Remove Ads, Experimental Pack, Pro) and their device bindings/offline grace. | References `DeviceProfile` entries; influences feature toggles for `ROMLibraryEntry` and `GameplaySession`. |
| DeviceProfile | Captures hardware capability, entitlement keys, and validation timestamps per install. | Has many `EntitlementRecord`s (active keys) and `GameplaySession`s (runs on device). |
| GameplaySession | Represents an individual play or multiplayer session with Legit Mode telemetry. | Tied to one `ROMLibraryEntry`, one `DeviceProfile`, optionally one `MultiplayerMatch`. |
| AchievementDefinition | Defines unlock criteria and integrity rules. | Consumed by `GameplaySession` evaluation; unlocks recorded under a player profile. |
| MultiplayerMatch | Stores lobby metadata, players, network stats, and enforcement outcomes. | Aggregates multiple `GameplaySession`s (one per participant) and references ROM hash + achievement impacts. |

## ROMLibraryEntry

| Field | Type | Description |
|-------|------|-------------|
| `entry_id` | UUID | Internal identifier; unique per imported ROM. |
| `user_id` | UUID | Owner profile. |
| `rom_hash` | SHA256 | Dedup + compatibility lookups; also used for multiplayer validation. |
| `title` | String | User-visible title (auto-detected, editable). |
| `platform` | Enum (`NES`, `GB`, `GBA`, `GENESIS`, `NDS`, `PS1`, `PS2`, `3DS`) | Determines emulator core and compatibility tier. |
| `tier` | Enum (`Stable`, `Experimental`, `Unknown`) | Drives gating and warning copy. |
| `artwork_uri` | URL | Cached artwork or placeholder. |
| `playtime_total` | Duration | Aggregated from `GameplaySession`s. |
| `completion_state` | Enum (`NotStarted`, `InProgress`, `Completed`, `Mastered`) | Derived from Legit Mode stats + achievements. |
| `per_game_settings` | JSON | Overrides for controls, video filters, performance flags. |
| `last_played_at` | Timestamp | For surfacing recently played list. |
| `eligible_for_leaderboard` | Boolean | False when metadata unknown or Legit Mode disabled. |

**State Transitions**: `tier` defaults to `Unknown` → `Stable/Experimental` once compatibility DB matches hash. `completion_state` progresses only via validated `GameplaySession` summaries (e.g., Completed after credits flag or 100% achievements).

## EntitlementRecord

| Field | Type | Description |
|-------|------|-------------|
| `entitlement_id` | UUID | Unique record per purchase. |
| `user_id` | UUID | Owner. |
| `product_code` | Enum (`REMOVE_ADS`, `EXPERIMENTAL_PACK`, `PRO_BUNDLE`) | Maps to StoreKit product IDs. |
| `transaction_id` | String | Apple order/transaction identifier used for audits. |
| `status` | Enum (`Active`, `Revoked`, `Refunded`, `Expired`) | Drives gating UI. |
| `activated_at` | Timestamp | When entitlements became available. |
| `expires_at` | Timestamp | Null for non-consumables; used for experimental trials. |
| `offline_grace_end` | Timestamp | Last permissible offline launch time. |
| `device_bindings` | Array<DeviceBinding> | Up to three installs with device key + validated_at. |
| `features` | JSON | Flags toggled by backend (e.g., `ps2_enabled`, `ads_disabled`). |

**Lifecycle**: Created after backend receipt verification → `Active`. Moves to `Revoked/Refunded` on chargebacks or DMCA events. When `offline_grace_end` < now, app disables premium features until refresh.

## DeviceProfile

| Field | Type | Description |
|-------|------|-------------|
| `device_id` | UUID | Generated during first launch; stored in Keychain. |
| `user_id` | UUID | Linked account. |
| `hardware_class` | Enum (`Tier1`, `Tier2`, `Tier3`, `Unsupported`) | Based on SoC + RAM. |
| `whitelist_version` | String | Remote config version used for gating decisions. |
| `last_entitlement_refresh` | Timestamp | Latest successful backend validation. |
| `registered_at` | Timestamp | When counted toward 3-device limit. |
| `rom_storage_bytes` | Integer | Space consumed, helps prompt cleanup. |
| `legit_mode_capable` | Boolean | False if jailbreak/root detection triggered. |

**Constraints**: Each `user_id` can have up to 3 `DeviceProfile`s in `registered` status. `hardware_class` drives experimental gating and performance warnings.

## GameplaySession

| Field | Type | Description |
|-------|------|-------------|
| `session_id` | UUID | Unique per run. |
| `user_id` | UUID | Player identity. |
| `device_id` | UUID | Device used. |
| `entry_id` | UUID | Linked ROMLibraryEntry. |
| `mode` | Enum (`SinglePlayer`, `Legit`, `MultiplayerHost`, `MultiplayerGuest`) | Affects telemetry rules. |
| `started_at` | Timestamp | Start time. |
| `ended_at` | Timestamp | Null until completion. |
| `heartbeat_interval` | Integer (ms) | Frequency for server validation. |
| `rewind_events` | Integer | Count of rewinds/save-state restores. |
| `achievement_triggers` | Array<AchievementTrigger> | Candidate unlocks captured during session. |
| `verdict` | Enum (`Pending`, `Valid`, `Invalid`, `Flagged`) | Assigned after server review. |
| `latency_metrics` | JSON | Populated for multiplayer; includes RTT, jitter, packet loss. |

**State**: `Pending` upon session end → `Valid` if telemetry passes; `Invalid` when unauthorized save states detected; `Flagged` when manual review required. Legit Mode requires `rewind_events = 0`.

## AchievementDefinition

| Field | Type | Description |
|-------|------|-------------|
| `achievement_id` | UUID | Identifier for references. |
| `title` | String | UI label. |
| `description` | String | Unlock criteria copy. |
| `category` | Enum (`Completion`, `TimeAttack`, `NoSaveState`, `Multiplayer`) | Filter grouping. |
| `requirements` | JSON | Declarative conditions (e.g., `no_rewinds=true`, `max_time=02:00:00`). |
| `reward_points` | Integer | Contribution to profile score/seasonal ladder. |
| `legit_only` | Boolean | True when only Legit Mode sessions can earn it. |
| `seasonal` | Boolean | False for evergreen achievements. |

**Lifecycle**: Definitions versioned with `seasonal` flag; revoking an achievement requires migrating existing unlocks to archived status.

## MultiplayerMatch

| Field | Type | Description |
|-------|------|-------------|
| `match_id` | UUID | Lobby identifier. |
| `game_hash` | SHA256 | Must match between peers. |
| `host_session_id` | UUID | Links to host `GameplaySession`. |
| `guest_session_ids` | Array<UUID> | Linked guest sessions. |
| `region` | Enum (`NA`, `EU`, `APAC`, etc.) | Determines signaling/STUN selection. |
| `candidate_types` | Array (`host`, `srflx`, `relay`) | Actual ICE candidates used. |
| `rtt_ms_p50/p95` | Integer | Telemetry for tuning. |
| `rollback_depth_max` | Integer | Max frames rolled back in match. |
| `disconnect_reason` | Enum (`None`, `Timeout`, `CheatSuspected`, `Quit`) | Finishes match summary. |
| `enforcement_action` | Enum (`None`, `ShadowBan`, `LeaderboardBan`) | Soft penalties recorded.

**Flow**: Match enters `Pending` when lobby created, `Active` after handshake success, `Completed` on clean finish, `Invalidated` when ROM hashes mismatch or enforcement triggers.

## Supporting Structures

- **DeviceBinding**: `{ device_id, key, validated_at }` used inside `EntitlementRecord.device_bindings`.
- **AchievementTrigger**: `{ achievement_id, condition_payload, occurred_at }` stored during sessions for server validation.
- **CompatibilityProfile**: Remote config object `{ rom_hash, min_device_tier, tier, notes }` referenced when ROM metadata fails to auto-classify; ensures gating and warnings remain consistent.

## Data Volume & Scale Assumptions

- Expect ~2k ROM entries per power user; Core Data indexing must handle 50k rows without UI lag.
- Gameplay sessions produce heartbeat events every 30 seconds; backend stores up to 5M session heartbeats per day at target MAU (500k) with average 45-minute sessions.
- Multiplayer matches produce ~100 telemetry records per game; storage is append-only with 30-day retention before aggregation.
