# Drop Android 11-15 and Magisk Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** aa4mg installs on Android 16 and later only, documents KernelSU-Next as the only supported root solution, and produces on Android 16 exactly the same installed module as today.

**Architecture:** one fail-closed API gate at the top of `customize.sh`; the Android 16 files move from `api36/` to their final place in the zip, so the installer branches that moved files per API level disappear. The install simulation test gains refusal cases and a strict comparison with the current master (`9b464e7`).

**Tech Stack:** POSIX shell sourced by the KernelSU-Next (or Magisk) busybox `ash`; bash test harness run in an unprivileged chroot.

**Spec:** `docs/superpowers/specs/2026-10-13-drop-legacy-design.md`

## Global Constraints

- Work in `/home/l0rdg3x/coding/aa4mg/.worktrees/drop-legacy` (branch `drop-legacy`). Never commit on `master`.
- The user's login shell is fish: run every non-trivial command as `bash -c '...'` or from a bash script.
- `customize.sh` is sourced by busybox `ash`: POSIX sh only, no bashisms.
- Gate line, verbatim: `[ "$API" -ge 36 ] 2>/dev/null || abort "! aa4mg requires Android 16 or later (API 36+)"`
- Do not modify `module.prop`, `update.json`, `uninstall.sh`, `META-INF/` or `data/`.
- Product text (code, comments, commits, docs) is English.
- Test command (busybox sha256 `060844b0…`, from KernelSU-Next v3.4.0):
  `bash -c 'cd /home/l0rdg3x/coding/aa4mg/.worktrees/drop-legacy && BUSYBOX=/tmp/claude-1000/-home-l0rdg3x-coding-aa4mg/925a891b-dd6b-4873-8503-dda601127a3f/scratchpad/tools/busybox bash tests/install-test.sh --compare-ref 9b464e7'`
- Commit trailers (personal project), with the name of the model you are running on:
  ```
  Co-Authored-By: Claude <Model Name> <noreply@anthropic.com>
  Claude-Session: https://claude.ai/code/session_01PEwPq74VqFT7N3ZoYgDH5G
  ```
  Write the message to a file and use `git commit -F <file>`.

## Review Focus

- Update attempted on Android < 16 over an installed aa4mg: refused, the installed module under `data/adb/modules/aa4mg` untouched (Task 1, `installed` abort case).
- `API` empty or not a number: refused, not installed (Task 1, empty-API abort case).
- Android 17 and later: installs exactly like Android 16 (Tasks 1-2, API 37 cases and compare).
- Magisk on Android 16: installs as today, no KernelSU warning; Magisk on Android < 16: refused (Task 1, `magisk` cases).
- The stub shipped without its privapp XML would bootloop: both files must be present with the Android 16 hashes (Tasks 1-2, `check_hash` on stub and XML).

---

### Task 1: Refuse installs below Android 16

**Files:**
- Modify: `customize.sh:1-3` (insert the gate)
- Test: `tests/install-test.sh`

**Interfaces:**
- Produces: the abort message `! aa4mg requires Android 16 or later (API 36+)`; test helpers `check_abort_case API [SCENARIO]`, `ABORT_LINE`, scenario `installed` in `setup_metamodule`. Task 2 keeps them unchanged.

- [ ] **Step 1: Write the failing tests**

In `tests/install-test.sh`:

1. Replace `APIS="30 31 32 33 34 35 36"` with `APIS="36 37"`.

2. After the line `WARN_LINE='*** WARNING: no KernelSU metamodule found!'` add:

```bash
ABORT_LINE='! aa4mg requires Android 16 or later (API 36+)'
```

3. In the comment above `setup_metamodule`, replace `Other scenarios: nometa, propfallback, dangling, magisk, phenotype (default plus a
# pre-existing phenotype.db).` with:

```bash
# module.prop carries metamodule=1. Other scenarios: nometa, propfallback, dangling, magisk, phenotype (default plus a
# pre-existing phenotype.db), installed (default plus an aa4mg already installed under modules/).
```

(keep the first line of that comment as it is; only the scenario list changes).

4. In `setup_metamodule`, add this branch after the `phenotype)` branch:

