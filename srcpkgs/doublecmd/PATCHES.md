# Patches

All eleven patches exist because Void ships `fpc 3.2.0` / `lazarus 2.2.0`,
while Double Commander 1.2.9 asks for FPC >= 3.2.2 and Lazarus >= 3.0
(`doc/INSTALL.txt`). They are the minimum needed to build against the older
toolchain. None removes or changes a feature; a few have small cosmetic side
effects, called out in the individual entries below.

## 0001-lazbuild-dir.patch

**What:** `build.sh` no longer overwrites an already exported `lazbuild`
command; it falls back to `which lazbuild` only when the variable is unset.

**Why:** Void's `lazarus` package installs no `environmentoptions.xml`, so
`lazbuild` cannot work out its own data directory and aborts with
`invalid Lazarus directory ""`. The template exports
`lazbuild="/usr/bin/lazbuild --lazarusdir=/usr/lib/lazarus"` before calling
`build.sh`, which upstream's unconditional `export lazbuild=$(which lazbuild)`
would discard.

**Upstream status:** not submitted. A cleaner fix would be for `build.sh` to
honour `LAZARUSDIR` or an existing `lazbuild` variable.

**Still needed?** Only while the template calls `build.sh`; if the template
ever calls `lazbuild` directly this patch can go.

## 0002-fpc-3.2.0-ioctl-request.patch

**What:** `FS_IOC_GETFLAGS` becomes `LongInt($80086601)` instead of the
untyped `$80086601`.

**Why:** FPC 3.2.0 declares `TIOCtlRequest = cInt` on Linux
(`rtl/linux/ptypes.inc`), so the 0x80086601 request does not fit in a signed
32-bit constant and the compiler stops with
`range check error while evaluating constants`. FPC 3.2.2 changed the type to
`culong`. The bit pattern is unchanged: the compiler zero-extends the 32-bit
value into the argument register, so the kernel sees 0x80086601.

**Upstream status:** not needed upstream, which requires 3.2.2.

**Still needed?** Only while Void ships FPC < 3.2.2. Drop it when `fpc` is
bumped.

## 0003-fpc-3.2.0-strtouintdef.patch

**What:** adds a local `StrToUIntDef()` to `src/platform/unix/uusersgroups.pas`.

**Why:** `StrToUIntDef()` was added to `SysUtils` in FPC 3.2.2.
`uusersgroups.pas` calls it when `getpwnam()`/`getgrnam()` fail, so the unit
does not compile with 3.2.0. The local copy has the same semantics: invalid
input yields the supplied default.

**Upstream status:** not needed upstream, which requires 3.2.2.

**Still needed?** Only while Void ships FPC < 3.2.2.

## 0004-lazarus-2.2-tspeedbutton-alignment.patch

**What:** replaces `Self.Alignment` with `taLeftJustify` when drawing
`TKASToolLabel` captions.

**Why:** `TSpeedButton.Alignment` was added in Lazarus 3.0; `TKASToolLabel`
derives from `TSpeedButton`. DC never sets `Alignment` on these labels, so the
LCL default (left) is the correct fixed value.

**Upstream status:** not needed upstream, which requires Lazarus >= 3.0.

**Still needed?** Only while Void ships Lazarus 2.2.0. If `lazarus` is bumped
to 3.x, drop it.

## 0005-fpc-3.2.0-jcl-interface-calling-convention.patch

**What:** in the bundled JCL copy used by the sevenzip plugin, the
`IInterface` overrides `_AddRef`/`_Release` use `winapi` on Windows and
`cdecl` elsewhere instead of `winapi` everywhere.

**Why:** FPC 3.2.0 treats `winapi` as `stdcall`, while `IUnknown._AddRef` and
`_Release` are `cdecl` outside Windows, so every class implementing the
interface fails with
`No matching implementation for interface method "_AddRef:LongInt; CDecl"`.
The other `winapi` occurrences in that unit belong to JCL's own COM
interfaces and are internally consistent, so they are untouched.

