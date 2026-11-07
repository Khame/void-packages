# Khame XBPS repository

Signed x86_64 packages for Void Linux, built for runit. These are not official
Void Linux packages.

The repository is served from GitHub Pages:
https://khame.github.io/void-packages/

## Packages

| Package | Description | Documentation |
| --- | --- | --- |
| `asusctl` | ASUS ROG control daemon, CLI tools and an optional KDE Plasma widget. | [Khame/asusctl-void-linux](https://github.com/Khame/asusctl-void-linux) |
| `doublecmd` | Twin-panel file manager, built from source with Void's FPC and Lazarus. | [Khame/doublecmd-void-linux](https://github.com/Khame/doublecmd-void-linux) |
| `rivalcfg` | SteelSeries mouse configuration CLI, patched for system udev rules and the `plugdev` group. | [Khame/rivalcfg-void-linux](https://github.com/Khame/rivalcfg-void-linux) |
| `sensei310-tray` | KDE tray controller for the SteelSeries Sensei 310. | [Khame/sensei310-tray](https://github.com/Khame/sensei310-tray) |

`rivalcfg` is installed as a dependency of `sensei310-tray`.

## Add the repository

```sh
sudo sh -c 'echo "repository=https://khame.github.io/void-packages/" > /etc/xbps.d/10-khame.conf'
sudo xbps-install -S
```

On the first sync, XBPS asks to import the signing key. Compare the fingerprint
before you answer yes:

```
35:2b:06:7c:52:04:76:b1:4a:de:a0:8b:49:9c:e2:66
```

The public key is also published as
[Khame-void-repo.pub](https://khame.github.io/void-packages/Khame-void-repo.pub).

## Install packages

```sh
sudo xbps-install asusctl doublecmd sensei310-tray
```

You can install any of them on its own. `sensei310-tray` needs KDE Plasma and
`kdialog`; its README covers mouse access and the udev rules.

## Update

```sh
sudo xbps-install -Su
```

## Remove the repository

```sh
sudo rm /etc/xbps.d/10-khame.conf
sudo xbps-install -S
```

Installed packages stay on the system. Remove them separately with
`sudo xbps-remove <package>`.

## Build sources

Templates, patches and packaging files are in `srcpkgs/`. The binary packages in
`docs/` were built from them. See [LICENSES.md](LICENSES.md) for the licenses of
the packaged software. The MIT license in [LICENSE](LICENSE) covers only the
files written for this repository.
