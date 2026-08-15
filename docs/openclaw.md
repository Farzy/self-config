# OpenClaw Architecture & Operations Guide

This guide details the deployment, configuration, operational management, and troubleshooting for the **OpenClaw** server hosted on Scaleway.

---

## 1. System Overview & Architecture

* **Cloud Provider**: Scaleway (`PLAY2-PICO` instance, Debian Bookworm).
* **Hostname / Domain**: `claw.farzad.tech` (IP: `163.172.189.14`).
* **Web Gateway**: Nginx reverse proxy with TLS certificate managed by Certbot (Let's Encrypt), forwarding `https://claw.farzad.tech` to `http://127.0.0.1:3000`.
* **Runtime Environment**: Node.js 26.x (`node_26.x` APT repository), OpenClaw systemd service (`openclaw.service`).
* **Dedicated System Account**: User `claw` (`/home/claw`, default shell `/usr/bin/zsh`).
* **LLM Provider**: Anthropic Claude (`anthropic/claude-sonnet-5`), routed through the `claude-cli` agent runtime (reuses a Claude Code login on the host instead of a separate API key — see [6.4](#64-claude-anthropic-model-via-claude-code-cli-reuse)), with optional Scaleway Generative APIs (`https://api.scaleway.ai/5e40a076-f4e5-4328-8052-1a543614ec45/v1`, supporting GLM 5.2, Qwen 3.6 Coder, and Mistral Small 3) available as an alternate provider.
* **Embeddings Provider**: Google Gemini (`gemini-embedding-001`) is still used for `memorySearch` — unrelated to the chat model, kept for semantic memory indexing (see [4.2](#42-memory-search--background-dreaming-configuration)).
* **API Key Management**: Dedicated Gemini API key (embeddings only) and optional Scaleway API key stored encrypted with Ansible Vault in [ansible/vars/openclaw.yml](file:///Users/ffarid/src/personal/self-config/ansible/vars/openclaw.yml). Claude auth uses a long-lived OAuth token (`CLAUDE_CODE_OAUTH_TOKEN`), also vault-encrypted.
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
* **Playbook**: [ansible/playbooks/openclaw.yml](file:///Users/ffarid/src/personal/self-config/ansible/playbooks/openclaw.yml)
* **Encrypted Vault Variables**: [ansible/vars/openclaw.yml](file:///Users/ffarid/src/personal/self-config/ansible/vars/openclaw.yml)
* **OpenClaw Role**: [ansible/roles/openclaw_setup/tasks/main.yml](file:///Users/ffarid/src/personal/self-config/ansible/roles/openclaw_setup/tasks/main.yml)
* **Configuration Template**: [ansible/roles/openclaw_setup/templates/openclaw.json.j2](file:///Users/ffarid/src/personal/self-config/ansible/roles/openclaw_setup/templates/openclaw.json.j2)
* **Systemd Service Template**: [ansible/roles/openclaw_setup/templates/openclaw.service.j2](file:///Users/ffarid/src/personal/self-config/ansible/roles/openclaw_setup/templates/openclaw.service.j2)
* **Secrets Environment Template**: [ansible/roles/openclaw_setup/templates/secrets.env.j2](file:///Users/ffarid/src/personal/self-config/ansible/roles/openclaw_setup/templates/secrets.env.j2)
* **Nginx SSL Proxy Template**: [ansible/roles/openclaw_setup/templates/nginx.conf.j2](file:///Users/ffarid/src/personal/self-config/ansible/roles/openclaw_setup/templates/nginx.conf.j2)

### 4.1 Systemd Secrets Externalization & Security Sandboxing

To protect API tokens and sensitive credentials from unauthorized process access or shell environment leaks, OpenClaw isolates credentials into a restricted secrets file and applies Systemd process sandboxing:

#### 1. Secrets File Isolation (`/etc/openclaw/secrets.env`)
- Instead of declaring inline `Environment=` lines in unit files, sensitive variables (`GEMINI_API_KEY`, `CLAUDE_CODE_OAUTH_TOKEN`, `GITHUB_TOKEN`, `GH_TOKEN`, `ANSIBLE_VAULT_PASSWORD`, `NOTION_API_TOKEN`, `SCALEWAY_API_KEY`) are templated into `/etc/openclaw/secrets.env`.
- Directory `/etc/openclaw` (`root:root`, mode `0700`) and file `/etc/openclaw/secrets.env` (`root:root`, mode `0600`) permissions are strictly locked down to `root`, preventing all unprivileged users (including `claw`) from reading raw tokens.
- **Ansible Vault Password Injection (`ANSIBLE_VAULT_PASSWORD`)**: The control node dynamically reads the local Ansible Vault key (`~/.ansible-personal-key`) during playbook deployment via Jinja2 file lookup (`{{ lookup('file', '~/.ansible-personal-key') | trim }}`) and injects it as `ANSIBLE_VAULT_PASSWORD` into `/etc/openclaw/secrets.env`. This allows OpenClaw subagents and tasks to execute Ansible operations using the standard Vault environment variable without hardcoding or committing plaintext keys to the repository.
- **Notion Integration (`NOTION_API_TOKEN` & `NOTION_API_VERSION`)**: Managed securely via Ansible Vault (`openclaw_notion_api_token` in `ansible/vars/openclaw.yml`) and injected into `/etc/openclaw/secrets.env` along with `NOTION_API_VERSION=2026-03-11` for Notion API integrations.
- Systemd loads `EnvironmentFile=/etc/openclaw/secrets.env` during unit startup before relinquishing root privileges to user `claw`.

#### 2. Threat Model Defense & Harmonized Systemd Sandboxing
The Systemd unit file ([ansible/roles/openclaw_setup/templates/openclaw.service.j2](file:///Users/ffarid/src/personal/self-config/ansible/roles/openclaw_setup/templates/openclaw.service.j2)) configures harmonized process sandboxing balancing security against Node.js runtime needs:

- **`ProtectSystem=strict`**: Mounts root `/`, `/usr`, `/boot`, `/etc` as read-only filesystem paths to prevent OS file tampering.
- **`ReadWritePaths=/home/claw /var/tmp/openclaw-compile-cache`**: Explicitly restricts write permissions strictly to `/home/claw` and the compilation cache directory.
- **`ProtectHome=false`**: Set to `false` to permit user `claw` to read and write its database, configuration, and workspace files under `/home/claw/`.
- **`PrivateTmp=true`**: Provides an isolated `/tmp` namespace preventing token leakage in shared temporary folders.
- **`MemoryDenyWriteExecute=false`**: Set to `false` because the Node.js V8 engine requires W^X JIT (Just-In-Time) compilation memory allocations to execute.
- **`NoNewPrivileges=true`**: Set to `true` to prevent child processes from gaining elevated privileges via `setuid` binaries (user `claw` is unprivileged and has zero sudo access).
- **`ProtectKernelTunables=true`**: Protects `/proc/sys`, `/sys`, and kernel variables from modification.
- **`ProtectKernelModules=true`**: Prevents loading or unloading Linux kernel modules at runtime.
- **`ProtectControlGroups=true`**: Mounts control group hierarchies (`/sys/fs/cgroup`) as read-only.
- **`RestrictRealtime=true`**: Prevents the service from acquiring realtime scheduling priorities to avoid CPU starvation attacks.
- **`CapabilityBoundingSet=` & `AmbientCapabilities=`**: Empty set drops all Linux kernel capabilities from the process bounding set.
- **`RestrictSUIDSGID=true`**: Prevents creation or execution of SUID/SGID binaries by child processes.
- **`ProtectHostname=true`**: Isolates UTS namespace to prevent modifications to system hostname or domain name.
- **`LockPersonality=true`**: Locks execution domain to prevent personality switching.
- **RAM Dump Protection (`kernel.yama.ptrace_scope = 2`)**: Configures kernel YAMA ptrace scope to admin-only (root with `CAP_SYS_PTRACE`), preventing unprivileged processes from attaching debuggers (`gdb`, `strace`) or inspecting `/proc/<pid>/mem` to extract in-memory tokens.


#### 3. Automated User Privilege Verification in Ansible
Ansible automatically asserts system user isolation during playbook execution:
- **Sudoers Cleanup**: Ensures `/etc/sudoers.d/claw` is absent.
- **Group Membership Assertion**: Verifies user `claw` is NOT a member of any privileged groups (`sudo`, `root`, `wheel`, `shadow`, `adm`, `disk`).
- **Sudo Access Check**: Executes `sudo -n -l -U claw` to verify that `claw` has no sudo privileges on the host.
- **Deliberate `systemd-journal` Exception**: `claw` IS added to the `systemd-journal` group so the agent can run `journalctl -u <service>` (e.g. to debug `openclaw` or `fastmail-mcp`) without sudo. This is an accepted trade-off: `systemd-journal` grants read access to the **full system journal** — all units, including sshd/PAM auth events, sudo invocations and kernel messages — chosen over granting `sudo` or the `adm` group. The grant is applied before the group snapshot so the deny-list assertion above validates the converged state.


#### 4.2 Memory Search & Background Dreaming Configuration

To leverage semantic search and automatic long-term memory consolidation, OpenClaw includes active memory searching and dreaming plugins pre-integrated into your Ansible defaults:

* **Semantic Memory Search (`agents.defaults.memorySearch`)**:
  - Configures OpenClaw's vector search pipeline using Google's modern embedding API.
  - Defaults are managed in Ansible via:
    - `openclaw_setup_memory_search_provider` (default: `"gemini"`)
    - `openclaw_setup_memory_search_model` (default: `"gemini-embedding-001"`)
    - `openclaw_setup_memory_search_extra_paths` (default: `["{{ openclaw_setup_home }}/.openclaw/workspace/farzad-wiki"]` to index your professional wiki).
  - It generates the standard `memorySearch` block inside `openclaw.json`, allowing the agent to dynamically index and retrieve matching historical contexts during conversation turns.

* **Memory Dreaming (`plugins.entries.memory-core`)**:
  - Enables OpenClaw's background memory dreaming and consolidation sweeps.
  - Dreaming moves highly reinforced, short-term conversational signals into durable long-term memory (`MEMORY.md`) automatically on a background cron schedule.
  - Managed in Ansible via `openclaw_setup_dreaming_enabled` (default: `true`).

* **Memory Wiki (`plugins.entries.memory-wiki`)**:
  - Enables OpenClaw's structured memory wiki plugin, which maintains cross-linked long-term memory pages alongside `MEMORY.md`.
  - Managed in Ansible via `openclaw_setup_memory_wiki_enabled` (default: `true`).

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
* **`gog`**: Installed via versioned GitHub release download (checksum-verified against the release's `checksums.txt`), extracted to `/opt/gogcli-<version>/`, and symlinked to `/usr/local/bin/gog` — same pattern as `signal-cli` above. The pinned version lives in `openclaw_setup_gog_cli_version` (`ansible/roles/openclaw_setup/defaults/main.yml`). Ansible only installs the binary; OAuth account authorization is a manual, interactive one-time step — see [6.6](#66-gog-google-workspace-cli-oauth-setup).

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
   Append the encrypted block to [ansible/vars/openclaw.yml](file:///Users/ffarid/src/personal/self-config/ansible/vars/openclaw.yml) and re-deploy:
   ```bash
   uv run ansible-playbook --diff --vault-id personal@~/.ansible-personal-key playbooks/openclaw.yml
   ```

4. **Pair Telegram DM**:
   - Open Telegram and start a chat with your new bot.
   - Send a message to the bot.
   - The bot will reply with a 6-character pairing code.
   - Approve the code on the server:
     ```bash
     ssh claw "sudo -u claw openclaw pairing approve <CODE>"
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
   ssh claw "sudo -u claw openclaw channels status"
   ```

3. **DM Pairing Procedure**:
   OpenClaw enforces a pairing policy for direct messages:
   - Send an initial Direct Message to your Signal bot.
   - The bot will reply with a 6-character pairing code.
   - Approve the pairing request on the server:
     ```bash
     ssh claw "sudo -u claw openclaw pairing approve <CODE>"
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
   Append `openclaw_github_pat` to [ansible/vars/openclaw.yml](file:///Users/ffarid/src/personal/self-config/ansible/vars/openclaw.yml) and deploy:
   ```bash
   uv run ansible-playbook --diff --vault-id personal@~/.ansible-personal-key playbooks/openclaw.yml
   ```
   Ansible automatically authenticates `gh` for user `claw` (`gh auth login --with-token`) and injects `GITHUB_TOKEN` and `GH_TOKEN` into the systemd environment.

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
   Append the encrypted block to [ansible/vars/openclaw.yml](file:///Users/ffarid/src/personal/self-config/ansible/vars/openclaw.yml) and re-deploy:
   ```bash
   uv run ansible-playbook --diff --vault-id personal@~/.ansible-personal-key playbooks/openclaw.yml
   ```
   The role installs `@anthropic-ai/claude-code` globally and injects `CLAUDE_CODE_OAUTH_TOKEN` into `/etc/openclaw/secrets.env` (root-only, `0600`), loaded by systemd's `EnvironmentFile=` before OpenClaw drops to the `claw` user — same isolation pattern as `GEMINI_API_KEY` and `GITHUB_TOKEN`.

4. **Register the auth profile (required — the env var alone is not enough)**:
   `agentRuntime.id: "claude-cli"` on its own does **not** give OpenClaw a usable Anthropic credential. OpenClaw's own "CLI reuse" verification path (`openclaw models auth login --provider anthropic --method cli`) needs an interactive TTY to confirm the host's `claude` login — impossible on a systemd-managed headless box, and it fails with `Error: models auth login requires an interactive TTY`. Without a registered profile, `openclaw models auth list` shows `Profiles: (none)` and every request silently falls through the whole fallback chain (Gemini, then Scaleway) — Claude is configured as primary but never actually gets called. Register the same token as a profile instead (headless-safe, reads from stdin so the token never touches shell history):
   ```bash
   ssh claw "sudo bash -c '
     grep ^CLAUDE_CODE_OAUTH_TOKEN= /etc/openclaw/secrets.env | cut -d= -f2- \
       | sudo -u claw openclaw models auth paste-token --provider anthropic
   '"
   ```
   This writes the actual token only into `~/.openclaw/agents/main/agent/openclaw-agent.sqlite` (never into `openclaw.json`). It also adds a non-secret pointer, `agents` → `auth.profiles.anthropic:manual = {"provider": "anthropic", "mode": "token"}`, to `openclaw.json` itself — that pointer **is** templated (`openclaw.json.j2`, gated on `openclaw_setup_claude_cli_enabled`) specifically so a future `ansible-playbook` run doesn't overwrite it and silently reintroduce this exact bug. The token in the sqlite store is untouched by Ansible either way (it's not a file the role manages).

5. **Whitelist the token through OpenClaw's own subprocess env sanitization (required — steps 1–4 alone still silently fall back to Gemini)**:
   OpenClaw hard-codes `CLAUDE_CODE_OAUTH_TOKEN` into `CLAUDE_CLI_CLEAR_ENV` (`extensions/anthropic/cli-shared.ts` in the npm package) and strips it — along with every other Anthropic auth env var — before spawning the `claude` CLI subprocess for every `claude-cli` turn. This is deliberate: OpenClaw's docs say it "never forwards a copied token for this path," so the CLI is expected to already be natively logged in on the host via its own persisted credentials. A systemd-managed headless box has no such interactive login to reuse, so without this step every `claude-cli` turn fails with `error=FailoverError` / `detail=Not logged in · Please run /login` (visible in `journalctl -u openclaw`) and falls straight through to Gemini — invisibly, since the gateway logs "model configured, enabled automatically" at startup regardless. There's a documented escape hatch: `OPENCLAW_LIVE_CLI_BACKEND_PRESERVE_ENV`, a comma/space-separated allowlist of env vars to preserve despite `clearEnv`. `secrets.env.j2` sets `OPENCLAW_LIVE_CLI_BACKEND_PRESERVE_ENV=CLAUDE_CODE_OAUTH_TOKEN` whenever the token is defined — no separate action needed beyond deploying.

6. **Verify — with an actual live call, not just a status check**:
   `openclaw models auth list` (expect `anthropic:manual [anthropic/token]`) and `openclaw models status`'s `Runtime auth: ... status=usable` line both look green even when the subprocess env-stripping bug above is still active — they only confirm a profile *exists*, not that a `claude-cli` turn actually succeeds. Likewise `status --deep`'s "Model selection" table reflects each session's *last actual turn*, so a session shown on a fallback model may just predate a fix. The only real proof is a completed turn with no fallback:
   ```bash
   ssh claw "sudo -u claw openclaw agent --session-key agent:main:verify --message 'reply with exactly: OK' --model anthropic/claude-sonnet-5 --json" \
     | python3 -c "import json,sys; r=json.load(sys.stdin)['result']; print(r['payloads'][0]['text']); print(r['meta']['systemPromptReport']['provider'])"
   # expect: OK / claude-cli  (not gemini-3.1-pro-preview or scaleway/*)
   ```
   Or just send a real message through Telegram/Signal and check which model answered.

**Token lifecycle**: `claude setup-token` tokens are long-lived (weeks to months) but not permanent. If OpenClaw's model calls start failing with auth errors, regenerate with `claude setup-token`, redeploy step 2–3, then re-run step 4 (`paste-token`) with the new token — the profile isn't updated automatically just because `secrets.env` changed. Step 5 (`OPENCLAW_LIVE_CLI_BACKEND_PRESERVE_ENV`) is a static config value and doesn't need repeating on rotation.

**Switching model tier**: `openclaw_setup_model` (`ansible/roles/openclaw_setup/defaults/main.yml`, default `anthropic/claude-sonnet-5`) can be overridden per-inventory to `anthropic/claude-opus-5` for higher-quality/slower responses, or any other `anthropic/claude-*` id — the `claude-cli` `agentRuntime` mapping in the template follows whatever `openclaw_setup_model` is set to, as long as `openclaw_setup_claude_cli_enabled` stays `true`.

**Reverting to Gemini as primary**: set `openclaw_setup_model: "google/gemini-3.1-pro-preview"` and `openclaw_setup_claude_cli_enabled: false`, then redeploy. `GEMINI_API_KEY` and the `google` plugin stay wired regardless (needed for `memorySearch` embeddings).

### 6.5 Model Fallback Chain & Reasoning Config

`agents.defaults.model` failover order and the per-model reasoning tuning are template-driven from `ansible/roles/openclaw_setup/defaults/main.yml`:

* **`openclaw_setup_model_fallbacks`** (default: `["google/gemini-3.1-pro-preview", "scaleway/glm-5.2", "scaleway/qwen3.6-35b-a3b"]`) — ordered failover list rendered into `agents.defaults.model.fallbacks`, tried in order if the primary Claude model errors or rate-limits. Empty list omits the `fallbacks` key entirely.
* **`agents.defaults.models`** is built in the template (`openclaw.json.j2`, via a Jinja `namespace`/`combine`) rather than hand-authored, so it never has to choose between the Claude `agentRuntime` entry and the Scaleway reasoning params — both are merged in:
  - The primary model gets `{"agentRuntime": {"id": "claude-cli"}}` when `openclaw_setup_claude_cli_enabled` is `true`.
  - Every id in **`openclaw_setup_scaleway_reasoning_model_ids`** (default: `glm-5.2`, `qwen3.6-35b-a3b`) gets `{"params": {"extra_body": {"thinking": {"type": "enabled"}, "reasoning_effort": "high"}}}` when `openclaw_setup_scaleway_enabled` is `true`. `mistral-small-3.2-24b-instruct-2506` is deliberately excluded (no extended-thinking support).
* **`openclaw_setup_reasoning_default`** (default: `"stream"`) — rendered as `agents.defaults.reasoningDefault`.
* **`openclaw_setup_scaleway_api`** (default: `"openai-responses"`) — rendered as `models.providers.scaleway.api`, alongside the existing `baseUrl`/`apiKey`/`models` fields.
* **`openclaw_setup_telegram_thread_bindings_enabled`** (default: `true`) — rendered as `channels.telegram.threadBindings.enabled`.

These four settings previously existed only as manual drift on the live server (set outside Ansible) and were wiped by a plain redeploy; they're now first-class template inputs so `ansible-playbook --diff` stays a true no-op when nothing has actually changed.

---

### 6.6 `gog` (Google Workspace CLI) OAuth Setup

Ansible only installs the `gog` binary (see [5.5](#55-google-workspace-cli-gog)); authorizing it against a Google account requires an interactive OAuth flow in a browser, so it cannot be automated headlessly and must be run manually after deploy:

1. **Run the interactive auth setup on the server**:
   ```bash
   ssh claw "sudo -u claw gog auth setup"
   ```
   Follow the printed instructions to create/select a Google Cloud project and enable the required APIs.

2. **Authorize the account for the services you need**:
   ```bash
   ssh claw "sudo -u claw gog auth add you@gmail.com --services calendar"
   ```
   This opens a browser-based OAuth consent flow — if the server has no local browser/display, `gog` prints a URL to open manually and a code/callback to complete on the server side.

3. **Verify**:
   ```bash
   ssh claw "sudo -u claw gog calendar list"
   ```

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

* **Check Systemd Status**:
  ```bash
  ssh claw "sudo systemctl status openclaw"
  ```
* **View Live Gateway Logs**:
  ```bash
  ssh claw "sudo journalctl -u openclaw -f"
  ```
* **Run OpenClaw Deep Diagnostics**:
  ```bash
  ssh claw "sudo -u claw openclaw status --deep"
  ```
* **Restart OpenClaw Gateway**:
  ```bash
  ssh claw "sudo systemctl restart openclaw"
  ```
* **Display Dashboard URL on Headless Servers (`--no-open`)**:
  Running `openclaw dashboard` on a remote server attempts to invoke desktop GUI helpers (`xdg-open`) and will delay ~10–12 seconds on headless systems. Pass `--no-open` to output the Gateway URL and token details instantly:
  ```bash
  ssh claw "sudo -u claw openclaw dashboard --no-open"
  ```
