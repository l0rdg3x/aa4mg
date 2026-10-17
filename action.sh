#!/system/bin/sh
# Action button in the KernelSU-Next manager. The Android Auto updates must be uninstalled before aa4mg is disabled
# or removed (README, Warning); uninstall.sh runs at the next boot, before the package manager starts, so it cannot.
PKG=com.google.android.projection.gearhead
DELAY=10

echo "Uninstall the Android Auto updates?"
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
            echo "Uninstall the updates in Settings => Apps => See all apps => Android Auto => Uninstall updates."
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

echo "Uninstalling the Android Auto updates..."
# This pm command exits with 1 on success and 0 on failure, and throws when Android Auto is not a system app
# (AOSP PackageManagerShellCommand), so read its output
OUT=$(/system/bin/pm uninstall-system-updates "$PKG" 2>&1)
echo "$OUT"
case "$OUT" in
    *"Uninstalling updates to $PKG"*Success)
        echo "Android Auto updates removed. You can now disable or remove aa4mg and reboot." ;;
    *Success)
        echo "No Android Auto updates were installed. You can disable or remove aa4mg and reboot." ;;
    *)
        echo "Failed: uninstall the updates in Settings => Apps => See all apps => Android Auto => Uninstall updates."
        echo "If aa4mg is not active, Android Auto is not a system app and has no updates to uninstall."
        exit 1 ;;
esac
