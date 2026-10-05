# Status

## Done
- Android 16 support (stub, privapp permissions, overlay from NikGapps 20260222), installed only on API 36+ (d67a694).
- Install simulation test: `tests/install-test.sh`.

## In progress
- On-device validation on Nothing Phone 2, LineageOS 23.2, microG, KernelSU-Next 3 + Hybrid Mount.

## Next (proposed, not started)
- uninstall.sh never works: it runs before PackageManager starts (Magisk and KernelSU-Next).
- Warn when KernelSU-Next has no metamodule (module files are not mounted at all).
- README: KernelSU-Next metamodule, "Umount modules" for Android Auto / XLauncher Unlocked, Zygisk + LSPosed (Vector).
- phenotype.db is ignored by microG; minimum microG version for Car App Library apps.
- Stale oat/ (odex/vdex) for the pre-2025 stub on Android 11-15.
- Next release: version number, update.json zipUrl/changelog pointing to this fork.
