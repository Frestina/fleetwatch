# Architecture

Two parts with one rule: `bin/fleetwatch` decides, `Fleetwatch.qml` displays.
`hypr/ssh-border.lua` is an optional third, which runs inside Hyprland.

## `bin/fleetwatch` (Python 3, standard library only)

- Reads `~/.config/fleet/hosts`, shared by the Fleet tools in the format of
  Fleet's HOSTS.md, and `~/.config/fleet/watch/config.toml`, parsed with
  `tomllib` (`$XDG_CONFIG_HOME` is honoured). Its settings are strings, except
  `DAYS_KEYS`, numbers of days that a `[machine.<label>]` table can set for one
  machine (`days_setting()`). Every run first creates
  whichever is missing, with `open(…, "x")` so an existing file is never
  replaced: `hosts` from `examples/hosts` plus a line for this machine,
  `config.toml` as `examples/config.toml`.
- Runs one read-only bash collector per machine in parallel: `bash -s` for this
  machine, `ssh -T -o BatchMode=yes -o ConnectTimeout=4 -o ForwardAgent=no
  [ssh_options] -- <target> bash -s` for the others, with a 45 second deadline.
  The agent check receives its socket path as a shell-quoted variable ahead
  of the script (`AGENT_SOCK=…`); `~/` expands on the far side.
- The far side only reports `key=value` facts. Fields that identify the machine
  (`label`, `target`, `local`) and the computed `error` and `view` always come
  from this side, so a machine cannot redirect the widget's ssh click.
- `assess()` turns facts into display cells, issues with a severity, and a
  status (`ok`, `warn`, `bad`). An unreachable machine's ssh error is a `warn`
  when it matches `OFFLINE` (timeout, no route, name not resolving: off or out
  of reach, often on purpose) and `bad` otherwise. The terminal table and
  `--json` share it.
- The collector sends the pending updates as well as their count, `;`-joined
  on one line (`updates_list`, `updates_aur_list`). `pending_updates()` keeps
  only lines that parse as an update from pacman, yay or apt, so what a machine
  sends can't carry control characters to the terminal or the agent. It puts
  `REBOOT_PACKAGES` first and tags them, along with the packages a pacman
  machine reports as its kernels (`kernels`, the owners of
  `/usr/lib/modules/*/vmlinuz`), so any flavour is tagged. `updates_view()`
  gives the popup the first `UPDATES_SHOWN`, and the stats line's `summary`.
  `--updates [LABEL...]` prints all of them in place of the table.
- Held updates (`held`, `held_list`) come apart from the rest. `checkupdates`
  drops every `pacman -Qu` line with a `[…]` suffix, held ones included, so
  the collector runs `pacman -Qu` on the database `checkupdates` just synced and
  keeps the lines tagged `[ignored]`. Pacman decides those itself, so globs in
  `IgnorePkg` and `IgnoreGroup` need nothing here. On apt, `apt list
  --upgradable` includes held packages, and `apt-mark showhold` picks them out.
  They don't count towards the 50 of `updates`. Their warning's key is `held:`
  and a hash of the held names and new versions (`held_key()`), so a new held
  update is a new warning and the old key is forgotten.
- `upgraded` is when the last full upgrade that installed something was: on
  pacman a `starting full system upgrade` with an `[ALPM] transaction
  completed` before the next `[PACMAN] Running` (one with nothing to do, or
  that failed, has none). On apt, a `history.log*` block whose command is
  `apt`/`apt-get` `upgrade`, `full-upgrade` or `dist-upgrade`. Without one,
  `log_start` is when the log begins. Both are `%Y-%m-%dT%H:%M:%S%z`; apt's
  local times get the machine's `date +%z`. `updated_cell()` makes the UPDATED
  column and the `age` warning past `update_every_days`.
- `reboot=1` when the running kernel's modules dir is gone (Arch), Debian's
  `/var/run/reboot-required` exists, or pacman says no package owns a modules
  dir that has a `pkgbase` file. That last one is Omarchy's
  `kernel-modules-hook`, which puts the running kernel's modules back after
  an upgrade. Only pacman's own "No package owns" counts, so a pacman that
  fails is no reboot.
