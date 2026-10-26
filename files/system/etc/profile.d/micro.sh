# micro is the only editor on moonOS.
#
# The systemd environment.d file covers graphical sessions and services; this
# covers login shells. Anything that is already set by the user is left alone.
if [ -z "${EDITOR:-}" ]; then
	export EDITOR="/usr/bin/micro"
fi

if [ -z "${VISUAL:-}" ]; then
	export VISUAL="/usr/bin/micro"
fi

if [ -z "${GIT_EDITOR:-}" ]; then
	export GIT_EDITOR="/usr/bin/micro"
fi
