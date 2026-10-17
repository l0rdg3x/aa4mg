# Drop Android 11-15 and Magisk: design

Date: 2026-10-13. Status: approved in chat by the maintainer.

## Goal

The fork supports Android 16 and later with KernelSU-Next only. Android 11 to 15 support is removed from
the module; Magisk support is removed from the documentation only.

## Decisions (maintainer)

- Android < 16: dropped. The installer refuses to install.
- Magisk: dropped from the documentation only. The installer keeps working on Magisk as it does today; it
  is not blocked and not tested.
- Approach A: the Android 16 files move to their final place in the zip, and the files and installer
  branches for older releases are deleted.

## Verified facts this design relies on

- KernelSU-Next v3.4.1 (`userspace/ksud/src/module.rs` `get_common_script_envs`) and KernelSU v3.3.1
  export the same installer variables (`KSU`, `KSU_VER`, `KSU_VER_CODE`, `KSU_KERNEL_VER_CODE`,
  `KSU_UAPI_VER`, `KSU_RUNTIME_MODE`) and derive the version code the same way (`30000` + git commit
  count, `build.rs`). The installer cannot tell them apart, so the original KernelSU is not blocked;
  the README states it is not supported.
- APatch 11224 exports `APATCH=true` and no `KSU`.
- KernelSU-Next v3.4.1 `installer.sh` and Magisk v30.7 `scripts/util_functions.sh` both set `API` from
  `ro.build.version.sdk` before sourcing `customize.sh`, and both define `abort()` as: print the message,
  `rm -rf $MODPATH`, `rm -rf $TMPDIR`, `exit 1`. In boot mode `MODPATH` is `modules_update/<id>`, so an
  already installed aa4mg under `modules/` is left untouched.
- KernelSU-Next extracts the zip with `-x 'META-INF/*'`: `META-INF` is used by Magisk only and stays in
  the zip so Magisk can still install the module.

## Design

### 1. Installer (`customize.sh`)

- First statement of the script, before the `chooseport` definition, any prompt or any write to `/data`:

  ```sh
  [ "$API" -ge 36 ] 2>/dev/null || abort "! aa4mg requires Android 16 or later (API 36+)"
  ```

  An empty or non-numeric `API` makes the test fail, so the install is refused (fail closed).
- Delete the Android 16 block (the `if [ $API -ge 36 ]` block that moves the `api36/` files and removes
  `oat/`, plus `rm -rf $MODPATH/api36`) and its comment.
- Delete the `API -lt 33` branch (moves `system/product/*` to `system/`) and the `API -lt 31` branch
  (Velvet to QuickSearchBox), with the "ready for A13" comment.
- Everything else is unchanged: prompts, phenotype.db, .pb, metamodule warning (text included), summary.

### 2. Files

- `git mv` each `api36/` file over its counterpart:
  - `api36/priv-app/AndroidAutoStubPrebuilt/AndroidAutoStubPrebuilt.apk` →
    `system/product/priv-app/AndroidAutoStubPrebuilt/AndroidAutoStubPrebuilt.apk`
  - `api36/etc/permissions/com.google.android.projection.gearhead.xml` →
    `system/product/etc/permissions/com.google.android.projection.gearhead.xml`
  - `api36/overlay/AndroidAutoOverlay.apk` → `system/product/overlay/AndroidAutoOverlay.apk`
- `git rm` `system/product/priv-app/AndroidAutoStubPrebuilt/oat/arm64/AndroidAutoStubPrebuilt.{odex,vdex}`.
- Resulting sha256 (unchanged Android 16 files): stub `37f588bf…4903`, XML `edfc75e8…01f8`, overlay
  `85ad586a…20c7` (full values in `tests/install-test.sh`).
- `META-INF/`, `module.prop`, `update.json`, `uninstall.sh` and `data/` are unchanged.

### 3. Documentation

README:
- Title: `# Android Auto 4 MicroG (for A16)`.
- Intro: "This is a [KernelSU-Next](https://github.com/KernelSU-Next/KernelSU-Next) module that provides
  …", followed by: it supports Android 16 and later only, the installer stops on older releases, and
  Magisk, the original KernelSU and APatch are not supported and not tested.
