#!/bin/bash

[ "$API" -ge 36 ] 2>/dev/null || abort "! aa4mg requires Android 16 or later (API 36+)"

# Define "detect Volume key input" helper
chooseport() {
    [ -n "$1" ] && local DELAY=$1 || local DELAY=10
    [ "$2" = "YES" ] && local DEFAULT=$2 || local DEFAULT="NO"
    local START_TIMESTAMP=$(date +%s)
    local REMAINING_DELAY=$DELAY

    ui_print "Please answer within $DELAY seconds or $DEFAULT will be assumed."

    while [ "$REMAINING_DELAY" -gt 0 ]; do
        timeout ${REMAINING_DELAY}s /system/bin/getevent -lqc 1 2>&1 > $TMPDIR/events &
        wait $! 2>/dev/null # hide "Terminated" message
        if (`grep -q 'KEY_VOLUMEUP *DOWN' $TMPDIR/events`); then
            ui_print "Volume UP (+) = YES detected!"
            return 0 # 0 = True
        elif (`grep -q 'KEY_VOLUMEDOWN *DOWN' $TMPDIR/events`); then
            ui_print "Volume DOWN (-) = NO detected!"
            return 1 # 1 = False
        fi
        REMAINING_DELAY=$(($START_TIMESTAMP + $DELAY - $(date +%s)))
    done

    ui_print "Volume key could not be detected..."
    if [ "$DEFAULT" = "YES" ] ; then
        ui_print "Volume UP (+) = YES assumed!"
        return 0 # 0 = True
    else
        ui_print "Volume DOWN (-) = NO assumed!"
        return 1 # 1 = False
    fi
}

INSTALLED_APPS=""
SKIPPED_APPS=""

# Initialize installation
ui_print ""
ui_print "Installing AA dependency stubs for MicroG"
ui_print "+ XLauncher Unlocked..."
ui_print ""
ui_print "*** Please answer using volume keys ***"
ui_print "*** Volume UP (+)   = YES           ***"
ui_print "*** Volume DOWN (-) = NO            ***"
ui_print ""
ui_print "Stubs are fake placeholder apps. Answer YES only for"
ui_print "Google apps you do NOT have installed: a stub replaces"
ui_print "the real app. To change your choice later, install"
ui_print "aa4mg again and reboot."

# Request if Fake Google Maps stub dependency should be installed
ui_print ""
ui_print "*** Install Fake Google Maps stub? ***"
ui_print "(a.k.a. com.google.android.apps.maps)"
ui_print ""
if chooseport 30 "NO"; then # 0 = True, why shell why..
    ui_print "Fake Google Maps stub will be installed on next reboot!"
    INSTALLED_APPS="Google Maps stub"
else
    rm -r "$MODPATH/system/product/app/Maps";
    ui_print "Excluded Fake Google Maps stub from installation..."
    [ -n "$SKIPPED_APPS" ] && SKIPPED_APPS="$SKIPPED_APPS,"
    SKIPPED_APPS="${SKIPPED_APPS}Google Maps stub"
fi

# Request if Fake Google Speech Services stub dependency should be installed
ui_print ""
ui_print "*** Install Fake Google Speech Services stub? ***"
ui_print "(a.k.a. com.google.android.tts)"
ui_print ""
if chooseport 30 "NO"; then # 0 = True, why shell why..
    ui_print "Fake Google Speech Services stub will be installed on next reboot!"
    [ -n "$INSTALLED_APPS" ] && INSTALLED_APPS="$INSTALLED_APPS,"
    INSTALLED_APPS="${INSTALLED_APPS}Google Speech Services stub"
else
    rm -r "$MODPATH/system/product/app/GoogleTTS";
    ui_print "Excluded Fake Google Speech Services stub from installation..."
    [ -n "$SKIPPED_APPS" ] && SKIPPED_APPS="$SKIPPED_APPS,"
    SKIPPED_APPS="${SKIPPED_APPS}Google Speech Services stub"
fi

# Request if Fake Google Search stub dependency should be installed
ui_print ""
ui_print "*** Install Fake Google Search stub? ***"
ui_print "(a.k.a. com.google.android.googlequicksearchbox)"
ui_print ""
if chooseport 30 "NO"; then # 0 = True, why shell why..
    ui_print "Fake Google Search stub will be installed on next reboot!"
    [ -n "$INSTALLED_APPS" ] && INSTALLED_APPS="$INSTALLED_APPS,"
    INSTALLED_APPS="${INSTALLED_APPS}Google Search stub"
else
    rm -r "$MODPATH/system/product/priv-app/Velvet";
    ui_print "Excluded Fake Google Search stub from installation..."
    [ -n "$SKIPPED_APPS" ] && SKIPPED_APPS="$SKIPPED_APPS,"
    SKIPPED_APPS="${SKIPPED_APPS}Google Search stub"