**Upstream status:** not submitted; the bundled JCL is a vendored copy inside
the sevenzip plugin.

**Still needed?** Only while Void ships FPC < 3.2.2.

## 0006-fpc-3.2.0-sevenzip-messagebox-convention.patch

**What:** `TMessageBoxFunction` in the sevenzip plugin uses `winapi` on
Windows and `cdecl` elsewhere.

**Why:** the `MessageBox` pointer supplied by the plugin API is `cdecl` outside
Windows, so assigning it to a `winapi` procedure variable fails with
`Incompatible types: got "...;CDecl" expected "...;Register"`.

**Upstream status:** not submitted; same bundled plugin as 0005.

**Still needed?** Only while Void ships FPC < 3.2.2.

## 0007-lazarus-2.2-lcl-min-version.patch

**What:** `src/doublecmd.lpi` asks for `LCL >= 3.0`; the minimum is lowered to
2.2.

**Why:** lazbuild refuses to build with
`Project: doublecmd uses LCL (>=3.0), but found LCL 2.2.0.4`. The only 3.0
API 1.2.9 relies on is `TSpeedButton.Alignment`, covered by patch 0004.

**Upstream status:** not needed upstream, which requires Lazarus >= 3.0.

**Still needed?** Only while Void ships Lazarus 2.2.0. With the version floor
removed, a future release that uses more 3.0 API is no longer caught by the
dependency check and only shows up as a compile error (or a subtle
difference) during a build, so always recompile in full when bumping the
upstream version.

## 0008-lazarus-2.2-synedit-ini-commenttypes.patch

**What:** drops the `CommentTypes := [ictSemicolon, ictHash]` assignment from
`TSynIniSynEx.Create`.

**Why:** `TSynIniSyn.CommentTypes` and the `ict*` enum were added in Lazarus
3.0's SynEdit. Cosmetic only: with 2.2.0 the INI highlighter colours `;`
comments but not `#` ones.

**Upstream status:** not needed upstream, which requires Lazarus >= 3.0.

**Still needed?** Only while Void ships Lazarus 2.2.0.

## 0009-lazarus-2.2-grid-smooth-scroll.patch

**What:** thumbnail view wheel handler calls `ScrollBy()` and marks the event
handled, instead of `TrySmoothScrollBy()`.

**Why:** `TCustomGrid.TrySmoothScrollBy()` was added in Lazarus 3.0. The only
behavioural difference is that a scroll attempted at the grid boundary no
longer falls through to the parent control.

**Upstream status:** not needed upstream, which requires Lazarus >= 3.0.

**Still needed?** Only while Void ships Lazarus 2.2.0.

## 0010-lazarus-2.2-fmain-speedbutton-alignment.patch

**What:** drops `Button.Alignment := taLeftJustify` in the drive-info tool
button setup.

**Why:** same `TSpeedButton.Alignment` as patch 0004 (Lazarus 3.0). Patch 0004
already draws `TKASToolLabel` captions left-aligned, which is exactly what
this line requests, so it is redundant on 2.2.0.

**Upstream status:** not needed upstream.

**Still needed?** Only while Void ships Lazarus 2.2.0.

## 0011-lazarus-2.2-image-list-properties.patch

**What:** `AssignRetinaBitmapForControl` assigns the bitmap to
`TCustomImage.Picture` instead of putting it into a `TImageList` and setting
`Images`/`ImageWidth`/`ImageIndex`.

**Why:** those three properties were added to `TCustomImage` in Lazarus 3.0.
With 2.2.0 the HiDPI scale factor is not applied to the bitmap; the control
geometry still decides the displayed size.

**Upstream status:** not needed upstream.

**Still needed?** Only while Void ships Lazarus 2.2.0. Worth re-testing HiDPI
icon rendering when the toolchain is bumped.
