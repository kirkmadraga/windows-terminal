# dotfiles

Portable snapshot of my terminal setup.

## Layout

```
dotfiles/
├── install.ps1                        # bootstraps everything below onto a new machine
├── bash/
│   ├── .bashrc                        # oh-my-posh init, aliases, pokecow trigger
│   └── .bash_profile                  # sources .bashrc
├── oh-my-posh/
│   └── powerlevel10k_rainbow.omp.json # active theme (referenced by .bashrc)
├── pokecow/
│   ├── pokesay.sh                     # custom renderer: extracts a .cow sprite via perl,
│   │                                  #   renders a cowsay speech bubble, merges them side-by-side
│   └── cows/                          # 400 Pokémon .cow sprite files + LICENSE (from tmck-code/pokesay, see Credits)
└── windows-terminal/
    └── profile-fragment.json          # the "Bash" profile + Tokyo Night scheme, merged by install.ps1
```

## Install on a new machine

Install [MSYS2](https://www.msys2.org/) first, then run from PowerShell
(`-ExecutionPolicy Bypass` because Windows blocks scripts by default; this
only applies to this one run):

```powershell
powershell -ExecutionPolicy Bypass -File install.ps1                     # MSYS2 in the default C:\msys64
powershell -ExecutionPolicy Bypass -File install.ps1 -Msys2Root C:\msys2 # MSYS2 somewhere else
```

This copies everything into place, sets the `MSYS2_ROOT` user environment
variable (only if it isn't already set), points MSYS2's home directory at
your Windows user folder, and merges the Windows Terminal
profile. It does **not** download or install anything — fonts and the
other external dependencies are installed manually (the script prints the
steps at the end):

| Dependency | Why | Install |
|---|---|---|
| FiraCode Nerd Font | font used by the "Bash" WT profile | https://www.nerdfonts.com/font-downloads — unzip, select the `.ttf` files, right-click → Install |
| MSYS2 (UCRT64) | the actual shell the "Bash" WT profile launches | https://www.msys2.org/ (default location `C:\msys64`) |
| `fortune-mod`, `cowsay` | pokecow greeting | `pacman -S --needed mingw-w64-ucrt-x86_64-fortune-mod mingw-w64-ucrt-x86_64-cowsay` inside the UCRT64 shell |
| oh-my-posh | prompt renderer | `pacman -S --needed mingw-w64-ucrt-x86_64-oh-my-posh` inside the UCRT64 shell (not winget) |

After that: fully close and reopen Windows Terminal (so it sees
`MSYS2_ROOT`), then Settings → Startup → default profile → "Bash".

## Notes

- MSYS2's `~` is set to your Windows user folder (`db_home: windows` in
  `nsswitch.conf`), so re-run the script if MSYS2 wasn't installed yet.
- Use the pacman oh-my-posh, not winget — the winget build hangs in MSYS2.
- `.bashrc` doesn't set `PATH`; the shell inherits the Windows one. Add
  extra tool folders there.

## Credits

- The Pokémon `.cow` sprite files in `pokecow/cows/` come from
  [tmck-code/pokesay](https://github.com/tmck-code/pokesay), © 2024 Tom
  McKeesick, under the BSD 3-Clause License — see
  [`pokecow/cows/LICENSE`](pokecow/cows/LICENSE).
