# Phase 0 Research — iOS Multi-System Emulator Platform

## Decision 1: StoreKit 2 + server receipt validation for entitlements
- **Decision**: Use StoreKit 2 for device-side checks plus a custom backend that verifies app receipts, issues short-lived JWT entitlements, and enforces device-binding/offline grace rules.
- **Rationale**: Aligns with App Store guidance (Guidelines 3.1.1, 4.7) that demand reliable entitlement enforcement, enables revocation for policy breaches, and keeps Experimental Pack access tightly controlled.
- **Alternatives considered**:
  - *Device-only receipt caching*: rejected because it is prone to tampering and cannot coordinate multi-device limits.
  - *Third-party receipt validation service*: rejected to avoid external dependencies on a compliance-sensitive flow.

## Decision 2: Host services layer with Swift protocols + Metal render loop
- **Decision**: Introduce a reusable host layer that defines emulator-core protocols (video/audio buffers, save service, input bus), owns a Metal-driven frame scheduler, and exposes state to SwiftUI screens via Combine.
- **Rationale**: Provides a consistent surface for six+ emulation cores, allows QA automation to reuse the same hooks, and isolates heavy rendering work from SwiftUI scene updates to maintain 60 fps goals.
- **Alternatives considered**:
  - *Direct UIKit per-core integration*: rejected because it duplicates glue code per console and complicates QA.
  - *SpriteKit renderer*: rejected since Metal offers finer control over frame pacing, shaders, and scaling.

## Decision 3: Deterministic rollback netplay over WebRTC with TURN fallback
- **Decision**: Build multiplayer on deterministic emulation cores that support save/load hooks, add a rollback layer similar to GGPO, and transport input timelines via WebRTC DataChannels backed by STUN/TURN infrastructure.
- **Rationale**: Guarantees fair synchronization under 120 ms latency targets, leverages WebRTC security (DTLS/SRTP), and supports relay fallbacks for restrictive NATs while keeping App Store-compliant technology.
- **Alternatives considered**:
  - *Server-authoritative streaming*: rejected due to high infra cost and App Store constraints on remote gameplay.
  - *Simple lockstep without rollback*: rejected because packet loss/jitter on mobile networks would cause frequent desyncs.

## Decision 4: DMCA workflow + controller messaging baked into UX
- **Decision**: Ship onboarding and settings copy that reiterates "bring your own ROM/BIOS," include a DMCA/takedown contact with 24 h response SLA, block linking to piracy sources, and provide accurate controller support messaging (MFi/Bluetooth HID).
- **Rationale**: Meets App Store legal/compliance expectations, reduces review risk, and sets user expectations about input peripherals.
- **Alternatives considered**:
  - *Minimal legal copy with web links*: rejected because App Review now scrutinizes emulator submissions for piracy risk.

## Decision 5: Save-state storage with checksum metadata + async compression
- **Decision**: Persist save states as metadata + binary chunks under FileManager-managed directories, compress/encrypt on background queues, and log checksums so QA can diff snapshots across cores.
- **Rationale**: Keeps gameplay responsive, supports determinism/rollback, and equips QA with artifacts for debugging.
- **Alternatives considered**:
  - *Synchronous CoreData blobs*: rejected because blocking disk I/O would create frame hitches.
