# CapNoeh launcher

`capnoeh` starts CapCut in its own Wine prefix and warns you if auto-update
has been re-enabled (which would replace the working 3.9 build with the
broken 9.x one).

## Install

```bash
install -m755 capnoeh ~/.local/bin/capnoeh
install -m644 capnoeh.desktop ~/.local/share/applications/capnoeh.desktop
update-desktop-database ~/.local/share/applications
```

Make sure `~/.local/bin` is on your `PATH`.

For the menu icon, copy a square PNG from the install to
`~/.local/share/icons/hicolor/256x256/apps/capcut.png`:

```bash
cp "$WINEPREFIX/drive_c/users/$USER/AppData/Local/CapCut/Apps/3.9.0.1459/Resources/logo_cc.png" \
   ~/.local/share/icons/hicolor/256x256/apps/capcut.png
gtk-update-icon-cache -f -t ~/.local/share/icons/hicolor
```

## Prefix location

Defaults to `~/.local/share/wineprefixes/capcut39`. Override with:

```bash
CAPNOEH_PREFIX=/path/to/prefix capnoeh
```
