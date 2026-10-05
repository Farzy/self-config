# Read by every zsh — interactive, login, and plain `zsh -c` scripts alike —
# before .zprofile/.zshrc. Keep it to environment variables: anything that
# prints, prompts or is slow runs for every script too.
#
# Keep in sync with roles/master_setup/templates/dotfiles/.zshenv (same ~/.env
# loader; that copy also carries an OpenClaw-only block).

# Load environment variables from ~/.env if present. Here rather than in .zshrc
# so non-interactive shells (cron jobs, `ssh host cmd`, agent and editor tool
# shells) see them as well.
#
# Only once per process tree: the values are exported, so child shells inherit
# them, and re-sourcing in every child would silently overwrite variables a
# caller set on purpose (`GITHUB_TOKEN=other zsh -c ...`). A side effect: an
# edit to ~/.env reaches new terminal windows, not shells started from one that
# already loaded it (or panes of a running tmux server).
if [[ -z ${DOTENV_LOADED-} && -s "${HOME}/.env" ]]; then
    set -a; source "${HOME}/.env"; set +a
    export DOTENV_LOADED=1
fi
