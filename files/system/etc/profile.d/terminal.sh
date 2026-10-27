# The terminal the Noctalia shell launches for applications that ask for
# one. The same is set for systemd sessions and graphical sessions in
# /usr/lib/environment.d/95-terminal.conf; this file covers login shells.
export TERMINAL="${TERMINAL:-kitty}"
