# Android Auto 4 MicroG (for A11, A12, A13, A14, A15, A16)

This is a [Magisk](https://topjohnwu.github.io/Magisk/) / KernelSU module (KernelSU-Next included) that provides an AA (Android Auto) stub as system app, optionally together with [XLauncher Unlocked](https://github.com/Rikj000/Android-Auto-XLauncher-Unlocked) and stubs for Google TTS, Google Maps & Google Search.
It is intended to be used on de-googled devices running MicroG!

If you instead prefer a non-root solution to be built into your own rom, please have a look at [Android Auto as user app with media apps support](https://github.com/sn-00-x/android-auto)

## Warning

**Before uninstalling `aa4mg`,**
Settings => Apps => See all apps => Android Auto => Triple dot icon *(top right corner)* => Uninstall updates

**Otherwise you may end up with an un-boot-able device.**
If the AA system app is missing *(by disabling `aa4mg` or booting without Magisk)*,
but the AA update installed is still present,
your device may fail to boot due to permission errors!

## Installation

1. Install de-googled ROM with microG (for example [LineageOS for MicroG](https://lineage.microg.org/))
2. Install [Magisk](https://topjohnwu.github.io/Magisk/install.html), or KernelSU / KernelSU-Next.
    *(On KernelSU-Next 3.x, and on KernelSU versions with metamodule support, module files are mounted by a metamodule such as Hybrid Mount, Meta Magic Mount or Mountify. Install one first and reboot, then install aa4mg. If you switch metamodule later, install aa4mg again.)*
3. Install the [aa4mg](https://github.com/sn-00-x/aa4mg/releases) module through the Magisk Manager App (or the KernelSU manager) => Reboot
    *(Select the desired dependency stubs with the volume keys during the installation process. The installer prompts explain what the stubs are: answer YES only for Google apps you do not have installed, see [Stubs](#stubs))*
4. Install [Android Auto](https://play.google.com/store/apps/details?id=com.google.android.projection.gearhead) through [Aurora Store](https://gitlab.com/AuroraOSS/AuroraStore),
    use `Root installer` (preferred) or `Aurora Services` as installation method to "install as Google Play Store".
    *(A user on LineageOS 23.2 reported that Android Auto only worked after reinstalling it with the Root installer instead of Aurora Services, upstream issue #48.)*
    *(If the car shows communication error 14, a user reported success after spoofing a Pixel device in Aurora Store (upstream issue #30). For `signatures do not match`, another user in the same issue also restored the app from a saved bundle.)*
    *(You can also install through your Package Manager if Aurora doesn't work, not preferred as it does not "install as Google Play Store")*
5. **(Optional)** Settings => Apps => See all apps => Android Auto => Mobile data & Wi-Fi => UnCheck all - ***WARNING:*** **THIS WILL MAKE IT IMPOSSIBLE TO CONNECT WIRELESSLY**. If you want to use Android Auto wirelessly you should keep these options enabled (already enabled by default) and skip this step. This step only provides further privacy.
6. Settings => Notifications => Device & app notifications => Android Auto => Check `Allow Notification Access` => Allow
   ([A15] Settings => Notifications => Notification read, reply & control)
7. [A15 and LineageOS based]  Settings => Security & privacy => Privacy controls => Permissions manager => Check Android Auto is allowed in every permisssion, especcialy Call logs and Phone.
   (sometimes you can refuse permission by mistake when popup came prompt, here you cane change that)
8. Settings => Connected Devices => Connection Preferences => Android Auto
    - About => Tap `Version` a lot => Accept PopUp to become a developer
    - Triple dot icon *(top right corner)* => Developer Settings
        - Application Mode => Developer
        - Scroll down => Check `Unknown Sources`
    - Close app

## Stubs

During installation aa4mg asks whether to install these stubs, which are fake placeholder apps for the Google apps Android Auto depends on:

- **Fake Google Maps** (`com.google.android.apps.maps`)
- **Fake Google Speech Services** (`com.google.android.tts`)
- **Fake Google Search** (`com.google.android.googlequicksearchbox`)

A stub replaces the real app of the same name, so the real app disappears or stops working (users reported this in upstream issues #15 and #19). Answer YES only for Google apps you do not have installed.

Do not install the Maps stub if you use the real Google Maps. To switch from the stub back to the real app, a user confirmed this sequence (upstream issue #19): uninstall the Android Auto updates, remove aa4mg and reboot, install Maps, then install aa4mg again and answer NO to the Maps stub. Another user reported that the Maps stub kept coming back after every reboot even after removing aa4mg and uninstalling the stub with an app manager (upstream issue #42); that report has no confirmed fix.

On ROMs de-bloated by hiding system apps (for example with a de-bloater module), a user reported that the stubs were not written to their original locations and installed the stub APKs as normal apps instead (upstream issue #28).

## Updates

Once the installation is complete:
- [Android Auto](https://play.google.com/store/apps/details?id=com.google.android.projection.gearhead) can be updated through [Aurora Store](https://gitlab.com/AuroraOSS/AuroraStore).
- [aa4mg](https://github.com/sn-00-x/aa4mg) can be updated through the Magisk or KernelSU manager

## Uninstall

1. Settings => Apps => See all apps => Android Auto => Triple dot icon *(top right corner)* => Uninstall updates
2. Magisk or KernelSU manager => Modules => Remove "Android Auto 4 microG" => Reboot

## First steps

When first using your device in your car,
follow the usual flow on your head unit and device until you reach a page asking for location permissions for maps.
Double check maps has permissions and click "cancel".

If nothing happens, unplug and re-plug your device.
When asked for, grant all permissions.

In case you encounter an error "Communication error 17",
manually open Settings and grant all available permissions to the Android Auto app.
Then unplug and re-plug your device.

## 3rd party apps

#### Android Auto won't show apps not installed through Google Play Store.
To mitigate this, first un-install the app, then you can use following ways to "install as Google Play Store".

- **Play Store APKs**: Use [Aurora Store](https://gitlab.com/AuroraOSS/AuroraStore) + `Root installer` or `Aurora Services` as the installation method, works for single + split APKs.
- **Non Play Store APKs**: Use [King Installer](https://github.com/Rikj000/KingInstaller), works for single APK.
- Or use **direct Android Shell install**, works for single APK:   
    ```bash
    pm install -i "com.android.vending" <apk>
    ```
- **Split APKs**: Use [AppManager](https://github.com/MuntashirAkon/AppManager), in the settings in `Installer => Installer App` choose microG Companion or manually enter `com.android.vending` before installing the APK.

#### Android Auto still won't show some apps.
Some apps have additional restrictions applied on them by AA,
which leads to them still not showing up, even if "installed as Google Play Store".

To unlock these apps we'll use the Xposed module, included by [Android Auto - XLauncher Unlocked](https://github.com/Rikj000/Android-Auto-XLauncher-Unlocked)

**Magisk**

1. Magisk => Settings => Magisk => Check `Zygisk`
2. Install [LSPosed (Zygisk) + Shamiko](https://lsposed.org/)
3. LSPosed => Modules => Android Auto - XLauncher Unlocked
    - Check `Enable module`
    - Check `Android Auto`
4. Reboot

**KernelSU / KernelSU-Next**

KernelSU has no built-in Zygisk, so you need a Zygisk provider ([NeoZygisk](https://github.com/JingMatrix/NeoZygisk), [ReZygisk](https://github.com/PerformanC/ReZygisk) or [ZygiskNext](https://github.com/LSPosed/ZygiskNext)) plus a maintained LSPosed fork: [JingMatrix's](https://github.com/JingMatrix/Vector), now named Vector.

1. Install a Zygisk provider and Vector, then reboot
2. In the LSPosed manager => Modules => Android Auto - XLauncher Unlocked
    - Check `Enable module`
    - Check `Android Auto`
3. Reboot

If XLauncher Unlocked does not open, turn off 'Umount modules' for XLauncher Unlocked and Android Auto in the KernelSU App Profile.

## Can not open Android Auto
If you can not directly open the AA app after installation,
then you can still access the AA settings through either of below ways:

- Settings => Connected Devices => Connection Preferences => Android Auto
- [Android Auto - XLauncher Unlocked](https://github.com/Rikj000/Android-Auto-XLauncher-Unlocked) => Click
    - Check `Set the next used launch option as default`
    - Click `Classic` or `Material3` *(Choose which you prefer)*

## Troubleshooting

- **A third-party Car App Library app such as Spotify reports "requires a newer version of Android Auto":** updating microG may help. The Android Auto flag that was missing was added to microG in mid-2026 (microG PR #3491). Users also reported that Android Auto and Spotify updates changed this behaviour (upstream issue #49).
- **Wireless Android Auto does not connect:** users reported that VPN apps, including DNS-blocking VPNs, can break the wireless connection (upstream issue #13). Some head units needed a restart after a failed connection (upstream issue #12).

## Recovery

If the device does not boot after installing or enabling aa4mg, boot with modules disabled and then remove aa4mg. Once the phone boots, uninstall the Android Auto updates before removing aa4mg. If updates were already installed, booting with modules disabled may also fail (see [Warning](#warning)).

- **Magisk safe mode:** Magisk disables all modules when Volume Down is held continuously for more than 3 seconds while it checks at early boot. This check happens earlier than the system's own Safe Mode detection, so the key must be held from before the boot animation starts. The Magisk FAQ (`docs/faq.md` in the Magisk repository) describes the timing.
- **KernelSU-Next safe mode:** KernelSU-Next disables all modules when it counts at least 3 Volume Down key presses during early boot. The exact timing is not documented, so you may need to try a few times.
- **Recovery shell:** with `/data` decrypted, create the file `/data/adb/modules/aa4mg/disable`, or delete the directory `/data/adb/modules/aa4mg`.

## Build

```bash
zip aa4mg.zip -9r * -x 'tests/*' 'docs/*'
```

Run `BUSYBOX=/path/to/static/busybox tests/install-test.sh` to simulate the installation on every supported API level.

## Credits

- **Nikhil Menghani** for [NikGapps](https://nikgapps.com/)
- **[@braga2](https://github.com/braga2)** for his [tutorial on xda](https://forum.xda-developers.com/t/microg-android-auto-fully-working.4319159/page-6)
- **[@SolidHal](https://github.com/SolidHal)** for the initial [dependency stub APKs](https://github.com/SolidHal/android-auto-stub)
- **[@Rikj000](https://github.com/Rikj000)** for [Android Auto - XLauncher Unlocked](https://github.com/Rikj000/Android-Auto-XLauncher-Unlocked)
