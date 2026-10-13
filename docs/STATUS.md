# Status

## Done
- Android 16 support (stub, privapp permissions, overlay from NikGapps 20260222) (d67a694): implemented and simulation-tested; the maintainer reported on 2026-10-12 that Android Auto works with this build on the Nothing Phone 2 (detailed read-only checks not reported).
- Android 11-15 dropped, KernelSU-Next the only supported root solution (branch drop-legacy): the installer stops below API 36; Magisk is no longer documented but not blocked. Simulation-tested: on API 36 and 37 the installed module is identical to 9b464e7 apart from the root metadata files (customize.sh, README.md, CHANGELOG, module.prop, update.json); device check pending.
- Install simulation test: `tests/install-test.sh`.
- Installer warns when KernelSU has no metamodule: implemented, simulation-tested; device validation pending.
- Installer explains the stubs, lists skipped items and uses 30 s prompts: implemented, simulation-tested; device validation pending.
- README: KernelSU-Next metamodule, "Umount modules" for Android Auto / XLauncher Unlocked, Zygisk provider + Vector, Stubs, Troubleshooting, Recovery.
- README "3rd party apps": XLauncher module with Android Auto as only scope makes navigation/IoT apps
  appear; verified on Nothing Phone 2, LineageOS 23.2, microG 0.3.17, KernelSU-Next + Hybrid Mount, ReZygisk + Vector.

## In progress
- Detailed on-device checks for the Android 16 files (hashes, overlay, projection role, logcat) not reported yet.
- Untested README path: Aurora's microG install method verified with one app only (Car Scanner).
- README KernelSU-Next advice: the Zygisk provider + Vector steps are device-verified (ReZygisk + Vector); only the "Umount modules" advice for XLauncher Unlocked and Android Auto is not yet device-tested.
- README Installation steps 6 and 7 still carry "[A15]" notes: confirm the settings paths on Android 16.

## Next (proposed, not started)
- uninstall.sh never works: it runs before PackageManager starts (KernelSU-Next).
- phenotype.db is ignored by microG; minimum microG version for Car App Library apps.
- Next release: version number, update.json zipUrl/changelog and README install/update links pointing to this fork.
- customize.sh leaves IFS=',' set after it returns (since 2023); Hybrid Mount's metainstall.sh partition loop then never creates the product link (mount still works per Hybrid Mount v6.2.2 source; needs a device test before fixing).
- AA's files/phenotype/shared/ does not exist on the test phone: the .pb copied by customize.sh is not
  there; find out why before keeping or removing that copy.
- Security (pre-existing, low risk): customize.sh runs chown -R / chgrp -R as root on "<app>/files/" and "<gms>/databases/". Tested with the KernelSU-Next busybox: symlinks met during recursion are not followed, but the start path has a trailing slash, so if Android Auto replaced files/ (or microG replaced databases/) with a symlink, root would chown the symlink target tree to the app's uid at install time. Fix: skip the copy when that path is a symlink.
- Magisk (unsupported) recovery flash on Android < 16: Magisk deletes /data/adb/modules/aa4mg before customize.sh runs, then the gate refuses, so an installed aa4mg is lost (bootloop risk if Android Auto updates are installed). customize.sh cannot prevent it; boot-mode installs from a manager are not affected.
