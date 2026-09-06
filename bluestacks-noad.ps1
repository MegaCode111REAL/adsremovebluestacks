# =============================================================================
#  bluestacks-noad.ps1 -- BlueStacks 5 / Air Ad Remover for Windows
#  Tested on BlueStacks 5.21.755.7538
#
#  What this script does:
#   Edits bluestacks.conf -- every ad-related config key is set to "0".
#   The file is then set to read-only so BlueStacks cannot overwrite it.
#
#  Undo / restore:
#   Run:  powershell -ExecutionPolicy Bypass -File bluestacks-noad.ps1 -Restore
#
#  Requirements: Windows, Administrator privileges
# =============================================================================

param(
    [ValidateSet("Apply", "Restore", "Status", "Help")]
    [string]$Action = "Apply"
)

$ErrorActionPreference = "Stop"

# ── Paths ─────────────────────────────────────────────────────────────────
$CONF = "$env:ProgramData\BlueStacks_nxt\bluestacks.conf"
$BACKUP_DIR = "$env:USERPROFILE\.bluestacks-noad-backup"
$CONF_BACKUP = "$BACKUP_DIR\bluestacks.conf.orig"

# ── Ad-related top-level keys to zero out ─────────────────────────────────
$CONF_PATCHES = @(
    "bst.enable_programmatic_ads",
    "bst.enable_android_ads_test_app",
    "bst.feature.programmatic_ads",
    "bst.feature.send_programmatic_ads_boot_stats",
    "bst.feature.send_programmatic_ads_click_stats",
    "bst.feature.send_programmatic_ads_fill_stats",
    "bst.feature.show_gp_ads",
    "bst.feature.show_programmatic_ads_preference",
    "bst.feature.send_offer_stats",
    "bst.feature.ipi",
    "bst.feature.nowbux",
    "bst.feature.nowgg_login_popup",
    "bst.programmatic_android_ads_count"
)

# ── Per-instance ad keys to zero out ──────────────────────────────────────
# Format: key:value  -- value defaults to "0" if omitted
$CONF_INSTANCE_PATCHES = @(
    "split_ad_enabled:0",
    "ads_screen_width:0",
    "ads_screen_width_percentage:0",
    "split_ad_show_times:-1"
)

# ── Colour codes (for PowerShell console) ─────────────────────────────────
$Colors = @{
    Reset   = "`e[0m"
    Blue    = "`e[0;34m"
    Green   = "`e[0;32m"
    Yellow  = "`e[1;33m"
    Red     = "`e[0;31m"
    Cyan    = "`e[0;36m"
}

function Write-Info {
    Write-Host "$($Colors.Blue)[*]$($Colors.Reset) $args"
}

function Write-Ok {
    Write-Host "$($Colors.Green)[+]$($Colors.Reset) $args"
}

function Write-Warn {
    Write-Host "$($Colors.Yellow)[!]$($Colors.Reset) $args" -ForegroundColor Yellow
}

function Write-Err {
    Write-Host "$($Colors.Red)[X]$($Colors.Reset) $args" -ForegroundColor Red
}

function Write-Section {
    Write-Host ""
    Write-Host "$($Colors.Cyan)-- $args --$($Colors.Reset)"
}

# =============================================================================
#  Helpers
# =============================================================================

function Assert-Administrator {
    $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object System.Security.Principal.WindowsPrincipal($identity)
    
    if (-not $principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Err "This script must be run as Administrator."
        Write-Host "Please restart PowerShell as Administrator and try again."
        exit 1
    }
}

function Ensure-BackupDir {
    if (-not (Test-Path $BACKUP_DIR)) {
        New-Item -ItemType Directory -Path $BACKUP_DIR -Force | Out-Null
    }
}

# =============================================================================
#  CONFIG FILE PATCHING
# =============================================================================

