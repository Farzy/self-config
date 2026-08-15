# Gemini Code Assistant Context

This file provides context to the Gemini Code Assistant to help it understand the project and provide more accurate and relevant assistance.

## Project Overview

This is a personal infrastructure-as-code (IaC) repository for managing personal servers and development environments. It uses a combination of technologies to automate the setup and configuration of various services.

The primary tools used are:

*   **Ansible:** For configuration management and application deployment.
*   **Terraform:** For provisioning and managing cloud infrastructure.
*   **Docker:** For containerization of applications.
*   **Kubernetes (KinD & MicroK8s):** For container orchestration.

The infrastructure is hosted on:

*   **Google Cloud Platform (GCP)**
*   **Scaleway**

The project is structured to manage different environments, including web servers, Kubernetes clusters, and personal laptops.

## Building and Running

### Python Environment

The project uses Python with dependencies managed by `uv`. The required Python version is specified in the `.python-version` file.

To set up the environment:

1.  Install `uv` if you haven't already.
2.  Install the dependencies:

    ```bash
    uv pip install -r requirements.txt
    ```

### Ansible

The Ansible configuration is in the `ansible/` directory.

*   **Configuration:** `ansible/ansible.cfg`
*   **Inventory:** `ansible/hosts`
*   **Roles:** `ansible/roles/`
*   **Playbooks:** `ansible/playbooks/`

- You **must** change directory to `ansible/` before running any playbook.
- Always test the playbook with `--check` flag first.
- Always test the playbook with `--diff` flag.

To run a playbook, for example `laptop.yml`:

```bash
cd ansible
ansible-playbook playbooks/laptop.yml
```

### GitHub Actions

Ansible also runs from CI. See [docs/ci-ansible.md](docs/ci-ansible.md) for the
full design; the essentials for making changes:

*   `.github/workflows/ansible-ci.yml` — lint and syntax validation. Runs on
    every pull request **including forks**, so it must never be given a secret
    or made to contact a managed host.
*   `.github/workflows/ansible-deploy.yml` — the only workflow with server
    access. Manually dispatched; `apply` runs are gated by the
    `claw-production` environment. `push`/`schedule` runs are check-mode only.
*   Deploys are refused unless every host matched by `--limit` has a pinned SSH
    host key in `ansible/known_hosts`. Adding a server means adding its host key
    there first.
*   **This repository is public**: workflow logs are world-readable. `--diff` is
    off by default in CI (overriding `ansible.cfg`) because rendered templates
    can contain vault-decrypted secrets. Never echo a secret into a log or a job
    summary.
*   Workflows are linted by `actionlint` and audited by `zizmor` via
    `pre-commit`. Pin third-party actions to a commit SHA with a
    `# ratchet:owner/repo@vX` comment.

### Terraform

The Terraform configuration is in the `terraform/` directory.

*   **Backend:** Google Cloud Storage (GCS)
*   **Providers:** Google Cloud, Scaleway

To apply the Terraform configuration:

```bash
cd terraform
terraform init
terraform plan
terraform apply
```

## Development Conventions

*   **Python:**
    *   Uses `uv` for dependency management.
    *   The main dependencies are listed in `pyproject.toml`.
*   **Ansible:**
    *   Roles are used to structure the configuration.
    *   The inventory is split into groups for different types of hosts.
    *   Vault is used for managing secrets.
*   **Terraform:**
    *   The configuration is modularized.
    *   A GCS backend is used for storing the state.

## Security & Secret Handling

> [!CAUTION]
> **No Secrets in Prompts**: Under no circumstances should raw API tokens, passwords, private keys, or other credentials be copied or pasted directly into a chat prompt or agent message.

> [!CAUTION]
> **No Plaintext Secrets in Ansible Vars**: NEVER store secrets (SSH keys, API tokens, passwords, private keys) in plain text in Ansible vars or role default files. They MUST always be encrypted using the default Ansible Vault key (`ansible-vault encrypt_string --vault-id personal@~/.ansible-personal-key ...`).


### Prompt Leak Warning & Invalidation Rule
If the user ever copies or pastes a raw private key, password, or token into a prompt:
1. **Warn the User immediately**: Alert the user that a secret was shared in plain text.
2. **Request Invalidation**: Instruct the user to immediately revoke/invalidate the exposed secret on the provider's platform (e.g., GitHub, AWS, etc.).
3. **Instruct Safe Transmission**: Guide the user to transmit the secret safely by saving it to a temporary local file (e.g., under `/tmp/` or a gitignored path) and pointing the agent to its location.

### Renewing Personal GitHub Keys
The Ansible configuration stores personal GitHub tokens encrypted with Ansible Vault.
The two relevant tokens are:
*   `github_token` (Regular and MCP key, corresponding to `.zshrc`'s `export GITHUB_TOKEN=...`)
*   `github_homebrew_token` (Homebrew API key, corresponding to `.zshrc`'s `export HOMEBREW_GITHUB_API_TOKEN=...`)

#### Safe Encryption and Update Procedure:
> [!CAUTION]
> **Avoid Vault Typos**: When copying the encrypted vault string from the command output to the YAML file, do not manually edit, retype, or format any hex characters. Make sure the lines are copied exactly as-is and aligned with 2 spaces of indentation. Valid hex characters are only lowercase `[0-9a-f]` and lines must have an even length (no odd-length hex strings).

1. Save the new keys temporarily to local files (e.g., under `/tmp/` or a gitignored path):
   * Regular key: `/tmp/temp-regular-key` (or similar)
   * Homebrew key: `/tmp/temp-homebrew-key` (or similar)
2. Run `ansible-vault encrypt_string` to encrypt the keys using the vault key stored at `~/.ansible-personal-key` and the vault ID `personal`:
   ```bash
   uv run ansible-vault encrypt_string --vault-id personal@~/.ansible-personal-key --name github_token "$(cat /tmp/temp-regular-key | tr -d '\r\n')"
   uv run ansible-vault encrypt_string --vault-id personal@~/.ansible-personal-key --name github_homebrew_token "$(cat /tmp/temp-homebrew-key | tr -d '\r\n')"
   ```
3. Update the encrypted values under `github_token` and `github_homebrew_token` in [laptop.yml](file:///Users/ffarid/src/personal/self-config/ansible/vars/laptop.yml).
4. **Delete the temporary key files immediately** from local storage:
   ```bash
   rm -f /tmp/temp-regular-key /tmp/temp-homebrew-key
   ```
