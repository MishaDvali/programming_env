# Shared PowerShell profile for Windows PowerShell and PowerShell 7.
# Keep this file in the repository and load it from $PROFILE.

$env:VIRTUAL_ENV_DISABLE_PROMPT = '1'

if (
    (Get-Module -ListAvailable -Name PSReadLine) -and
    $Host.Name -eq 'ConsoleHost' -and
    -not [Console]::IsOutputRedirected
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
