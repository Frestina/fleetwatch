# Architecture

Two parts with one rule: `bin/fleetwatch` decides, `Fleetwatch.qml` displays.
`hypr/ssh-border.lua` is an optional third, which runs inside Hyprland.

## `bin/fleetwatch` (Python 3, standard library only)

- Reads `~/.config/fleetwatch/hosts` and `config` (`$XDG_CONFIG_HOME` is
  honoured). Every run first creates whichever is missing, with `open(…, "x")`
  so an existing file is never replaced: `hosts` from `examples/hosts` plus a
  line for this machine, `config` as `examples/config`.
- Runs one read-only bash collector per machine in parallel: `bash -s` for this
  machine, `ssh -T -o BatchMode=yes -o ConnectTimeout=4 -o ForwardAgent=no
  [ssh_options] -- <target> bash -s` for the others, with a 45 second deadline.
  Optional checks receive their paths as shell-quoted variables ahead of the
  script (`REPOS=(…)` for the `repo` lines, numbered `repo0_…` in its
  report); `~/` expands on the far side. A repo's HEAD comes back from the far
  side, so only a plain object id is passed to git here. Behind and ahead
  are measured against this machine's copy of the repo; when it has none, or
  doesn't know that commit, the far side's own count from its last fetch is
  used instead.
- The far side only reports `key=value` facts. Fields that identify the machine
  (`label`, `target`, `local`) and the computed `error` and `view` always come
  from this side, so a machine cannot redirect the widget's ssh click.
- `assess()` turns facts into display cells, issues with a severity, and a
  status (`ok`, `warn`, `bad`, `down`). Repository issues have the severity
  `info`: listed, but never raising the status. The terminal table and `--json` share
  it.
- `--json --max-age N` / `--since EPOCH` serve `~/.cache/fleetwatch/last.json`
  under an exclusive `flock`, so the widget's copies on several monitors share
  one collection. The cache's mtime is when its collection started.

- `--uninstall` runs before the files are created. It lists what is there
  (the three folders, `~/.local/bin/fleetwatch` when it links to this plugin,
  the `-- >>> fleetwatch` … `-- <<< fleetwatch` block in
  `hyprland.lua`). It asks with `gum choose` whether to remove all of it or only the
  plugin, then runs `omarchy-plugin-remove --yes` first, so a running widget
  can't create its files again. A start marker without an end is left
  alone, and `hyprland.lua` is written through a symlink to the file it
  points at. A folder that is a symlink loses only the link. `starship.toml` is never edited: what we added there can't be
  told apart from the user's own settings.

## `hypr/ssh-border.lua` (optional, in Hyprland)

- Loaded with `pcall(dofile, …)` from the user's `hyprland.lua`, so it does
  nothing once the plugin is gone. Omarchy reloads Hyprland on a theme switch,
  which runs it again.
- Reads `~/.local/state/omarchy/current/theme/colors.toml`. Of yellow,
  magenta, cyan, green, orange and blue (red would read as an error), it
  picks the one with the largest OKLab distance from the theme's border
  (`hyprland_active_border`, else `accent`, as in Omarchy's template), capped
  by 1.5 × its distance from the background. Ties go to the earlier colour
  in that list, and the fallback is amber. It applies
  `o.window("^org\\.omarchy\\.ssh$", …)` only when `o` exists, so tests can
  load it with plain `lua`.

## `Fleetwatch.qml` (bar widget)

- One instance per monitor (`allowMultiple: false` per bar). Each runs the
  bundled script through a Quickshell `Process` with an argument array; the
  script path comes from `Qt.resolvedUrl`, so it follows wherever the plugin
  is installed.
- A timer refreshes every `refreshIntervalSec` (60 to 86400, default 600) with
  `--max-age`; refresh-now passes one shared `--since` timestamp to every
  instance so only the first collects.
- A start failure only flips `running`, so completion is handled on
  `onRunningChanged`; exit code, JSON parsing and shape are checked separately
  and the last stderr line becomes the visible error.
- The footer runs the script with `--edit hosts|config` (Omarchy's default
  editor), `--uninstall` (in a floating terminal, since it asks) or
  `--setup-with-agent` (`omarchy agent prompt` pointing at
  `docs/AGENT_SETUP.md`, or Omarchy's agent picker when none is chosen). A
  `FileView` watches both files and the dismissed crashes; a save waits 500 ms
  for the editor to finish, then refreshes with `--since` the save, so every
  monitor shares one check. A watch only takes on an existing file, so the
  watchers get their paths after the first successful check, by which time
  the script has created all three.
- Repos are listed per machine from the view's `repos` (`ok` muted, `info` in
  full), never as issues. A crash issue carries its crash ids
  (`<time>-<pid>`); its ✓ runs `--dismiss-crashes <label> <ids…>`, which adds
  exactly those to `~/.local/state/fleetwatch/dismissed-crashes.json`.
  Ids older than the 7-day window are pruned on each write.
- All external text is rendered with `Text.PlainText`. The ssh click and the
  table action go through the bar's `run()` with `Util.shellQuote`.
- IPC target `io.github.frestina.fleetwatch`: `open`, `close`, `toggle`,
  `refresh`.

Nothing runs with elevated privileges, and nothing is installed outside the
plugin folder. `omarchy plugin remove` leaves only `~/.config/fleetwatch`,
`~/.cache/fleetwatch`, `~/.local/state/fleetwatch` and whatever the
user or setup agent added; `--uninstall` removes all of that except the
starship settings.
Node.js is a development dependency for the repository checks only.
