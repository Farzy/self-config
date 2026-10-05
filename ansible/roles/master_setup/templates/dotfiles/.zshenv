# {{ ansible_managed }}

{% if openclaw_setup_user is defined %}
{# Same guard as .zshrc and .gitconfig in this directory: `openclaw_setup_user`
   is only in scope on plays that include the openclaw_setup role. #}
if [[ $(id -un) == "{{ openclaw_setup_user }}" ]]; then
    # GitHub CLI authentication: gh — and git, through the `gh auth git-credential`
    # helper in .gitconfig — reads GH_TOKEN from the environment, so this account
    # needs no `gh auth login` and keeps no token in a gh config file. The value
    # comes from the openclaw_setup role's secrets.env (Ansible Vault, not
    # git-tracked). Surrounding double quotes are stripped because systemd's
    # EnvironmentFile format allows them, and an empty value is not exported:
    # gh treats an empty GH_TOKEN as "authenticated" and then fails every call.
    #
    # This lives in .zshenv, not .zshrc, because .zshenv is sourced for every
    # zsh invocation — including the non-interactive, non-login shells used by
    # tools like Claude Code's exec sandbox (`zsh -c '...'`) — while .zshrc only
    # runs for interactive shells. See docs/openclaw.md §6.3.
    if [ -r /etc/openclaw/secrets.env ]; then
        _gh_token="$(sed -n 's/^GITHUB_TOKEN=//p' /etc/openclaw/secrets.env | head -n1)"
        _gh_token="${_gh_token#\"}"
        _gh_token="${_gh_token%\"}"
        if [ -n "${_gh_token}" ]; then
            export GITHUB_TOKEN="${_gh_token}"
            export GH_TOKEN="${_gh_token}"
        fi
        unset _gh_token
    fi
fi
{% endif %}