function Patch-Config {
    Write-Section "Config file patching"

    if (-not (Test-Path $CONF)) {
        Write-Warn "bluestacks.conf not found at:"
        Write-Warn "  $CONF"
        Write-Warn "Has BlueStacks been launched at least once? Skipping."
        return
    }

    # Remove read-only flag in case it was previously set
    Set-ItemProperty -Path $CONF -Name Attributes -Value "Normal" -Force -ErrorAction SilentlyContinue

    # Backup (only once - never overwrite a clean backup)
    if (-not (Test-Path $CONF_BACKUP)) {
        Write-Info "Backing up config to $CONF_BACKUP ..."
        Copy-Item -Path $CONF -Destination $CONF_BACKUP -Force
        Write-Ok "Config backup saved."
    }
    else {
        Write-Info "Config backup already exists - skipping backup step."
    }

    # Read the config file
    $configContent = Get-Content -Path $CONF -Raw

    # Zero out top-level ad keys
    foreach ($key in $CONF_PATCHES) {
        if ($configContent -match "^${key}=") {
            $configContent = $configContent -replace "^${key}=.*$", "${key}=`"0`"", "Multiline"
            Write-Info "  set  ${key}=`"0`""
        }
        else {
            $configContent += "`n${key}=`"0`""
            Write-Info "  added  ${key}=`"0`""
        }
    }

    # Zero out per-instance ad keys for every discovered instance
    $instances = @()
    $configContent -split "`n" | ForEach-Object {
        if ($_ -match '^bst\.instance\.([^.]+)\.') {
            $instance = $matches[1]
            if ($instance -notin $instances) {
                $instances += $instance
            }
        }
    }

    foreach ($instance in $instances) {
        foreach ($entry in $CONF_INSTANCE_PATCHES) {
            $key, $val = $entry -split ':'
            if (-not $val) { $val = "0" }
            
            $fullKey = "bst.instance.${instance}.${key}"
            
            if ($configContent -match "^${fullKey}=") {
                $configContent = $configContent -replace "^${fullKey}=.*$", "${fullKey}=`"${val}`"", "Multiline"
                Write-Info "  set  ${fullKey}=`"${val}`""
            }
        }
    }

    # Write the modified config back
    Set-Content -Path $CONF -Value $configContent -NoNewline -Force

    # Set read-only flag so BlueStacks cannot overwrite our changes
    Set-ItemProperty -Path $CONF -Name Attributes -Value "ReadOnly" -Force
    Write-Ok "Config patched and locked (read-only)."
    Write-Warn "To change BlueStacks settings later, temporarily unlock first:"
    Write-Warn "  Set-ItemProperty -Path `"$CONF`" -Name Attributes -Value `"Normal`""
}

function Restore-Config {
    Write-Section "Restoring config"

    if (-not (Test-Path $CONF_BACKUP)) {
        Write-Err "No config backup found at $CONF_BACKUP"
        exit 1
    }

    Set-ItemProperty -Path $CONF -Name Attributes -Value "Normal" -Force -ErrorAction SilentlyContinue
    Write-Info "Restoring $CONF from backup..."
    Copy-Item -Path $CONF_BACKUP -Destination $CONF -Force
    Write-Ok "Config restored."
}

# =============================================================================
#  APPLY / RESTORE / STATUS
# =============================================================================

function Print-Banner {
    Write-Host ""
    Write-Host "$($Colors.Cyan)  +======================================+"
    Write-Host "  |  BlueStacks Ad Blocker - noad.ps1   |"
    Write-Host "  |    config lock (Layer 2 only)      |"
    Write-Host "  +======================================+$($Colors.Reset)"
    Write-Host ""
}

function Do-Apply {
    Print-Banner
    Assert-Administrator
    Ensure-BackupDir
    Patch-Config

    Write-Section "Done"
    Write-Ok "Config patch applied."
    Write-Host ""
    Write-Host "  $($Colors.Green)Launch BlueStacks - ads will not be shown.$($Colors.Reset)"
    Write-Host ""
    Write-Host "  To revert:  $($Colors.Yellow)powershell -ExecutionPolicy Bypass -File bluestacks-noad.ps1 -Restore$($Colors.Reset)"
    Write-Host ""
}

function Do-Restore {
    Print-Banner
    Assert-Administrator
    Restore-Config

    Write-Section "Done"
    Write-Ok "Config restored. BlueStacks is back to its original state."
}

