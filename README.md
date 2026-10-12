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
The steps below were tested on Android 16 (LineageOS 23.2) with microG 0.3.17, KernelSU-Next, ReZygisk and Vector.
The Magisk steps and the "Umount modules" advice are untested.

#### Media and messaging apps
Music, podcast and messaging apps only need `Unknown Sources` enabled in the Android Auto developer settings
(Installation, step 8). They do not need to come from the Play Store. If apps disappear, first check that
`Unknown Sources` is still enabled: a user reported that an Android Auto update turned the developer settings off
(XLauncher Unlocked issue #4).

#### Navigation, IoT and other templated apps
Android Auto asks the Play Store whether these apps were installed through it. microG does not answer that check, and
Android Auto then hides apps whose install record does not point to the Play Store
(`CAR.VALIDATOR: Package DENIED` in logcat). Two ways to make them appear (this concerns third-party apps; for
Android Auto itself follow Installation, step 4):

- **XLauncher Unlocked's Xposed module (recommended)**: aa4mg installs XLauncher Unlocked if you answer YES during
  installation, or get it from [its repository](https://github.com/Rikj000/Android-Auto-XLauncher-Unlocked). It works
  for apps installed from F-Droid, Aurora or other stores, with `Unknown Sources` still enabled. The module makes
  Android Auto see the Play Store as the app that started each installation. Enable it for **Android Auto only**: the
  module ignores every other app, so adding more apps to its scope only exposes them to Xposed. Then restart Android
  Auto (reboot, or Settings => Apps => Android Auto => Force stop).
- **Without Xposed**: install the app with [Aurora Store](https://gitlab.com/AuroraOSS/AuroraStore) using the `microG`
  installation method (microG 0.3.10 or later according to microG issue #3030; tested with 0.3.17), so that the Play
  Store is recorded both as installer and as the app that started the installation. This only works for apps listed
  on the Play Store. Uninstall a copy from another store first (it has a different signature), and update the app the
  same way: an update from another store records that store again.
  Root or shell installs (`pm install -i com.android.vending`, App Manager, Aurora's `Root installer`) can only set
  the installer, not the app that started the installation: Android 14 and later record the shell there, Android 11 to
  13 record no app. A user reported that the shell is not enough for navigation apps (microG issue #3030); Android 11
  to 13 is untested.

**Magisk**

1. Magisk => Settings => Magisk => Check `Zygisk`
2. Install [Vector](https://github.com/JingMatrix/Vector), the maintained LSPosed fork (the original
   [LSPosed](https://lsposed.org/) supports Android 8.1 to 14 only)
3. In the LSPosed manager => Modules => Android Auto - XLauncher Unlocked
    - Check `Enable module`
    - Check `Android Auto` (only)
4. Reboot

**KernelSU / KernelSU-Next**

KernelSU has no built-in Zygisk, so you need a Zygisk provider ([NeoZygisk](https://github.com/JingMatrix/NeoZygisk), [ReZygisk](https://github.com/PerformanC/ReZygisk) or [ZygiskNext](https://github.com/LSPosed/ZygiskNext)) plus a maintained LSPosed fork: [JingMatrix's](https://github.com/JingMatrix/Vector), now named Vector.

1. Install a Zygisk provider and Vector, then reboot
2. In the LSPosed manager => Modules => Android Auto - XLauncher Unlocked
    - Check `Enable module`
    - Check `Android Auto` (only)
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
