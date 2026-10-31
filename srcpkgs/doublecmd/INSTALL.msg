Double Commander runs natively on Wayland: the qt5 platform plugin is part
of the dependencies. On X11 sessions it uses xcb instead.

Two console lines are normal and not errors of this package:

  Error loading configuration file .../favoritetabs.xml

shows up on every start until the first favourite tabs set is saved, and

  Wayland does not support QWindow::requestActivate()

is a Wayland limitation that every Qt application reports.

Archive support comes from the bundled WCX plugins in
/usr/lib/doublecmd/plugins: zip, sevenzip, unrar, deb, rpm, cpio, base64.
