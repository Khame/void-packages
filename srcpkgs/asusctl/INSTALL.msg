The KDE Plasma widget is installed system-wide at

    /usr/share/plasma/plasmoids/org.voidlinux.plasma.asusctl

It needs KDE Plasma 6. On a system without it the widget is simply unused;
nothing else in this package depends on Plasma.

Install the runtime components with:

    xbps-install plasma-workspace kf6-kirigami plasma5support

The upstream asus-shutdown helper is not included: it waits for a
PrepareForShutdown signal from logind and calls systemctl, so it cannot do
its work under runit. asusd is started by the asusd runit service instead.
