# Develop and test the plugin

Run `./tests/run` from the repository root. It runs the template's structural
checks (Node.js 22) and the `bin/fleetwatch` unit and end-to-end tests
(Python 3). The end-to-end tests run the real collector on the local machine
only; nothing connects over ssh.

On Omarchy also run:

```bash
omarchy plugin validate .
```

To try a working copy in the shell, link it in place of an installed copy and
restart the shell (symlinked plugins are not hot-reloaded):

```bash
omarchy plugin remove io.github.frestina.fleetwatch   # if installed from git
ln -s "$PWD" ~/.config/omarchy/plugins/io.github.frestina.fleetwatch
omarchy plugin enable io.github.frestina.fleetwatch
omarchy restart shell
```

Check horizontal and vertical bars, several monitors (one collection per
refresh), an empty or missing hosts file, an unreachable machine, and the
right-click table. Record live results in `docs/ACCEPTANCE.json`.