```bash
        installed)
            mkdir -p "$mods/hybrid_mount" "$mods/aa4mg"
            printf 'id=hybrid_mount\nname=Hybrid Mount\nmetamodule=1\n' > "$mods/hybrid_mount/module.prop"
            ln -s /data/adb/modules/hybrid_mount "$root/data/adb/metamodule"
            printf 'id=aa4mg\nversion=installed\n' > "$mods/aa4mg/module.prop" ;;
```

5. In `run_case`, make the `abort` double behave like the real one. Replace

```bash
    unshare -r --fork chroot "$root" /bin/busybox env -i PATH=/bin ASH_STANDALONE=1 API="$api" \
        MODPATH=/data/adb/modules_update/$ID TMPDIR=/dev/tmp BOOTMODE=true "${ksu[@]}" \
        /bin/busybox sh -c 'ui_print() { echo "$1"; }; abort() { echo "$1"; exit 1; }; . "$MODPATH/customize.sh"' \
        > "$dir/log" 2>&1 || rc=$?
```

with

```bash
    # ui_print and abort as in KernelSU-Next's installer.sh in boot mode: abort removes MODPATH and TMPDIR.
    unshare -r --fork chroot "$root" /bin/busybox env -i PATH=/bin ASH_STANDALONE=1 API="$api" \
        MODPATH=/data/adb/modules_update/$ID TMPDIR=/dev/tmp BOOTMODE=true "${ksu[@]}" \
        /bin/busybox sh -c 'ui_print() { echo "$1"; }; abort() { echo "$1"; rm -rf "$MODPATH" "$TMPDIR"; exit 1; }; . "$MODPATH/customize.sh"' \
        > "$dir/log" 2>&1 || rc=$?
```

6. Replace the whole `check_working_tree_case` function with:

```bash
check_working_tree_case() {
    local api=$1 answer=$2
    local dir=$W/case/worktree-$api-$answer
    MOD=$dir/root/$MODREL

    [ "$(cat "$dir/rc")" = 0 ] || fail "installer exited with status $(cat "$dir/rc")"
    grep -q 'Installation of' "$dir/log" || fail "log does not contain 'Installation of'"
    check_warning "$dir" absent
    check_prompts "$dir" "$answer"
    [ ! -e "$MOD/api36" ] || fail "api36 directory still present after install"

    local stubdir=system/product/priv-app/AndroidAutoStubPrebuilt
    check_hash "$stubdir/AndroidAutoStubPrebuilt.apk" $A_STUB
    check_hash system/product/etc/permissions/com.google.android.projection.gearhead.xml $A_XML
    check_hash system/product/overlay/AndroidAutoOverlay.apk $A_OVL
    if [ -d "$MOD/$stubdir" ]; then
        [ "$(find "$MOD/$stubdir" -mindepth 1 -maxdepth 1 | wc -l)" = 1 ] \
            || fail "$stubdir must contain exactly one entry"
    fi

    local n
    if [ "$answer" = no ]; then
        for n in Maps.apk GoogleTTS.apk Velvet.apk QuickSearchBox.apk AndroidAuto-XLauncherUnlocked.apk; do
            ! has_named "$n" || fail "$n present although answer was no"
        done
    else
        for n in Maps.apk GoogleTTS.apk Velvet.apk AndroidAuto-XLauncherUnlocked.apk; do
            has_named "$n" || fail "$n missing although answer was yes"
        done
    fi

    local extra
    extra=$(LC_ALL=C comm -13 "$dir/dirs.before" "$dir/dirs.after")
    [ -z "$extra" ] || fail "directories created by customize.sh under system/: $(echo $extra)"

    finish_case "api=$api answer=$answer [worktree]" "$dir/log"
}
```

7. Add this function right after `check_phenotype_case`:

