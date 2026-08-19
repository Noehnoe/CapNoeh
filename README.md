# CapNoeh — CapCut on Linux under Wine

**A complete, working setup for running CapCut on Linux — plus the analysis of why the current version can't work.**

The short version: **the current CapCut (9.x) cannot work under Wine, and no amount of configuration fixes it. CapCut 3.9.0.1459 works fine.** The deciding factor is the app version, not your Wine settings.

CapNoeh is a set of configuration notes and fixes, not a fork or a repackage of CapCut — you install ByteDance's own signed installer and apply what's below.

Written up because the failure mode of 9.x is misleading — it looks like a broken-input problem, and you can burn a lot of time chasing that.

Tested on Fedora 44 (Nobara), KDE Plasma / Wayland, NVIDIA RTX 5060 Ti (proprietary driver), wine-staging 11.13.

---

## TL;DR

| | CapCut 9.2.0.3931 | CapCut 3.9.0.1459 |
|---|---|---|
| WineHQ rating | lowest tier | **Silver** |
| Result | UI paints, then nothing responds — unusable | Works |
| Install via Bottles / GE-Proton | n/a | **segfaults** (see below) |
| Install via plain wine-staging | n/a | Works |

---

## Why CapCut 9.x cannot be fixed

The symptom is that the UI renders perfectly but ignores every click, hover, and keypress. This looks exactly like a Wine input-routing problem, and it isn't.

**The main process is dead.** Check for yourself while the window is on screen:

```bash
ps -e -o pid,stat,etime,comm | grep -E 'CrBrowserMain|CrGpuMain|CrRendererMain'
```

You get:

```
 98798 Zsl   CrBrowserMain <defunct>      <-- main process, a zombie
 98849 Ssl   CrGpuMain
 99100 Ssl   CrRendererMain
 99103 Ssl   CrRendererMain
```

CapCut's main CEF process exits seconds after painting its first frame, leaving a zombie plus orphaned GPU/renderer children. The window you're clicking on is a corpse — Wine hasn't torn it down because the zombie was never reaped.

**The diagnostic tell:** the "environment testing" popup (`VEDetector.exe`) *does* respond to hover, because it is a separate, still-living process. The main window doesn't. Same screen, same Wine, same compositor, opposite behaviour. Nothing about pointer routing explains that; a dead process explains it exactly.

**The fatal error**, visible in stderr:

```
err:virtual:virtual_setup_exception stack overflow 1920 bytes addr 0x6ffffff37397
    stack 0x10880 (0x10000-0x11000-0x110000)
```

A 1 MB thread stack fully consumed by runaway recursion inside Wine's own builtin code. It reproduces at an identical point on every run.

### Things that do NOT fix it

Don't repeat these:

- `QT_QPA_PLATFORM=windows:nowmpointer` — CapCut ships Qt 6.2.2, whose modern input handler calls the WinRT APIs `Windows.Devices.Input.PenDevice` and `Windows.UI.Input.PointerPoint`, which Wine doesn't implement. Those failures appear in the log immediately before the crash, so this looks like the answer. It isn't — forcing the legacy input path changes nothing. The WinRT calls come from CEF, not Qt.
- Switching runner (tested GE-Proton 11-5 and 10-34, including a proper `wineboot -u` after downgrading)
- `virtual_desktop` on/off, `Managed=N`, `DISABLE_LAYERED_WINDOWS`, `mouse_warp`
- `QT_QUICK_BACKEND=software`, renderer gl/vulkan
- Window repositioning / DPI / focus — all verified fine

The environment detector is *not* rejecting your hardware, incidentally: it correctly identifies the GPU and reports Windows 10.

### Bonus: skipping the Terms of Service dialog

Unrelated to the crash, 9.x shows an unclickable ToS dialog. The dialog is `qrc:/VEUpdate/view/PrivacyPolicyCheckUI.qml`, and the flag it reads is `user_license_agreed`, stored not in the registry but in QSettings INI files:

```
.../CapCut/User Data/Config/{globalSetting,commonSetting.ini,compliance_config}
```

```ini
[General]
user_license_agreed=true
privacy_policy_update_time=9999999999
```

**Note the profile name.** GE-Proton renames the Wine user to `steamuser`, so the config lives under `drive_c/users/steamuser/...` while the app is installed under your own username. The user directory looking empty is the giveaway.

This gets you past the dialog to the home screen. It does not fix the crash.

---

## The working setup: CapCut 3.9.0.1459

3.x predates the CEF/Qt6/WinRT stack that fails above.

### 1. Get the installer

WineHQ AppDB lists this version (rated Silver, tested on 10.13-staging) and links to a mirror. It is not distributed here — get it yourself and verify it.

Expected for `3.9.0.1459`:

```
size    550534120 bytes (525.03 MB)
sha256  7f8c29b84334b76d4a0af8674b63c7a3c64cc3a03519ae0e552d5baaa115755d
```

### 2. Verify before running it

You are downloading an old build from a mirror, so check it. The file is Authenticode-signed by ByteDance; verify that, not just the hash:

```bash
sha256sum CapCut_3.9.0.1459.exe

pip install --user signify
python3 - <<'PY'
from signify.authenticode.signed_file import SignedPEFile
with open("CapCut_3.9.0.1459.exe","rb") as f:
    pe = SignedPEFile(f)
    print(pe.explain_verify())
    for sig in pe.signatures:
        for c in sig.certificates:
            if "ytedance" in c.subject.dn:
                print(c.subject.dn)
PY
```

