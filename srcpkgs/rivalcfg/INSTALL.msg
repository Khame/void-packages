The rivalcfg udev rules are installed in /usr/lib/udev/rules.d.

To apply them without rebooting, run as root:

    udevadm control --reload-rules
    udevadm trigger

Access to SteelSeries devices is granted to the "plugdev" group. Add
your user with: usermod -aG plugdev <user>, then log in again.
