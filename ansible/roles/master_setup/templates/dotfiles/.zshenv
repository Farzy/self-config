# Read by every zsh — interactive, login, and plain `zsh -c` scripts alike —
# before .zprofile/.zshrc. Keep it to environment variables: anything that
# prints, prompts or is slow runs for every script too.
#
# Keep the ~/.env loader in sync with roles/laptop_setup/templates/dotfiles/.zshenv
# (same block). This copy also carries the OpenClaw-only block below, which the
# laptop has no use for.

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
{% if openclaw_setup_user is defined %}
{# Same guard as .zshrc and .gitconfig in this directory: `openclaw_setup_user`
   is only in scope on plays that include the openclaw_setup role. #}

# GitHub CLI authentication for the OpenClaw account: gh — and git, through the
# `gh auth git-credential` helper in .gitconfig — reads GH_TOKEN from the
# environment, so this account needs no `gh auth login` and keeps no token in a
# gh config file. The value comes from the openclaw_setup role's secrets.env
# (Ansible Vault, not git-tracked). Surrounding double quotes are stripped
# because systemd's EnvironmentFile format allows them, and an empty value is
# not exported: gh treats an empty GH_TOKEN as "authenticated" and then fails
# every call.
#
# Here rather than in .zshrc so non-interactive shells get it too, including the
# agent's own exec sandbox (`zsh -c '...'`). $USERNAME is zsh's built-in, so the
# guard costs no fork in every other account's shells. See docs/openclaw.md §6.3.
if [[ $USERNAME == "{{ openclaw_setup_user }}" && -r /etc/openclaw/secrets.env ]]; then
    _gh_token="$(sed -n 's/^GITHUB_TOKEN=//p' /etc/openclaw/secrets.env | head -n1)"
    _gh_token="${_gh_token#\"}"
    _gh_token="${_gh_token%\"}"
    if [[ -n "${_gh_token}" ]]; then
        export GITHUB_TOKEN="${_gh_token}"
        export GH_TOKEN="${_gh_token}"
    fi
    unset _gh_token
fi
{% endif %}
