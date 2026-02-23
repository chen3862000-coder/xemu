# Legal Compliance Checklist (App Store + GPL Emulator Core)

This checklist is for shipping Xemu builds that include a GPL-licensed emulator
core (planned: `melonDS DS` via libretro).

This is an engineering/compliance workflow document, not legal advice. Review
with qualified counsel before App Store submission.

## Scope

Use this checklist before any external distribution channel, including:
- TestFlight external testing
- App Store release
- direct IPA distribution to customers/partners

## Decision Gate (Do Not Skip)

Before integrating or shipping a GPL core:

1. Confirm exact upstream licenses
- `melonDS` / `melonDS libretro core` license (exact SPDX and version variant)
- libretro API/glue component licenses (per file/repo)
- any helper libraries linked into the DS path

2. Confirm distribution strategy
- `Internal-only` (no public distribution) or
- `External distribution` (App Store/TestFlight/etc.)

3. Confirm legal path
- Counsel sign-off for GPL + App Store distribution risk
- or obtain alternate/commercial licensing if required

## GPL Distribution Compliance (Engineering Checklist)

If you distribute a build containing GPL-covered code:

1. Source availability
- Publish corresponding source for the exact shipped binary
- Tag the release source (example: `ios-v1.2.0-nds-preview1`)
- Include local modifications to upstream GPL code
- Include build scripts and instructions needed to reproduce the shipped binary

2. Notices and license texts
- Keep upstream copyright notices intact
- Keep upstream license files intact in vendored code
- Include project `LICENSE` in the distributed source tree
- Update `THIRD_PARTY_NOTICES.md` with exact versions/commits and license details

3. Modification marking
- Mark local changes to GPL-covered upstream files
- Record patch summaries and dates in `THIRD_PARTY_NOTICES.md`

4. In-app attribution and source link
- Add an in-app Open Source / Licenses screen (Settings/About)
- Include component names, licenses, and a source code URL for the shipped build
- Include “no warranty” language for OSS components where required

5. Release artifact retention
- Retain source tarball/archive for each shipped binary
- Retain CI artifacts and build logs for auditability
- Retain exact core commit SHAs and patches applied

## App Store / Apple Submission Checklist (GPL Build)

These items are in addition to GPL compliance and do not replace legal review.

1. App Review notes
- Explain emulator functionality clearly
- Explain ROM import flow
- Explain BIOS/firmware requirements (if applicable)
- Provide test credentials/data if any gated features exist

2. Content/IP hygiene
- Do not bundle copyrighted ROMs without rights
- Do not provide ROM download/discovery indexing
- Avoid Nintendo/Sony trademarks in ways that imply endorsement
- Use generic naming in screenshots/marketing unless you have rights

3. Privacy and policy
- Complete App Privacy disclosures in App Store Connect
- Add privacy policy and terms links in-app (Settings page already has placeholders)
- Document telemetry and data collection behaviors (if any)

4. Binary/review readiness
- Confirm no debug menus, test endpoints, or placeholder content are exposed
- Verify file import, save states, audio, controller input on real devices
- Verify crash reporting and logging do not leak user file paths/ROM names unnecessarily

## Open-Source Repo Preparation Checklist

Before first public GPL-based release:

1. Add/confirm repo metadata
- `LICENSE` (done)
- `COPYING` (done)
- `NOTICE` (done)
- `THIRD_PARTY_NOTICES.md` (done; fill in actual values)

2. Add public compliance docs
- `docs/OPEN_SOURCE_COMPLIANCE.md` (optional but recommended)
- Source-build instructions for the exact release
- App Store release notes mentioning OSS license availability location

3. Add release automation checks (recommended)
- CI step validates `THIRD_PARTY_NOTICES.md` has no `TODO` for shipped components
- CI step captures core commit SHAs into release metadata
- CI step archives source bundle alongside release artifacts

## Xemu-Specific Pre-Ship TODOs (Planned NDS)

- [ ] Finalize `melonDS libretro` upstream repo and exact commit
- [ ] Record license SPDX and text locations in `THIRD_PARTY_NOTICES.md`
- [ ] Add in-app OSS licenses/source link screen in Settings
- [ ] Add release source URL field to Settings/About (or static website page)
- [ ] Prepare App Review notes template for emulator + ROM import workflow
- [ ] Counsel review for App Store + GPL compatibility

## Release Sign-Off Template

Use this block in release PRs or release docs:

```text
GPL Core Included: Yes/No
Core(s): ______________________
Upstream Commit(s): ______________________
Corresponding Source URL: ______________________
THIRD_PARTY_NOTICES Updated: Yes/No
In-App OSS Screen Verified: Yes/No
App Review Notes Updated: Yes/No
Legal Review Complete: Yes/No
Approved By: ______________________
Date: ______________________
```

