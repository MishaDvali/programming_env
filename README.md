# Programming environment

Personal Windows terminal configuration containing:

- a shared PowerShell profile;
- Oh My Posh themes;
- zoxide initialization;
- bundled FiraCode and Hack Nerd Fonts.

## Fresh Windows setup

Install Git, clone this repository outside OneDrive, and run the bootstrap:

```powershell
New-Item -ItemType Directory -Path "$HOME\source" -Force
git clone https://github.com/MishaDvali/programming_env.git "$HOME\source\programming_env"
Set-Location "$HOME\source\programming_env"
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
.\setup.ps1
```

The script installs Git, PowerShell 7, Oh My Posh, and zoxide through WinGet. It
also installs the bundled FiraCode Nerd Font Mono files for the current user and
connects both PowerShell profile locations to `powershell/profile.ps1`.

Existing PowerShell profiles are backed up before replacement.

## Updating

```powershell
Set-Location "$HOME\source\programming_env"
git pull
```

Because the real PowerShell profiles load the repository copy, configuration
updates apply the next time a shell opens.

## Files that matter

- `powershell/profile.ps1` contains shared shell behavior.
- `oh-my-posh/config.json` is the active prompt theme.
- `setup.ps1` installs dependencies and connects the profiles.
- `Fonts/` contains offline Nerd Font files.
- `ascii_art/` contains drawings shown randomly when an interactive shell opens.

## Startup ASCII art

Copy `ascii_art/config.example.json` to a file named for the current computer:

```powershell
$deviceConfig = "config.$env:COMPUTERNAME.json"
Copy-Item .\ascii_art\config.example.json ".\ascii_art\$deviceConfig"
```

Machine-specific `config.*.json` files are ignored by Git. Each computer reads
only the file matching its own computer name, so this remains device-specific
even if the repository itself is synchronized by OneDrive. A legacy
`ascii_art/config.json` is used only when no machine-specific file exists.

- An empty `allowedFiles` list allows every `.txt` drawing.
- `blockedFiles` excludes drawings by exact filename.
- `maxWidth` and `maxHeight` skip drawings that are too large.
- Set either size to `0` to use the current terminal dimensions.
- `rainbowChance` is a percentage from `0` to `100` controlling how often a
  drawing receives rainbow-colored lines.
- Set `enabled` to `false` to disable startup art on that device.

Keep the repository outside OneDrive. Git is the synchronization mechanism for
these files and avoids OneDrive conflicts inside the `.git` directory.

