# The moonOS defaults for a new account.
#
# The prompt and the type-ahead completion are set up system-wide in
# /etc/zsh/moonos.zsh, which zsh reads before this file, so they are not
# repeated here. What is left is the history and the few options that
# belong to the user rather than to the image.
#
# Note that there is no compinit call here: the type-ahead completion
# takes over zsh's completion system, and the two do not go together.

# History shared between the sessions of one user.
setopt SHARE_HISTORY
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_SAVE_NO_DUPS
setopt HIST_REDUCE_BLANKS

# A prompt that does not beep at the terminal.
setopt NO_BEEP