fi

# Ask for Android Auto - XLauncher Unlocked
ui_print ""
ui_print "*** Install Android Auto - XLauncher Unlocked? ***"
ui_print "*** Recommended for enabling 3rd party apps    ***"
ui_print ""
AAXLU="true"
if chooseport 30 "YES"; then
    ui_print "Android Auto - XLauncher Unlocked will be installed on next reboot!"
    [ -n "$INSTALLED_APPS" ] && INSTALLED_APPS="$INSTALLED_APPS,"
    INSTALLED_APPS="${INSTALLED_APPS}Android Auto - XLauncher Unlocked"
else
    rm -r "$MODPATH/system/product/app/XLauncherUnlocked";
    ui_print "Excluded Android Auto - XLauncher Unlocked from installation..."
    [ -n "$SKIPPED_APPS" ] && SKIPPED_APPS="$SKIPPED_APPS,"
    SKIPPED_APPS="${SKIPPED_APPS}Android Auto - XLauncher Unlocked"
    AAXLU="false"
fi

# KernelSU-Next 3.x and recent KernelSU mount module files only through a metamodule: the
# /data/adb/metamodule symlink to an existing module, or any module with metamodule=1|true in
# its module.prop (KernelSU-Next userspace/ksud/src/metamodule.rs).
NO_METAMODULE="false"
MM_DIR=/data/adb/metamodule
if [ "$KSU" = "true" ] && ! { [ -L /data/adb/metamodule ] && [ -d /data/adb/metamodule ]; } ; then
    NO_METAMODULE="true"
    for MM_PROP in /data/adb/modules/*/module.prop ; do
        [ -f "$MM_PROP" ] || continue
        MM_VALUE=$(sed -n 's/^[[:space:]]*metamodule[[:space:]]*=//p' "$MM_PROP" | tr -d ' \t\r' | tr 'A-Z' 'a-z')
        case "$MM_VALUE" in
            1|true) NO_METAMODULE="false"; MM_DIR=${MM_PROP%/module.prop} ;;
        esac
    done
fi
# ksud skips the mount script of a disabled metamodule, and deletes one marked for removal at the next boot
MM_INACTIVE="false"
if [ "$KSU" = "true" ] && [ "$NO_METAMODULE" = "false" ] && { [ -e "$MM_DIR/disable" ] || [ -e "$MM_DIR/remove" ]; } ; then
    MM_INACTIVE="true"
fi

# Finish installation, dependency APKs will automatically be installed on reboot
ui_print ""
ui_print "Installation of"
ui_print "    Android Auto 4 MicroG"
# The installer and the metamodule's metainstall.sh keep running in this shell, so IFS must be restored
OLD_IFS=$IFS
IFS=','
for INSTALLED_APP in $INSTALLED_APPS ; do
    ui_print "    $INSTALLED_APP"
done
if [ -n "$SKIPPED_APPS" ] ; then
    ui_print "Skipped:"
    for SKIPPED_APP in $SKIPPED_APPS ; do
        ui_print "    $SKIPPED_APP"
    done
fi
IFS=$OLD_IFS
ui_print "successfull! 🎉"
if [ "$NO_METAMODULE" = "true" ] ; then
    ui_print ""
    ui_print "*** WARNING: no KernelSU metamodule found!           ***"
    ui_print "*** KernelSU-Next 3.x and recent KernelSU only mount ***"
    ui_print "*** module files through a metamodule (for example   ***"
    ui_print "*** Hybrid Mount or Meta Magic Mount). Without one,  ***"
    ui_print "*** aa4mg is installed but Android Auto will not     ***"
    ui_print "*** work. Install a metamodule, reboot, then install ***"
    ui_print "*** aa4mg again. Older KernelSU releases that mount  ***"
    ui_print "*** modules themselves can ignore this warning.      ***"
fi
if [ "$MM_INACTIVE" = "true" ] ; then
    ui_print ""
    ui_print "*** WARNING: the KernelSU metamodule is disabled or  ***"
    ui_print "*** marked for removal. KernelSU-Next does not mount ***"
    ui_print "*** module files without an active metamodule, so    ***"
    ui_print "*** Android Auto will not work. Enable or restore    ***"
    ui_print "*** the metamodule and reboot, or install another    ***"
    ui_print "*** one, reboot, then install aa4mg again.           ***"
fi
ui_print ""
ui_print "*** Please re-boot your device,                      ***"
ui_print "*** and then update Android Auto (e.g. with Aurora)! ***"
ui_print ""
if [ $AAXLU = "true" ] ; then
    ui_print "*** Please also have a look at the README            ***"
    ui_print "*** for instructions on how to activate              ***"
    ui_print "*** XLauncher Unlocked's XPosed module               ***"
fi
ui_print ""
ui_print ""
ui_print ""