```bash
# check_abort_case API [SCENARIO]: below Android 16 the installer must stop before any prompt, leave no module
# directory behind and write nothing under data/ apart from the fixtures.
check_abort_case() {
    local api=$1 scenario=${2:-default}
    local dir=$W/case/worktree-$api-yes
    [ "$scenario" = default ] || dir=$dir-$scenario
    local label="api=${api:-empty} answer=yes [abort${2:+ $2}]"

    [ "$(cat "$dir/rc")" = 1 ] || fail "installer exited with status $(cat "$dir/rc"), expected 1"
    grep -qxF -- "$ABORT_LINE" "$dir/log" || fail "abort message missing"
    ! grep -qF -- 'Please answer within' "$dir/log" || fail "a prompt was shown before the abort"
    [ ! -e "$dir/root/$MODREL" ] || fail "$MODREL still present"
    local extra
    extra=$(cd "$dir/root/data" && find . -type f | grep -vE '^\./adb/modules/[^/]+/module\.prop$' || true)
    [ -z "$extra" ] || fail "files written under data/: $(echo $extra)"
    if [ "$scenario" = installed ]; then
        [ "$(cat "$dir/root/data/adb/modules/aa4mg/module.prop")" = "$(printf 'id=aa4mg\nversion=installed')" ] \
            || fail "installed module.prop changed"
    fi
    finish_case "$label" "$dir/log"
}
```

8. After the loop that runs and checks the phenotype cases (`for answer in $ANSWERS; do run_case worktree 36 "$answer" phenotype ...; done`), add:

```bash
for api in 30 35 ""; do
    run_case worktree "$api" yes
    check_abort_case "$api"
done
for scenario in magisk installed; do
    run_case worktree 35 yes "$scenario"
    check_abort_case 35 "$scenario"
done
```

- [ ] **Step 2: Run the tests and verify they fail for the right reason**

Run the test command from Global Constraints.
Expected: `Summary: 16/21 passed, 5 failed`. The five failures are the abort cases (`api=30`, `api=35`, `api=empty`, `api=35 ... [abort magisk]`, `api=35 ... [abort installed]`), each failing at least on `installer exited with status 0, expected 1`, `abort message missing` and `a prompt was shown before the abort`. All `[worktree]`, `[ksu-…]`, `[phenotype-exists]`, `[broken-…]` and `[compare 9b464e7]` cases PASS.

- [ ] **Step 3: Add the gate**

In `customize.sh`, insert the gate between the shebang and the `chooseport` comment, so the top of the file reads:

```sh
#!/bin/bash

[ "$API" -ge 36 ] 2>/dev/null || abort "! aa4mg requires Android 16 or later (API 36+)"

# Define "detect Volume key input" helper
```

- [ ] **Step 4: Run the tests and verify they pass**

Run the test command. Expected: `Summary: 21/21 passed, 0 failed`.

- [ ] **Step 5: Verify the tests are not vacuous**

a. Move the gate line from the top of `customize.sh` to just before the line `# Setup "vanilla" phenotype.db SQLite database, pre-patched with AA-Tweaker.` Run the test command. Expected: the five abort cases FAIL with `a prompt was shown before the abort` (other cases PASS). Put the gate back at the top.

b. Change `-ge 36` to `-ge 35` in the gate. Run the test command. Expected: the `api=35` cases (three of them) FAIL; `api=30` and `api=empty` PASS. Restore `-ge 36`.

c. `git diff customize.sh` must show only the gate line and the blank line after it.

- [ ] **Step 6: Commit**

```bash
bash -c 'cd /home/l0rdg3x/coding/aa4mg/.worktrees/drop-legacy && git add customize.sh tests/install-test.sh && git commit -F <message file>'
```

Message subject: `Refuse to install below Android 16`. Body: the installer now stops before any prompt or write to /data when API is below 36 or not a number; an installed aa4mg is left in place because abort only removes modules_update; tests cover API 30, 35, empty, Magisk and an installed module, and drop the API 30-35 install cases. Add the trailers.

---

### Task 2: Ship the Android 16 files in place and remove the per-API moves

**Files:**
- Move: `api36/priv-app/AndroidAutoStubPrebuilt/AndroidAutoStubPrebuilt.apk` → `system/product/priv-app/AndroidAutoStubPrebuilt/AndroidAutoStubPrebuilt.apk`
- Move: `api36/etc/permissions/com.google.android.projection.gearhead.xml` → `system/product/etc/permissions/com.google.android.projection.gearhead.xml`
- Move: `api36/overlay/AndroidAutoOverlay.apk` → `system/product/overlay/AndroidAutoOverlay.apk`
- Delete: `system/product/priv-app/AndroidAutoStubPrebuilt/oat/arm64/AndroidAutoStubPrebuilt.odex`, `system/product/priv-app/AndroidAutoStubPrebuilt/oat/arm64/AndroidAutoStubPrebuilt.vdex`
- Modify: `customize.sh` (delete the Android 16 block and the A11/A12 branches)
- Test: `tests/install-test.sh`

