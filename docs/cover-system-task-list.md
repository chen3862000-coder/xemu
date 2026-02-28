# RetroMind Cover System - Implementation Task List

Source spec: `/Users/spiderck/Downloads/RetroMind_Cover_System_Specification.md`

## Current Status
- [x] **Kickoff foundation merged**
  - `CoverArtService` added with deterministic source precedence:
    - custom override on disk
    - embedded cover bytes
    - generated placeholder
  - deterministic placeholder generation added (offline, 1:1)
  - custom cover storage scaffolded at `Application Support/AppHost/Covers/{gameID}.jpg`
  - import flow wired to assign placeholder immediately
  - primary surfaces wired to resolver (home/library/recent)

## Phase 1 - Close Foundation Gaps (Immediate)
- [ ] Resolve test harness for cover service in package tests (linking config currently blocks `swift test` in this workspace).
- [ ] Add telemetry-safe structured logs for cover resolution path:
  - source used
  - cache hit/miss
  - placeholder fallback reason
- [ ] Ensure all list/grid/card surfaces use resolver only (remove remaining direct `coverImageData` reads).
- [ ] Add migration hook for older rows with missing `coverImageData` and no custom cover URL.

## Phase 2 - Offline Metadata Matching
- [ ] Introduce metadata bundle format:
  - `metadata_manifest.json`
  - SQLite database file(s)
  - checksum list in manifest
- [ ] Implement manifest validator:
  - schema version compatibility
  - file existence
  - SHA256 verification
- [ ] Add read-only SQLite access layer:
  - `rom_hash_map`
  - `titles`
  - `aliases`
- [ ] Add import-time SHA1 computation on background queue.
- [ ] Implement deterministic matcher pipeline:
  - SHA1 lookup first
  - normalized title alias fallback
  - confidence thresholding
- [ ] Persist canonical mapping fields:
  - `romSha1`
  - `defaultCoverKey`
  - optional `canonicalTitleID`

## Phase 3 - Manual Cover Override UX
- [ ] Add `Edit Cover` action to existing game context menus (all entry points).
- [ ] Add Photos + Files picker flow.
- [ ] Add square crop step (1:1 output).
- [ ] Save as JPEG (`~0.8` quality, max `600x600`) to covers directory.
- [ ] Add `Reset Cover` action and optimistic UI refresh.
- [ ] Add haptic feedback for save/reset.

## Phase 4 - UI Specification Alignment
- [ ] Grid card conformance:
  - 1:1 image
  - bottom gradient overlay for title legibility
  - 2-line title clamp
  - optional hours badge style
- [ ] List row conformance:
  - 72pt height
  - 52x52 thumbnail
  - swipe actions (delete/share)
- [ ] Resolve badge collision ordering:
  - platform badge
  - compatibility badge
  - no overlap in all card variants

## Phase 5 - Performance and Stability
- [ ] Add cache policy:
  - `NSCache` count/bytes limits
  - invalidation on custom-cover overwrite/reset
- [ ] Move remaining image decode and disk reads off main thread.
- [ ] Decode-at-target-size thumbnails to avoid full-res memory spikes.
- [ ] Stress test with 200/500 ROM library datasets:
  - smooth scrolling
  - no dropped frames from cover decode
  - bounded memory growth

## Phase 6 - iCloud Boundaries (Per Spec)
- [ ] Assert save-state iCloud sync remains independent from cover system.
- [ ] Keep metadata DB local-only for MVP.
- [ ] Gate optional custom cover sync as post-MVP feature flag.

## Acceptance Criteria Mapping
- [ ] No empty/broken cover slots across home/library/system/recent views.
- [ ] Fully offline operation (no network dependency for covers/metadata).
- [ ] `200+` game library scroll remains smooth.
- [ ] Edit cover updates instantly across all active screens.
- [ ] App Store-safe (no bundled copyrighted commercial cover assets).

## Execution Order
- [ ] **Sprint A:** Phase 1 + Phase 2 (data pipeline)
- [ ] **Sprint B:** Phase 3 + Phase 4 (UX + consistency)
- [ ] **Sprint C:** Phase 5 + Phase 6 + acceptance hardening
