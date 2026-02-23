# Third-Party Notices

This file tracks third-party software bundled, linked, vendored, or otherwise
distributed with Xemu releases.

Use this file as the release-time source of truth for:
- component attribution
- license identification
- modification notices
- source code locations
- any additional compliance obligations

## Release Compliance Rules (Project Policy)

- Every shipped third-party component must have an entry below.
- The version/commit must match the exact shipped binary/source snapshot.
- If a component is modified locally, mark `Modified by Xemu: Yes` and summarize changes.
- If GPL/LGPL/MPL code is distributed, include source availability details and release tag/URL.
- Keep this file synchronized with the App Store/TestFlight build that was submitted.

## Components

### Template Entry (copy for each dependency)

```text
Name:
Upstream Project URL:
Version / Commit:
License:
SPDX Identifier:
Distribution Form: (source / static link / dynamic link / vendored code / binary)
Modified by Xemu: (Yes/No)
Modification Summary:
Copyright Notice(s):
Source Code Availability URL:
Additional Obligations:
Notes:
```

---

## Current / Planned Components

### Gambatte (GB/GBC core)

Name: Gambatte
Upstream Project URL: https://github.com/sinamas/gambatte (or exact upstream fork used)
Version / Commit: TODO
License: TODO (verify exact upstream license and the specific integrated copy)
SPDX Identifier: TODO
Distribution Form: Vendored source / static library (project-specific)
Modified by Xemu: TODO
Modification Summary: TODO
Copyright Notice(s): See bundled upstream files in `cores/third_party/gambatte/`
Source Code Availability URL: TODO (release source tag/repo URL)
Additional Obligations: TODO
Notes: Confirm the license of the exact vendored snapshot, not just the upstream project page.

### mGBA (GBA core)

Name: mGBA
Upstream Project URL: https://github.com/mgba-emu/mgba
Version / Commit: TODO
License: Mozilla Public License 2.0
SPDX Identifier: MPL-2.0
Distribution Form: Vendored source / static library (project-specific)
Modified by Xemu: TODO
Modification Summary: TODO
Copyright Notice(s): See `cores/third_party/mgba/LICENSE` and upstream notices
Source Code Availability URL: TODO (release source tag/repo URL)
Additional Obligations: Preserve MPL notices; publish modified MPL-covered files when distributed
Notes: Review MPL file-level copyleft requirements for any local changes.

### melonDS DS (planned via libretro core)

Name: melonDS DS (libretro core) [PLANNED]
Upstream Project URL: https://github.com/libretro/melonds (verify exact repo used)
Version / Commit: TODO
License: GNU General Public License v3.0 (verify exact upstream declaration)
SPDX Identifier: GPL-3.0-only OR GPL-3.0-or-later (verify exact upstream declaration)
Distribution Form: Planned native bridge integration (TBD)
Modified by Xemu: TBD
Modification Summary: TBD
Copyright Notice(s): TODO
Source Code Availability URL: TODO (must point to exact corresponding source for shipped builds)
Additional Obligations:
- GPL compliance for conveyed binaries (corresponding source)
- Preserve notices and license text
- Review App Store / GPL compatibility with counsel before shipping
Notes: Do not ship until legal/compliance review is complete.

### libretro API / glue (planned)

Name: libretro API headers/glue [PLANNED]
Upstream Project URL: https://github.com/libretro/libretro-common (verify exact source)
Version / Commit: TODO
License: TODO (verify per file/component)
SPDX Identifier: TODO
Distribution Form: Header/source integration (planned)
Modified by Xemu: TBD
Modification Summary: TBD
Copyright Notice(s): TODO
Source Code Availability URL: TODO
Additional Obligations: TODO
Notes: libretro ecosystem licensing varies by core and support libraries; verify each component individually.
