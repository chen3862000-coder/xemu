# iOS Multi-System Emulator Platform Blueprint

## Executive Summary

This document outlines the full product, technical, monetization, and
phased roadmap plan for an App Store--first multi-system emulator
platform. The goal is to build a scalable retro gaming ecosystem rather
than a standalone emulator.

------------------------------------------------------------------------

# 1. Product Vision

Build a commercial-grade, App Store-compliant retro gaming platform
with:

-   Stable multi-system emulation
-   Server-backed entitlement control
-   Ads + In-App Purchase monetization
-   Experimental next-gen systems
-   Community rankings
-   Multiplayer (phased rollout)
-   Long-term ecosystem expansion

Positioning:

> Not just an emulator --- a scalable retro gaming platform.

------------------------------------------------------------------------

# 2. System Scope by Phase

## Phase 1 -- Stable Retro Foundation

Supported Systems:

-   NES (FC)
-   GB / GBC
-   GBA
-   Genesis / Mega Drive
-   NDS
-   PS1

Core Features:

-   Save states
-   Controller support (GameController framework)
-   Per-game settings
-   ROM library management
-   Ads (Free tier)
-   Remove Ads IAP
-   Server-side entitlement validation
-   Offline grace period

UX:
-   Use given figma make output (generated in HTML and Typescript already) under "figma" directory to generate UI
-   Ideally, use HTML and Typescript provided by figma directly as foundation of UI (convert to native only when necessary)

Goal: Launch commercially viable base app.

------------------------------------------------------------------------

## Phase 2 -- Experimental Expansion

Add:

-   PS2 (Experimental)
-   3DS (Experimental)

Requirements:

-   Device gating (A17 Pro / M-series recommended)
-   Resolution scaling
-   Frameskip options
-   Compatibility list
-   Clear in-app "Experimental Beta" messaging

Monetization:

-   Experimental Pack IAP
-   Optional Pro bundle

Goal: Increase ARPU without destabilizing core experience.

------------------------------------------------------------------------

## Phase 3 -- Community Platform

Add:

-   Playtime tracking (server-authoritative)
-   Game completion stats
-   Achievement system
-   Legit Mode (no save states/replay abuse)
-   Global leaderboards
-   User profiles
-   Seasonal rankings

Goal: Improve retention and differentiation.

------------------------------------------------------------------------

## Phase 4 -- Multiplayer (Beta → Production)

Step 1: - P2P Netplay (WebRTC) - NES / GBA first - Invite-only beta

Step 2: - Ranked multiplayer - Elo rating system - Match history -
Seasonal ladders

Avoid starting with PS2 multiplayer.

Goal: Transform into retro gaming network.

------------------------------------------------------------------------

# 3. Core Architecture

## App Structure

UI Layer (SwiftUI / UIKit) ↓ Core Host Layer - EmulatorCore protocol -
Input abstraction - Audio engine - Save manager - Shader pipeline -
License manager - Ads manager

System Modules (Plug-in Style) - NESCore - GB/GBC Core - GBA Core - NDS
Core - Genesis Core - PS1 Core - PS2 Core (Phase 2) - 3DS Core (Phase 2)

Benefits: - Clean separation - Future extensibility - Experimental
systems isolated

------------------------------------------------------------------------

# 4. Monetization Strategy

Single App Binary

Tiers:

Free: - Ads enabled - Stable systems only

Remove Ads IAP: - Ads disabled

Experimental Pack IAP: - PS2 + 3DS unlocked

Optional: - Pro bundle (all-in-one unlock)

Ad Placement Strategy: - Banner in library screen - Interstitial on game
launch (cooldown enforced) - No ads during gameplay

------------------------------------------------------------------------

# 5. License Server Architecture

Purpose: - Prevent IAP bypass - Enable feature gating - Device
management - Usage analytics

## Entitlement Flow

On launch:

1.  App verifies receipt
2.  Calls `/entitlements/refresh`
3.  Server validates receipt
4.  Server returns:
    -   Short-lived JWT (4--6h)
    -   Feature flags
    -   Offline grace window

## Device Binding

-   Per-install public key
-   Max 3 devices per account
-   Device revocation endpoint

## Offline Grace

-   5--7 days allowed
-   Stable systems remain accessible
-   Experimental systems disabled if expired

------------------------------------------------------------------------

# 6. Backend Design

Suggested Stack: - FastAPI or Node.js - PostgreSQL - Redis - JWT (ES256)

Core Endpoints: - /entitlements/refresh - /devices/register -
/devices/revoke - /session/start - /session/heartbeat -
/leaderboard/query

------------------------------------------------------------------------

# 7. Community System Architecture

## Server-Authoritative Play Tracking

Session Flow:

1.  /session/start
2.  Periodic heartbeat
3.  /session/end

Server validates: - Time progression - Device signature - No abnormal
jumps

## Achievements

Phase 1: - Time-based - Completion-based - No-save-state mode

Advanced: - Memory watch triggers

## Legit Mode

Only Legit Mode contributes to rankings and seasonal ladders.

------------------------------------------------------------------------

# 8. Multiplayer Architecture

Initial Model: P2P Netplay

Server Responsibilities: - Matchmaking - Signaling - Authentication

Client Responsibilities: - WebRTC communication - Deterministic frame
sync - Input synchronization

Security: - ROM hash verification - Version matching - Session tokens

Later: - Elo ranking - Match history - Seasonal resets

------------------------------------------------------------------------

# 9. Anti-Cheat Strategy

Do Not: - Overuse aggressive DRM - Hard-ban prematurely

Do: - Shadow-ban suspicious users - Exclude suspicious sessions from
rankings - Validate sessions server-side - Use soft anomaly detection

------------------------------------------------------------------------

# 10. Compliance & Legal Guardrails

Requirements:

-   No ROM distribution
-   No BIOS distribution
-   Clear DMCA contact path
-   User-import only
-   Avoid promoting pirated content

Multiplayer Messaging: "Play your legally dumped games online."

------------------------------------------------------------------------

# 11. Risk Assessment

Technical Risks: - PS2 / 3DS performance complaints - Device
fragmentation

Mitigation: - Device gating - Clear experimental labeling -
Compatibility list

Review Risks: - Aggressive ads - Piracy perception

Mitigation: - No gameplay ads - Transparent legal messaging

------------------------------------------------------------------------

# 12. Revenue Strategy

Suggested Pricing:

Remove Ads: \$4.99--\$7.99\
Experimental Pack: \$6.99--\$9.99\
Pro Bundle: \$12.99--\$19.99

Key Revenue Driver: Community + Multiplayer ecosystem

------------------------------------------------------------------------

# 13. Long-Term Evolution

Future Opportunities:

-   Cloud save sync
-   Retro achievement network
-   Shader marketplace
-   AI upscaling filters
-   Cross-device sync
-   Companion web portal
-   Community tournaments

------------------------------------------------------------------------

# 14. Strategic Summary

Phase 1: Stable commercial retro emulator

Phase 2: Revenue expansion via PS2/3DS experimental

Phase 3: Retention engine via community

Phase 4: Differentiation via multiplayer

End State: A scalable retro gaming platform, not a commodity emulator.