Expected: `AuthenticodeVerificationResult.OK`, signer `CN=Bytedance Pte. Ltd., O=Bytedance Pte. Ltd., L=Singapore, C=SG` (an EV certificate), chaining to DigiCert Trusted Root G4. The signing certificate expired in 2025, which is fine — the signature was countersigned with a timestamp while valid, so it still verifies.

### 3. Do NOT install via Bottles / Proton

The installer is a 32-bit PE32 binary. Under GE-Proton it dies instantly:

```
INSTALLER_EXIT=139     # 128 + 11 = SIGSEGV
```

Proton's new WoW64 layer breaks it. Use a plain wine-staging build. This cost me a while — the segfault is silent, with no window and no error output.

### 4. Install

The installer hangs unless these directories exist first:

```bash
export WINEPREFIX="$HOME/.local/share/wineprefixes/capcut39"
wine wineboot -i

C="$WINEPREFIX/drive_c/users/$USER/AppData/Local/CapCut"
mkdir -p "$C" "$C/User Data/Config" "$C/User Data/Log"
```

### 5. Block auto-update BEFORE first launch

**This is the important step.** Left alone, 3.9 will update itself straight into the broken 9.x and you lose everything above. Seed the config before you ever start it:

```bash
printf '[General]\r\nenableAutoUpdate=false\r\ntotalSilentUpgradeSwitch=false\r\nlocalTestSilentUpdateSwtich=false\r\ndebugSilentUpgradeSwitch=false\r\nuser_license_agreed=true\r\nprivacy_policy_update_time=9999999999\r\n' \
  > "$C/User Data/Config/globalSetting"
```

CapCut appends its own defaults below these on first run and leaves them intact. Re-check the file after any reinstall.

Then install and launch:

```bash
wine CapCut_3.9.0.1459.exe
wine "C:\\users\\$USER\\AppData\\Local\\CapCut\\Apps\\CapCut.exe"
```

Confirm it's actually alive — `CrBrowserMain` should show `S` or `R`, never `Z`:

```bash
ps -e -o pid,stat,etime,comm | grep CrBrowserMain
```

### 6. Launcher (optional)

[`launcher/`](launcher/) has a `capnoeh` wrapper script and a desktop entry, so CapCut shows up in your application menu like a normal app. The wrapper also warns you if auto-update ever gets re-enabled, since that would quietly replace your working install with the broken 9.x build.

---

## Making the file dialog usable

Wine's built-in file picker is painful to navigate and doesn't show Downloads.

**Native KDE/GTK dialogs are not possible.** Wine would need XDG desktop portal support in `comdlg32`; that's an unmerged draft (MR10060). Current Wine master has zero portal references in `filedlg.c`, `itemdlg.c`, or `cdlg32.c`. No released build has it, so switching builds won't help.

What does work is Wine's registry-customizable places bar (`filedlg.c: filedlg_collect_places_pidls`), which accepts either a path string or a CSIDL number:

```bash
K='HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\Comdlg32\Placesbar'
wine reg add "$K" /v Place0 /t REG_SZ /d "C:\\users\\$USER\\Downloads" /f
wine reg add "$K" /v Place1 /t REG_SZ /d "C:\\users\\$USER\\Videos"    /f
wine reg add "$K" /v Place2 /t REG_SZ /d "C:\\users\\$USER\\Pictures"  /f
wine reg add "$K" /v Place3 /t REG_SZ /d "C:\\users\\$USER"            /f
wine reg add "$K" /v Place4 /t REG_DWORD /d 17 /f    # 17 = CSIDL_DRIVES
```

Also worth mapping drive letters, which show up under My Computer:

```bash
cd "$WINEPREFIX/dosdevices"
ln -sfn "$HOME/Downloads" d:
ln -sfn "$HOME/Videos"    v:
ln -sfn "$HOME/Pictures"  p:
ln -sfn "$HOME"           h:
for d in d v p h; do wine reg add 'HKLM\Software\Wine\Drives' /v "$d:" /d hd /f; done
```

Drive letters are only enumerated when the wineserver starts, so fully quit the app first. You can tell the difference: `dir d:\` will work immediately, but the drive won't appear in `wmic logicaldisk get caption` until a restart.

---

## Known issues with 3.9

- The video-preview overlay and some child windows can render **black instead of transparent**. Workarounds: drag the overlay aside, or set its opacity to ~50% in KWin.
- Old build, so unpatched. It handles media files; judge that risk yourself.

## Alternatives

If you don't specifically need CapCut, DaVinci Resolve and Kdenlive both run natively on Linux and are less trouble. CapCut also has a browser version that needs no Wine at all.

---

## Licence / redistribution

CapCut is proprietary software by ByteDance, and CapNoeh is not affiliated with or endorsed by ByteDance. Nothing here redistributes CapCut — these are configuration notes only. Get the installer from a source you trust and verify the signature as shown above.

The notes themselves are free to use, adapt, and share.

## Contributing

If you get this working on another distro, desktop, or GPU — or find a Wine version where 9.x behaves differently — please share it.

**Bug reports and technical findings:** open an issue. Include your Wine version and the output of:

```bash
ps -e -o pid,stat,comm | grep CrBrowserMain
```

The zombie-vs-live distinction (`Z` vs `S`/`R`) is the fastest way to tell whether a given build has any chance at all.

**Or just email me: noehnoeis5@gmail.com**

Whether it's a fix, something that didn't work for you, a question, or you just want to say it helped — I read them, I'll take a careful look, and I'll reply. If your findings improve things, I'll update the launcher and these notes so everyone gets the benefit.

Issues are better for anything with logs attached, since other people hitting the same problem can find them. But email is genuinely welcome.
