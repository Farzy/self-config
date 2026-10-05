# Read by every zsh — interactive, login, and plain `zsh -c` scripts alike —
# before .zprofile/.zshrc. Keep it to environment variables: anything that
# prints, prompts or is slow runs for every script too.

# Load environment variables from ~/.env if present. Here rather than in .zshrc
# so non-interactive shells (cron jobs, `ssh host cmd`, agent and editor tool
# shells) see them as well.
if [ -s "${HOME}/.env" ]; then set -a; source "${HOME}/.env"; set +a; fi
