# Deterministic Replay Harness

## Purpose

Provide a repeatable way to validate emulator determinism, save-state integrity, and Legit Mode telemetry before backend services exist.

## Components

1. **Input Capture**: `InputBus` logs button and analog events to `qa/scenarios/logs/<rom-hash>.json` when QA enables replay mode.
2. **State Snapshots**: `SaveStateStorage` writes checkpoints every 30 seconds for replay diffing.
3. **Verifier Script**: Upcoming script (Phase 3) replays captured events to compare frame hashes and telemetry outputs.

## Workflow

1. Launch the app with `QA_REPLAY=1` environment variable.
2. Import a ROM and enable Legit Mode.
3. Play for 5 minutes; the harness records inputs + save states.
4. Use `scripts/validate-quickstart.sh` to copy logs into `qa/scenarios/artifacts/` for archival.

## Exit Criteria

- Input log + telemetry bundle generated.
- Save-state checksums stable between runs.
- No desync detected while replaying logs in the simulator.
