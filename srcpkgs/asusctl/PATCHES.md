# Local patches for asusctl

This package carries six local patches against upstream commit
[`13cdaa9ccbc0b519d3c888c1c9d97e00faf91cf9`](https://github.com/OpenGamingCollective/asusctl/tree/13cdaa9ccbc0b519d3c888c1c9d97e00faf91cf9).
They stay here, not upstream, because they only fix what breaks on my laptop.
Check them again on every version bump.

## 1. The sleep handler was never registered

`0001-aura-register-logind-sleep-handler.patch`

After suspend or resume the keyboard backlight stayed dark until reboot.
`asusctl leds set` worked, but waking up never restored the brightness or the
mode.

`AuraZbus::start_tasks()` in `asusd/src/aura_laptop/trait_impls.rs` never called
`create_tasks()`. Upstream had it commented out with a TODO, because the handle
to the tasks died when `self` was moved into the D-Bus object server. The logind
`PrepareForSleep` handler was therefore never registered, and the log had no
`CtrlKbdLedTask reloading brightness and modes` line after a resume.

The patch keeps a clone of the controller alive and calls `create_tasks()` after
`add_to_server()`.

To check it after a resume:

```sh
grep 'CtrlKbdLedTask reloading brightness and modes' /var/log/asusd/current | tail
asusctl leds get   # must match /etc/asusd/aura_*.ron
```

Upstream still has the TODO and the commented-out call at `13cdaa9`
(checked 2026-10-28).

## 2. asusd-user panicked at login

`0002-asusd-user-create-runtime-after-blocking-setup.patch`

`asusd-user` exited right away with:

```
thread 'main' panicked at …:
Cannot start a runtime from within a runtime
```

`#[tokio::main]` entered the Tokio runtime before the zbus blocking proxies
(`AnimeProxyBlocking::new`, `AuraProxyBlocking::new`) were built. Those call
`Runtime::block_on` internally, and Tokio panics when that happens on a thread
that already runs a runtime.

`main` is now a plain `fn main()`. All blocking setup happens first, then a
`current_thread` runtime is built and the async server tasks run inside
`block_on()`. Nothing else changed.

Check:

```sh
asusd-user --help        # must not panic
pgrep -a asusd-user      # stays alive when the session starts it
```

## 3. Sleep wiped runtime state and the chosen brightness

`0003-aura-keep-runtime-state-and-brightness-on-sleep.patch`

Two bugs in one function, `Aura::update_config()`, which patch 1 made run on
every sleep and wake.

First: after a resume the GUI could not change anything. `rog-control-center`
reported "LED mode failed" for every colour or mode change and brightness would
not stick. D-Bus showed the rejection:

```sh
busctl --system set-property xyz.ljones.Asusd /xyz/ljones/aura/*_*_* \
  xyz.ljones.Aura LedModeData '(uu(yyy)(yyy)ss)' 0 0 255 0 0 0 0 0 Med Right
# The Aura effect is not supported: AuraEffect { mode: Static, zone: None, ... }
```

`SupportedBasicZones` and `SupportedPowerZones` also came back empty, even
though the support data for this model has zones. The cause is
`StdConfig::read()`, which does `*self = ron::from_str(file)`. The
`#[serde(skip)]` fields (`led_type`, `support_data`, `per_key_mode_active`) are
not in the file and get reset to their defaults. With empty `support_data`,
`set_led_mode_data()` rejects every effect and the zone lists come back empty.
Restarting `asusd` fixed it, which is why the GUI worked until the first
suspend. The patch saves those three fields before `read()` and puts them back
afterwards.

Second: the keyboard was dark after suspend or hibernate, and
`/etc/asusd/aura_*.ron` said `brightness: Off` even though I never chose Off.
The same `update_config()` wrote the current sysfs value of
`asus::kbd_backlight`, and KDE PowerDevil (or the firmware) turns that LED off
while the screen blanks. asusd saved the transient Off, and the resume handler
then restored it faithfully. The patch ignores a zero reading when saving. A
real Off is already in the config from the D-Bus brightness setter, and non-zero
changes made by power management are still saved.

Check:

```sh
asusctl leds set med
grep brightness /etc/asusd/aura_*.ron          # must stay Med, not Off
grep 'CtrlKbdLedTask reloading brightness and modes' /var/log/asusd/current | tail
# after a resume the GUI must still change colour, mode and brightness
busctl --system get-property xyz.ljones.Asusd /xyz/ljones/aura/*_*_* \
  xyz.ljones.Aura SupportedBasicZones          # must not be empty
```

Upstream still calls `update_config()` from the `sleeping` branch and still does
a bare `read()` at `13cdaa9` (checked 2026-10-28). This patch needs patch 1,
because that is what registers the handler.

## 4. Direct addressing ran on keyboards without per-key support

`0004-asusd-user-only-direct-address-per-key-keyboards.patch`

Every session start logged this:

```
ERROR: Aura direct addressing error: org.freedesktop.DBus.Error.UnknownObject:
       Unknown object '/xyz/ljones/Aura'
```

Nobody saw it while the autostart entry sent stdout to `/dev/null`. It appeared
once `asusd-user-session` started keeping the log.

`asusd-user` always created an `AuraProxyBlocking` for the legacy path
`/xyz/ljones/Aura` and ran a 30 Hz direct-addressing loop, whatever keyboard was
installed. That object only exists for per-key keyboards. On plain and zoned
keyboards `asusd` applies the effects itself, so the call fails and the loop
exits. Upstream still has the intended guard commented out
(`// if supported.keyboard_led.per_key_led_mode {`).

The patch turns the guard back on and bases it on the detected keyboard type
(`LedSupportData::advanced_type == AdvancedAuraType::PerKey`) rather than the
user config, which defaults to `Some(...)`.

After the next login there should be no `Aura direct addressing error` in
`~/.local/state/asusd/asusd-user.log`, and normal Aura control still works.

Upstream still has the guard commented out at `13cdaa9` (checked 2026-10-28).

## 5. Startup restored the effect but not the brightness

`0005-aura-apply-brightness-on-startup.patch`

After a normal boot the keyboard was lit exactly as before the poweroff, but
`asusctl leds get` printed `Off`, the rog-control-center slider sat at zero and
`asusctl leds next` went Off to Low, dimming the keyboard instead of turning it
off.

`reload()` runs when the daemon starts and reapplies the power states and the
Aura effect, but never `config.brightness`. The kernel LED class
(`/sys/class/leds/asus::kbd_backlight/brightness`) starts at 0 and stays there,
so everything that reads it thinks the keyboard is off. The EC keeps the
physical level from before the shutdown, which is why the keys were still lit.
On resume the sleep handler hid the same gap, because it reapplies brightness by
itself.

The patch writes `config.brightness` through `set_brightness()` after applying
the mode, so sysfs, the config and the hardware agree. On a device without the
LED class it only logs a warning and the daemon keeps running.

Check it by restarting `asusd` or rebooting with `brightness: High` in
`/etc/asusd/aura_1866.ron`. `asusctl leds get` must print `High`, sysfs must read
`3`, and the lighting must not change.

Upstream still ends `reload()` after `write_current_config_mode()` at `13cdaa9`
(checked 2026-10-29).

## 6. One wake reloaded the keyboard twice

`0006-dedupe-logind-sleep-signals.patch`

After patch 1 the backlight came back after every resume, but the log showed the
same work twice:

```
[DEBUG asusd] Doing on_prepare_for_sleep(false)
[INFO  asusd::aura_laptop::trait_impls] CtrlKbdLedTask reloading brightness and modes
[DEBUG asusd] Doing on_prepare_for_sleep(false)
[INFO  asusd::aura_laptop::trait_impls] CtrlKbdLedTask reloading brightness and modes
```

elogind delivers `PrepareForSleep(false)` more than once for one resume. Every
subscriber opens its own connection in `create_sys_event_tasks()`, so each
subscriber sees the repeat and runs its handler again. The handler writes the
same brightness and mode both times, so nothing was visibly broken, but the
second pass is wasted work on every wake.

The patch remembers the last value and when it arrived, inside
`asusd/src/lib.rs`. A signal identical to the previous one within 2 seconds is
logged as `Ignoring repeated on_prepare_for_sleep(...)` and skipped. A different
value always goes through, so `true` followed by `false` is never swallowed and
a real resume still reaches the handler.

Check it after a suspend and resume:

```sh
grep -c 'Ignoring repeated on_prepare_for_sleep' /var/log/asusd/current
grep 'reloading brightness and modes' /var/log/asusd/current | tail -3
```

There should be one `Ignoring repeated` line per subscriber and a single reload
for the wake.

Upstream has no de-duplication at `13cdaa9` (checked 2026-10-29).

## What the tests showed

On 2026-10-28 I suspended and hibernated with revision 6, resumed, then used the
GUI.

`PrepareForSleep(true)` went out at 20:11:52 UTC and `PrepareForSleep(false)`
came back at 20:13:13 UTC with the same boot id, so it was a real resume.
`/var/log/asusd/current` had two `CtrlKbdLedTask reloading brightness and modes`
lines after the wake (patch 1). `/etc/asusd/aura_1866.ron` still said
`brightness: High`, sysfs read 3 and the keyboard was lit (patch 3, second
part). `SupportedBasicZones` returned `au 4 1 2 3 4` and `SupportedPowerZones`
returned `au 2 1 2`; `SetLedModeData` succeeded and the GUI could change colour,
mode and brightness (patch 3, first part). `asusd-user` ran without the runtime
panic (patch 2).

Before revision 6 the same test left the keyboard dark and the Aura properties
reported no zones, so all three patches are needed on this hardware: G513Q,
Aura type 1866, Void with runit and elogind, no systemd.

Revision 7 added the layouts in `/usr/share/rog-gui/layouts/`, the
`aura_support.ron` database and a logging `asusd-user-session` wrapper. After
installing it and restarting the session daemon, `asusd-user.log` showed
`Loaded default LED support data from /usr/share/asusd/aura_support.ron` and
`Matched to G513Q`, with no `IO Error` and no `Aura direct addressing error`
(patch 4). `asusctl leds get` still reported `High`.

Revision 8 was checked on 2026-10-29 by writing 0 to
`/sys/class/leds/asus::kbd_backlight/brightness` and restarting `asusd`. The
value came back to 3, `asusctl leds get` printed `High`, and the log had a
`reloading brightness` line with no errors (patch 5).

Revision 9 was checked on the same day with a suspend and resume. Two
`PrepareForSleep(false)` signals arrived at 11:18:15 UTC. The log has two
`Doing on_prepare_for_sleep(false)` lines, one per subscriber, then two
`Ignoring repeated on_prepare_for_sleep(false)` lines. The Aura handler reloaded
the keyboard once, not twice (patch 6). It came back lit and `asusctl leds get`
printed `High`.

Note that `busctl emit` cannot be used to test this: zbus matches the signal
sender, and a signal from another connection does not reach the handler.

## Where the duplicate signals come from

elogind sends `PrepareForSleep(false)` more than once for a single resume. Even
before patch 1, when only one subscriber existed, the wake signal arrived twice.
Patch 1 made that visible because the Aura handler now runs at all: four
`Doing on_prepare_for_sleep(false)` lines, two per subscriber, and two reloads.
Patch 6 keeps the first pass and drops the repeat. Nothing was sent upstream.

## Checking a new upstream release

Start with `asusd/src/aura_laptop/trait_impls.rs`: is `create_tasks()` called,
and does the `sleeping` branch still call `update_config()`? Then
`asusd-user/src/daemon.rs`: is `main` still `#[tokio::main]`, and is the per-key
guard still commented out? Then `asusd/src/lib.rs`: does
`create_sys_event_tasks()` still forward every `PrepareForSleep` it receives?
Drop a patch only after a local build and a real resume or login. A clean compile
does not prove the handler runs.

Current package revision with these patches: `revision=9`, upstream commit
`13cdaa9`.