**Interfaces:**
- Consumes: Task 1's gate, `check_abort_case`, `ABORT_LINE`, `installed` scenario (unchanged).
- Produces: the final file layout; strict `check_compare_case`.

This task is a layout refactor: the tests must pass before and after it, and the strict comparison with `9b464e7` proves the installed result did not change.

- [ ] **Step 1: Tighten the tests**

In `tests/install-test.sh`:

1. Delete the five legacy hash lines `M_STUB=…`, `M_XML=…`, `M_OVL=…`, `M_ODEX=…`, `M_VDEX=…` (keep `A_STUB`, `A_XML`, `A_OVL`).

2. Delete the broken-tree setup:

```bash
mkdir -p "$W/tree/broken-xml" "$W/tree/broken-stub"
cp -a "$W/tree/worktree/." "$W/tree/broken-xml/"
cp -a "$W/tree/worktree/." "$W/tree/broken-stub/"
rm "$W/tree/broken-xml/api36/etc/permissions/com.google.android.projection.gearhead.xml"
rm "$W/tree/broken-stub/api36/priv-app/AndroidAutoStubPrebuilt/AndroidAutoStubPrebuilt.apk"
```

3. Delete the whole `check_broken_case` function together with its comment line `# Hand-built or interrupted module trees: the stub must never be installed without its allowlist XML.`, and delete its four invocation lines:

```bash
run_case broken-xml 36 yes
run_case broken-stub 36 yes
check_broken_case xml $M_XML
check_broken_case stub $A_XML
```

4. Replace the whole `check_compare_case` function with:

```bash
check_compare_case() {
    local api=$1 answer=$2
    local wdir=$W/case/worktree-$api-$answer rdir=$W/case/ref-$api-$answer
    local label="api=$api answer=$answer [compare $COMPARE_REF]"

    [ "$(cat "$rdir/rc")" = 0 ] || fail "reference installer exited with status $(cat "$rdir/rc")"

    local mp=adb/modules_update/aa4mg
    grep -vE "  $mp/(customize\.sh|README\.md|CHANGELOG|module\.prop|update\.json)\$" "$rdir/manifest" > "$rdir/manifest.cmp"
    grep -vE "  $mp/(customize\.sh|README\.md|CHANGELOG|module\.prop|update\.json)\$" "$wdir/manifest" > "$wdir/manifest.cmp"
    diff -u "$rdir/manifest.cmp" "$wdir/manifest.cmp" > "$W/diff" || fail "manifest differs from $COMPARE_REF:"$'\n'"$(sed 's/^/        /' "$W/diff")"

    finish_case "$label" "$rdir/log"
}
```

- [ ] **Step 2: Run the tests on the current layout**

Run the test command. Expected: `Summary: 19/19 passed, 0 failed` (the installer still moves the `api36/` files, so the result already equals `9b464e7`).

- [ ] **Step 3: Move the files**

```bash
bash -c 'cd /home/l0rdg3x/coding/aa4mg/.worktrees/drop-legacy && \
git mv -f api36/priv-app/AndroidAutoStubPrebuilt/AndroidAutoStubPrebuilt.apk system/product/priv-app/AndroidAutoStubPrebuilt/AndroidAutoStubPrebuilt.apk && \
git mv -f api36/etc/permissions/com.google.android.projection.gearhead.xml system/product/etc/permissions/com.google.android.projection.gearhead.xml && \
git mv -f api36/overlay/AndroidAutoOverlay.apk system/product/overlay/AndroidAutoOverlay.apk && \
git rm -q system/product/priv-app/AndroidAutoStubPrebuilt/oat/arm64/AndroidAutoStubPrebuilt.odex system/product/priv-app/AndroidAutoStubPrebuilt/oat/arm64/AndroidAutoStubPrebuilt.vdex && \
git ls-files api36 system/product/priv-app && \
sha256sum system/product/priv-app/AndroidAutoStubPrebuilt/AndroidAutoStubPrebuilt.apk system/product/etc/permissions/com.google.android.projection.gearhead.xml system/product/overlay/AndroidAutoOverlay.apk'
```

