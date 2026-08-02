# Fastmail MCP Server Setup & Administration Guide

This document details the architecture, security hardening, secrets management, deployment procedure, and upgrade operations for the Fastmail Model Context Protocol (MCP) server ([MadLlama25/fastmail-mcp](https://github.com/MadLlama25/fastmail-mcp)) running on `claw.farzad.tech`.

---

## 1. Overview & Architecture

The Fastmail MCP server enables AI assistants (such as OpenClaw) to securely query and manage Fastmail email, contacts, and calendar data via JMAP/CalDAV APIs.

- **Process Supervisor**: Managed as a Systemd service (`fastmail-mcp.service`).
- **Dedicated System User**: Runs under dedicated unprivileged account `fastmail-mcp` (`/home/fastmail-mcp`, shell `/usr/sbin/nologin`).
- **Application Path**: Application source compiled at `/opt/fastmail-mcp`.
- **Local Network Isolation**: Uses `supergateway` to bridge stdio to HTTP/SSE listening **exclusively on loopback** (`127.0.0.1:18790`). The service is not bound to `0.0.0.0` and is completely unexposed to the internet.

---

## 2. Security Hardening & Isolation

### Secrets Isolation (`/etc/fastmail-mcp/secrets.env`)
To prevent token leakage in process environments or shell history:
- Sensitive runtime environment variables (`FASTMAIL_API_TOKEN`, `FASTMAIL_BASE_URL`, `FASTMAIL_DOWNLOAD_DIR`, `PORT`) are externalized to `/etc/fastmail-mcp/secrets.env`.
- Directory `/etc/fastmail-mcp` (`root:root`, mode `0700`) and file `/etc/fastmail-mcp/secrets.env` (`root:root`, mode `0600`) permissions are strictly locked down to `root`. Unprivileged system accounts (including `fastmail-mcp`) cannot read raw credentials from disk.
- Systemd loads `EnvironmentFile=/etc/fastmail-mcp/secrets.env` as `root` during unit startup before dropping privileges to user `fastmail-mcp`.

### Privilege Isolation & Automated Assertions
- **No Sudo Access**: User `fastmail-mcp` is not present in `/etc/sudoers` or `/etc/sudoers.d/`.
- **Automated Assertions**: The Ansible setup role (`fastmail_mcp_setup`) runs automated checks verifying that `fastmail-mcp` is not a member of any privileged groups (`sudo`, `root`, `wheel`, `shadow`, `adm`, `disk`) and has zero sudo execution privileges.

### Systemd Process Sandboxing
The unit file (`fastmail-mcp.service.j2`) applies defense-in-depth Systemd sandboxing policies:
- **`ProtectSystem=strict`**: Mounts root `/`, `/usr`, `/boot`, `/etc` as read-only.
- **`ReadWritePaths=/home/fastmail-mcp`**: Limits write permissions strictly to the user's home directory.
- **`ProtectHome=false`**: Allows `fastmail-mcp` to write attachment downloads in `/home/fastmail-mcp/downloads`.
- **OpenClaw File Access**: User `claw` is added to group `fastmail-mcp`, and directories `/home/fastmail-mcp` and `/home/fastmail-mcp/downloads` are configured with permissions `0750` (`owner: fastmail-mcp`, `group: fastmail-mcp`), allowing OpenClaw to read email attachment downloads.

- **`PrivateTmp=true`**: Provides an isolated `/tmp` and `/var/tmp` namespace.
- **`MemoryDenyWriteExecute=false`**: Allows Node.js V8 engine W^X JIT compilation allocations.
- **`NoNewPrivileges=true`**: Blocks privilege escalation via `setuid`/`setgid` binaries.
- **`CapabilityBoundingSet=` & `AmbientCapabilities=`**: Drops all Linux kernel capabilities.
- **`RestrictSUIDSGID=true`**: Prevents creation or execution of SUID/SGID binaries.
- **`ProtectHostname=true`**: Prevents system hostname modifications.
- **`LockPersonality=true`**: Locks execution architecture domain.
- **`ProtectKernelTunables=true`**: Protects `/proc/sys`, `/sys`, and kernel parameters.
- **`ProtectKernelModules=true`**: Prevents kernel module loading/unloading.
- **`ProtectControlGroups=true`**: Mounts control group hierarchies read-only.
- **`RestrictRealtime=true`**: Blocks acquisition of realtime scheduling priorities.

---

## 3. Maintenance & Upgrades

### Bumping Version
The installation version is managed by the default variable `fastmail_mcp_version` in [ansible/roles/fastmail_mcp_setup/defaults/main.yml](file:///Users/ffarid/src/personal/self-config/ansible/roles/fastmail_mcp_setup/defaults/main.yml):

```yaml
fastmail_mcp_version: "v1.13.4"
```

To upgrade to a new release:
1. Update `fastmail_mcp_version` in `defaults/main.yml`.
2. Run the Ansible playbook:
   ```bash
   cd ansible
   uv run ansible-playbook --diff --vault-id personal@~/.ansible-personal-key playbooks/openclaw.yml
   ```
3. Ansible will pull the new tag, re-run `npm install` & `npm run build`, restart `fastmail-mcp.service`, and verify health.

---

## 4. Operational Commands

### Checking Service Status
```bash
systemctl status fastmail-mcp
```

### Viewing Realtime Logs
```bash
journalctl -u fastmail-mcp -f
```

### Testing Local Loopback Endpoint
```bash
curl -s http://127.0.0.1:18790/sse
```
