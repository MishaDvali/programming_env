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
        [string] $Directory,

        [switch] $ShowChances
    )

    if (-not (Test-Path -LiteralPath $Directory -PathType Container)) {
        return
    }

    $enabled = $true
    $allowedFiles = @()
    $blockedFiles = @()
    $rainbowChance = 0
    $sizeBiasStrength = 100
    $deviceConfigName = "config.$env:COMPUTERNAME.json"
    $deviceConfigPath = Join-Path $Directory $deviceConfigName
    $fallbackConfigPath = Join-Path $Directory 'config.json'
    $configPath = if (Test-Path -LiteralPath $deviceConfigPath -PathType Leaf) {
        $deviceConfigPath
    }
    else {
        $fallbackConfigPath
    }

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
            if ($config.PSObject.Properties.Name -contains 'rainbowChance') {
                $rainbowChance = [Math]::Min(100, [Math]::Max(0, [int] $config.rainbowChance))
            }
            if ($config.PSObject.Properties.Name -contains 'sizeBiasStrength') {
                $sizeBiasStrength = [Math]::Min(100, [Math]::Max(0, [int] $config.sizeBiasStrength))
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

    try {
        $windowSize = $Host.UI.RawUI.WindowSize
        $availableWidth = [Math]::Max(1, $windowSize.Width - 2)
        $availableHeight = [Math]::Max(1, $windowSize.Height - 5)
    }
    catch {
        $availableWidth = 78
        $availableHeight = 19
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

            if ($width -gt $availableWidth) {
                return
            }
            if ($lines.Count -gt $availableHeight) {
                return
            }

            [pscustomobject]@{
                Name = $_.Name
                Lines = $lines
                Width = $width
                Height = $lines.Count
                Area = $width * $lines.Count
            }
        }
    )

    if ($candidates.Count -gt 0) {
        $widthRoominess = [Math]::Min(1.0, [Math]::Max(0.0, ($availableWidth - 80) / 80.0))
        $heightRoominess = [Math]::Min(1.0, [Math]::Max(0.0, ($availableHeight - 24) / 48.0))
        $screenRoominess = [Math]::Max($widthRoominess, $heightRoominess)
        $sizeBias = [Math]::Pow($screenRoominess, 2)
        $effectiveBias = $sizeBias * ($sizeBiasStrength / 100.0)
        $largestArea = ($candidates | Measure-Object -Property Area -Maximum).Maximum

        foreach ($candidate in $candidates) {
            $relativeArea = if ($largestArea -gt 0) {
                $candidate.Area / $largestArea
            }
            else {
                0
            }
            $weight = 1 + [Math]::Floor(
                12 * $effectiveBias * [Math]::Pow($relativeArea, 2)
            )
            $candidate | Add-Member -NotePropertyName Weight -NotePropertyValue ([int] $weight) -Force
        }

        $totalWeight = ($candidates | Measure-Object -Property Weight -Sum).Sum

        if ($ShowChances) {
            $effectiveBiasPercent = [Math]::Round($effectiveBias * 100, 1)
            Write-Host "Usable terminal: ${availableWidth}x${availableHeight} | Configured bias: ${sizeBiasStrength}% | Effective bias: ${effectiveBiasPercent}%"

            return $candidates |
                Sort-Object Area -Descending |
                Select-Object Name, Width, Height, Weight, @{
                    Name = 'ChancePercent'
                    Expression = { [Math]::Round(100 * $_.Weight / $totalWeight, 1) }
                }
        }

        $ticket = Get-Random -Minimum 1 -Maximum ([int] $totalWeight + 1)
        $drawing = $candidates[-1]
        foreach ($candidate in $candidates) {
            $ticket -= $candidate.Weight
            if ($ticket -le 0) {
                $drawing = $candidate
                break
            }
        }

        $useRainbow = (
            $rainbowChance -gt 0 -and
            (Get-Random -Minimum 1 -Maximum 101) -le $rainbowChance
        )

        Write-Host
        if ($useRainbow) {
            $rainbowColors = @('Red', 'Yellow', 'Green', 'Cyan', 'Blue', 'Magenta')
            $colorOffset = Get-Random -Minimum 0 -Maximum $rainbowColors.Count

            for ($lineIndex = 0; $lineIndex -lt $drawing.Lines.Count; $lineIndex++) {
                $colorIndex = ($lineIndex + $colorOffset) % $rainbowColors.Count
                Write-Host ($drawing.Lines[$lineIndex]) -ForegroundColor ($rainbowColors[$colorIndex])
            }
        }
        else {
            Write-Host ($drawing.Lines -join [Environment]::NewLine)
        }
        Write-Host
    }
}

function Get-AsciiArtChances {
    Show-RandomAsciiArt -Directory $asciiArtDirectory -ShowChances
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