- Warning: "booting without Magisk" → "booting without KernelSU-Next".
- Installation step 2: install KernelSU-Next; keep the metamodule note, reworded for KernelSU-Next 3.x
  only. Step 3: install through the KernelSU-Next manager.
- Updates and Uninstall: "Magisk or KernelSU manager" → "KernelSU-Next manager".
- 3rd party apps: the tested line keeps "Android 16 (LineageOS 23.2) with microG 0.3.17, KernelSU-Next,
  ReZygisk and Vector"; the untested line keeps only the "Umount modules" advice. The root/shell sentence
  says Android 16 records the shell as the app that started the installation; drop the Android 11 to 13
  clauses. Delete the **Magisk** block. "**KernelSU / KernelSU-Next**" → "**KernelSU-Next**",
  "KernelSU has no built-in Zygisk" → "KernelSU-Next has no built-in Zygisk", "KernelSU App Profile" →
  "KernelSU-Next App Profile".
- Recovery: delete the Magisk safe mode bullet.
- Unchanged: the "[A15]" notes in Installation steps 6 and 7 (paths not yet confirmed on Android 16),
  Build, Stubs, Troubleshooting, Credits, links to upstream releases (release work).

CHANGELOG, section renamed `Unreleased (A16)`:
- New entries: Android 11 to 15 dropped (installer stops below API 36; stub, privapp permissions,
  overlay and oat files for older releases removed); Magisk dropped from the documentation, KernelSU-Next
  is the only supported root solution, the installer does not block Magisk but it is not tested.
- The Android 16 entry drops "installed only on Android 16 and later (API 36+)"; the README KernelSU entry
  says KernelSU-Next; the 3rd party entry drops the clause about pointing Magisk users to Vector.

`docs/STATUS.md`: record the change under Done (simulation-tested, device check pending); remove the
Android 11-13 and Magisk + Vector untested paths and the stale oat item; uninstall.sh item names
KernelSU-Next only; add the "[A15]" README notes to confirm on Android 16.

### 4. Tests (`tests/install-test.sh`)

- Install cases: API 36 and 37, answers yes and no; the existing checks for API 36+ (hashes, single entry
  in the stub directory, prompts, skipped list, no new directories under `system/`, no `api36/`).
- Abort cases: API 30, API 35, empty API, and API 35 with the Magisk scenario. Each must show: non-zero
  exit status, the abort message in the log, no prompt (`Please answer within` absent), `MODPATH` gone,
  and no file written under `data/data/`.
- The test `abort` double behaves like the real one: print, `rm -rf "$MODPATH" "$TMPDIR"`, `exit 1`.
- Metamodule scenarios (nometa, propfallback, dangling, magisk) and phenotype-exists cases unchanged.
- Remove the legacy hashes (`M_*`), the broken-xml / broken-stub trees and their checks (there is no file
  move left to interrupt).
- Compare mode: for API 36 and 37 the manifest must equal the reference's exactly, apart from the root
  metadata files already filtered (customize.sh, README.md, CHANGELOG, module.prop, update.json).
  Reference: `9b464e7` (current master).
- Non-vacuity: removing the gate must make the abort cases fail; moving it after the prompts must make
  the "no prompt" assertion fail; leaving the legacy stub in place must make the compare fail.

## Out of scope

Version number, `update.json`, release links, `uninstall.sh`, IFS leak, chown symlink hardening, an upper
API bound, blocking Magisk / KernelSU / APatch, the "[A15]" README notes.

## Risk and validation

- Android 16 / 17 installs: the installed module must be byte-identical to `9b464e7` apart from the root metadata files (compare mode).
- Android < 16: install refused with a clear message; an installed aa4mg stays in place for boot-mode installs from a manager. A Magisk recovery flash deletes it before customize.sh runs (Magisk v30.7 install_module), which customize.sh cannot prevent.
- Magisk: installer path unchanged; not tested on a device.
- Device check for the maintainer: reinstall the built zip on the phone, confirm Android Auto still works
  and the three file hashes under `/data/adb/modules/aa4mg/system/product/` match the values above.
