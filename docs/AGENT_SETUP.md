# Setting up Fleetwatch: a guide for coding agents

The user clicked "Set up with agent" or "Ask agent" in the Fleetwatch bar
widget. Help them list their machines and choose the optional settings, or
change what they set up before. Work with them step by step: they decide what
goes in, you do the looking up and the typing.

## Limits

You may have been started with approvals switched off. Hold yourself to these
regardless:

- Write only `~/.config/fleetwatch/hosts` and
  `~/.config/fleetwatch/config` (under `$XDG_CONFIG_HOME` if it is set).
  Both already exist; edit them in place and keep their comments. Only if the
  user accepts them: the link for [the terminal command](#the-terminal-command),
  and for [Know where you are](#know-where-you-are)
  `~/.config/hypr/hyprland.lua` and `~/.config/starship.toml` on this machine.
- Read anything else you need, but change nothing else: not `~/.ssh/config`,
  keys, `known_hosts`, agents or any other machine. If something there needs
  fixing, explain what and why, and let the user do it or ask them first.
- Ask before connecting to any machine. Connect only to machines the user has
  agreed to list, and only with the read-only test below.
- Never paste file contents from `~/.ssh` beyond host names and addresses into
  your replies. Never read private keys.

## The files

`hosts`: one machine per line, `<label>  <ssh target>  [<hostname>]`.

- The label is the name shown in the widget.
- The target is whatever the user would type after `ssh`: a `Host` alias from
  `~/.ssh/config`, `user@address` or an address. Prefer an existing alias.
- The hostname is what `hostname` prints on that machine. With it, the line for
  the machine the widget runs on is checked locally, and the same file works
  when copied to each listed machine. Fill it in for every line.
- The file already lists this machine. Keep that line.

`config`: optional `key = value` settings, all commented out to begin with.
Comments in the file explain each one.

| Setting | Suggest it when |
| --- | --- |
| `ssh_options` | The user's ssh agent asks for approval on each use (Bitwarden, 1Password, KeePassXC). Polling would then show every machine as unreachable, so suggest `-o IdentityAgent=none` together with a key that works without the agent, or explain the trade-off. |
| `agent_socket` | They use an ssh agent socket that is not the default (look at `SSH_AUTH_SOCK` and `IdentityAgent` in `~/.ssh/config`) and want to see whether it is running and unlocked. |
| `forwarded_agent_socket` | They forward their agent to the other machines through a fixed socket path (an `~/.ssh/rc` that links `SSH_AUTH_SOCK` somewhere). Only when such a setup already exists. |

## Set up already?

Read both files first. If `hosts` lists only this machine and every setting
in `config` is still commented out, this is a first setup: follow
[Steps](#steps) from the start.

Otherwise the user has set it up before, and is back to change something or
ask about it. Don't go through every step again:

1. Run the plugin's `bin/fleetwatch` (the user's prompt gives its full path)
   to see the current state.
2. Summarize the setup in a few lines: the machines and how each is doing,
   the settings that are on, and whether [the terminal
   command](#the-terminal-command) and the additions in [Know where you
   are](#know-where-you-are) are in place.
3. Ask what they would like: add or remove a machine, change a setting, one
   of the optional additions they haven't made, or an explanation of
   something the widget shows. For an explanation, follow `AGENT_EXPLAIN.md`
   next to this file.
4. Do what they choose with the matching steps below, within the same
   limits. If you changed anything, finish with the summary from step 8,
   listing only this session's changes.

## Steps

1. Read both files and `~/.ssh/config` (with any `Include`d files). Also look
   at what the user's network tools already know, when they are installed:
   `tailscale status` and `/etc/hosts`. Don't scan the network.
2. Show the candidates as a short list with the target you would use for each,
   and ask which to include and what to call them. Ask about machines you could
   not find.
3. For each chosen machine, ask once for permission, then test it exactly the
   way the widget will connect:

   ```bash
   ssh -T -o BatchMode=yes -o ConnectTimeout=4 -o ForwardAgent=no <target> hostname
   ```

   Add any `ssh_options` from the config. The output is the hostname for the
   third column. If it fails, explain the
   error. The usual causes:
   - `Host key verification failed`: the user has never connected. They run
     `ssh <target>` once themselves and accept the key.
   - `Permission denied`: no key the machine accepts is available without a
     prompt. The widget never prompts.
   - A timeout: the machine is off, asleep or not reachable from here.

   List a machine that fails anyway if the user wants it; it shows as
   unreachable until fixed.
4. Write `hosts`. Then go through the settings table and suggest only the
   settings that fit what you found, and write the ones the user accepts.
5. Run the plugin's `bin/fleetwatch` (the user's prompt gives its full path) to
   show the result, and explain any machine that is not OK. The widget checks
   again by itself when either file is saved.
6. Offer [the terminal command](#the-terminal-command).
7. Offer the additions in [Know where you are](#know-where-you-are), and make
   the ones the user wants.
8. Finish with a summary the user can keep:
   - What you changed, file by file.
   - That both settings files can be edited later from the widget's popup.
   - How to remove it all: **Uninstall** at the bottom of the widget's popup
     (or `bin/fleetwatch --uninstall`) asks first, then removes
     `~/.config/fleetwatch`, `~/.cache/fleetwatch`,
     `~/.local/state/fleetwatch`, the `~/.local/bin/fleetwatch` link and
     the `fleetwatch` block in `hyprland.lua`, and removes the plugin.
     It never touches `starship.toml`. If you changed it, tell the user that
     undoing it is up to them: take `$hostname` back out of `format` if you
     put it there, and delete the `[hostname]` tables. List only what you
     actually made.

## The terminal command

The plugin's `bin/fleetwatch` prints the same check as a table in the terminal,
but it isn't on the user's `PATH` until it is linked. Explain this and offer
to link it:

```bash
ln -s <plugin folder>/bin/fleetwatch ~/.local/bin/fleetwatch
```

Use the full path from the user's prompt; the link follows the plugin when
it is updated. Before linking:

- If `~/.local/bin/fleetwatch` exists and already points at this plugin's
  `bin/fleetwatch`, there is nothing to do.
- If it exists as anything else, leave it alone and tell the user; don't
  replace it, and don't use `ln -f`.
- If `command -v fleetwatch` finds a different `fleetwatch` earlier on `PATH`,
  say so: the link would be hidden behind it.
- If `~/.local/bin` is not on `PATH`, say so instead of linking (Omarchy puts
  it there).

Then run `fleetwatch` through the link once to show it works.

## Know where you are

Clicking a machine in the popup opens an ssh session in a terminal with the
window class `org.omarchy.ssh`. Two optional additions make those sessions
easy to tell apart from local ones. Explain both, and ask which the user wants.

**A border of their own** for those windows, on this machine, in a colour
picked from their Omarchy theme. It follows them when they switch themes.
Skip it if `~/.config/hypr/hyprland.lua` already has a `fleetwatch`
block. If it already has another rule that sets a border for
`org.omarchy.ssh`, ask the user which one to keep. Append, at the end
of that file, exactly:

```lua
-- >>> fleetwatch: ssh sessions from the Fleetwatch bar widget get a border
-- colour from the current theme. `fleetwatch --uninstall` removes this block.
pcall(dofile, os.getenv("HOME") .. "/.config/omarchy/plugins/io.github.frestina.fleetwatch/hypr/ssh-border.lua")
-- <<< fleetwatch
```

Keep both marker lines as they are: uninstalling removes what is between
them. Hyprland reloads the file when it is saved. Then run
`hyprctl configerrors`, and if it reports a problem, undo your change and tell
the user.

**The machine's name in the prompt** over ssh, with starship. This shows on
the machine being connected to, so here it helps when the user connects to
this machine from another one. Edit `~/.config/starship.toml` only if
`starship` is installed and the file exists:

- If `format` is set and has no `$hostname`, put `$hostname` at its start.
  Omarchy's default `format` leaves it out. Without a `format`, starship's
  default already includes it.
- Add, or merge into an existing `[hostname]` table:

  ```toml
  [hostname]
  ssh_only = true
  format = "[$hostname]($style) "
  style = "bold yellow"
  ```

- Keep `style` a colour name such as `yellow`: the user's terminal draws it
  in their theme's colour. A hex colour would not follow theme switches.
- If labels in the hosts file differ from hostnames, offer
  `[hostname.aliases]` (`<hostname> = "<label>"`) so the prompt uses the same
  names as the widget.
- Run `starship prompt >/dev/null` to check the file still parses; undo your
  change if it does not.
- If `~/.config/starship.toml` is a symlink, say where it points. In a
  dotfiles repository, the change reaches the other machines through it once
  committed; don't commit for the user.

For the other machines, give the user the same steps to do there, or to run
this setup there too. Don't change them yourself.
