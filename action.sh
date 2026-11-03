#!/system/bin/sh
# Action button in the KernelSU-Next manager. The updates of the system apps aa4mg provides must be uninstalled before
# aa4mg is disabled or removed (README, Warning); uninstall.sh runs at the next boot, before the package manager starts,
# so it cannot. These are the Android Auto updates and, when aa4mg installed the Google app as a system app, the
# Google app updates.
MODDIR=$(dirname "$0")
DELAY=10
PKGS="com.google.android.projection.gearhead"
NAMES="Android Auto"
if [ "$(cat "$MODDIR/velvet_mode" 2>/dev/null)" = real ]; then
    PKGS="$PKGS com.google.android.googlequicksearchbox"
    NAMES="Android Auto and the Google app"
fi

echo "Uninstall the updates of $NAMES?"
echo "Do this before you disable or remove aa4mg."
echo "Volume UP (+) = YES"
echo "Volume DOWN (-) or no answer within $DELAY seconds = NO"

ANSWER="NO"
END=$(($(date +%s) + DELAY))
while :; do
    REMAINING=$((END - $(date +%s)))
    [ "$REMAINING" -gt 0 ] || break
    EVENT=$(timeout ${REMAINING}s /system/bin/getevent -lqc 1 2>/dev/null)
    RC=$?
    # 143: busybox timeout stopped getevent because no event came in time
    case "$RC" in
        0|143) ;;
        *)
            echo "Cannot read the volume keys (getevent exit status $RC): nothing was changed."
            echo "Uninstall the updates in Settings => Apps => See all apps => <app> => Uninstall updates."
            exit 1 ;;
    esac
    case "$EVENT" in
        *KEY_VOLUMEUP*DOWN*) ANSWER="YES"; break ;;
        *KEY_VOLUMEDOWN*DOWN*) break ;;
    esac
done

if [ "$ANSWER" != "YES" ]; then
    echo "Cancelled: nothing was changed."
    exit 0
fi

FAILED=0
for PKG in $PKGS; do
    case "$PKG" in
        com.google.android.googlequicksearchbox) NAME="Google app"; APP="Google"; WHO="the Google app" ;;
        *) NAME="Android Auto"; APP="Android Auto"; WHO="Android Auto" ;;
    esac
    echo "Uninstalling the $NAME updates..."
    # This pm command exits with 1 on success and 0 on failure, and throws when the package is not a system app
    # (AOSP PackageManagerShellCommand), so read its output
    OUT=$(/system/bin/pm uninstall-system-updates "$PKG" 2>&1)
    echo "$OUT"
    case "$OUT" in
        *"Uninstalling updates to $PKG"*Success) echo "$NAME updates removed." ;;
        *Success) echo "No $NAME updates were installed." ;;
        *)
            echo "Failed: uninstall the updates in Settings => Apps => See all apps => $APP => Uninstall updates."
            echo "If aa4mg is not active, $WHO is not a system app and has no updates to uninstall."
            FAILED=1 ;;
    esac
done
[ "$FAILED" = 0 ] || exit 1
echo "You can now disable or remove aa4mg and reboot."
