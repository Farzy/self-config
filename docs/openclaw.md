# OpenClaw Architecture & Operations Guide

This guide details the deployment, configuration, operational management, and troubleshooting for the **OpenClaw** server hosted on Scaleway.

---

## 1. System Overview & Architecture

* **Cloud Provider**: Scaleway (`PLAY2-PICO` instance, Debian Bookworm).
* **Hostname / Domain**: `claw.farzad.tech` (IP: `163.172.189.14`).
* **Web Gateway**: Nginx reverse proxy with TLS certificate managed by Certbot (Let's Encrypt), forwarding `https://claw.farzad.tech` to `http://127.0.0.1:3000`.
* **Runtime Environment**: Node.js 26.x (`node_26.x` APT repository), OpenClaw systemd service (`openclaw.service`).
* **Dedicated System Account**: User `claw` (`/home/claw`, default shell `/usr/bin/zsh`).
* **LLM Provider**: Google Gemini (`google/gemini-3.1-pro-preview`).
* **API Key Management**: Dedicated Gemini API key stored encrypted with Ansible Vault in [ansible/vars/openclaw.yml](file:///Users/ffarid/src/personal/self-config/ansible/vars/openclaw.yml).
* **Control Channels**:
  - **Telegram**: Stock `@openclaw/telegram` plugin connected in live long-polling mode using an encrypted bot token.
  - **Signal**: Integration using `@openclaw/signal` plugin and native `signal-cli` (`v0.13.12`), enforcing Direct Message pairing policy (`dmPolicy: "pairing"`).
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
- Instead of declaring inline `Environment=` lines in unit files, sensitive variables (`GEMINI_API_KEY`, `GITHUB_TOKEN`, `GH_TOKEN`) are templated into `/etc/openclaw/secrets.env`.
- Directory `/etc/openclaw` (`root:root`, mode `0700`) and file `/etc/openclaw/secrets.env` (`root:root`, mode `0600`) permissions are strictly locked down to `root`, preventing all unprivileged users (including `claw`) from reading raw tokens.

- Systemd loads `EnvironmentFile=/etc/openclaw/secrets.env` during unit startup before relinquishing root privileges to user `claw`.

#### 2. Threat Model Defense & Harmonized Systemd Sandboxing
The Systemd unit file ([ansible/roles/openclaw_setup/templates/openclaw.service.j2](file:///Users/ffarid/src/personal/self-config/ansible/roles/openclaw_setup/templates/openclaw.service.j2)) configures harmonized process sandboxing balancing security against Node.js runtime needs:
- **`ProtectSystem=strict`**: Mounts root `/`, `/usr`, `/boot`, `/etc` as read-only filesystem paths to prevent OS file tampering.
- **`ReadWritePaths=/home/claw /var/tmp/openclaw-compile-cache`**: Explicitly restricts write permissions strictly to `/home/claw` and the compilation cache directory.
- **`ProtectHome=false`**: Set to `false` to permit user `claw` to read and write its database, configuration, and workspace files under `/home/claw/`.
- **`PrivateTmp=true`**: Provides an isolated `/tmp` namespace preventing token leakage in shared temporary folders.
- **`MemoryDenyWriteExecute=false`**: Set to `false` because the Node.js V8 engine requires W^X JIT (Just-In-Time) compilation memory allocations to execute.
- **`NoNewPrivileges=false`**: Set to `false` to allow the agent to execute administrative subcommands (e.g., `sudo`) if configured.
- **`ProtectKernelTunables=true`**: Protects `/proc/sys`, `/sys`, and kernel variables from modification.
- **`ProtectKernelModules=true`**: Prevents loading or unloading Linux kernel modules at runtime.
- **`ProtectControlGroups=true`**: Mounts control group hierarchies (`/sys/fs/cgroup`) as read-only.
- **`RestrictRealtime=true`**: Prevents the service from acquiring realtime scheduling priorities to avoid CPU starvation attacks.
- **RAM Dump Protection (`kernel.yama.ptrace_scope = 2`)**: Configures kernel YAMA ptrace scope to admin-only (root with `CAP_SYS_PTRACE`), preventing unprivileged processes from attaching debuggers (`gdb`, `strace`) or inspecting `/proc/<pid>/mem` to extract in-memory tokens.



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

## 7. Agent Skills Ecosystem

OpenClaw workspace skills are automatically provisioned via Ansible:
1. **Repository Clone**: Clones Addy Osmani's `agent-skills` repository to `/home/claw/src/agent-skills`.
2. **Workspace Symlinks**: Automatically creates symlinks for all available skills under `/home/claw/.openclaw/workspace/skills/`.

---

## 8. Service Management & Troubleshooting

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
