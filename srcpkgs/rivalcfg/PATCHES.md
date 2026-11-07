# Local patches for rivalcfg

This package carries two patches against rivalcfg 4.17.0. They stay here, not
upstream, because they adapt the tool to Void packaging and to system-wide udev
rules. Check both on every version bump.

The package also ships `INSTALL.msg`, which tells the user to reload the udev
rules and join `plugdev`. There is no `REMOVE.msg`: removing the package removes
its rules from `/usr/lib/udev/rules.d`, and group membership is left to the
administrator.

## 1. Relax the flit_core pin

`relax-flit-core-version.patch`

`pyproject.toml` asks for `flit_core >=3.2,<4`. Void ships a newer flit_core, so
the upper bound blocks the build. The patch drops the upper bound and keeps
`>=3.2`.

To check it, build the package with `build_style=python3-pep517`. If the build
gets past the build backend check, the patch still does its job.

Drop it when upstream accepts the flit_core version Void ships without an upper
bound.

## 2. Accept system-wide udev rules

`udev-system-rules.patch`

Upstream looks only at `/etc/udev/rules.d/99-steelseries-rival.rules` and writes
rules with `MODE="0666"`. Void packages install system rules in
`/usr/lib/udev/rules.d`, so the checks reported missing rules even when the
package had installed them.

The patch does three things:

- `rivalcfg/udev.py` adds `RULES_FILE_PATHS`, with the `/etc` path first and the
  `/usr/lib` path second. `generate_rules()` writes `MODE="0660"`,
  `GROUP="plugdev"`, and `TAG+="uaccess"`.
- `rivalcfg/__main__.py` picks the first rules file that exists and checks that
  file for freshness.
- `rivalcfg/debug.py` reports whether any known rules file exists and is current.

To check it:

```sh
rivalcfg --print-debug | grep -i udev
ls -l /dev/hidraw*          # group must be plugdev, mode 0660
```

The debug output must not claim that the rules are missing while the package
file is present.

Drop it when upstream searches `/usr/lib/udev/rules.d` and writes `plugdev`
rules with `uaccess` by default.

## Upstream

Nothing from this package has been sent upstream.

rivalcfg is WTFPL. The notes written here are MIT.
