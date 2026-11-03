The optional KDE Plasma widget is provided by the asusctl-plasma subpackage.

Install it and its runtime components with:

    xbps-install asusctl-plasma

The upstream asus-shutdown helper is not included: it waits for a
PrepareForShutdown signal from logind and calls systemctl, so it cannot do
its work under runit. asusd is started by the asusd runit service instead.
