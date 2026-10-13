#!/bin/bash
# Simulates the module installation by sourcing customize.sh under a static
# busybox in an unprivileged chroot. Never touches the host /data.
#
# Usage: BUSYBOX=<static busybox> tests/install-test.sh [--compare-ref <git-ref>]
set -euo pipefail

die() { echo "install-test: $*" >&2; exit 2; }

COMPARE_REF=""
while [ $# -gt 0 ]; do
    case "$1" in
        --compare-ref) [ $# -ge 2 ] || die "--compare-ref needs an argument"; COMPARE_REF=$2; shift 2 ;;
        *) die "unknown argument: $1" ;;
    esac
done

[ -n "${BUSYBOX:-}" ] && [ -x "$BUSYBOX" ] || die "BUSYBOX must point to an executable static busybox"
for tool in git unshare chroot sha256sum tar find; do
    command -v "$tool" >/dev/null || die "missing required tool: $tool"
done

REPO=$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)
W=$(mktemp -d)
trap 'rm -rf "$W"' EXIT

APIS="36 37"
ANSWERS="yes no"
ID=aa4mg
MODREL=data/adb/modules_update/$ID

A_STUB=37f588bf651527a249e8b38ab01f8d28b9143b2050bd9820d2caa21f255c4903
A_XML=edfc75e888e8f3c7b97359e059f08640bc06599b9daa11497e1033f3c2a401f8
A_OVL=85ad586ad6dc57cb19720324299f7763121b0ee6b735f831e4ea5874c6b120c7

prune_tree() { rm -rf "$1/META-INF" "$1/tests" "$1/docs"; }

mkdir -p "$W/tree/worktree"
(cd "$REPO" && git ls-files -z | tar --null -T - -cf -) | tar -xf - -C "$W/tree/worktree"
prune_tree "$W/tree/worktree"
TREES="worktree"
if [ -n "$COMPARE_REF" ]; then
    mkdir -p "$W/tree/ref"
    git -C "$REPO" archive "$COMPARE_REF" | tar -xf - -C "$W/tree/ref"
    prune_tree "$W/tree/ref"
    TREES="worktree ref"
fi

make_manifest() {
    (
        cd "$1/data"
        find . -mindepth 1 -type d -printf '%m  %P/\n'
        find . -type l -printf 'L %l  %P\n'
        find . -type f -print0 | while IFS= read -r -d '' f; do
            h=$(sha256sum < "$f")
            printf '%s %s  %s\n' "${h%% *}" "$(stat -c %a "$f")" "${f#./}"
        done
    ) | LC_ALL=C sort
}

WARN_LINE='*** WARNING: no KernelSU metamodule found!'
ABORT_LINE='! aa4mg requires Android 16 or later (API 36+)'

# Metamodule fixtures under data/, so they appear in every manifest. The default models KernelSU with
# Hybrid Mount: /data/adb/metamodule is an absolute symlink to /data/adb/modules/hybrid_mount, whose
# module.prop carries metamodule=1. Other scenarios: nometa, propfallback, dangling, magisk, phenotype (default plus a
# pre-existing phenotype.db), installed (default plus an aa4mg already installed under modules/).
setup_metamodule() {
    local root=$1 scenario=$2 mods=$1/data/adb/modules
    mkdir -p "$mods"
    case "$scenario" in
        default)
            mkdir -p "$mods/hybrid_mount"
            printf 'id=hybrid_mount\nname=Hybrid Mount\nmetamodule=1\n' > "$mods/hybrid_mount/module.prop"
            ln -s /data/adb/modules/hybrid_mount "$root/data/adb/metamodule" ;;
        nometa|dangling|magisk)
            mkdir -p "$mods/other"
            printf 'id=other\nname=Other\n' > "$mods/other/module.prop"
            [ "$scenario" != dangling ] || ln -s /data/adb/modules/gone "$root/data/adb/metamodule" ;;
        phenotype)
            mkdir -p "$mods/hybrid_mount"
            printf 'id=hybrid_mount\nname=Hybrid Mount\nmetamodule=1\n' > "$mods/hybrid_mount/module.prop"
            ln -s /data/adb/modules/hybrid_mount "$root/data/adb/metamodule"
            mkdir -p "$root/data/data/com.google.android.gms/databases"
            echo 'pre-existing phenotype.db' > "$root/data/data/com.google.android.gms/databases/phenotype.db" ;;
        installed)
            mkdir -p "$mods/hybrid_mount" "$mods/aa4mg"
            printf 'id=hybrid_mount\nname=Hybrid Mount\nmetamodule=1\n' > "$mods/hybrid_mount/module.prop"
            ln -s /data/adb/modules/hybrid_mount "$root/data/adb/metamodule"
            printf 'id=aa4mg\nversion=installed\n' > "$mods/aa4mg/module.prop" ;;
        propfallback)
            mkdir -p "$mods/pf"
            printf 'id=pf\nmetamodule = True \n' > "$mods/pf/module.prop" ;;
    esac
}

