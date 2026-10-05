# Status

## Done
- Android 16 support (stub, privapp permissions, overlay from NikGapps 20260222), installed only on API 36+ (d67a694): implemented and simulation-tested; on-device validation pending.
- Install simulation test: `tests/install-test.sh`.
- Installer warns when KernelSU has no metamodule: implemented, simulation-tested; device validation pending.
- Installer explains the stubs, lists skipped items and uses 30 s prompts: implemented, simulation-tested; device validation pending.
- README: KernelSU / KernelSU-Next metamodule, "Umount modules" for Android Auto / XLauncher Unlocked, Zygisk + LSPosed (Vector), Stubs, Troubleshooting, Recovery.

## In progress
- On-device validation on Nothing Phone 2, LineageOS 23.2, microG, KernelSU-Next 3 + Hybrid Mount.

## Next (proposed, not started)
- uninstall.sh never works: it runs before PackageManager starts (Magisk and KernelSU-Next).
- phenotype.db is ignored by microG; minimum microG version for Car App Library apps.
- Stale oat/ (odex/vdex) for the pre-2025 stub on Android 11-15.
- Next release: version number, update.json zipUrl/changelog and README install/update links pointing to this fork.
