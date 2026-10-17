# Status

## Done
- Android 16 support (stub, privapp permissions, overlay from NikGapps 20260222) (d67a694): implemented and simulation-tested; the maintainer reported on 2026-10-12 that Android Auto works with this build on the Nothing Phone 2 (read-only checks done later on the beb933e build, which ships the same files: see below).
- Android 11-15 dropped, KernelSU-Next the only supported root solution (merge ab0b938): the installer stops below API 36; Magisk is no longer documented but not blocked. Simulation-tested: on API 36 and 37 the installed module is identical to 8140f66 apart from the root metadata files (customize.sh, README.md, CHANGELOG, module.prop, update.json). Device-checked on 2026-10-17 with a build of beb933e (Nothing Phone 2, LineageOS 23.2, KernelSU-Next + Hybrid Mount): the installer accepted it and the module is active (its CHANGELOG is in /data/adb/modules/aa4mg); under /product the stub, privapp XML and overlay match the expected sha256 and the stub has no oat files; the overlay com.nikgapps.overlay.androidauto is enabled; Android Auto holds the SYSTEM_AUTOMOTIVE_PROJECTION role and is a system package. In the car the maintainer reported that everything works. No logcat check of the privapp permissions was done.
- README states that the fork is maintained mainly for personal use.
- Installer fixes (merge dd97612): phenotype.db and .pb copies, the overwrite prompt and data/ removed (closes the symlink risk of the root copies into app-owned paths); IFS restored after the summary; warning when the metamodule is disabled or marked for removal (reachable only with metamodules without metainstall.sh: KernelSU-Next refuses the install for the others, so it cannot be tested with Hybrid Mount). Simulation-tested, each fix checked by mutation. Device check pending: with Hybrid Mount the install log should show "- linked /product" and /data/adb/modules/aa4mg/product should be a symlink to ./system/product; after the reboot, repeat the read-only checks of 2026-10-17 (sha256 under /product, system package, overlay enabled), because the new product link changes the installed layout. phenotype.db and the .pb already copied by older versions stay in place: nothing removes them.
- Action button (action.sh, merge 8ff0e86): uninstalls the Android Auto updates after a Volume UP confirmation within 10 s, because uninstall.sh runs at the next boot before PackageManager starts (KernelSU-Next), where pm fails; uninstall.sh is kept. Simulation-tested (Volume UP after another event, no updates, pm failure, Android Auto not a system app, Volume DOWN, Volume UP released, getevent failing, no answer), each guard checked by mutation. Device check pending (invasive: Android Auto must then be updated again with Aurora).
- Install simulation test: `tests/install-test.sh`.
- Installer warns when KernelSU has no metamodule: implemented, simulation-tested; device validation pending.
- Installer explains the stubs, lists skipped items and uses 30 s prompts: implemented, simulation-tested; device validation pending.
- README: KernelSU-Next metamodule, "Umount modules" for Android Auto / XLauncher Unlocked, Zygisk provider + Vector, Stubs, Troubleshooting, Recovery.
- README "3rd party apps": XLauncher module with Android Auto as only scope makes navigation/IoT apps
  appear; verified on Nothing Phone 2, LineageOS 23.2, microG 0.3.17, KernelSU-Next + Hybrid Mount, ReZygisk + Vector.

## In progress
- Release v0.7.0 (versionCode 2610171, branch release-0.7.0): update.json and the README install/update links point to this fork. Waits for the device check of the 0.7.0 build and the maintainer's OK to publish. Publication order: push the v0.7.0 tag, create the GitHub release with aa4mg-v0.7.0.zip built from that tag, then push master, so that update.json never points to a missing asset.
- Untested README path: Aurora's microG install method verified with one app only (Car Scanner).
- README KernelSU-Next advice: the Zygisk provider + Vector steps are device-verified (ReZygisk + Vector); only the "Umount modules" advice for XLauncher Unlocked and Android Auto is not yet device-tested.
- README Installation steps 6 and 7 still carry "[A15]" notes: confirm the settings paths on Android 16.
- README "3rd party apps" uses the LSPosed wording ("LSPosed manager", "Enable module"); Vector v2.2 has no "Enable module" string: confirm the wording against the installed Vector version.

## Next (proposed, not started)
- Magisk (unsupported) recovery flash on Android < 16: Magisk deletes /data/adb/modules/aa4mg before customize.sh runs, then the gate refuses, so an installed aa4mg is lost (bootloop risk if Android Auto updates are installed). customize.sh cannot prevent it; boot-mode installs from a manager are not affected.
