# Local patches for asusctl

This package carries four local patches against upstream commit
[`13cdaa9ccbc0b519d3c888c1c9d97e00faf91cf9`](https://github.com/OpenGamingCollective/asusctl/tree/13cdaa9ccbc0b519d3c888c1c9d97e00faf91cf9).
They are kept here (not sent upstream) so that this Void package behaves
correctly on the maintainer's laptop. Re-check them on every version bump.

## 1. `0001-aura-register-logind-sleep-handler.patch`

**Symptom:** after suspend/resume the ASUS ROG keyboard backlight stayed dark
until reboot. `asusctl leds set …` worked, but resume never restored the
configured brightness/mode.

**Cause:** `AuraZbus::start_tasks()` in `asusd/src/aura_laptop/trait_impls.rs`
never called `create_tasks()`. Upstream had commented it out with a `TODO`
because the handle to the tasks was dropped when `self` was moved into the
D-Bus object server. As a result the logind `PrepareForSleep` handler was never
registered in `asusd` — the log contained no
`CtrlKbdLedTask reloading brightness and modes` line after resume.

**Fix:** keep a clone of the controller alive, call `create_tasks()` after
`add_to_server()`, and let the tasks be registered.

**Verification after resume** (`/var/log/asusd/current`):

```sh
grep 'CtrlKbdLedTask reloading brightness and modes' /var/log/asusd/current | tail
asusctl leds get   # must match /etc/asusd/aura_*.ron
```

**Upstream status:** not fixed as of `13cdaa9` (checked 2026-10-28); the `TODO`
and the commented-out call are still present.

## 2. `0002-asusd-user-create-runtime-after-blocking-setup.patch`

**Symptom:** `asusd-user` exited immediately at login with:

```
thread 'main' panicked at …:
Cannot start a runtime from within a runtime
```

**Cause:** `#[tokio::main]` entered the Tokio runtime before the zbus
**blocking** proxies (`AnimeProxyBlocking::new`, `AuraProxyBlocking::new`)
were created. zbus blocking objects call `Runtime::block_on` internally, and
Tokio panics when that happens while a runtime is already running on the same
thread.

**Fix:** turn `main` into a plain `fn main()`, do every blocking setup step
first, then build a `current_thread` Tokio runtime and run the async server
tasks inside `block_on()`. No behaviour change other than not panicking.

**Verification:**

```sh
asusd-user --help        # must not panic (it may exit 0 or print usage)
pgrep -a asusd-user      # should stay alive when started from the session
```

## 3. `0003-aura-keep-runtime-state-and-brightness-on-sleep.patch`

Two defects in the same function, `Aura::update_config()`, which patch 1 now
calls on every sleep/wake.

**Symptom A — the GUI cannot change anything after a resume:**
`rog-control-center` reports "LED mode failed" for every colour/mode change and
brightness changes do not stick. D-Bus confirms the rejection:

```sh
busctl --system set-property xyz.ljones.Asusd /xyz/ljones/aura/*_*_* \
  xyz.ljones.Aura LedModeData '(uu(yyy)(yyy)ss)' 0 0 255 0 0 0 0 0 Med Right
# The Aura effect is not supported: AuraEffect { mode: Static, zone: None, ... }
```

`SupportedBasicZones` / `SupportedPowerZones` also read back empty even though
the model's support data has zones.

**Cause A:** `update_config()` calls `StdConfig::read()`, which does
`*self = ron::from_str(file)`. The `#[serde(skip)]` fields (`led_type`,
`support_data`, `per_key_mode_active`) are not in the file, so they are reset
to their defaults. With empty `support_data`, `set_led_mode_data()` rejects
every effect as unsupported and the zone lists come back empty. A restart of
`asusd` restored them — which is why the GUI worked until the first suspend.

**Fix A:** snapshot `led_type`, `support_data` and `per_key_mode_active` before
`read()` and restore them afterwards.

**Symptom B — keyboard dark after suspend/hibernate:** `/etc/asusd/aura_*.ron`
contained `brightness: Off` although the user never chose Off.

**Cause B:** the same `update_config()` saved the current sysfs value of
`asus::kbd_backlight`. KDE PowerDevil (and/or the firmware) turns that LED off
while the screen blanks / prepares to sleep, so asusd persisted the transient
`Off`, and the resume handler correctly restored `Off`.

**Fix B:** ignore a zero reading when saving. A user-chosen `Off` is already in
the config (written by the D-Bus brightness setter); non-zero changes made
through desktop power management are still persisted.

**Verification:**

```sh
asusctl leds set med
grep brightness /etc/asusd/aura_*.ron          # must stay Med, not Off
grep 'CtrlKbdLedTask reloading brightness and modes' /var/log/asusd/current | tail
# after a resume, the GUI must still change colour/mode/brightness
busctl --system get-property xyz.ljones.Asusd /xyz/ljones/aura/*_*_* \
  xyz.ljones.Aura SupportedBasicZones          # must not be empty
```

**Upstream status:** not fixed as of `13cdaa9` (checked 2026-10-28); the
`update_config()` call is still in the `sleeping` branch and still does a bare
`read()`. This patch depends on patch 1, which registers the sleep handler.

## 4. `0004-asusd-user-only-direct-address-per-key-keyboards.patch`

**Symptom:** `asusd-user` logged, on every session start:

```
ERROR: Aura direct addressing error: org.freedesktop.DBus.Error.UnknownObject:
       Unknown object '/xyz/ljones/Aura'
```

It was invisible while the autostart entry sent stdout to `/dev/null`; it
became visible once `asusd-user-session` started keeping the log.

**Cause:** `asusd-user` always created an `AuraProxyBlocking` for the legacy
object path `/xyz/ljones/Aura` and ran a 30 Hz direct-addressing loop, for every
keyboard. That object only exists for per-key keyboards; on plain and zoned Aura
keyboards `asusd` applies the effects itself, so the call fails and the loop
exits. Upstream still has the intended guard commented out
(`// if supported.keyboard_led.per_key_led_mode {`).

**Fix:** restore the guard, based on the detected keyboard type
(`LedSupportData::advanced_type == AdvancedAuraType::PerKey`) instead of the
user config, which defaults to `Some(...)`.

**Verification:** after a new login there is no `Aura direct addressing error`
in `~/.local/state/asusd/asusd-user.log`, and normal (non-per-key) Aura
control still works.

**Upstream status:** not fixed as of `13cdaa9` (checked 2026-10-28); the guard
is still commented out.

## Live verification (2026-10-28, revision 6)

Task: suspend/hibernate with all three patches, then resume and drive the GUI.

Result — pass:

- `PrepareForSleep(true)` 20:11:52 UTC → `PrepareForSleep(false)` 20:13:13 UTC,
  same boot id (real resume, not a fresh boot).
- `/var/log/asusd/current` contains two `CtrlKbdLedTask reloading brightness
  and modes` lines after the wake (patch 1).
- `/etc/asusd/aura_1866.ron` still had `brightness: High`; sysfs
  `asus::kbd_backlight` = 3 and the keyboard was lit (patch 3, part 2).
- `SupportedBasicZones` returned `au 4 1 2 3 4` and `SupportedPowerZones`
  `au 2 1 2` after the resume; `SetLedModeData` succeeded and
  `rog-control-center` could change colour, mode and brightness (patch 3,
  part 1).
- `asusd-user` runs without the `Cannot start a runtime from within a runtime`
  panic (patch 2).

Before revision 6 the same test left the keyboard dark and the Aura properties
reported no zones, so all three patches are required on this hardware
(G513Q / Aura type 1866, Void Linux, runit + elogind, no systemd).

Revision 7 additionally ships the layouts in `/usr/share/rog-gui/layouts/`, the
`aura_support.ron` database and a logging `asusd-user-session` wrapper. After
installing it and restarting the session daemon, `asusd-user.log` shows
`Loaded default LED support data from /usr/share/asusd/aura_support.ron` and
`Matched to G513Q` with no `IO Error` and no `Aura direct addressing error`
(patch 4); `asusctl leds get` still reports `High`.

## Known upstream behaviour, intentionally not patched

After resume, elogind delivers `PrepareForSleep(false)` more than once, so with
both the platform and Aura subscribers registered the log shows four
`Doing on_prepare_for_sleep(false)` lines and patch 1's handler runs twice
(`CtrlKbdLedTask reloading brightness and modes`). Before patch 1 there was only
one subscriber, but the wake signal was still delivered twice. The handler is
idempotent — it applies the same brightness/mode twice — so this is harmless.
Not patched and not reported upstream.

## Re-checking against a new upstream release

Look at `asusd/src/aura_laptop/trait_impls.rs` (is `create_tasks()` called? does
the `sleeping` branch still call `update_config()`?) and
`asusd-user/src/daemon.rs` (is `main` still `#[tokio::main]`? is the per-key
guard still commented out?). Drop a patch only after a local build **and** a
live resume/login test — a clean compile does not prove the handler runs.

Current package revision with these patches: `revision=7`, upstream commit
`13cdaa9`.
