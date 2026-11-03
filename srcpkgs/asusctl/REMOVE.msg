If asusd was enabled, its runit service was stopped during removal.

The administrator-owned service link was left in place:
  /var/service/asusd

Remove it manually if asusd will not be reinstalled:
  sudo rm /var/service/asusd
