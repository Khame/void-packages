# Licenses in this repository

This repository mixes material under different licenses. The root `LICENSE`
(MIT) covers **only what Khame wrote**. Everything derived from upstream keeps
the license of that upstream.

| Path | License | Why |
| --- | --- | --- |
| `srcpkgs/*/template` | MIT | Packaging recipes written here |
| `srcpkgs/asusctl/files/asusd*/`, `xdg-autostart/`, `asusd-user-session`, `*.msg`, `REMOVE` | MIT | Packaging glue written here (runit services, autostart, install messages) |
| `srcpkgs/asusctl/files/plasmoid/` | MIT | Own KDE Plasma widget. Shipped in the `asusctl-plasma` package, which declares `license="MIT"` and installs its own license text |
| `srcpkgs/asusctl/patches/*.patch` | MPL-2.0 | Modifications of upstream asusctl files (MPL-2.0) |
| `srcpkgs/doublecmd/patches/*.patch` | Same as the file each patch changes | Mostly GPL-2.0-or-later; 0002, 0005 and 0006 touch LGPL or MPL-1.1 files. Per-directory licenses are listed in upstream's `install/linux/deb/doublecmd/copyright` |
| `srcpkgs/doublecmd/files/licenses/CC0-1.0.txt`, `Apache-2.0.txt` | CC0-1.0, Apache-2.0 | Canonical license texts for bundled KAScrypt components |
| `srcpkgs/doublecmd/files/licenses/SOURCE-AVAILABILITY.txt` | MIT | Packaging notice giving the source URL required by UReSample's terms |
| `srcpkgs/*/PATCHES.md`, `docs/index.html` | MIT | Documentation written here |
| `docs/*.xbps`, `docs/*-repodata` | License of the packaged software | Binary packages built from the templates above |

## Packaged software

| Package | Upstream | Upstream license | `license=` in the template |
| --- | --- | --- | --- |
| `asusctl` | https://github.com/OpenGamingCollective/asusctl | MPL-2.0 | `MPL-2.0` |
| `asusctl-plasma` | own widget | MIT (own work) | `MIT` |
| `doublecmd` | https://github.com/doublecmd/doublecmd | GPL-2.0-or-later, with bundled components under other licenses | SPDX-style expression listing them all, including Void custom refs for TDiff and UReSample |

### Notes

* `rog-control-center` (part of `asusctl`) is built with Slint, which upstream
  asusctl pulls in as a dependency. Slint is offered as
  `GPL-3.0-only OR LicenseRef-Slint-Royalty-free-2.0 OR LicenseRef-Slint-Software-3.0`.
  The choice among these is upstream's. The `asusctl` template keeps
  `MPL-2.0`, the license of the asusctl source itself.
* `doublecmd` bundles third-party code (see the template's `license=` line).
  The notices that must accompany binaries (X11, Zlib, BSD, bzip2, Boost, CC0,
  Apache, and the MIT text of `inflate64` in the zip plugin) are installed to
  `/usr/share/licenses/doublecmd/`. Upstream's `copyright` file does not list
  `inflate64` or the KAScrypt CC0/Apache grants, so these were found by scanning
  the source tree. Argon2 and BLAKE3 permit either CC0-1.0 or Apache-2.0; BLAKE2
  is CC0-1.0. Both license texts are shipped, as requested by the Argon2 header.
  The package also includes Public Domain units, the TDiff freeware terms, and
  UReSample's custom source-availability terms in `COPYRIGHT.thirdparty`. The
  installed `SOURCE-AVAILABILITY.txt` gives the direct source URL required by
  UReSample's license.
* The unrar plugin of Double Commander is only a wrapper. `libunrar` is not
  bundled or distributed here.

## Sources

Binary packages are built from the templates and patches in this repository
plus the upstream sources named in each template (`distfiles` and `checksum`).
