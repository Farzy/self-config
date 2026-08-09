---
name: openclaw-ops
description: Edit, dry-run test, and deploy the OpenClaw Ansible config — covers the `fastmail_mcp_setup` and `openclaw_setup` roles on claw.farzad.tech. Use when the user asks to change OpenClaw/fastmail-mcp settings, plugins, skills, or models, or wants to test/apply that config with ansible-playbook.
user-invocable: true
allowed-tools:
  - Read
  - Edit
  - Write
  - Bash
  - Grep
  - Glob
---

# OpenClaw Ansible: edit, test, apply

Manages the OpenClaw gateway host (`claw.farzad.tech`, inventory group `openclaw`)
via two Ansible roles, both driven by `ansible/playbooks/openclaw.yml`:

| Role                 | Tag            | Purpose                                                             |
|----------------------|----------------|----------------------------------------------------------------------|
| `fastmail_mcp_setup` | `fastmail_mcp` | Fastmail MCP server (supergateway + `fastmail-mcp` systemd service) |
| `openclaw_setup`     | `openclaw`     | OpenClaw gateway itself (`openclaw.json`, systemd unit, nginx)      |

The playbook also carries `master_setup` (tag `setup`) and `iterm2_integration`
(tag `iterm2`), but those are out of scope for this skill.

All `ansible-playbook` commands below **must be run from the `ansible/`
subdirectory** — `ansible.cfg` there sets `inventory = ./hosts` and
`roles_path = ./roles`, and paths break if run from the repo root.

## Manual host access

Two accounts on `claw.farzad.tech` (SSH alias `claw`):

- `ssh claw@claw` — the `claw` account itself, unprivileged. It's in the
  `systemd-journal` group only, so `journalctl -u openclaw` / `journalctl -u
  fastmail-mcp` work without sudo; nothing else does.
- `ssh debian@claw` — the admin account, can `sudo` to `root`. Use this for
  anything beyond reading logs: restarting services by hand, inspecting
  `/home/claw/.openclaw/openclaw.json` as root, editing files outside what
  Ansible manages, etc. This is also the account Ansible itself connects as
  (`ansible_user=debian` in `ansible/hosts`).

Prefer re-running the Ansible role (see Applying, below) over manual changes
on the host — manual edits will be silently reverted on the next playbook
run.

## Where things live

- `ansible/roles/openclaw_setup/`
  - `defaults/main.yml` — all `openclaw_setup_*` variables (model, port, plugins toggles, memory search, signal/telegram allowlists, version pin).
  - `templates/openclaw.json.j2` — renders `~/.openclaw/openclaw.json` on the host. Plugin toggles live under `plugins.entries.<name>.enabled`; skill toggles under `skills.entries.<name>.enabled`.
  - `templates/openclaw.service.j2`, `templates/nginx.conf.j2`, `templates/secrets.env.j2`.
  - `handlers/main.yml` — service restart handlers triggered by template changes.
- `ansible/roles/fastmail_mcp_setup/`
  - `defaults/main.yml` — `fastmail_mcp_*` variables, including the `fastmail_mcp_supergateway_source: npm|git` switch for the patched supergateway build.
  - `templates/fastmail-mcp.service.j2`, `templates/secrets.env.j2`.
- `ansible/vars/openclaw.yml` — host-specific values and **ansible-vault encrypted** secrets (`openclaw_gateway_token`, `openclaw_telegram_bot_token`, `openclaw_github_pat`, `openclaw_fastmail_token`, `openclaw_claude_code_oauth_token`, etc). Vault identity/password are configured in `ansible/ansible.cfg` (`vault_identity_list`, `vault_password_file`) — `ansible-vault edit vars/openclaw.yml` / `ansible-vault view vars/openclaw.yml` work without extra flags from inside `ansible/`.
- `ansible/hosts` — `[openclaw]` group, currently just `claw.farzad.tech`.
- `docs/openclaw.md` — human-facing docs for the deployed config (memory search, dreaming, plugins, security hardening rationale). Update this alongside any non-trivial `defaults/main.yml` or `openclaw.json.j2` change.

## Editing

1. Change variables in `defaults/main.yml` for simple toggles (ports, model ids, feature flags, allow-lists), or edit the `.j2` template directly when adding a new structural block (e.g. a new `plugins.entries.<name>` or `skills.entries.<name>` entry).
2. Secrets never go in `defaults/main.yml` or templates as literals — they're `!vault` blocks in `vars/openclaw.yml`, referenced by variable name in the template (e.g. `{{ openclaw_telegram_bot_token }}`).
3. If the change is user-facing or changes deployed behavior, update `docs/openclaw.md` in the same commit.
4. Follow the repo's standard git workflow (feature branch, Conventional Commits, PR — see the global git-workflow directives): don't edit and apply directly against `main` without going through a PR first, even though this is a personal repo where admin-merge is available.

## Testing (dry run)

From the `ansible/` directory, use `--check --diff` to preview rendered file
changes without touching the host:

```bash
cd ansible
ansible-playbook playbooks/openclaw.yml --check --diff -t openclaw
ansible-playbook playbooks/openclaw.yml --check --diff -t fastmail_mcp
```

Combine both tags in one dry run when a change touches both roles:

```bash
ansible-playbook playbooks/openclaw.yml --check --diff -t openclaw,fastmail_mcp
```

`--diff` prints a unified diff of any template-managed file (e.g.
`openclaw.json`, the systemd units) so you can confirm the rendered output
matches intent before applying. Some tasks (package installs, npm/git builds)
report `changed` under `--check` even when nothing would actually change,
since Ansible can't simulate command output — read the diff, not just the
changed/ok counts.

`ansible-lint` also runs as a pre-commit hook on this repo; a plain `git
commit` will catch structural issues before you even get to `--check`.

## Applying

Same command, without `--check`:

```bash
cd ansible
ansible-playbook playbooks/openclaw.yml -v --diff -t openclaw
ansible-playbook playbooks/openclaw.yml -v --diff -t fastmail_mcp
```

- `-v --diff` keeps the rendered diff visible during the real run — useful to
  confirm exactly what changed on the host, matching what the dry run showed.
- Config template changes to `openclaw_setup` normally trigger a service
  restart via the role's handlers — check the play recap (`changed=`) and, if
  in doubt, confirm with `ssh claw@claw journalctl -u openclaw -n 50` (or
  `-u fastmail-mcp` for that role); use `ssh debian@claw sudo systemctl status
  openclaw` if you need more than the journal.
- Always run the matching `--check --diff` dry run first unless the user has
  explicitly said to apply directly.