- `--json --max-age N` / `--since EPOCH` serve `~/.cache/fleet/watch/last.json`
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
  `--ask-agent` (`omarchy agent prompt` pointing at `docs/AGENT_SETUP.md`,
  or Omarchy's agent picker when none is chosen). The guide tells a first setup
  from a later visit by the two files; the button's label follows
  `onlyThisMachine`. Each issue's agent button runs `--ask-agent <label>
  <issue text>`, pointing at `docs/AGENT_EXPLAIN.md`. `--ask-agent` is only
  recognised as the first argument, so issue text from a machine can never
  read as an option; the label must be in the hosts file, which supplies the
  target, and the issue goes into the prompt as one JSON-quoted line without
  control characters, marked as data. A
  `FileView` watches both files and both dismissed files; a save waits 500 ms
  for the editor to finish, then refreshes with `--since` the save, so every
  monitor shares one check. A watch only takes on an existing file, so the
  watchers get their paths after the first successful check, by which time
  the script has created all four.
- A machine's stats line has an arrow when it has updates to list. It sets
  `expandedLabel`, held on the root so a refresh keeps the list open and one
  machine shows at a time; closing the popup clears it. The arrow, the terminal
  and agent buttons under the list sit above the row's ssh `MouseArea`, so they
  don't open ssh. One repeater shows `list` then `held`, and the first held
  row carries the "Held back on purpose" heading. The terminal button runs
  `--updates <label>` through `less`, the agent button `--ask-agent <label>`
  with `view.updates.issue`. The caption before the uptime takes the UPDATED
  column when it reads as a time ("updated 12d ago").
- A crash issue carries its crash ids
  (`<time>-<pid>`); its dismiss button (a broom) runs `--dismiss-crashes <label> <ids…>`, which adds
  exactly those to `~/.local/state/fleet/watch/dismissed-crashes.json`.
  Ids older than the 7-day window are pruned on each write.
- The collector's last line, `unchecked=`, names the checks whose tool is
  there and failed. A tool the machine lacks is left out silently, so an empty
  list always means nothing is wrong. `collect()` takes a report without that
  line as cut off and reports an error, and `cells()` shows `?` and a
  `couldn't check` warning for what it names.
- A warning issue carries a `key` (`unreachable`, `reboot`, `updates`, `age`, `held:<hash>`, `load`,
  `mem`, `disk`, `runtime`, `unchecked`, `agent`) and an `until` for its dismiss button's tooltip. The button runs
  `--dismiss-warning <label> <key>`, which adds the key to
  `dismissed-warnings.json`; `assess()` then leaves that warning out while it
  is a warning, never once it is `bad`. After every collection,
  `forget_cleared()` drops the keys a reachable machine no longer warns
  about, so the warning shows again when it comes back. It leaves an
  unreachable machine's keys alone, and `updates` while the count is `?`.
  Both dismissed files are written under a lock in the state folder: a
  dismiss and a check can write at once.
- Warnings use the theme's `orange`, else `yellow`, else `color3`, else
  the accent, read from `colors.toml`: the shell's palette has no warning
  colour. A theme switch updates the shell over IPC without a file change, so
  the file is read again when `Color`'s accent, urgent or background changes.
- All external text is rendered with `Text.PlainText`. The ssh click and the
  table action go through the bar's `run()` with `Util.shellQuote`.
- IPC target `io.github.frestina.fleetwatch`: `open`, `close`, `toggle`,
  `refresh`.

Nothing runs with elevated privileges, and nothing is installed outside the
plugin folder. `omarchy plugin remove` leaves only `~/.config/fleet/watch`,
`~/.cache/fleet/watch`, `~/.local/state/fleet/watch`, the shared
`~/.config/fleet/hosts` and whatever the user or setup agent added;
`--uninstall` removes all of that except the starship settings, and the hosts
file while another Fleet tool uses it.
Node.js is a development dependency for the repository checks only.
