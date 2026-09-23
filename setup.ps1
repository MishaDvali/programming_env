[CmdletBinding()]
param(
    [switch] $SkipPackages,
    [switch] $SkipFonts
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = $PSScriptRoot
$sharedProfile = Join-Path $repositoryRoot 'powershell\profile.ps1'

if (-not $IsWindows -and $PSVersionTable.PSEdition -eq 'Core') {
    throw 'This bootstrap script is intended for Windows.'
}

function Install-WingetPackage {
    param([Parameter(Mandatory)][string] $Id)

    $installed = winget list --id $Id --exact --accept-source-agreements 2>$null
    if ($LASTEXITCODE -eq 0 -and $installed -match [regex]::Escape($Id)) {
        Write-Host "$Id is already installed."
        return
    }

    winget install --id $Id --exact --source winget `
        --accept-package-agreements --accept-source-agreements
    if ($LASTEXITCODE -ne 0) {
        throw "WinGet failed to install $Id."
    }
}

function Install-BundledFont {
    param([Parameter(Mandatory)][string] $Path)

    $fontDirectory = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Fonts'
    $registryPath = 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts'
    $file = Get-Item -LiteralPath $Path
    $destination = Join-Path $fontDirectory $file.Name

    New-Item -ItemType Directory -Path $fontDirectory -Force | Out-Null
    New-Item -Path $registryPath -Force | Out-Null
    Copy-Item -LiteralPath $file.FullName -Destination $destination -Force
    New-ItemProperty -Path $registryPath -Name "$($file.BaseName) (TrueType)" `
        -Value $destination -PropertyType String -Force | Out-Null
}

function Set-ProfileLoader {
    param([Parameter(Mandatory)][string] $ProfilePath)

    $profileDirectory = Split-Path -Parent $ProfilePath
    New-Item -ItemType Directory -Path $profileDirectory -Force | Out-Null

    $escapedProfile = $sharedProfile.Replace("'", "''")
    $loader = ". '$escapedProfile'"

    if (Test-Path -LiteralPath $ProfilePath) {
        $currentProfile = (Get-Content -LiteralPath $ProfilePath -Raw).Trim()
        if ($currentProfile -eq $loader) {
            Write-Host "$ProfilePath is already configured."
            return
        }

        $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
        Copy-Item -LiteralPath $ProfilePath -Destination "$ProfilePath.backup-$timestamp"
    }

    Set-Content -LiteralPath $ProfilePath -Encoding utf8 -Value $loader
    Write-Host "Configured $ProfilePath"
}

function Set-TerminalFontDefaults {
    $terminalPackage = Get-AppxPackage -Name 'Microsoft.WindowsTerminal' -ErrorAction SilentlyContinue
    if ($terminalPackage) {
        $terminalSettings = Join-Path $env:LOCALAPPDATA `
            "Packages\$($terminalPackage.PackageFamilyName)\LocalState\settings.json"

        if (-not (Test-Path -LiteralPath $terminalSettings)) {
            New-Item -ItemType Directory -Path (Split-Path -Parent $terminalSettings) -Force | Out-Null
            @'
{
    "$schema": "https://aka.ms/terminal-profiles-schema",
    "defaultProfile": "{574e775e-4f2a-5b96-ac1e-a2962a402336}",
    "profiles": {
        "defaults": {
            "font": {
                "face": "FiraCode Nerd Font Mono"
            }
        },
        "list": []
    }
}
'@ | Set-Content -LiteralPath $terminalSettings -Encoding utf8
        } else {
            $terminalBackup = "$terminalSettings.backup-before-programming-env"
            if (-not (Test-Path -LiteralPath $terminalBackup)) {
                Copy-Item -LiteralPath $terminalSettings -Destination $terminalBackup
            }

            $terminalConfig = Get-Content -LiteralPath $terminalSettings -Raw | ConvertFrom-Json
            $terminalConfig.defaultProfile = '{574e775e-4f2a-5b96-ac1e-a2962a402336}'

            if (-not $terminalConfig.profiles.defaults.PSObject.Properties['font']) {
                $terminalConfig.profiles.defaults | Add-Member -NotePropertyName font -NotePropertyValue ([pscustomobject]@{})
            }
            if (-not $terminalConfig.profiles.defaults.font.PSObject.Properties['face']) {
                $terminalConfig.profiles.defaults.font | Add-Member -NotePropertyName face -NotePropertyValue 'FiraCode Nerd Font Mono'
            } else {
                $terminalConfig.profiles.defaults.font.face = 'FiraCode Nerd Font Mono'
            }

            $terminalConfig | ConvertTo-Json -Depth 100 |
                Set-Content -LiteralPath $terminalSettings -Encoding utf8
        }
        Write-Host 'Configured Windows Terminal for PowerShell 7 and FiraCode Nerd Font Mono.'
    }

    $vsCodeSettings = Join-Path $env:APPDATA 'Code\User\settings.json'
    if (-not (Test-Path -LiteralPath $vsCodeSettings)) {
        New-Item -ItemType Directory -Path (Split-Path -Parent $vsCodeSettings) -Force | Out-Null
        @'
{
    "terminal.integrated.fontFamily": "FiraCode Nerd Font Mono"
}
'@ | Set-Content -LiteralPath $vsCodeSettings -Encoding utf8
        Write-Host 'Configured the VS Code integrated terminal font.'
    } else {
        Write-Host 'VS Code settings already exist; leaving them unchanged.'
    }
}

if (-not $SkipPackages) {
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        throw 'WinGet is unavailable. Update/install App Installer from Microsoft Store, then rerun setup.ps1.'
    }

    Install-WingetPackage -Id 'Git.Git'
    Install-WingetPackage -Id 'Microsoft.PowerShell'
    Install-WingetPackage -Id 'JanDeDobbeleer.OhMyPosh'
    Install-WingetPackage -Id 'ajeetdsouza.zoxide'
}

if (-not $SkipFonts) {
    Get-ChildItem -LiteralPath (Join-Path $repositoryRoot 'Fonts\FiraCode') `
        -Filter 'FiraCodeNerdFontMono-*.ttf' -File |
        ForEach-Object { Install-BundledFont -Path $_.FullName }
    Write-Host 'Installed FiraCode Nerd Font Mono for the current user.'
}

$documents = [Environment]::GetFolderPath('MyDocuments')
$powerShell7Profile = Join-Path $documents 'PowerShell\Microsoft.PowerShell_profile.ps1'
$windowsPowerShellProfile = Join-Path $documents 'WindowsPowerShell\Microsoft.PowerShell_profile.ps1'

Set-ProfileLoader -ProfilePath $powerShell7Profile
Set-ProfileLoader -ProfilePath $windowsPowerShellProfile
Set-TerminalFontDefaults

Write-Host ''
Write-Host 'Setup complete. Restart Windows Terminal, select FiraCode Nerd Font Mono,'
Write-Host 'and set PowerShell 7 as the default profile.'
