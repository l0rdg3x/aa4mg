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

APIS="30 31 32 33 34 35 36"
ANSWERS="yes no"
ID=aa4mg
MODREL=data/adb/modules_update/$ID

M_STUB=46c6b78585a5f94d3433606859f65268db18d7418dc1682b4b86ea0a214a64a5
M_XML=8993f986dfce491d61b4cde4306a0c6e381cd58c66af741b604ec59c6605a9ed
M_OVL=f99e9966145eb83b2f0049c346f3805ef8d43ebd748f4677cf20731dc760df55
M_ODEX=b892cb16dbce06f8c934d5000924d413a42fe44a80e9ddcaf1341c0234e2f193
M_VDEX=33b67d121d4cebe74588cb6d6ed23138ec72f2b6f6cb05ae662bd211b965b8cb
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
        find . -mindepth 1 -type d -printf '%P/\n'
        find . -type l -printf 'L %l  %P\n'
        find . -type f -exec sha256sum {} + | sed 's|  \./|  |'
    ) | LC_ALL=C sort
}

# run_case TREE API ANSWER -> populates $W/case/TREE-API-ANSWER/{root,log,rc,manifest,dirs.before,dirs.after}
run_case() {
    local tree=$1 api=$2 answer=$3
    local dir=$W/case/$tree-$api-$answer
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
    mkdir -p "$root/$MODREL"
    cp -a "$W/tree/$tree/." "$root/$MODREL/"
    (cd "$root/$MODREL/system" && find . -type d | LC_ALL=C sort) > "$dir/dirs.before"
    local rc=0
    unshare -r --fork chroot "$root" /bin/busybox env -i PATH=/bin ASH_STANDALONE=1 API="$api" \
        MODPATH=/data/adb/modules_update/$ID TMPDIR=/dev/tmp BOOTMODE=true KSU=true \
        /bin/busybox sh -c 'ui_print() { echo "$1"; }; abort() { echo "$1"; exit 1; }; . "$MODPATH/customize.sh"' \
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

check_working_tree_case() {
    local api=$1 answer=$2
    local dir=$W/case/worktree-$api-$answer
    MOD=$dir/root/$MODREL

    [ "$(cat "$dir/rc")" = 0 ] || fail "installer exited with status $(cat "$dir/rc")"
    grep -q 'Installation of' "$dir/log" || fail "log does not contain 'Installation of'"
    [ ! -e "$MOD/api36" ] || fail "api36 directory still present after install"

    local stubdir
    if [ "$api" -ge 33 ]; then
        stubdir=system/product/priv-app/AndroidAutoStubPrebuilt
        local xml=system/product/etc/permissions/com.google.android.projection.gearhead.xml
        local ovl=system/product/overlay/AndroidAutoOverlay.apk
        if [ "$api" -ge 36 ]; then
            check_hash "$stubdir/AndroidAutoStubPrebuilt.apk" $A_STUB
            check_hash "$xml" $A_XML
            check_hash "$ovl" $A_OVL
            if [ -d "$MOD/$stubdir" ]; then
                [ "$(find "$MOD/$stubdir" -mindepth 1 -maxdepth 1 | wc -l)" = 1 ] \
                    || fail "$stubdir must contain exactly one entry"
            fi
        else
            check_hash "$stubdir/AndroidAutoStubPrebuilt.apk" $M_STUB
            check_hash "$xml" $M_XML
            check_hash "$ovl" $M_OVL
            check_hash "$stubdir/oat/arm64/AndroidAutoStubPrebuilt.odex" $M_ODEX
            check_hash "$stubdir/oat/arm64/AndroidAutoStubPrebuilt.vdex" $M_VDEX
        fi
    else
        [ ! -e "$MOD/system/product" ] || fail "system/product still present"
        stubdir=system/priv-app/AndroidAutoStubPrebuilt
        check_hash "$stubdir/AndroidAutoStubPrebuilt.apk" $M_STUB
        check_hash system/etc/permissions/com.google.android.projection.gearhead.xml $M_XML
        check_hash system/overlay/AndroidAutoOverlay.apk $M_OVL
        check_hash "$stubdir/oat/arm64/AndroidAutoStubPrebuilt.odex" $M_ODEX
        check_hash "$stubdir/oat/arm64/AndroidAutoStubPrebuilt.vdex" $M_VDEX
    fi

    if [ "$answer" = no ]; then
        local n
        for n in Maps.apk GoogleTTS.apk Velvet.apk QuickSearchBox.apk AndroidAuto-XLauncherUnlocked.apk; do
            ! has_named "$n" || fail "$n present although answer was no"
        done
    else
        local n
        for n in Maps.apk GoogleTTS.apk AndroidAuto-XLauncherUnlocked.apk; do
            has_named "$n" || fail "$n missing although answer was yes"
        done
        if [ "$api" -ge 31 ]; then
            has_named Velvet.apk || fail "Velvet.apk missing although answer was yes"
        else
            check_exists system/app/QuickSearchBox/QuickSearchBox.apk
        fi
    fi

    if [ "$api" -ge 31 ]; then
        local before=$dir/dirs.before extra
        if [ "$api" -le 32 ]; then
            sed -e 's#^\./product$#.#' -e 's#^\./product/#./#' "$dir/dirs.before" | LC_ALL=C sort -u > "$dir/dirs.before.mapped"
            before=$dir/dirs.before.mapped
        fi
        extra=$(LC_ALL=C comm -13 "$before" "$dir/dirs.after")
        [ -z "$extra" ] || fail "directories created by customize.sh under system/: $(echo $extra)"
    fi

    finish_case "api=$api answer=$answer [worktree]" "$dir/log"
}

check_compare_case() {
    local api=$1 answer=$2
    local wdir=$W/case/worktree-$api-$answer rdir=$W/case/ref-$api-$answer
    local label="api=$api answer=$answer [compare $COMPARE_REF]"

    [ "$(cat "$rdir/rc")" = 0 ] || fail "reference installer exited with status $(cat "$rdir/rc")"

    if [ "$api" -le 35 ]; then
        diff -u "$rdir/manifest" "$wdir/manifest" > "$W/diff" || fail "manifest differs from $COMPARE_REF:"$'\n'"$(sed 's/^/        /' "$W/diff")"
    else
        local line path
        while IFS= read -r line; do
            path=${line#*  }
            case "$path" in
                *system/product/priv-app/AndroidAutoStubPrebuilt/*) ;;
                *system/product/etc/permissions/com.google.android.projection.gearhead.xml) ;;
                *system/product/overlay/AndroidAutoOverlay.apk) ;;
                *) fail "unexpected manifest difference: $line" ;;
            esac
        done < <(diff "$rdir/manifest" "$wdir/manifest" | sed -n 's/^[<>] //p')
    fi

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

if [ -n "$COMPARE_REF" ]; then
    for api in $APIS; do
        for answer in $ANSWERS; do
            check_compare_case "$api" "$answer"
        done
    done
fi

echo "Summary: $((TOTAL - FAILED))/$TOTAL passed, $FAILED failed"
[ "$FAILED" -eq 0 ]