# run_case TREE API ANSWER [SCENARIO] -> populates $W/case/TREE-API-ANSWER[-SCENARIO]/{root,log,rc,manifest,dirs.before,dirs.after}
run_case() {
    local tree=$1 api=$2 answer=$3 scenario=${4:-default}
    local dir=$W/case/$tree-$api-$answer
    [ "$scenario" = default ] || dir=$dir-$scenario
    local root=$dir/root key=KEY_VOLUMEUP
    [ "$answer" = no ] && key=KEY_VOLUMEDOWN
    mkdir -p "$root"/{bin,etc,system/bin,dev/tmp,data/data/com.google.android.gms,data/data/com.google.android.projection.gearhead}
    cp "$BUSYBOX" "$root/bin/busybox"
    # No /proc in the chroot, so ASH_STANDALONE cannot find the applets by itself
    local applet
    for applet in $("$BUSYBOX" --list); do ln -s busybox "$root/bin/$applet"; done
    echo 'root:x:0:0::/:/bin/sh' > "$root/etc/passwd"
    echo 'root:x:0:' > "$root/etc/group"
    printf '#!/bin/sh\necho "/dev/input/event0: EV_KEY       %s         DOWN"\n' "$key" > "$root/system/bin/getevent"
    chmod 755 "$root/system/bin/getevent"
    setup_metamodule "$root" "$scenario"
    local ksu=(KSU=true)
    [ "$scenario" != magisk ] || ksu=()
    mkdir -p "$root/$MODREL"
    cp -a "$W/tree/$tree/." "$root/$MODREL/"
    (cd "$root/$MODREL/system" && find . -type d | LC_ALL=C sort) > "$dir/dirs.before"
    local rc=0
    # ui_print and abort as in KernelSU-Next's installer.sh in boot mode: abort removes MODPATH and TMPDIR.
    unshare -r --fork chroot "$root" /bin/busybox env -i PATH=/bin ASH_STANDALONE=1 API="$api" \
        MODPATH=/data/adb/modules_update/$ID TMPDIR=/dev/tmp BOOTMODE=true "${ksu[@]}" \
        /bin/busybox sh -c 'ui_print() { echo "$1"; }; abort() { echo "$1"; rm -rf "$MODPATH" "$TMPDIR"; exit 1; }; . "$MODPATH/customize.sh"' \
        > "$dir/log" 2>&1 || rc=$?
    echo "$rc" > "$dir/rc"
    (cd "$root/$MODREL/system" 2>/dev/null && find . -type d | LC_ALL=C sort) > "$dir/dirs.after" || : > "$dir/dirs.after"
    make_manifest "$root" > "$dir/manifest"
}

REASONS=()
fail() { REASONS+=("$1"); }
FAILED=0
TOTAL=0

