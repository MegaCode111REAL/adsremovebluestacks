# BlueStacks Ad Blocker — Windows Edition

This PowerShell script removes ads from **BlueStacks 5 / BlueStacks Air** on Windows by patching and locking the config file so all ad-related settings are permanently disabled.

Tested on **BlueStacks 5.21.755.7538 (Windows)**.

---

## Requirements

- Windows 10 / Windows 11
- BlueStacks 5 installed and launched at least once
- Administrator privileges (for applying/restoring patches)
- PowerShell 5.0 or later

---

## Usage

### Apply the patch

```powershell
powershell -ExecutionPolicy Bypass -File bluestacks-noad.ps1
```

Or with explicit action:

```powershell
powershell -ExecutionPolicy Bypass -File bluestacks-noad.ps1 -Action Apply
```

BlueStacks does **not** need to be closed first — but relaunch it after patching for the changes to take effect.

### Check status

No Administrator privileges needed:

```powershell
powershell -ExecutionPolicy Bypass -File bluestacks-noad.ps1 -Action Status
```

### Restore original config

```powershell
powershell -ExecutionPolicy Bypass -File bluestacks-noad.ps1 -Action Restore
```

---

## How it works

The script edits `%ProgramData%\BlueStacks_nxt\bluestacks.conf` and sets every ad-related key to `"0"`:

| Key | What it controls |
|---|---|
| `bst.enable_programmatic_ads` | Master switch for programmatic ads |
| `bst.enable_android_ads_test_app` | Android in-app ad test app |
| `bst.feature.programmatic_ads` | Programmatic ads feature flag |
| `bst.feature.show_gp_ads` | Google Play ads |
| `bst.feature.ipi` | Install-per-install ad campaigns |
| `bst.feature.nowbux` | NowBux reward/ad system |
| `bst.feature.nowgg_login_popup` | NowGG login/ad popup |
| `bst.feature.send_programmatic_ads_*_stats` | Ad analytics reporting |
| `bst.feature.show_programmatic_ads_preference` | Ads preference UI |
| `bst.feature.send_offer_stats` | Offer/ad stats |
| `bst.programmatic_android_ads_count` | Ad impression counter |
| `bst.instance.<name>.split_ad_enabled` | Per-instance side ad panel |
| `bst.instance.<name>.ads_screen_width` | Ad panel width (set to 0) |
| `bst.instance.<name>.ads_screen_width_percentage` | Ad panel width % (set to 0) |
| `bst.instance.<name>.split_ad_show_times` | Ad show counter (set to -1) |

The file is then **locked** by setting it to read-only so BlueStacks cannot overwrite it at runtime.

---

## Changing BlueStacks settings after patching

Because `bluestacks.conf` is locked, the BlueStacks settings UI may not save some preferences. Temporarily unlock it before opening Settings, then lock it again:

```powershell
Set-ItemProperty -Path "$env:ProgramData\BlueStacks\bluestacks.conf" -Name Attributes -Value "Normal" -Force
# … change your settings in BlueStacks …
Set-ItemProperty -Path "$env:ProgramData\BlueStacks\bluestacks.conf" -Name Attributes -Value "ReadOnly" -Force
```

---

## Backup

The original config is backed up before any modification:

| Backup location | Original file |
|---|---|
| `%USERPROFILE%\.bluestacks-noad-backup\bluestacks.conf.orig` | The unmodified config |

The backup is created only once — subsequent runs will not overwrite a clean backup with an already-patched copy.