function Do-Status {
    Write-Host "$($Colors.Cyan)-- bluestacks-noad status --$($Colors.Reset)"
    Write-Host ""

    if (Test-Path $CONF) {
        $fileAttributes = (Get-ItemProperty -Path $CONF).Attributes
        
        if ($fileAttributes -match "ReadOnly") {
            Write-Host "  $($Colors.Green)[+]$($Colors.Reset) bluestacks.conf is locked (read-only)"
        }
        else {
            Write-Host "  $($Colors.Yellow)[!]$($Colors.Reset) bluestacks.conf is NOT locked"
        }

        $configContent = Get-Content -Path $CONF -Raw

        foreach ($key in $CONF_PATCHES) {
            if ($configContent -match "^${key}=`"([^`"]*)`"") {
                $val = $matches[1]
            }
            elseif ($configContent -match "^${key}=(.*)$") {
                $val = $matches[1]
            }
            else {
                $val = $null
            }

            if ($val -eq "0") {
                Write-Host "  $($Colors.Green)[+]$($Colors.Reset) ${key} = 0"
            }
            elseif ($null -eq $val) {
                Write-Host "  $($Colors.Yellow)[-]$($Colors.Reset) ${key} not found in config"
            }
            else {
                Write-Host "  $($Colors.Red)[X]$($Colors.Reset) ${key} = ${val}  - ads may be active"
            }
        }

        # Per-instance check
        $instances = @()
        $configContent -split "`n" | ForEach-Object {
            if ($_ -match '^bst\.instance\.([^.]+)\.') {
                $instance = $matches[1]
                if ($instance -notin $instances) {
                    $instances += $instance
                }
            }
        }

        foreach ($instance in $instances) {
            foreach ($entry in $CONF_INSTANCE_PATCHES) {
                $key, $expectedVal = $entry -split ':'
                if (-not $expectedVal) { $expectedVal = "0" }
                
                $fullKey = "bst.instance.${instance}.${key}"
                
                if ($configContent -match "^${fullKey}=`"([^`"]*)`"") {
                    $val = $matches[1]
                }
                elseif ($configContent -match "^${fullKey}=(.*)$") {
                    $val = $matches[1]
                }
                else {
                    $val = $null
                }

                if ($val -eq $expectedVal) {
                    Write-Host "  $($Colors.Green)[+]$($Colors.Reset) ${fullKey} = ${val}"
                }
                elseif ($null -eq $val) {
                    Write-Host "  $($Colors.Yellow)[-]$($Colors.Reset) ${fullKey} not found"
                }
                else {
                    Write-Host "  $($Colors.Red)[X]$($Colors.Reset) ${fullKey} = ${val}  - ads may be active"
                }
            }
        }

        if (Test-Path $CONF_BACKUP) {
            Write-Host "  $($Colors.Green)[+]$($Colors.Reset) Backup exists at $CONF_BACKUP"
        }
        else {
            Write-Host "  $($Colors.Yellow)[-]$($Colors.Reset) No backup found (patch not yet applied)"
        }
    }
    else {
        Write-Host "  $($Colors.Yellow)[-]$($Colors.Reset) bluestacks.conf not found"
    }
}

function Show-Help {
    Write-Host "Usage:"
    Write-Host "  powershell -ExecutionPolicy Bypass -File bluestacks-noad.ps1 [-Action Apply]"
    Write-Host "  powershell -ExecutionPolicy Bypass -File bluestacks-noad.ps1 -Action Restore"
    Write-Host "  powershell -ExecutionPolicy Bypass -File bluestacks-noad.ps1 -Action Status"
    Write-Host ""
    Write-Host "Parameters:"
    Write-Host "  -Action Apply      # Apply config patch (default)"
    Write-Host "  -Action Restore    # Revert to original config"
    Write-Host "  -Action Status     # Show patch status (no admin needed)"
    Write-Host "  -Action Help       # Show this help message"
}

# =============================================================================
#  Entry point
# =============================================================================

switch ($Action.ToLower()) {
    "apply" {
        Do-Apply
    }
    "restore" {
        Do-Restore
    }
    "status" {
        Do-Status
    }
    "help" {
        Show-Help
    }
    default {
        Write-Err "Unknown action: $Action"
        Write-Host "Run:  powershell -ExecutionPolicy Bypass -File bluestacks-noad.ps1 -Action Help"
        exit 1
    }
}
