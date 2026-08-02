# OpenClaw Architecture & Operations Guide

This guide details the deployment, configuration, operational management, and troubleshooting for the **OpenClaw** server hosted on Scaleway.

---

## 1. System Overview & Architecture

* **Cloud Provider**: Scaleway (`PLAY2-PICO` instance, Debian Bookworm).
* **Hostname / Domain**: `claw.farzad.tech` (IP: `163.172.189.14`).
* **Web Gateway**: Nginx reverse proxy with TLS certificate managed by Certbot (Let's Encrypt), forwarding `https://claw.farzad.tech` to `http://127.0.0.1:3000`.
* **Runtime Environment**: Node.js 26.x (`node_26.x` APT repository), OpenClaw systemd service (`openclaw.service`).
* **LLM Provider**: Google Gemini (`google/gemini-3.6-flash`).
* **API Key Management**: Dedicated Gemini API key stored encrypted with Ansible Vault in [ansible/vars/openclaw.yml](file:///Users/ffarid/src/personal/self-config/ansible/vars/openclaw.yml).
* **Control Channel**: Signal integration using `@openclaw/signal` plugin and native `signal-cli` (`v0.13.12`), enforcing Direct Message pairing policy (`dmPolicy: "pairing"`).

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
* **Configuration Template**: [ansible/roles/openclaw_setup/templates/openclaw.json.j2](file:///Users/ffarid/src/personal/self-config/ansible/roles/openclaw_setup/templates/openclaw.json.j2)
* **Systemd Service Template**: [ansible/roles/openclaw_setup/templates/openclaw.service.j2](file:///Users/ffarid/src/personal/self-config/ansible/roles/openclaw_setup/templates/openclaw.service.j2)
* **Nginx SSL Proxy Template**: [ansible/roles/openclaw_setup/templates/nginx.conf.j2](file:///Users/ffarid/src/personal/self-config/ansible/roles/openclaw_setup/templates/nginx.conf.j2)

---

## 5. Signal Control Channel & Pairing Workflow

### 1. Link Signal CLI
To link a Signal account (secondary device or new number):
```bash
ssh claw "sudo -u claw signal-cli link -n 'OpenClaw'"
```
Scan the displayed QR code using the Signal mobile app (**Settings > Linked Devices**).

### 2. Verify Signal Channel
Check channel readiness and status:
```bash
ssh claw "sudo -u claw openclaw channels status"
```

### 3. DM Pairing Procedure
OpenClaw enforces a pairing policy for direct messages:
1. Send a initial Direct Message to your Signal bot.
2. The bot will reply with a 6-character pairing code.
3. Approve the pairing request on the server:
   ```bash
   ssh claw "sudo -u claw openclaw pairing approve <CODE>"
   ```

---

## 5.2. Telegram Control Channel Setup

### 1. Create a Bot via @BotFather
1. Open Telegram and search for `@BotFather`.
2. Send `/newbot` and follow instructions to choose a Bot Name and Username.
3. `@BotFather` will output an HTTP API Bot Token (e.g. `123456789:ABCdefGhIJKlmNoPQRsTUVwxyZ`).

### 2. Encrypt Bot Token with Ansible Vault
Save the token temporarily to `/tmp/temp-telegram-bot-token` on your laptop, then encrypt it:
```bash
cd ansible
uv run ansible-vault encrypt_string --vault-id personal@~/.ansible-personal-key --name openclaw_telegram_bot_token "$(cat /tmp/temp-telegram-bot-token)"
rm -f /tmp/temp-telegram-bot-token
```
Append the encrypted block to [ansible/vars/openclaw.yml](file:///Users/ffarid/src/personal/self-config/ansible/vars/openclaw.yml) and re-deploy:
```bash
uv run ansible-playbook --diff --vault-id personal@~/.ansible-personal-key playbooks/openclaw.yml
```

### 3. Pair Telegram DM
1. Open Telegram and start a chat with your new bot.
2. Send a message to the bot.
3. The bot will reply with a 6-character pairing code.
4. Approve the code on the server:
   ```bash
   ssh claw "sudo -u claw openclaw pairing approve <CODE>"
   ```

---

## 5.3. GitHub Personal Access Token (PAT) Integration

To allow OpenClaw agents to interact securely with private GitHub repositories (e.g. via `gh`, `git`, or GitHub tools):

1. **Create a Fine-Grained PAT on GitHub**:
   - Go to **GitHub Settings > Developer Settings > Personal Access Tokens > Fine-grained tokens**.
   - Select your user account and choose **Only select repositories** (select the personal repos OpenClaw needs).
   - Grant minimal necessary permissions (e.g., `Contents: Read/Write`, `Pull requests: Read/Write`, `Issues: Read/Write`).

2. **Encrypt the PAT with Ansible Vault**:
   Save the token to a temporary file on your Mac, encrypt it, and remove the temp file:
   ```bash
   echo "github_pat_11..." > /tmp/temp-github-pat
   cd ansible
   uv run ansible-vault encrypt_string --vault-id personal@~/.ansible-personal-key --name openclaw_github_pat "$(cat /tmp/temp-github-pat | tr -d '\r\n')"
   rm -f /tmp/temp-github-pat
   ```

3. **Append to Vault Variables & Deploy**:
   Append `openclaw_github_pat` to [ansible/vars/openclaw.yml](file:///Users/ffarid/src/personal/self-config/ansible/vars/openclaw.yml) and deploy:
   ```bash
   uv run ansible-playbook --diff --vault-id personal@~/.ansible-personal-key playbooks/openclaw.yml
   ```
   The Ansible template automatically injects `GITHUB_TOKEN` and `GH_TOKEN` into OpenClaw's systemd environment.

---



## 6. Service Management & Troubleshooting

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
