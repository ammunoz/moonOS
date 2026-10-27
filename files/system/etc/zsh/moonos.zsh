# The moonOS shell setup for zsh.
#
# This file is sourced from /etc/zshrc, which zsh reads for every
# interactive shell, so it applies to every account - the ones created
# before the image was built as well as the ones created after it.
#
# A user's own ~/.zshrc is read after this, so anything set here can be
# overridden there.

# The starship prompt.
#
# starship's init is idempotent - it registers its hooks with add-zsh-hook,
# which does not add the same function twice - so running it again in a
# ~/.zshrc is harmless.
if (( $+commands[starship] )); then
	eval "$(starship init zsh)"
fi

# Use the prompt theme the image ships, unless the user has a config of
# their own. starship has no system-wide configuration path, so this is
# how the theme reaches every account.
if [[ -z "${STARSHIP_CONFIG:-}" && ! -f "${XDG_CONFIG_HOME:-$HOME/.config}/starship.toml" ]]; then
	export STARSHIP_CONFIG=/usr/share/moonos/starship.toml
fi

# Type-ahead completion: the completion menu appears while you type, Tab
# inserts the top match and the arrow keys pick another one.
#
# It replaces zsh's own completion setup, so it must not be combined with
# a compinit call.
if [[ -r /usr/share/zsh-autocomplete/zsh-autocomplete.plugin.zsh ]]; then
	source /usr/share/zsh-autocomplete/zsh-autocomplete.plugin.zsh
fi