# finish_case LABEL [LOGFILE]
finish_case() {
    TOTAL=$((TOTAL + 1))
    if [ ${#REASONS[@]} -eq 0 ]; then
        echo "PASS $1"
    else
        FAILED=$((FAILED + 1))
        echo "FAIL $1"
        printf '    - %s\n' "${REASONS[@]}"
        if [ -n "${2:-}" ]; then
            echo "    last log lines:"
            tail -n 20 "$2" | sed 's/^/    | /'
        fi
    fi
    REASONS=()
}

check_hash() {
    local f=$MOD/$1 want=$2 got
    if [ ! -f "$f" ]; then
        fail "missing $1"
        return
    fi
    got=$(sha256sum < "$f")
    got=${got%% *}
    [ "$got" = "$want" ] || fail "hash mismatch for $1 (got $got, want $want)"
}

check_exists() { [ -e "$MOD/$1" ] || fail "missing $1"; }

has_named() { [ -n "$(find "$MOD" -name "$1" -print -quit)" ]; }

# check_warning CASEDIR present|absent
check_warning() {
    local dir=$1 want=$2 w r
    w=$(grep -nF -- "$WARN_LINE" "$dir/log" | head -n 1 | cut -d: -f1 || true)
    if [ "$want" = absent ]; then
        [ -z "$w" ] || fail "metamodule warning printed but not expected"
        return
    fi
    if [ -z "$w" ]; then
        fail "metamodule warning missing"
        return
    fi
    r=$(grep -nF -- '*** Please re-boot your device,' "$dir/log" | head -n 1 | cut -d: -f1 || true)
    [ -n "$r" ] && [ "$w" -lt "$r" ] || fail "metamodule warning is not printed before the re-boot lines"
}

# check_prompts CASEDIR yes|no [EXPECTED_PROMPTS]
check_prompts() {
    local dir=$1 answer=$2 want=${3:-4} n
    grep -qF -- 'Stubs are fake placeholder apps. Answer YES only for' "$dir/log" || fail "stub explanation missing from the log"
    local prompts timeouts
    prompts=$(grep -cE '^\*\*\* (Install |Overwrite pre-existing)' "$dir/log" || true)
    timeouts=$(grep -cF -- 'Please answer within 30 seconds or' "$dir/log" || true)
    [ "$prompts" = "$want" ] && [ "$timeouts" = "$prompts" ] || fail "expected $want prompts with one 30 second timeout each, got $timeouts timeouts for $prompts prompts"
    ! grep -qE 'within (10|20) seconds or' "$dir/log" || fail "prompt with a timeout other than 30 seconds"
    if [ "$answer" = no ]; then
        grep -qxF -- 'Skipped:' "$dir/log" || fail "Skipped list missing although answer was no"
        for n in "Google Maps stub" "Google Speech Services stub" "Google Search stub" "Android Auto - XLauncher Unlocked"; do
            grep -qxF -- "    $n" "$dir/log" || fail "skipped item '$n' not listed"
        done
    else
        ! grep -qF -- 'Skipped:' "$dir/log" || fail "Skipped list printed although answer was yes"
    fi
}

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
        for n in Maps.apk GoogleTTS.apk Velvet.apk AndroidAuto-XLauncherUnlocked.apk; do
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

# check_ksu_case SCENARIO present|absent: API 36 with a non-default metamodule setup
check_ksu_case() {
    local scenario=$1 want=$2
    local dir=$W/case/worktree-36-yes-$scenario
    local ddir=$W/case/worktree-36-yes
    [ "$(cat "$dir/rc")" = 0 ] || fail "installer exited with status $(cat "$dir/rc")"
    grep -q 'Installation of' "$dir/log" || fail "log does not contain 'Installation of'"
    check_warning "$dir" "$want"
    check_prompts "$dir" yes
    # Payload (adb/modules_update/aa4mg and the rest of data/) must equal the default case's, apart from
    # the metamodule fixture paths (adb/metamodule and everything under adb/modules/).
    local f='  adb/(metamodule$|modules/)'
    grep -vE "$f" "$ddir/manifest" > "$dir/manifest.default"
    grep -vE "$f" "$dir/manifest" > "$dir/manifest.cmp"
    diff -u "$dir/manifest.default" "$dir/manifest.cmp" > "$W/diff" || fail "manifest differs from the default case:"$'\n'"$(sed 's/^/        /' "$W/diff")"
    finish_case "api=36 answer=yes [ksu-$scenario]" "$dir/log"
}

# check_phenotype_case yes|no: API 36 with a pre-existing phenotype.db
check_phenotype_case() {
    local answer=$1
    local dir=$W/case/worktree-36-$answer-phenotype
    local db=data/data/com.google.android.gms/databases/phenotype.db
    local pre got want
    [ "$(cat "$dir/rc")" = 0 ] || fail "installer exited with status $(cat "$dir/rc")"
    grep -q 'Installation of' "$dir/log" || fail "log does not contain 'Installation of'"
    check_warning "$dir" absent
    check_prompts "$dir" "$answer" 5
    grep -qF -- '*** Overwrite pre-existing phenotyope.db? ***' "$dir/log" || fail "phenotype.db overwrite prompt missing"
    pre=$(echo 'pre-existing phenotype.db' | sha256sum); pre=${pre%% *}
    got=$(sha256sum < "$dir/root/$db"); got=${got%% *}
    want=$(sha256sum < "$W/tree/worktree/$db"); want=${want%% *}
    if [ "$answer" = no ]; then
        [ "$got" = "$pre" ] || fail "pre-existing phenotype.db changed although answer was no"
        grep -qF -- 'Keeping pre-existing phenotype.db' "$dir/log" || fail "keep message missing"
    else
        [ "$got" = "$want" ] || fail "phenotype.db not replaced by the module copy although answer was yes"
        grep -qF -- 'Overwriting phenotype.db' "$dir/log" || fail "overwrite message missing"
    fi
    finish_case "api=36 answer=$answer [phenotype-exists]" "$dir/log"
}

# check_abort_case API [SCENARIO]: below Android 16 the installer must stop before any prompt, leave no module
# directory behind and write nothing under data/ apart from the fixtures.
check_abort_case() {
    local api=$1 scenario=${2:-default}
    local dir=$W/case/worktree-$api-yes
    [ "$scenario" = default ] || dir=$dir-$scenario
    local label="api=${api:-empty} answer=yes [abort${2:+ $2}]"

    [ "$(cat "$dir/rc")" = 1 ] || fail "installer exited with status $(cat "$dir/rc"), expected 1"
    grep -qxF -- "$ABORT_LINE" "$dir/log" || fail "abort message missing"
    [ "$(cat "$dir/log")" = "$ABORT_LINE" ] || fail "installer printed more than the abort message"
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

for tree in $TREES; do
    for api in $APIS; do
        for answer in $ANSWERS; do
            run_case "$tree" "$api" "$answer"
        done
    done
done

for api in $APIS; do
    for answer in $ANSWERS; do
        check_working_tree_case "$api" "$answer"
    done
done

for scenario in nometa propfallback dangling magisk; do
    run_case worktree 36 yes "$scenario"
done
check_ksu_case nometa present
check_ksu_case propfallback absent
check_ksu_case dangling present
check_ksu_case magisk absent

for answer in $ANSWERS; do
    run_case worktree 36 "$answer" phenotype
    check_phenotype_case "$answer"
done

for api in 30 35 ""; do
    run_case worktree "$api" yes
    check_abort_case "$api"
done
for scenario in magisk installed; do
    run_case worktree 35 yes "$scenario"
    check_abort_case 35 "$scenario"
done

if [ -n "$COMPARE_REF" ]; then
    for api in $APIS; do
        for answer in $ANSWERS; do
            check_compare_case "$api" "$answer"
        done
    done
fi

echo "Summary: $((TOTAL - FAILED))/$TOTAL passed, $FAILED failed"
[ "$FAILED" -eq 0 ]
