# Shared PowerShell profile for Windows PowerShell and PowerShell 7.
# Keep this file in the repository and load it from $PROFILE.

$env:VIRTUAL_ENV_DISABLE_PROMPT = '1'

$isInteractiveConsole = (
    $Host.Name -eq 'ConsoleHost' -and
    -not [Console]::IsOutputRedirected
)

if (
    (Get-Module -ListAvailable -Name PSReadLine) -and
    $isInteractiveConsole
) {
    if ($PSVersionTable.PSVersion.Major -ge 7) {
        Set-PSReadLineOption -PredictionSource History
        Set-PSReadLineOption -PredictionViewStyle ListView
    }
    Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward
    Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward
    Set-PSReadLineKeyHandler -Chord Tab -Function MenuComplete
}

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$ohMyPoshConfig = Join-Path $repositoryRoot 'oh-my-posh\config.json'
$asciiArtDirectory = Join-Path $repositoryRoot 'ascii_art'

function Show-RandomAsciiArt {
    param(
        [Parameter(Mandatory)]
        [string] $Directory
    )

    if (-not (Test-Path -LiteralPath $Directory -PathType Container)) {
        return
    }

    $enabled = $true
    $allowedFiles = @()
    $blockedFiles = @()
    $maxWidth = 0
    $maxHeight = 0
    $configPath = Join-Path $Directory 'config.json'

    if (Test-Path -LiteralPath $configPath -PathType Leaf) {
        try {
            $config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json

            if ($config.PSObject.Properties.Name -contains 'enabled') {
                $enabled = [bool] $config.enabled
            }
            if ($config.PSObject.Properties.Name -contains 'allowedFiles') {
                $allowedFiles = @($config.allowedFiles | Where-Object { $_ })
            }
            if ($config.PSObject.Properties.Name -contains 'blockedFiles') {
                $blockedFiles = @($config.blockedFiles | Where-Object { $_ })
            }
            if ($config.PSObject.Properties.Name -contains 'maxWidth') {
                $maxWidth = [int] $config.maxWidth
            }
            if ($config.PSObject.Properties.Name -contains 'maxHeight') {
                $maxHeight = [int] $config.maxHeight
            }
        }
        catch {
            Write-Warning "Could not read ASCII art config: $($_.Exception.Message)"
            return
        }
    }

    if (-not $enabled) {
        return
    }

    if ($maxWidth -le 0) {
        try { $maxWidth = $Host.UI.RawUI.WindowSize.Width } catch { $maxWidth = 0 }
    }
    if ($maxHeight -le 0) {
        try { $maxHeight = [Math]::Max(1, $Host.UI.RawUI.WindowSize.Height - 5) } catch { $maxHeight = 0 }
    }

    $candidates = @(
        Get-ChildItem -LiteralPath $Directory -Filter '*.txt' -File | ForEach-Object {
            if ($allowedFiles.Count -gt 0 -and $allowedFiles -notcontains $_.Name) {
                return
            }
            if ($blockedFiles -contains $_.Name) {
                return
            }

            $lines = @(Get-Content -LiteralPath $_.FullName)
            $width = if ($lines.Count -gt 0) {
                ($lines | ForEach-Object Length | Measure-Object -Maximum).Maximum
            }
            else {
                0
            }

            if ($maxWidth -gt 0 -and $width -gt $maxWidth) {
                return
            }
            if ($maxHeight -gt 0 -and $lines.Count -gt $maxHeight) {
                return
            }

            [pscustomobject]@{
                Name = $_.Name
                Lines = $lines
            }
        }
    )

    if ($candidates.Count -gt 0) {
        $drawing = $candidates | Get-Random
        Write-Host
        Write-Host ($drawing.Lines -join [Environment]::NewLine)
        Write-Host
    }
}

if ($isInteractiveConsole -and -not $global:ProgrammingEnvAsciiArtShown) {
    $global:ProgrammingEnvAsciiArtShown = $true
    Show-RandomAsciiArt -Directory $asciiArtDirectory
}

if (Get-Command oh-my-posh -ErrorAction SilentlyContinue) {
    oh-my-posh init pwsh --config $ohMyPoshConfig | Invoke-Expression
}

if (Get-Command zoxide -ErrorAction SilentlyContinue) {
    Invoke-Expression (& { (zoxide init powershell | Out-String) })
}

function gs { git status @args }
function ga { git add @args }
function gcmsg {
    param(
        [Parameter(Mandatory, Position = 0, ValueFromRemainingArguments)]
        [string[]] $Message
    )

    git commit -m ($Message -join ' ')
}