Expected: `git ls-files` prints only `system/product/priv-app/AndroidAutoStubPrebuilt/AndroidAutoStubPrebuilt.apk` and `system/product/priv-app/Velvet/Velvet.apk` (nothing under `api36`); the hashes start with `37f588bf` (stub), `edfc75e8` (XML), `85ad586a` (overlay). If an empty `api36/` directory remains on disk, remove it with `rmdir -p` on its leaf directories.

- [ ] **Step 4: Delete the per-API branches from `customize.sh`**

Delete this whole block (it starts right after the `.pb` block's closing `fi` and ends right before the comment `# KernelSU-Next 3.x and recent KernelSU mount module files only through a metamodule: the`), including the blank line after it:

```sh
# Android 16 needs the newer stub with its matching privapp permissions, and the
# overlay rebuilt for API 36 (NikGapps-Addon-16-AndroidAuto-20260222).
# The overlay requires API 36, so older releases keep the previous files.
if [ $API -ge 36 ] ; then
    rm -rf $MODPATH/system/product/priv-app/AndroidAutoStubPrebuilt/oat
    mv -f $MODPATH/api36/etc/permissions/com.google.android.projection.gearhead.xml $MODPATH/system/product/etc/permissions/ &&
        mv -f $MODPATH/api36/priv-app/AndroidAutoStubPrebuilt/AndroidAutoStubPrebuilt.apk $MODPATH/system/product/priv-app/AndroidAutoStubPrebuilt/
    mv -f $MODPATH/api36/overlay/AndroidAutoOverlay.apk $MODPATH/system/product/overlay/
fi
rm -rf $MODPATH/api36

# At this point, the module is ready for A13
# We need to make some changes for A11 and A12
if [ $API -lt 33 ] ; then
    mv $MODPATH/system/product/* $MODPATH/system/
    rm -rf $MODPATH/system/product
fi

if [ $API -lt 31 ] ; then
    # is this really needed for A11?
    if [ -f "$MODPATH/system/priv-app/Velvet/Velvet.apk" ] ; then
        mkdir -p $MODPATH/system/app/QuickSearchBox
        mv $MODPATH/system/priv-app/Velvet/Velvet.apk $MODPATH/system/app/QuickSearchBox/QuickSearchBox.apk
        rm -rf $MODPATH/system/priv-app/Velvet

        ls $MODPATH/system/app/QuickSearchBox -1
    fi
fi

```

After the edit, the `.pb` block's closing `fi` is followed by one blank line and then `# KernelSU-Next 3.x and recent KernelSU mount module files only through a metamodule: the`.

Check: `bash -c 'cd /home/l0rdg3x/coding/aa4mg/.worktrees/drop-legacy && grep -n "api36\|API -lt\|API -ge" customize.sh'` prints only line 3 (the gate).

- [ ] **Step 5: Run the tests**

Run the test command. Expected: `Summary: 19/19 passed, 0 failed`.

- [ ] **Step 6: Verify the comparison is not vacuous**

```bash
bash -c 'cd /home/l0rdg3x/coding/aa4mg/.worktrees/drop-legacy && git show 9b464e7:system/product/priv-app/AndroidAutoStubPrebuilt/AndroidAutoStubPrebuilt.apk > system/product/priv-app/AndroidAutoStubPrebuilt/AndroidAutoStubPrebuilt.apk'
```

Run the test command. Expected: the four `[worktree]` cases FAIL on `hash mismatch for system/product/priv-app/AndroidAutoStubPrebuilt/AndroidAutoStubPrebuilt.apk` and the four `[compare 9b464e7]` cases FAIL with a manifest difference on that file. Restore:

```bash
bash -c 'cd /home/l0rdg3x/coding/aa4mg/.worktrees/drop-legacy && git checkout -- system/product/priv-app/AndroidAutoStubPrebuilt/AndroidAutoStubPrebuilt.apk && sha256sum system/product/priv-app/AndroidAutoStubPrebuilt/AndroidAutoStubPrebuilt.apk'
```

The new stub is staged by `git mv`, so restore it from the index with `git checkout -- <path>`. Do NOT use `git checkout HEAD -- <path>`: HEAD still holds the old stub at that path. The hash must start with `37f588bf` again. Run the test command once more: `Summary: 19/19 passed, 0 failed`.

- [ ] **Step 7: Commit**

Stage `customize.sh`, `tests/install-test.sh` and the moves/deletions (`git status` must show no unstaged change and no file outside this task). Message subject: `Ship the Android 16 files in place`. Body: the Android 16 stub, privapp permissions and overlay now sit at their final paths, so the installer no longer moves them; the pre-Android 16 stub, its oat files, XML and overlay and the Android 11/12 relocations are gone; on API 36 and 37 the installed module is identical to 9b464e7 (strict compare). Add the trailers.

---

### Task 3: Documentation

**Files:**
- Modify: `README.md`, `CHANGELOG`, `docs/STATUS.md`

**Interfaces:**
- Consumes: the abort message and behaviour from Task 1, the layout from Task 2.

- [ ] **Step 1: README edits** (each `old` text is verbatim from the current file)

1. Line 1: `# Android Auto 4 MicroG (for A11, A12, A13, A14, A15, A16)` → `# Android Auto 4 MicroG (for A16)`

2. Replace

```
This is a [Magisk](https://topjohnwu.github.io/Magisk/) / KernelSU module (KernelSU-Next included) that provides an AA (Android Auto) stub as system app, optionally together with [XLauncher Unlocked](https://github.com/Rikj000/Android-Auto-XLauncher-Unlocked) and stubs for Google TTS, Google Maps & Google Search.
It is intended to be used on de-googled devices running MicroG!
```

with

```
This is a [KernelSU-Next](https://github.com/KernelSU-Next/KernelSU-Next) module that provides an AA (Android Auto) stub as system app, optionally together with [XLauncher Unlocked](https://github.com/Rikj000/Android-Auto-XLauncher-Unlocked) and stubs for Google TTS, Google Maps & Google Search.
It is intended to be used on de-googled devices running MicroG!

It supports Android 16 and later only: on older releases the installer stops with an error.
Magisk, the original KernelSU and APatch are not supported and not tested.
```

3. `If the AA system app is missing *(by disabling `aa4mg` or booting without Magisk)*,` → `If the AA system app is missing *(by disabling `aa4mg` or booting without KernelSU-Next)*,`

4. Replace

```
2. Install [Magisk](https://topjohnwu.github.io/Magisk/install.html), or KernelSU / KernelSU-Next.
    *(On KernelSU-Next 3.x, and on KernelSU versions with metamodule support, module files are mounted by a metamodule such as Hybrid Mount, Meta Magic Mount or Mountify. Install one first and reboot, then install aa4mg. If you switch metamodule later, install aa4mg again.)*
3. Install the [aa4mg](https://github.com/sn-00-x/aa4mg/releases) module through the Magisk Manager App (or the KernelSU manager) => Reboot
```

with

```
2. Install [KernelSU-Next](https://github.com/KernelSU-Next/KernelSU-Next).
    *(On KernelSU-Next 3.x, module files are mounted by a metamodule such as Hybrid Mount, Meta Magic Mount or Mountify. Install one first and reboot, then install aa4mg. If you switch metamodule later, install aa4mg again.)*
3. Install the [aa4mg](https://github.com/sn-00-x/aa4mg/releases) module through the KernelSU-Next manager => Reboot
```

5. `- [aa4mg](https://github.com/sn-00-x/aa4mg) can be updated through the Magisk or KernelSU manager` → `- [aa4mg](https://github.com/sn-00-x/aa4mg) can be updated through the KernelSU-Next manager`

6. `2. Magisk or KernelSU manager => Modules => Remove "Android Auto 4 microG" => Reboot` → `2. KernelSU-Next manager => Modules => Remove "Android Auto 4 microG" => Reboot`

7. `The Magisk steps and the "Umount modules" advice are untested.` → `The "Umount modules" advice is untested.`

8. Replace

```
  Root or shell installs (`pm install -i com.android.vending`, App Manager, Aurora's `Root installer`) can only set
  the installer, not the app that started the installation: Android 14 and later record the shell there, Android 11 to
  13 record no app. A user reported that the shell is not enough for navigation apps (microG issue #3030); Android 11
  to 13 is untested.
```

with

```
  Root or shell installs (`pm install -i com.android.vending`, App Manager, Aurora's `Root installer`) can only set
  the installer, not the app that started the installation: Android 16 records the shell there. A user reported that
  the shell is not enough for navigation apps (microG issue #3030).
```

9. Delete this block, including the blank line after it:

```
**Magisk**

1. Magisk => Settings => Magisk => Check `Zygisk`
2. Install [Vector](https://github.com/JingMatrix/Vector), the maintained LSPosed fork (the original
   [LSPosed](https://lsposed.org/) supports Android 8.1 to 14 only)
3. In the LSPosed manager => Modules => Android Auto - XLauncher Unlocked
    - Check `Enable module`
    - Check `Android Auto` (only)
4. Reboot

```

10. `**KernelSU / KernelSU-Next**` → `**KernelSU-Next**`; in the next paragraph `KernelSU has no built-in Zygisk` → `KernelSU-Next has no built-in Zygisk` (rest of the paragraph unchanged).

11. `If XLauncher Unlocked does not open, turn off 'Umount modules' for XLauncher Unlocked and Android Auto in the KernelSU App Profile.` → same sentence ending `in the KernelSU-Next App Profile.`

12. Delete the bullet that starts with `- **Magisk safe mode:**` (one line).

Leave everything else unchanged, including the "[A15]" notes in Installation steps 6 and 7.

- [ ] **Step 2: CHANGELOG edits**

1. `Unreleased (A11, A12, A13, A14, A15, A16)` → `Unreleased (A16)`

2. Insert these two lines as the first two entries under that header (after the blank line):

```
- Drop Android 11 to 15: the installer stops with an error below Android 16 (API 36), and the Android Auto stub, privapp permissions, overlay and oat files for older releases are removed
- Drop Magisk from the documentation: KernelSU-Next is the only supported root solution (the installer does not block Magisk, but Magisk is not tested)
```

3. In the entry starting `- Add Android 16 support:`, delete `, installed only on Android 16 and later (API 36+)` at its end.

4. `- README: document KernelSU / KernelSU-Next (metamodule,` → `- README: document KernelSU-Next (metamodule,` (rest of the line unchanged).

5. In the entry starting `- README: rewrite "3rd party apps"`, delete `; Magisk users are pointed to Vector instead of the original LSPosed` at its end.

- [ ] **Step 3: Replace `docs/STATUS.md` with**

```markdown
# Status

## Done
- Android 16 support (stub, privapp permissions, overlay from NikGapps 20260222) (d67a694): implemented and simulation-tested; the maintainer reported on 2026-10-12 that Android Auto works with this build on the Nothing Phone 2 (detailed read-only checks not reported).
- Android 11-15 dropped, KernelSU-Next the only supported root solution (branch drop-legacy): the installer stops below API 36; Magisk is no longer documented but not blocked. Simulation-tested: on API 36 and 37 the installed module is identical to 9b464e7; device check pending.
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
```

- [ ] **Step 4: Verify**

```bash
bash -c 'cd /home/l0rdg3x/coding/aa4mg/.worktrees/drop-legacy && grep -n "Magisk" README.md; grep -n "A11\|A12\|A13\|A14\|Android 11\|Android 14\|KernelSU /\|KernelSU manager\|KernelSU App" README.md; grep -n "A15" README.md; head -5 CHANGELOG'
```

Expected: `Magisk` appears only in `Magisk, the original KernelSU and APatch are not supported and not tested.`; the second grep prints nothing; `A15` appears only in Installation steps 6 and 7; the CHANGELOG header is `Unreleased (A16)` followed by the two new entries. Run the test command: `Summary: 19/19 passed, 0 failed` (docs are filtered out of the comparison).

- [ ] **Step 5: Commit**

Message subject: `Document Android 16 and KernelSU-Next as the only supported setup`. Body: README, CHANGELOG and STATUS follow the drop of Android 11-15 and Magisk; Magisk still installs but is no longer documented or tested; the "[A15]" notes stay until the paths are confirmed on Android 16. Add the trailers.
