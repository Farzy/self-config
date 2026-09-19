# OpenClaw Architecture & Operations Guide

This guide details the deployment, configuration, operational management, and troubleshooting for the **OpenClaw** server hosted on Scaleway.

---

## 1. System Overview & Architecture

* **Cloud Provider**: Scaleway (`PLAY2-PICO` instance, Debian Bookworm).
* **Hostname / Domain**: `claw.farzad.tech` (IP: `163.172.189.14`).
* **Web Gateway**: Nginx reverse proxy with TLS certificate managed by Certbot (Let's Encrypt), forwarding `https://claw.farzad.tech` to `http://127.0.0.1:3000`.
* **Runtime Environment**: Node.js 26.x (`node_26.x` APT repository). OpenClaw is installed in the `claw`-owned npm prefix `/home/claw/.npm-global` and runs as the systemd **user** unit `openclaw-gateway.service` of `claw` (lingering), which is what lets it update itself on request — see [4.4](#44-self-update-on-request).
* **Dedicated System Account**: User `claw` (`/home/claw`, default shell `/usr/bin/zsh`).
* **LLM Provider**: Anthropic Claude (`anthropic/claude-sonnet-5`), routed through the `claude-cli` agent runtime (reuses a Claude Code login on the host instead of a separate API key — see [6.4](#64-claude-anthropic-model-via-claude-code-cli-reuse)), with optional Scaleway Generative APIs (`https://api.scaleway.ai/5e40a076-f4e5-4328-8052-1a543614ec45/v1`, supporting GLM 5.2, Qwen 3.6 Coder, and Mistral Small 3) available as an alternate provider.
* **Embeddings Provider**: Google Gemini (`gemini-embedding-001`) is still used for `memory.search` — unrelated to the chat model, kept for semantic memory indexing (see [4.2](#42-memory-search--background-dreaming-configuration)).
* **API Key Management**: Dedicated Gemini API key (embeddings only) and optional Scaleway API key stored encrypted with Ansible Vault in [ansible/vars/openclaw.yml](../ansible/vars/openclaw.yml). Claude auth uses a long-lived OAuth token (`CLAUDE_CODE_OAUTH_TOKEN`), also vault-encrypted.
* **Control Channels**:
  - **Telegram**: Stock `@openclaw/telegram` plugin connected in live long-polling mode using an encrypted bot token.
  - **Signal**: Integration using `@openclaw/signal` plugin and native `signal-cli` (`v0.14.7`), enforcing Direct Message pairing policy (`dmPolicy: "pairing"`).
* **Agent Skills Integration**: Automated cloning of Addy Osmani's `agent-skills` repository with workspace symlinks in `/home/claw/.openclaw/workspace/skills/`.

---

## 2. Infrastructure Operations (Scaleway)

The Scaleway server can be stopped to save costs when not in active use.

### Server Lifecycle Commands

* **List Servers**:
  ```bash
  scw instance server list
  ```
* **Start Server**:
  ```bash
  scw instance server start openclaw
  ```
* **Stop Server**:
  ```bash
  scw instance server stop openclaw
  ```

---

## 3. SSH Access & Port Forwarding (Port 18789)

### Connecting via SSH
Connect to the host using the SSH alias configured in `~/.ssh/config`:
```bash
ssh claw
```

### SSH Config & Port 18789 Local Forwarding
The SSH configuration for `claw` includes local port forwarding for port **18789**:
```sshconfig
Host claw claw.farzad.tech
  HostName claw.farzad.tech
  User debian
  LocalForward localhost:18789 localhost:18789
```

#### Why Port 18789 is Forwarded
* **Default OpenClaw RPC / Gateway Port**: OpenClaw uses port `18789` for native WebSocket RPC communications (`ws://127.0.0.1:18789`).
* **Security Scenarios**: Binding port 18789 locally over SSH allows local developer tools and CLI commands on your workstation to interact securely with the remote OpenClaw gateway daemon without exposing port 18789 publicly over the internet.

#### Harmless Address Conflict Warning
If you open a second SSH session to `claw` while a primary SSH session is active, SSH will output:
```text
bind [127.0.0.1]:18789: Address already in use
channel_setup_fwd_listener_tcpip: cannot listen to port: 18789
Could not request local forwarding.
```
*This warning is expected and harmless*: the first SSH connection is already forwarding port 18789, and your second session connects normally.

---

## 4. Provisioning & Deployment with Ansible

To deploy or update OpenClaw configuration on the server:

```bash
cd ansible
uv run ansible-playbook --diff --vault-id personal@~/.ansible-personal-key playbooks/openclaw.yml
```

### Key Ansible Roles & Templates
* **Playbook**: [ansible/playbooks/openclaw.yml](../ansible/playbooks/openclaw.yml)
* **Encrypted Vault Variables**: [ansible/vars/openclaw.yml](../ansible/vars/openclaw.yml)
* **OpenClaw Role**: [ansible/roles/openclaw_setup/tasks/](../ansible/roles/openclaw_setup/tasks/) — `main.yml` imports one file per concern: `user.yml`, `packages.yml`, `signal-cli.yml`, `gog.yml`, `secrets-env.yml`, `install.yml`, `credential-stores.yml`, `config.yml`, `service.yml`, `nginx.yml`, `gateway.yml`, `skills.yml`. The import order is the order the tasks ran in when this was a single file, and the ordering that matters is documented in each file's header.
* **Configuration Template**: [ansible/roles/openclaw_setup/templates/openclaw.json.j2](../ansible/roles/openclaw_setup/templates/openclaw.json.j2)
* **Systemd User Unit Template**: [ansible/roles/openclaw_setup/templates/openclaw-gateway.service.j2](../ansible/roles/openclaw_setup/templates/openclaw-gateway.service.j2)
* **Admin Wrapper Template**: [ansible/roles/openclaw_setup/templates/openclaw-admin.j2](../ansible/roles/openclaw_setup/templates/openclaw-admin.j2)
* **Secrets Environment Template**: [ansible/roles/openclaw_setup/templates/secrets.env.j2](../ansible/roles/openclaw_setup/templates/secrets.env.j2)
* **Nginx SSL Proxy Template**: [ansible/roles/openclaw_setup/templates/nginx.conf.j2](../ansible/roles/openclaw_setup/templates/nginx.conf.j2)

### 4.1 Systemd Secrets Externalization & Security Sandboxing

To protect API tokens and sensitive credentials from unauthorized process access or shell environment leaks, OpenClaw isolates credentials into a restricted secrets file and applies Systemd process sandboxing:

#### 1. Secrets File Isolation (`/etc/openclaw/secrets.env`)
- Instead of declaring inline `Environment=` lines in unit files, sensitive variables (`OPENCLAW_GATEWAY_TOKEN`, `TELEGRAM_BOT_TOKEN`, `GEMINI_API_KEY`, `CLAUDE_CODE_OAUTH_TOKEN`, `GITHUB_TOKEN`, `GH_TOKEN`, `NOTION_API_TOKEN`, `SCALEWAY_API_KEY`) are templated into `/etc/openclaw/secrets.env`, the only place on the host where the role keeps them in plaintext. There is deliberately **no `ANSIBLE_VAULT_PASSWORD`** — see [4.5](#45-no-vault-password-on-the-host). `gh` no longer keeps its own login (the PAT copy in `~/.config/gh/hosts.yml` is removed; see [6.3](#63-github-personal-access-token-pat-integration)).
- **OpenClaw's own credential stores hold references only.** Besides `openclaw.json`, OpenClaw keeps auth profiles in SQLite (`state/openclaw.sqlite`, and a per-agent `agents/main/agent/openclaw-agent.sqlite`) and a generated `agents/main/agent/models.json`. Ansible cannot template those, so the role audits them on every converge with `openclaw secrets audit` (read-only, so it also runs in `--check` and the drift check reports residue). On findings, it fixes them the way OpenClaw documents:
  - it logs out every profile holding a plaintext key or token, plus profiles this repo does not manage (`openai:default` — no model in the config uses that provider);
  - it recreates the Claude profile `anthropic:manual` as a `tokenRef` to `CLAUDE_CODE_OAUTH_TOKEN`, from the committed plan [`files/secrets-plan.json`](../ansible/roles/openclaw_setup/files/secrets-plan.json) (references only), applied with `openclaw secrets apply`;
  - it deletes a `models.json` still holding a plaintext key (a generated cache; the gateway regenerates it with non-secret markers);
  - it then re-audits, and **fails the play unless `secrets audit --check` is clean**.

  Scaleway needs no profile: `models.providers.scaleway.apiKey` is already an env SecretRef in `openclaw.json`, and removing the old `scaleway:default` profile also removes the `REF_SHADOWED` finding it caused. Old `openclaw.json.bak*` / `*.clobbered*` copies that still hold a credential field as a plain string are deleted. They are matched on structure, so no secret value appears in the role.
- **No plaintext credentials in `openclaw.json`**: the gateway token, Telegram bot token and Scaleway API key are written as env SecretRefs (`{"source": "env", "provider": "default", "id": "OPENCLAW_GATEWAY_TOKEN"}`, …) that OpenClaw resolves from the service environment at startup. `openclaw.json` lives in the agent-readable state dir, and OpenClaw's updater and Doctor copy it into `openclaw.json.bak.*` and rollback snapshots — plaintext there would multiply with every update. Check with `sudo openclaw-admin secrets audit --check`.
- Directory `/etc/openclaw` is `root:claw` `0750`, file `/etc/openclaw/secrets.env` is `root:claw` `0640`. **Root-owned** so the agent cannot rewrite its own credentials or endpoints, and **outside `$HOME`** so it never lands in state backups, memory indexing or anything the agent syncs. **Group-readable by `claw`** because the gateway is a systemd *user* unit: `claw`'s user manager reads `EnvironmentFile=` itself (a system unit had PID 1 read it as root), as does OpenClaw's updater when it rebuilds the service environment.
- **What this does and does not protect** (OpenClaw's own position: SecretRefs are not a process-isolation boundary — see `docs/gateway/secrets/runtime-model.md` in the package). Any process running as `claw` can read every one of these values from the gateway's `/proc/<pid>/environ` (verified on this host: `kernel.yama.ptrace_scope=2` restricts ptrace *attach*, not same-uid `environ` reads), and the agent's own exec children inherit them. So the file mode was never what kept secrets from the agent while the gateway runs. The one real delta of making it `claw`-readable: the values stay readable while the gateway is stopped or crash-looping, when there is no live process to scrape — a small difference, and one the user-unit model requires. Protecting a credential *from the agent itself* takes OS isolation, sandboxed exec, or OpenClaw's egress proxy with protected store secrets — not file permissions.
- **Notion Integration (`NOTION_API_TOKEN` & `NOTION_API_VERSION`)**: Managed securely via Ansible Vault (`openclaw_notion_api_token` in `ansible/vars/openclaw.yml`) and injected into `/etc/openclaw/secrets.env` along with `NOTION_API_VERSION=2026-03-11` for Notion API integrations.
- `claw`'s systemd user manager loads `EnvironmentFile=/etc/openclaw/secrets.env` when it starts the `openclaw-gateway.service` user unit.
- **Running manual `openclaw` admin commands: always use `sudo openclaw-admin <cmd>`**, never a plain `sudo -u claw openclaw <cmd>`. The plain form now fails outright — sudo's `secure_path` does not include `claw`'s npm prefix — and even with a full path it would see none of the service environment: Doctor misreports normal config as broken (`NODE_COMPILE_CACHE`, `OPENCLAW_NO_RESPAWN`, API keys unset), and anything that talks to the gateway has no token, since `openclaw.json` only references it as an env SecretRef. The wrapper (`/usr/local/bin/openclaw-admin`, templated from `openclaw-admin.j2`) runs the command as a transient unit in `claw`'s own user manager — `systemd-run --user --machine=claw@ --pipe --wait --property=EnvironmentFile=/etc/openclaw/secrets.env …` — rather than via sudo or a bash `source`:
  - systemd's `EnvironmentFile=` parser does no shell expansion or command substitution, so a secret containing `$`, a backtick or `$(...)` is read exactly as the gateway reads it, and nothing is ever `source`d as root;
  - the command gets `claw`'s runtime dir and user bus, which OpenClaw needs to inspect its `openclaw-gateway.service` user unit;
  - it runs the absolute path in `claw`'s prefix and **never as root** — that tree is writable by `claw`, so running it with root privileges would hand the agent a privilege escalation. For the same reason nothing puts `openclaw` on root's `PATH`.

  It also sets `OPENCLAW_SERVICE_REPAIR_POLICY=external`: the unit is authored by Ansible (root-owned, "sealed" from OpenClaw's point of view), so manual Doctor runs stay diagnostic-only for the service lifecycle — no reinstalling or rewriting the unit — while state and database checks still run, and stop/start stays with us. stdin is passed through (`--pipe`), so `… | sudo openclaw-admin models auth paste-token` works. See [§8](#8-service-management--troubleshooting) for the Doctor stop/fix/start sequence.

#### 2. Threat Model Defense & Harmonized Systemd Sandboxing
The systemd user unit ([ansible/roles/openclaw_setup/templates/openclaw-gateway.service.j2](../ansible/roles/openclaw_setup/templates/openclaw-gateway.service.j2)) configures harmonized process sandboxing balancing security against Node.js runtime needs.

> **Scope of this sandbox.** It contains the gateway process and whatever runs inside it by accident; it is not a boundary against a compromised agent. `claw` has linger and therefore its own user manager, so any code running as `claw` can start an unsandboxed process with `systemd-run --user` — which is exactly how the updater escapes the gateway's lifecycle. That was already true with the old system unit, since linger was enabled then too.
>
> **User units need `PrivateUsers=true` for any of this to apply.** An unprivileged user manager cannot create mount namespaces on its own, and systemd then **silently skips** every namespace-based setting — `ProtectSystem`, `PrivateTmp`, `ProtectKernelTunables`, `ProtectHostname`… Verified on this host (systemd 252): without it, the root file system stays writable inside the unit and the journal only logs `namespace setup is prohibited … ignoring`. With it, `/` and `/proc/sys` are mounted read-only as intended, and everything the updater needs — the user bus, `systemctl --user`, `systemd-run --user --scope`, journal reads — still works. Don't remove it without re-checking `/proc/<pid>/mountinfo`.

- **`PrivateUsers=true`**: Runs the gateway in a user namespace that maps only `claw`; required for the settings below. Other users' files appear as `nobody:nogroup`, but kernel access checks are unchanged (journal reads through `systemd-journal` still work).
- **`ProtectSystem=strict`**: Mounts root `/`, `/usr`, `/boot`, `/etc` as read-only filesystem paths to prevent OS file tampering.
- **`ReadWritePaths=/home/claw`**: Restricts writes to `/home/claw`, which holds everything the gateway legitimately writes: state, config, workspace, the npm prefix the updater swaps, the Node compile cache (`~/.cache/openclaw/compile-cache`) and its `TMPDIR` (`~/.cache/openclaw/tmp`).
- **`ProtectHome=false`**: Set to `false` to permit user `claw` to read and write its database, configuration, and workspace files under `/home/claw/`.
- **`PrivateTmp=true`**: Provides an isolated `/tmp` namespace preventing token leakage in shared temporary folders. OpenClaw itself uses `TMPDIR=~/.cache/openclaw/tmp` instead: systemd deletes the PrivateTmp directory as soon as the service stops, which is exactly what the update helper does mid-update while its staged files live in `os.tmpdir()`.
- **`MemoryDenyWriteExecute=false`**: Set to `false` because the Node.js V8 engine requires W^X JIT (Just-In-Time) compilation memory allocations to execute.
- **`NoNewPrivileges=true`**: Set to `true` to prevent child processes from gaining elevated privileges via `setuid` binaries (user `claw` is unprivileged and has zero sudo access).
- **`ProtectKernelTunables=true`**: Protects `/proc/sys`, `/sys`, and kernel variables from modification.
- **`ProtectControlGroups=true`**: Mounts control group hierarchies (`/sys/fs/cgroup`) as read-only.
- **`RestrictRealtime=true`**: Prevents the service from acquiring realtime scheduling priorities to avoid CPU starvation attacks.
- **`RestrictSUIDSGID=false`** (deliberately off since 2026.9.5): systemd enforces this option with a seccomp filter on the mode argument of `open`/`openat`/`chmod`. `openat2()` passes its mode inside a struct seccomp cannot read, so the filter blocks `openat2()` entirely with `ENOSYS`. From 2026.9.5, OpenClaw's fs-safe layer defaults to native mode, which confines file access with `openat2(RESOLVE_BENEATH)` — race-free protection against `..` and symlink escapes for the agent's file tools — and fails closed on `ENOSYS`. With the option on, the gateway could not take its state lock and crash-looped (`openat2 beneath root: Function not implemented`). For an unprivileged uid already under `NoNewPrivileges=true`, the option only stopped `claw` from creating setuid-to-`claw` files, so native path containment is the better trade.
- **`ProtectHostname=true`**: Isolates UTS namespace to prevent modifications to system hostname or domain name.
- **`LockPersonality=true`**: Locks execution domain to prevent personality switching.
- **Dropped with the move to a user unit**: `CapabilityBoundingSet=`, `AmbientCapabilities=`, `ProtectKernelModules=`, `ProtectClock=` and `ProtectKernelLogs=` make a user unit fail with `status=218/CAPABILITIES` — a user manager cannot drop capabilities. Nothing is lost: each works by removing capabilities, which an unprivileged `claw` process never holds, and `NoNewPrivileges=true` already prevents gaining any through setuid or file-capability binaries.
- **RAM Dump Protection (`kernel.yama.ptrace_scope = 2`)**: Configures kernel YAMA ptrace scope to admin-only (root with `CAP_SYS_PTRACE`), preventing unprivileged processes from attaching debuggers (`gdb`, `strace`) or inspecting `/proc/<pid>/mem` to extract in-memory tokens.


#### 3. Automated User Privilege Verification in Ansible
Ansible automatically asserts system user isolation during playbook execution:
- **Sudoers Cleanup**: Ensures `/etc/sudoers.d/claw` is absent.
- **Group Membership Assertion**: Verifies user `claw` is NOT a member of any privileged groups (`sudo`, `root`, `wheel`, `shadow`, `adm`, `disk`).
- **Sudo Access Check**: Executes `sudo -n -l -U claw` to verify that `claw` has no sudo privileges on the host.
- **Deliberate `systemd-journal` Exception**: `claw` IS added to the `systemd-journal` group so the agent can run `journalctl -u <service>` (e.g. to debug `openclaw` or `fastmail-mcp`) without sudo. This is an accepted trade-off: `systemd-journal` grants read access to the **full system journal** — all units, including sshd/PAM auth events, sudo invocations and kernel messages — chosen over granting `sudo` or the `adm` group. The grant is applied before the group snapshot so the deny-list assertion above validates the converged state.


#### 4.2 Memory Search & Background Dreaming Configuration

To leverage semantic search and automatic long-term memory consolidation, OpenClaw includes active memory searching and dreaming plugins pre-integrated into your Ansible defaults:

* **Semantic Memory Search (top-level `memory.search`)**:
  - Configures OpenClaw's vector search pipeline using Google's modern embedding API.
  - Defaults are managed in Ansible via:
    - `openclaw_setup_memory_search_provider` (default: `"gemini"`)
    - `openclaw_setup_memory_search_model` (default: `"gemini-embedding-001"`)
    - `openclaw_setup_memory_search_extra_paths` (default: `["{{ openclaw_setup_home }}/.openclaw/workspace/farzad-wiki"]` to index your professional wiki).
  - It generates the standard `memory.search` block inside `openclaw.json` (moved from `agents.defaults.memorySearch` as of the 2026.8.1 schema — see [§8](#8-service-management--troubleshooting)), allowing the agent to dynamically index and retrieve matching historical contexts during conversation turns.

* **Memory Dreaming (`plugins.entries.memory-core`)**:
  - Enables OpenClaw's background memory dreaming and consolidation sweeps.
  - Dreaming moves highly reinforced, short-term conversational signals into durable long-term memory (`MEMORY.md`) automatically on a background cron schedule.
  - Managed in Ansible via `openclaw_setup_dreaming_enabled` (default: `true`).

* **Memory Wiki (`plugins.entries.memory-wiki`)**:
  - Enables OpenClaw's structured memory wiki plugin, which maintains cross-linked long-term memory pages alongside `MEMORY.md`.
  - Managed in Ansible via `openclaw_setup_memory_wiki_enabled` (default: `true`).

---

### 4.3 Config Writes & `OPENCLAW_CONFIG_READONLY`

Since the 2026.9.4 release, OpenClaw supports `OPENCLAW_CONFIG_READONLY=1`, which blocks the process's own config writers — `openclaw setup`, `openclaw configure`, `openclaw doctor --fix`, plugin install/update/uninstall/enable/disable, and mutating `openclaw update` flows — while leaving read-only commands (`config get`, `config file`, `config schema`, `config validate`) and ordinary runtime state untouched. It's meant for deployments where config is externally managed.

**It is off by default here, because it is incompatible with self-update.** A non-dry-run `openclaw update` asserts config writability before it does anything and refuses outright while the flag is set, and the update helper inherits the gateway's environment, so `update.run` from chat would be refused too. Ansible still owns `openclaw.json` — every converge re-renders it — but between converges OpenClaw may now write it, in practice when an update's Doctor pass migrates the schema. The weekly drift check surfaces any such difference, and [4.4](#44-self-update-on-request) covers reconciling it.

- **Toggle**: `openclaw_setup_config_readonly` (`ansible/roles/openclaw_setup/defaults/main.yml`, default `false`). Setting it to `true` freezes the install at its current version: Ansible can still bootstrap an absent install, but the role then refuses to upgrade one.
- **Where it's set**: as `Environment=OPENCLAW_CONFIG_READONLY=1` directly in [`openclaw-gateway.service.j2`](../ansible/roles/openclaw_setup/templates/openclaw-gateway.service.j2)'s `[Service]` block — **deliberately not** in `secrets.env.j2`, which `openclaw-admin` also loads: manual `doctor --fix` or `models auth paste-token` runs through it must never inherit the flag.

### 4.4 Self-Update on Request

OpenClaw can upgrade itself when you ask it to — "update yourself to the latest version" over Telegram or Signal, or **Update now** in the Control UI. Background auto-updates stay off (`update.auto.enabled: false` in `openclaw.json.j2`), so it never happens unprompted. The channel is `openclaw_setup_update_channel` (default `stable`).

**What makes it possible** — three things the previous deployment prevented:

1. **`claw` owns the install.** OpenClaw lives in the npm prefix `/home/claw/.npm-global` (`openclaw_setup_npm_prefix`, set in `~/.npmrc` by Ansible) instead of root's `/usr/lib/node_modules`, so the updater, which runs as `claw`, can stage and swap the package tree.
2. **It runs as OpenClaw's native service shape**: the systemd *user* unit `openclaw-gateway.service`, with the service identity markers `openclaw gateway install` writes (`OPENCLAW_SERVICE_MARKER`, `OPENCLAW_SERVICE_KIND`, `OPENCLAW_SYSTEMD_UNIT`). OpenClaw's updater only ever drives a user unit through `systemctl --user` — its code says outright "OpenClaw does not manage system-scope units" — and it treats a system unit named `openclaw-gateway.service` *or* `openclaw.service` as a conflicting owner that blocks activation. The role therefore removes the old `/etc/systemd/system/openclaw.service`.
3. **`OPENCLAW_CONFIG_READONLY` is off** (see [4.3](#43-config-writes--openclaw_config_readonly)).

The unit file itself is deployed **root-owned** in `~claw/.config/systemd/user/`. OpenClaw reads the unit from that exact path and treats one it does not own as a *sealed* definition: during an update it still stops, restarts and verifies the service, but OpenClaw's own code never rewrites the file. The seal is **advisory against OpenClaw, not a boundary against `claw`**: a user manager is controlled by its user, who can replace the file (the directory is theirs) or override it with drop-ins in `~/.config/systemd/user.control` — making the directory root-owned would not change that. Ansible re-asserts the unit on every converge, and the weekly drift check reports any change in between.

**What an update does** (OpenClaw's own updater — nothing custom here): the gateway hands `update.run` to a detached helper (`systemd-run --user --scope`) that stages the new package in a temporary prefix, validates it, and boots a canary on a *copy* of the config and SQLite state while the old gateway keeps serving. Only then does it stop the service, swap the package, run the required Doctor migrations, restart and verify (`/readyz`, version handshake, channel readiness). A failed validation leaves the old gateway untouched. A failed activation rolls back automatically *if* the database schema and config are unchanged; otherwise it stops and reports. Follow a run with `sudo openclaw-admin update status` or the helper log path it prints. **Before a release you have doubts about, take a backup**: the updater's own snapshots are disposable, not a recovery point.

**Chat acknowledgements are not results.** When the agent says the update "kicked off successfully", only the handoff has started; validation and the swap follow over the next few minutes. Check the outcome with `sudo openclaw-admin update status`. A failed validation leaves the old gateway serving (`downtimeMs: null`), and the report lands in `~claw/.openclaw/logs/support/openclaw-update-failure-*.json`.

**Known issue — the 2026.9.4 updater on this host.** Before swapping, the 2026.9.4 updater fingerprints the current package tree (about 546 MB, 36k files) under a hard, non-configurable 30 s budget (`MAX_SCAN_MS` in `update-runner-*.mjs`). With a cold page cache that scan takes about 19 s with native `sha256sum` alone on this 2-vCPU instance, and Node's per-file walk goes over the budget, so the swap fails with `Package rollback verification timed out` → `global-install-failed`. The live tree is left untouched. 2026.9.5 replaced the cap with the 20-minute runner timeout, so only the 9.4 → 9.5 hop is affected. Workaround for that hop: keep the tree in the page cache while the update runs (`find ~claw/.npm-global/lib/node_modules -type f -print0 | xargs -0 cat >/dev/null` in a loop), which brings the scan down to about 2 s.

**Reconciling with Ansible afterwards.** `openclaw_setup_version` is a **minimum**, not an exact pin:

| Installed vs `openclaw_setup_version` | What the role does |
|---|---|
| absent | Bootstraps it with `npm install --global --prefix … openclaw@<pin>` as `claw` (first install only). |
| older | Upgrades through the same updater the agent uses — `openclaw update --tag <pin> --yes --json`, run as a transient unit in `claw`'s user manager — then **waits** for the run to finish (polling `openclaw update status --json`, up to 30 min) and fails unless it succeeded at the pinned version. The wait is required: with a managed service, `openclaw update` hands off to a detached helper even when started from a terminal and returns immediately. So bumping the pin in the repo is also a supported way to upgrade. |
| equal | Nothing. |
| **newer** | **Fails the play** with a message telling you to bump the pin. |

The last row is deliberate. After a self-update the new release may have migrated the SQLite state and the `openclaw.json` schema (the 2026.8.1 release did — see [§8](#8-service-management--troubleshooting)). Re-rendering the old template, or downgrading the package, could then crash-loop the gateway, and OpenClaw warns that downgrades across a state migration are unsafe. So after asking OpenClaw to update itself:

1. Set `openclaw_setup_version` to the new version (`sudo openclaw-admin --version`).
2. Run `ansible-playbook playbooks/openclaw.yml --check --diff -t openclaw`. Any `openclaw.json` diff is a migration the updater applied: port it into `openclaw.json.j2`. That includes new `meta.migrations.*` markers, which the template mirrors so a converge doesn't make Doctor treat completed migrations as pending again; `meta.lastTouchedVersion` follows the pin automatically. Don't use `--diff` in CI logs — see [docs/ci-ansible.md](ci-ansible.md).
3. Converge, and commit the bump.

Until step 1 is merged, the weekly drift check goes red on that assertion — which is the intended signal that the repo lags the host.

**First cutover from the old system unit** (one-time; about 30 seconds of gateway downtime). The role bootstraps the new install while the old gateway still runs, then stops and removes `openclaw.service`, starts `openclaw-gateway.service`, and finally uninstalls the old root-owned copy under `/usr/lib/node_modules`. Afterwards:

```bash
ssh claw "sudo systemctl --user -M claw@ status openclaw-gateway"
ssh claw "sudo openclaw-admin gateway status --deep"      # managed user service, owned by this install
ssh claw "sudo openclaw-admin update --dry-run --json"     # update admission works (no change made)
ssh claw "sudo openclaw-admin secrets audit --check"       # no plaintext residue
```

To back out, check out the previous revision of this repo and converge it: that reinstalls the system unit and the root-owned package. First run `sudo systemctl --user -M claw@ disable --now openclaw-gateway`, so the two don't fight over port 18789.

### 4.5 No Vault Password on the Host

Until 2026-09-19 the role injected the Ansible Vault password into the gateway environment as `ANSIBLE_VAULT_PASSWORD`, so the agent could run Ansible on the box. That was the largest leak risk on the host: a single vault ID (`personal`) protects **every** `!vault` value in this public repository — `vars/laptop.yml` (18), `vars/openclaw.yml` (13), `vars/minecraft.yml` (6) and the microk8s role defaults — including every past commit. One successful prompt-injection exfiltration of that one value would have exposed all of them, offline and permanently.

Nothing the agent does needs it any more:
- its `config-drift-checker` skill decrypted `vars/openclaw.yml` only to compare secret values inside `openclaw.json`, which holds SecretRefs since #138. The script already runs without a password;
- its `self-config-development` skill only lints and syntax-checks, which CI does with a placeholder password;
- deploys go through the approval-gated `ansible-deploy.yml` workflow, not the agent.

The role therefore no longer ships the password, and it removes the stray `~claw/.ansible-personal-key` file. That file was not the current password: a 2026-09-19 check across the repository's history decrypted none of the 35 distinct vault blobs it sampled (the first block of every version of every vault-bearing file under `ansible/`). That sample is not all 51 values present today, but a password that opens none of 35 blobs spanning the history is not a vault password for this repository.

**Rekeyed on 2026-09-20**, after this change was converged, so the new password never reached the host. All 51 vault values in the repository were re-encrypted: the 12 fully encrypted files under `roles/laptop_setup/` and the 39 inline `!vault` values in `vars/laptop.yml` (18), `vars/openclaw.yml` (13), `vars/minecraft.yml` (6) and `roles/microk8s/defaults/main.yml` (2).

Worth knowing if this is ever repeated: **`ansible-vault rekey` only handles fully encrypted files.** Inline `!vault` values have to be decrypted and re-encrypted individually, preserving each block's indentation, which is what [`scripts/rekey-vault.py`](../scripts/rekey-vault.py) does (decrypt with the old secret through `VaultLib`, re-encrypt with the new one, compare sha256 digests of the plaintext before and after, and confirm the old password no longer decrypts anything).

To rotate again:

```bash
# 1. write the new password somewhere temporary, e.g. ~/.ansible-personal-key.new
# 2. fully encrypted files:
cd ansible
uv run ansible-vault rekey --vault-id personal@~/.ansible-personal-key \
  --new-vault-id personal@~/.ansible-personal-key.new \
  roles/laptop_setup/files/ssh/* roles/laptop_setup/files/ai/* roles/laptop_setup/templates/ssh/config
# 3. inline values, or simply both steps at once (from the repository root):
uv run python scripts/rekey-vault.py --new-key ~/.ansible-personal-key.new
# 4. activate: mv ~/.ansible-personal-key.new ~/.ansible-personal-key
# 5. commit and push the rekeyed files, then immediately update the
#    ANSIBLE_VAULT_PASSWORD repository secret used by
#    .github/workflows/ansible-deploy.yml
```

Step 5 opens a failure window: pushing to `main` triggers that workflow's check-mode drift run (and the weekly `cron`), which cannot decrypt anything until the repository secret holds the new password. Re-run it once the secret is updated.

**Accepted risk:** rekeying does not protect history. The old password was present in the agent's environment and in `~claw/.zsh_history`, and the vault values in past public commits remain decryptable with it — including the SSH CA private keys, `azure-farzad.pem`, the GitHub PATs, the Telegram bot token and the Scaleway key. The owner's decision (2026-09-20) was to rekey only, judging the old password not to have left the host, and to accept that exposure rather than rotate. Rotating any individual secret later closes its exposure; the OpenClaw ones are the most exposed, since they were also present in plaintext on the host.

---


## 5. System User, Shell & Tooling Environment

### 5.1 Dedicated `claw` User & SSH Key Authorization
- The service runs under a dedicated system user `claw` (`/home/claw`).
- Personal SSH public key authorization for `claw` is managed via Ansible Vault (`openclaw_setup_ssh_key` in `ansible/vars/openclaw.yml`) and deployed using `ansible.posix.authorized_key`.

### 5.2 Zsh Shell, Dotfiles & OpenClaw Autocompletion
- **Default Shell**: `claw` user is configured with `/usr/bin/zsh` and Oh My Zsh.
- **Dotfiles**: Standard dotfiles (`.zshrc`, `.bashrc`, `.profile`, `.gitignore_global`, `.gitconfig`) are deployed to `/home/claw/`.
- **Zsh Autocompletion**: `.zshrc` automatically loads OpenClaw CLI completion dynamically:
  ```zsh
  if command -v openclaw &> /dev/null; then
      eval "$(openclaw completion --shell zsh)"
  fi
  ```

### 5.3 Modern CLI Tools & Short-Name Symlinks
The server includes modern CLI tools configured with standard short names:
* `bat` -> `/usr/bin/batcat` (`/usr/local/bin/bat`)
* `fd` -> `/usr/bin/fdfind` (`/usr/local/bin/fd`)
* `rg` -> `/usr/bin/rg` (`ripgrep`)

### 5.4 Python & Package Managers
* **`uv`**: Installed system-wide at `/usr/local/bin/uv` for fast Python package management.
* **`gh`**: GitHub CLI installed via official GitHub APT keyring and authenticated for user `claw`.

### 5.5 Google Workspace CLI (`gog`)
* **`gog`**: Installed via versioned GitHub release download (checksum-verified against the release's `checksums.txt`), extracted to `/opt/gogcli-<version>/`, and symlinked to `/usr/local/bin/gog` — same pattern as `signal-cli` above. The pinned version lives in `openclaw_setup_gog_cli_version` (`ansible/roles/openclaw_setup/defaults/main.yml`). OAuth account authorization is provisioned non-interactively from vault-encrypted secrets — see [6.6](#66-gog-google-workspace-cli-oauth-setup). The `skills.entries.gog.enabled` flag in `openclaw.json` (gating whether the agent actually invokes the `gog` skill) is templated on whether `openclaw_gog_refresh_token_export_json` is defined, so the skill only turns on once an account is actually authorized.

---

## 6. Control Channels & Integration Workflows

### 6.1 Telegram Control Channel Setup

1. **Create a Bot via @BotFather**:
   - Open Telegram and search for `@BotFather`.
   - Send `/newbot` and follow instructions to choose a Bot Name and Username.
   - `@BotFather` will output an HTTP API Bot Token (e.g. `123456789:ABCdefGhIJKlmNoPQRsTUVwxyZ`).

2. **Encrypt Bot Token with Ansible Vault**:
   Save the token temporarily to `/tmp/temp-telegram-bot-token` on your laptop, then encrypt it:
   ```bash
   cd ansible
   uv run ansible-vault encrypt_string --vault-id personal@~/.ansible-personal-key --name openclaw_telegram_bot_token "$(cat /tmp/temp-telegram-bot-token)"
   rm -f /tmp/temp-telegram-bot-token
   ```
3. **Append to Vault Variables & Deploy**:
   Append the encrypted block to [ansible/vars/openclaw.yml](../ansible/vars/openclaw.yml) and re-deploy:
   ```bash
   uv run ansible-playbook --diff --vault-id personal@~/.ansible-personal-key playbooks/openclaw.yml
   ```

4. **Pair Telegram DM**:
   - Open Telegram and start a chat with your new bot.
   - Send a message to the bot.
   - The bot will reply with a 6-character pairing code.
   - Approve the code on the server:
     ```bash
     ssh claw "sudo openclaw-admin pairing approve <CODE>"
     ```

---

### 6.2 Signal Control Channel Setup

1. **Link Signal CLI**:
   To link a Signal account (secondary device or new number):
   ```bash
   ssh claw "sudo -u claw signal-cli link -n 'OpenClaw'"
   ```
   Scan the displayed QR code using the Signal mobile app (**Settings > Linked Devices**).

2. **Verify Signal Channel**:
   Check channel readiness and status:
   ```bash
   ssh claw "sudo openclaw-admin channels status"
   ```

3. **DM Pairing Procedure**:
   OpenClaw enforces a pairing policy for direct messages:
   - Send an initial Direct Message to your Signal bot.
   - The bot will reply with a 6-character pairing code.
   - Approve the pairing request on the server:
     ```bash
     ssh claw "sudo openclaw-admin pairing approve <CODE>"
     ```

---

### 6.3 GitHub Personal Access Token (PAT) Integration

To allow OpenClaw agents to interact securely with private GitHub repositories:

1. **Create a Fine-Grained PAT on GitHub**:
   - Go to **GitHub Settings > Developer Settings > Personal Access Tokens > Fine-grained tokens**.
   - Select your user account and choose **Only select repositories**.
   - Grant minimal necessary permissions (`Contents: Read/Write`, `Pull requests: Read/Write`, `Issues: Read/Write`).

2. **Encrypt the PAT with Ansible Vault**:
   Save the token to a temporary file on your Mac, encrypt it, and remove the temp file:
   ```bash
   cd ansible
   uv run ansible-vault encrypt_string --vault-id personal@~/.ansible-personal-key --name openclaw_github_pat "$(cat /tmp/temp-github-pat | tr -d '\r\n')"
   rm -f /tmp/temp-github-pat
   ```

3. **Append to Vault Variables & Deploy**:
   Append `openclaw_github_pat` to [ansible/vars/openclaw.yml](../ansible/vars/openclaw.yml) and deploy:
   ```bash
   uv run ansible-playbook --diff --vault-id personal@~/.ansible-personal-key playbooks/openclaw.yml
   ```
   Ansible injects `GITHUB_TOKEN` and `GH_TOKEN` into the gateway environment (`secrets.env`). `gh` — and `git`, through the `gh auth git-credential` helper in `.gitconfig` — reads `GH_TOKEN` from there, so there is deliberately **no `gh auth login`**. That command stored a second plaintext copy of the PAT in `~claw/.config/gh/hosts.yml`, and the role now removes it.

   Interactive `ssh claw@claw` shells get the same credential from `.zshrc`, which reads `GITHUB_TOKEN`/`GH_TOKEN` out of `/etc/openclaw/secrets.env` at startup (guarded on the user, in the same block as the OpenClaw completion). So `gh auth status` reports being logged in through `GH_TOKEN`, with no token written to any dotfile. Non-interactive shells (`ssh claw@claw '<cmd>'`) don't read `.zshrc`: use `sudo openclaw-admin` for those, or export the variable for that command.

---

### 6.4 Claude (Anthropic) Model via Claude Code CLI Reuse

OpenClaw's primary model runs on Anthropic Claude, routed through the bundled `claude-cli` agent runtime (`ansible/roles/openclaw_setup/templates/openclaw.json.j2` → `agents.defaults.models["{{ openclaw_setup_model }}"].agentRuntime.id`). This reuses a Claude Code login on the `claw` host and bills against your Claude subscription (Pro/Max/Team/Enterprise) instead of pay-as-you-go Anthropic API credits. `claude` (the Claude Code CLI) is installed globally via npm by the `openclaw_setup` role, resolving to `/usr/bin/claude` — same PATH pattern as the `openclaw` binary itself, so no systemd `PATH=` override is needed.

1. **Generate a long-lived OAuth token** (on your laptop, where you already have a browser-authenticated `claude` login):
   ```bash
   claude setup-token
   ```
   This opens a one-time browser authorization flow and prints a token (`claude_oauth_...`) to the terminal. It is **not** saved anywhere by the CLI — copy it immediately.

2. **Encrypt the token with Ansible Vault**:
   ```bash
   cd ansible
   uv run ansible-vault encrypt_string --vault-id personal@~/.ansible-personal-key --name openclaw_claude_code_oauth_token "<paste-token-here>"
   ```

3. **Append to Vault Variables & Deploy**:
   Append the encrypted block to [ansible/vars/openclaw.yml](../ansible/vars/openclaw.yml) and re-deploy:
   ```bash
   uv run ansible-playbook --diff --vault-id personal@~/.ansible-personal-key playbooks/openclaw.yml
   ```
   The role installs `@anthropic-ai/claude-code` globally and injects `CLAUDE_CODE_OAUTH_TOKEN` into `/etc/openclaw/secrets.env` (`root:claw`, `0640`), which `claw`'s user manager loads for the gateway — same pattern as `GEMINI_API_KEY` and `GITHUB_TOKEN` ([4.1](#41-systemd-secrets-externalization--security-sandboxing)).

4. **The auth profile (required — the env var alone is not enough; automated by the role)**:
   `agentRuntime.id: "claude-cli"` on its own does **not** give OpenClaw a usable Anthropic credential. OpenClaw's own "CLI reuse" verification path (`openclaw models auth login --provider anthropic --method cli`) needs an interactive TTY to confirm the host's `claude` login — impossible on a systemd-managed headless box, and it fails with `Error: models auth login requires an interactive TTY`. Without a registered profile, `openclaw models auth list` shows `Profiles: (none)` and every request silently falls through the whole fallback chain (Gemini, then Scaleway) — Claude is configured as primary but never actually gets called.
   The role creates that profile, `anthropic:manual`, as a **`tokenRef`** to `CLAUDE_CODE_OAUTH_TOKEN` by applying the committed plan [`files/secrets-plan.json`](../ansible/roles/openclaw_setup/files/secrets-plan.json) with `openclaw secrets apply` ([4.1](#41-systemd-secrets-externalization--security-sandboxing)). The profile stores a reference, never the token. **Don't use `models auth paste-token`** any more: it stores the token in plaintext, and the next converge would log that profile out and recreate the reference. The non-secret pointer `auth.profiles.anthropic:manual = {"provider": "anthropic", "mode": "token"}` stays templated in `openclaw.json.j2` (gated on `openclaw_setup_claude_cli_enabled`).

5. **Whitelist the token through OpenClaw's own subprocess env sanitization (required — steps 1–4 alone still silently fall back to Gemini)**:
   OpenClaw hard-codes `CLAUDE_CODE_OAUTH_TOKEN` into `CLAUDE_CLI_CLEAR_ENV` (`extensions/anthropic/cli-shared.ts` in the npm package) and strips it — along with every other Anthropic auth env var — before spawning the `claude` CLI subprocess for every `claude-cli` turn. This is deliberate: OpenClaw's docs say it "never forwards a copied token for this path," so the CLI is expected to already be natively logged in on the host via its own persisted credentials. A systemd-managed headless box has no such interactive login to reuse, so without this step every `claude-cli` turn fails with `error=FailoverError` / `detail=Not logged in · Please run /login` (visible in `journalctl _SYSTEMD_USER_UNIT=openclaw-gateway.service`) and falls straight through to Gemini — invisibly, since the gateway logs "model configured, enabled automatically" at startup regardless. There's a documented escape hatch: `OPENCLAW_LIVE_CLI_BACKEND_PRESERVE_ENV`, a comma/space-separated allowlist of env vars to preserve despite `clearEnv`. `secrets.env.j2` sets `OPENCLAW_LIVE_CLI_BACKEND_PRESERVE_ENV=CLAUDE_CODE_OAUTH_TOKEN` whenever the token is defined — no separate action needed beyond deploying.

6. **Verify — with an actual live call, not just a status check**:
   `openclaw models auth list` (expect `anthropic:manual [anthropic/token]`) and `openclaw models status`'s `Runtime auth: ... status=usable` line both look green even when the subprocess env-stripping bug above is still active — they only confirm a profile *exists*, not that a `claude-cli` turn actually succeeds. Likewise `status --deep`'s "Model selection" table reflects each session's *last actual turn*, so a session shown on a fallback model may just predate a fix. The only real proof is a completed turn with no fallback:
   ```bash
   ssh claw "sudo openclaw-admin agent --session-key agent:main:verify --message 'reply with exactly: OK' --model anthropic/claude-sonnet-5 --json" \
     | python3 -c "import json,sys; r=json.load(sys.stdin)['result']; print(r['payloads'][0]['text']); print(r['meta']['systemPromptReport']['provider'])"
   # expect: OK / claude-cli  (not gemini-3.1-pro-preview or scaleway/*)
   ```
   Or just send a real message through Telegram/Signal and check which model answered.

**Token lifecycle**: `claude setup-token` tokens are long-lived (weeks to months) but not permanent. If OpenClaw's model calls start failing with auth errors, regenerate with `claude setup-token` and redeploy steps 2–3. Because the profile is a reference to `CLAUDE_CODE_OAUTH_TOKEN`, the new value in `secrets.env` is picked up on the gateway restart the deploy triggers; nothing else needs repeating. Step 5 (`OPENCLAW_LIVE_CLI_BACKEND_PRESERVE_ENV`) is a static config value and doesn't need repeating on rotation either.

**Switching model tier**: `openclaw_setup_model` (`ansible/roles/openclaw_setup/defaults/main.yml`, default `anthropic/claude-sonnet-5`) can be overridden per-inventory to `anthropic/claude-opus-5` for higher-quality/slower responses, or any other `anthropic/claude-*` id — the `claude-cli` `agentRuntime` mapping in the template follows whatever `openclaw_setup_model` is set to, as long as `openclaw_setup_claude_cli_enabled` stays `true`.

**Reverting to Gemini as primary**: set `openclaw_setup_model: "google/gemini-3.1-pro-preview"` and `openclaw_setup_claude_cli_enabled: false`, then redeploy. `GEMINI_API_KEY` and the `google` plugin stay wired regardless (needed for `memory.search` embeddings).

### 6.5 Model Fallback Chain & Reasoning Config

`agents.defaults.model` failover order and the per-model reasoning tuning are template-driven from `ansible/roles/openclaw_setup/defaults/main.yml`:

* **`openclaw_setup_model_fallbacks`** (default: `["google/gemini-3.1-pro-preview", "scaleway/glm-5.2", "scaleway/qwen3.6-35b-a3b"]`) — ordered failover list rendered into `agents.defaults.model.fallbacks`, tried in order if the primary Claude model errors or rate-limits. Empty list omits the `fallbacks` key entirely.
* **`agents.defaults.models`** is built in the template (`openclaw.json.j2`, via a Jinja `namespace`/`combine`) rather than hand-authored, so it never has to choose between the Claude `agentRuntime` entry and the Scaleway reasoning params — both are merged in:
  - The primary model gets `{"agentRuntime": {"id": "claude-cli"}}` when `openclaw_setup_claude_cli_enabled` is `true`.
  - Every id in **`openclaw_setup_scaleway_reasoning_model_ids`** (default: `glm-5.2`, `qwen3.6-35b-a3b`) gets `{"params": {"extra_body": {"thinking": {"type": "enabled"}, "reasoning_effort": "high"}}}` when `openclaw_setup_scaleway_enabled` is `true`. `mistral-small-3.2-24b-instruct-2506` is deliberately excluded (no extended-thinking support).
* **`openclaw_setup_reasoning_default`** (default: `"stream"`) — rendered as `agents.defaults.reasoningDefault`.
* **`openclaw_setup_scaleway_api`** (default: `"openai-responses"`) — rendered as `models.providers.scaleway.api`, alongside the existing `baseUrl`/`apiKey`/`models` fields.
* **`openclaw_setup_telegram_thread_bindings_enabled`** (default: `true`) — rendered as `channels.telegram.threadBindings.enabled`.
* **`agents.defaults.modelPolicy.allow`** — no dedicated variable: computed in `openclaw.json.j2` as the primary model, plus `openclaw_setup_model_fallbacks`, plus every id in `openclaw_setup_scaleway_models` (when `openclaw_setup_scaleway_enabled` is `true`) prefixed `scaleway/`, deduplicated. Including every configured Scaleway model — not just the fallback chain — matters because `models.providers.scaleway.models` registers all of them (including `mistral-small-3.2-24b-instruct-2506`, which isn't a fallback) as selectable in the Control UI; leaving one out of the allow-list would silently block a model this same config otherwise advertises as available. A separate allow-list variable existed briefly and was removed after it drifted out of sync with the fallback chain (missing `google/gemini-3.1-pro-preview`) the first time `openclaw doctor --fix` touched it — deriving it removes the possibility of that drift rather than requiring the lists to be kept in sync by hand.

These settings previously existed only as manual drift on the live server (set outside Ansible) and were wiped by a plain redeploy; they're now first-class template inputs so `ansible-playbook --diff` stays a true no-op when nothing has actually changed.

---

### 6.6 `gog` (Google Workspace CLI) OAuth Setup

`gog`'s account authorization normally requires an interactive browser OAuth
flow, but `gog auth credentials set`/`gog auth tokens import` accept the OAuth
client JSON and a refresh-token export as files (or stdin), so the whole thing
can be done headlessly by reusing a login already authorized on your laptop —
no browser or TTY needed on the server. This mirrors the [6.4](#64-claude-anthropic-model-via-claude-code-cli-reuse)
pattern (laptop-side secret → `ansible-vault encrypt_string` → deploy):

1. **Authorize the account on your laptop first** (one-time, interactive —
   this is the only step that needs a browser), if you haven't already:
   ```bash
   gog auth setup                      # OAuth client / Google Cloud project
   gog auth add you@gmail.com --services calendar,contacts,docs,drive,gmail,sheets
   ```
   The OAuth client's consent screen must be in **Production/published**
   status, not Testing — Google auto-expires refresh tokens after 7 days for
   apps still in Testing, regardless of how the token is used. Publishing an
   unverified app is safe for single-user personal use: it only changes who
   can *start* a consent flow against your client, not what they can access —
   OAuth grants scopes against the consenting account's own data, never the
   app owner's.

2. **Export the refresh token and grab the OAuth client credentials**:
   ```bash
   gog auth tokens export you@gmail.com --out /tmp/gog-token-export.json
   ```
   This produces a self-contained JSON blob (refresh token, granted services/scopes,
   client name) designed to round-trip into `gog auth tokens import` on another
   machine. Separately, get the OAuth client JSON (client_id + client_secret) from
   **Google Cloud Console → APIs & Services → Credentials → your OAuth client →
   Download JSON** — `gog auth credentials set` splits this into `credentials.json`
   (client_id) plus the keyring (client_secret) on first use, so the original
   downloaded file (not gog's local copy) is what's needed here; re-downloading
   doesn't rotate anything.

3. **Encrypt both blobs, plus a keyring password, with Ansible Vault**:
   ```bash
   cd ansible
   uv run ansible-vault encrypt_string --vault-id personal@~/.ansible-personal-key \
     --name openclaw_gog_oauth_client_json "$(cat /path/to/downloaded-client-secret.json)"
   uv run ansible-vault encrypt_string --vault-id personal@~/.ansible-personal-key \
     --name openclaw_gog_refresh_token_export_json "$(cat /tmp/gog-token-export.json)"
   uv run ansible-vault encrypt_string --vault-id personal@~/.ansible-personal-key \
     --name openclaw_gog_keyring_password "$(openssl rand -hex 32)"
   rm -f /tmp/gog-token-export.json
   ```
   `openclaw_gog_keyring_password` protects `gog`'s on-disk token store: the
   server has no OS keychain or D-Bus secret service, so `gog`'s `auto` keyring
   backend falls back to its encrypted-file backend, which needs a password on
   every invocation (there's no TTY to prompt for one). It's an arbitrary secret
   you generate once, not something Google issues.

4. **Append the three encrypted blocks to
   [ansible/vars/openclaw.yml](../ansible/vars/openclaw.yml)
   and deploy**:
   ```bash
   uv run ansible-playbook --diff --vault-id personal@~/.ansible-personal-key playbooks/openclaw.yml
   ```
   The role writes the client JSON and token export to short-lived 0600
   temp files under `/home/claw`, feeds them to `gog auth credentials set` /
   `gog auth tokens import` as the `claw` user, then deletes the temp files.
   The token-import step is skipped on repeat runs once `gog auth list`
   already shows `openclaw_setup_gog_account_email`. The client-credentials
   step is skipped the same way once
   `openclaw_setup_gog_credentials_path` exists, which keeps a converged
   host at `changed=0`. Both guards key on presence, not content, so
   **rotating to a different OAuth client or token requires clearing the
   existing keyring entry first** — otherwise the new value is written to
   the vault but never applied to the host. `GOG_KEYRING_PASSWORD`
   is also injected into `/etc/openclaw/secrets.env`, so the openclaw
   service's own `gog` subprocess calls (and manual verification below) can
   unlock the store. `GOG_ACCOUNT` is injected the same way (from
   `openclaw_setup_gog_account_email`) so `gog` invocations that omit
   `-a/--account` — including the agent's own tool calls — default to the
   authorized account instead of falling back to whichever account was
   authorized most recently. `skills.entries.gog.enabled` in `openclaw.json`
   turns on automatically once `openclaw_gog_refresh_token_export_json` is
   defined.

5. **Verify**:
   ```bash
   ssh claw "sudo bash -c '
     set -a; source /etc/openclaw/secrets.env; set +a
     sudo -u claw -E gog auth list
     sudo -u claw -E gog calendar list
   '"
   ```

**Token lifecycle**: with the OAuth client published, the refresh token
doesn't expire on a fixed schedule — it lasts until revoked, unused for 6
months, or invalidated by a Google account security event (e.g. a password
change). If `gog` calls start failing with auth errors, redo step 1 on your
laptop (`gog auth add` re-authorizes in place) and step 2 to get a fresh
export, then re-encrypt `openclaw_gog_refresh_token_export_json` (step 3) and
redeploy. The import task only runs when `gog auth list` on the server does
**not** yet show the account, so redeploying alone won't pick up a rotated
token — first remove the stale one so the task's guard clears:
```bash
ssh claw "sudo bash -c '
  set -a; source /etc/openclaw/secrets.env; set +a
  sudo -u claw -E gog auth remove you@gmail.com --force
'"
```
then redeploy.

---

## 7. Agent Skills Ecosystem

OpenClaw workspace skills are automatically provisioned via Ansible:
1. **Repository Clone**: Clones Addy Osmani's `agent-skills` repository to `/home/claw/src/agent-skills`.
2. **Workspace Symlinks**: Automatically creates symlinks for all available skills under `/home/claw/.openclaw/workspace/skills/`.

---

## 8. Service Management & Troubleshooting

> **Note on the `claw` SSH alias:** The commands below connect through the `ssh claw`
> host alias, which logs in as the **`debian`** account (an administrator with `sudo`),
> *not* the unprivileged `claw` service user. That is why `sudo` is used here for
> system-level operations. The `claw` service user itself has zero sudo; it reads the
> journal directly via its `systemd-journal` group membership (see §3).
>
> The gateway is a systemd **user** unit of `claw`, so root reaches it through that
> user's manager: `systemctl --user -M claw@ …`. Every `openclaw` CLI command goes
> through `sudo openclaw-admin …` (see [§4.1](#41-systemd-secrets-externalization--security-sandboxing)) —
> a plain `sudo -u claw openclaw …` no longer finds the binary or the service environment.

* **Check Systemd Status**:
  ```bash
  ssh claw "sudo systemctl --user -M claw@ status openclaw-gateway"
  ```
* **View Live Gateway Logs**:
  ```bash
  ssh claw "sudo journalctl _SYSTEMD_USER_UNIT=openclaw-gateway.service -f"
  ```
  Use the field match: as root, `journalctl --user-unit=…` also filters on the caller's own uid and shows nothing. As `claw` itself, `journalctl --user -u openclaw-gateway -f` works.
* **Run OpenClaw Deep Diagnostics**:
  ```bash
  ssh claw "sudo openclaw-admin status --deep"
  ```
* **Restart OpenClaw Gateway**:
  ```bash
  ssh claw "sudo systemctl --user -M claw@ restart openclaw-gateway"
  ```
* **Display Dashboard URL on Headless Servers (`--no-open`)**:
  Running `openclaw dashboard` on a remote server attempts to invoke desktop GUI helpers (`xdg-open`) and will delay ~10–12 seconds on headless systems. Pass `--no-open` to output the Gateway URL and token details instantly:
  ```bash
  ssh claw "sudo openclaw-admin dashboard --no-open"
  ```
* **Recovering from an `openclaw.json` schema migration crash-loop**:
  An OpenClaw version bump can ship a breaking `openclaw.json` schema change (e.g. the 2026.8.1 release moved `agents.list` → `agents.entries`, `agents.defaults.memorySearch` → top-level `memory.search`, and flattened `channels.<name>.cliPath` under a `transport` object). If the live config still uses the old shape, the gateway can crash-loop on startup. `openclaw doctor --fix` auto-migrates the on-disk config to the new schema and writes timestamped `openclaw.json.bak.*` snapshots before each rewrite — diff those against `ansible/roles/openclaw_setup/templates/openclaw.json.j2` to confirm the Ansible template matches. **Stop the systemd unit first**: `doctor --fix` refuses to touch the shared state database while it detects the gateway still owns it (`Doctor could not enter maintenance. Error: Gateway service ownership or shutdown could not be verified.`) — a bare `kill`/crash-loop restart loop doesn't count as a clean stop in its eyes, only `systemctl stop` does:
  ```bash
  ssh claw "sudo systemctl --user -M claw@ stop openclaw-gateway"
  ssh claw "sudo openclaw-admin doctor --fix"
  ssh claw "sudo systemctl --user -M claw@ start openclaw-gateway"
  ```
  Run the repair itself through `openclaw-admin` (see [§4.1](#41-systemd-secrets-externalization--security-sandboxing)), not a bare `sudo -u claw openclaw doctor --fix` — the bare form sees none of the service's environment and `doctor` misreports perfectly normal config as broken (missing API keys, `NODE_COMPILE_CACHE`, `OPENCLAW_NO_RESPAWN`, ...). This still works normally even with `openclaw_setup_config_readonly: true` ([§4.3](#43-config-writes--openclaw_config_readonly)): `OPENCLAW_CONFIG_READONLY` is only set on the systemd unit's own `Environment=` line, never in `secrets.env`, so `openclaw-admin` never inherits it — no need to toggle anything off first.

  Update `openclaw.json.j2` (and `ansible/roles/openclaw_setup/defaults/main.yml: openclaw_setup_version`) to match so the next Ansible deploy doesn't regenerate the old schema and re-trigger the same migration. When the new version arrived through a self-update, the updater normally runs these Doctor migrations itself; the reconciliation steps are in [4.4](#44-self-update-on-request).
