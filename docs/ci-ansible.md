# Running Ansible from GitHub Actions

This guide covers the CI/CD pipeline that lints this repository and converges
Ansible configuration onto remote servers, starting with the OpenClaw server
(`claw.farzad.tech`).

> [!IMPORTANT]
> **This repository is public.** Workflow logs, job summaries and artifacts are
> world-readable. Every design decision below follows from that.

---

## 1. The two workflows

| Workflow | File | Triggers | Secrets | Reaches a server? |
|---|---|---|---|---|
| `✅ Ansible CI` | [`.github/workflows/ansible-ci.yml`](../.github/workflows/ansible-ci.yml) | every `pull_request`, `push` to `main` | none | no |
| `🚀 Ansible Deploy` | [`.github/workflows/ansible-deploy.yml`](../.github/workflows/ansible-deploy.yml) | `workflow_dispatch`, `push` to `main` (check only), weekly cron | `CI_SSH_PRIVATE_KEY`, `ANSIBLE_VAULT_PASSWORD` | yes |

The split is the primary control. `Ansible CI` runs on untrusted input — anyone
can fork this repository and open a pull request — so it holds **no credential
of any kind** and never opens a network connection to a managed host. It does
`yamllint`, `ansible-lint`, `ansible-playbook --syntax-check` on every playbook,
and an inventory parse.

`Ansible Deploy` is the only workflow with server access, and it is never
triggered by pull request content.

---

## 2. Safety model

| Control | Implementation |
|---|---|
| **No PR-triggered access** | `workflow_dispatch` is restricted by GitHub to users with write access. `push`/`schedule` runs are hard-wired to `--check`; only an explicit dispatch can apply. |
| **Human approval for apply** | `apply` runs execute in the `claw-production` environment, which requires a reviewer. `check` runs use `claw-check`, which has no protection rules. |
| **Blast-radius limit** | Before connecting, the workflow resolves `--limit` against the inventory and **refuses to run** unless every resulting host has a pinned SSH host key in [`ansible/known_hosts`](../ansible/known_hosts). A typo like `--limit all` fails closed. |
| **MITM resistance** | `StrictHostKeyChecking=yes` against the committed `known_hosts`. Ephemeral runners have no known-hosts of their own, so without this pin the only options would be trust-on-first-use or disabling host key checking. |
| **Least-privilege credentials** | A dedicated ed25519 key used only by CI, revocable without touching your personal key. |
| **No secret spillage into logs** | `--diff` is **off by default**, overriding `[diff] always = True` in `ansible.cfg`, because rendered templates can contain vault-decrypted secrets. `ANSIBLE_LOG_PATH` is redirected to `$RUNNER_TEMP` and shredded. |
| **Credential hygiene** | Secrets are written outside the workspace with `umask 077` and shredded in an `always()` step: the SSH key to `$RUNNER_TEMP`, the vault password to `~/.ansible-personal-key` (see §9). `actions/checkout` runs with `persist-credentials: false`. |
| **Supply chain** | All third-party actions pinned to commit SHAs; Python toolchain installed with `uv sync --locked`; Galaxy collections pinned in `ansible/requirements.yml`; `zizmor` and `actionlint` enforce workflow hygiene via `pre-commit`. |
| **No concurrent converges** | `concurrency: ansible-deploy` with `cancel-in-progress: false` — a queued run is better than a half-applied one. |

---

## 3. Secrets to add to GitHub

Exactly **two**. Both are repository secrets.

| Secret | Value | Rotate by |
|---|---|---|
| `CI_SSH_PRIVATE_KEY` | Private half of the dedicated CI ed25519 key (full PEM, `-----BEGIN OPENSSH PRIVATE KEY-----` … `-----END OPENSSH PRIVATE KEY-----`). Must be **unencrypted** — a runner cannot type a passphrase. | Generating a new keypair, §4.1 |
| `ANSIBLE_VAULT_PASSWORD` | The contents of `~/.ansible-personal-key` — the passphrase that decrypts the `!vault` values in `ansible/vars/*.yml`. | `ansible-vault rekey` across all vars files |

`ANTHROPIC_API_KEY` already exists for the Claude workflows and is unrelated.

> [!NOTE]
> These are repository-level secrets, so the `check` path can use them without
> approval. If you later want the vault password to require approval too, move
> both secrets into the `claw-check` and `claw-production` environments (they
> must be duplicated into each) and remove the repository-level copies.

---

## 4. One-time setup

### 4.1 Generate the dedicated CI key

Do **not** reuse your personal SSH key: the whole point is that this credential
can be revoked without touching anything else you log in with.

```bash
ssh-keygen -t ed25519 -C "github-actions@self-config" -f ~/.ssh/claw_ci -N ""
```

### 4.2 Record the public half in Ansible

Public keys are not secrets, so this lives in plain text and is managed as code
— rotating or revoking the key becomes a reviewed commit rather than a manual
edit on the box.

Paste the contents of `~/.ssh/claw_ci.pub` into `master_setup_ci_authorized_keys`
in [`ansible/vars/openclaw.yml`](../ansible/vars/openclaw.yml):

```yaml
master_setup_ci_authorized_keys:
  - "ssh-ed25519 AAAAC3Nza... github-actions@self-config"
```

The `master_setup` role installs these into the `authorized_keys` of the
inventory's `ansible_user` (`debian` for `claw.farzad.tech`).

### 4.3 Bootstrap the key onto the server

Chicken-and-egg: CI cannot log in to install its own key. Install it once from
your laptop, which already has access:

```bash
cd ansible
ansible-playbook playbooks/openclaw.yml --tags ci_access --check --diff   # review
ansible-playbook playbooks/openclaw.yml --tags ci_access                  # apply
```

Verify before going further:

```bash
ssh -i ~/.ssh/claw_ci -o IdentitiesOnly=yes debian@claw.farzad.tech 'sudo -n true && echo "CI key works, passwordless sudo OK"'
```

### 4.4 Load the secrets into GitHub

```bash
gh secret set CI_SSH_PRIVATE_KEY   --repo Farzy/self-config < ~/.ssh/claw_ci
gh secret set ANSIBLE_VAULT_PASSWORD --repo Farzy/self-config < ~/.ansible-personal-key
```

Reading from a file via `<` keeps the values out of your shell history.

### 4.5 Create the two environments

`claw-check` needs no configuration — GitHub creates it on first use. It exists
so check runs show up in the deployment timeline and so secrets can be scoped
there later.

`claw-production` is the approval gate. Create it under
**Settings → Environments** and configure:

* **Required reviewers**: yourself. This is the second factor between clicking
  "Run workflow" and a live change.
* **Deployment branches**: *Selected branches* → `main`. Without this, a
  dispatch could apply to production from any branch.

### 4.6 Smoke test

> [!NOTE]
> GitHub only offers the *Run workflow* button once the workflow file exists on
> the **default branch**. `🚀 Ansible Deploy` therefore does not appear in the
> Actions UI until the pull request adding it has been merged to `main`.

Actions → **🚀 Ansible Deploy** → *Run workflow*, leaving the defaults
(`openclaw.yml`, `check`, `openclaw`). It should complete without an approval
prompt. Then run the same thing with `mode: apply` and confirm you are asked to
approve.

---

## 5. Day-to-day use

### Dispatch inputs

| Input | Default | Notes |
|---|---|---|
| `playbook` | `openclaw.yml` | `openclaw.yml` or `linux.yml`; adding one is a reviewed change — see §7. |
| `mode` | `check` | `check` adds `--check`; `apply` converges for real and requires approval. |
| `limit` | `openclaw` | Must match the chosen playbook (`openclaw.yml` -> `openclaw`, `linux.yml` -> `linux_servers`) and resolve only to hosts pinned in `known_hosts`. |
| `tags` / `skip_tags` | empty | Passed straight to `--tags` / `--skip-tags`. |
| `diff` | `false` | ⚠️ Enables `--diff`. Logs are public — only enable when you know the diff contains no secrets. |
| `verbosity` | `default` | `-v` … `-vvv`; `default` passes no flag. |

### Drift detection

Both the push-to-`main` trigger and the Monday 06:17 UTC cron run in check mode
against **every** CI-managed group — one matrix job per entry in the `targets`
job, currently `openclaw` and `linux_servers`. A dispatch, by contrast, runs
only the single playbook/limit pair chosen. `fail-fast` is off, so one target
failing still leaves a usable drift signal for the others. A green run with non-zero `changed` counts means the
repository and the server have diverged — check mode reports *pending* changes,
not applied ones.

### A pending apply can be cancelled by a newer run

`check` and `apply` share one concurrency group per *lock*
(`ansible-deploy-<lock>`), so a drift check can never run against a host at the
same time as a converge, while non-overlapping targets still sweep in parallel.

The lock is usually the limit, but not always: targets whose host sets overlap
must share one. `minecraft-01.farzad.tech` belongs to both `linux_servers` (base
OS, via `linux.yml`) and `minecraft` (the game servers), and both playbooks run
apt — keyed on the limit they would have raced for the dpkg lock. Adding a
target that shares hosts with an existing one means giving it the existing
target's `lock`, not a new one. GitHub
keeps at most one *pending* run per group, so an apply left sitting at the
approval prompt can be cancelled when a newer run queues for the same target —
typically a push-to-`main` check run.

This is fail-safe rather than dangerous: the cancelled run had not been
approved, so it never reached the server. Just re-dispatch it. Splitting the
group would remove the annoyance but reintroduce concurrent access to the same
host, which is the worse trade.

> [!WARNING]
> Not every Ansible task is check-mode safe. Tasks using `command`/`shell`
> without `check_mode`, or that depend on a file an earlier task would have
> created, can fail in `--check` even when nothing is wrong. A red check run is
> not automatically real drift. If the scheduled run becomes persistently noisy,
> either add `check_mode: false` to the offending tasks or drop the `schedule:`
> block from the workflow.

---

## 6. Rotation and revocation

**Rotate the CI SSH key** (do this if a runner or the repository is ever
suspect):

1. Generate a new keypair (§4.1).
2. Replace the entry in `master_setup_ci_authorized_keys` and merge.
3. Apply from your laptop with `--tags ci_access`.
4. `gh secret set CI_SSH_PRIVATE_KEY --repo Farzy/self-config < ~/.ssh/claw_ci_new`

Setting `master_setup_ci_authorized_keys_exclusive: true` makes Ansible purge
any key not in the list, which is what actually completes a revocation. It is
`false` by default so that a mistake in the list cannot lock you out; turn it on
once you trust the list.

**Emergency revocation** — remove the key on the box directly, then reconcile
the repository afterwards:

```bash
ssh debian@claw.farzad.tech "sed -i '/github-actions@self-config/d' ~/.ssh/authorized_keys"
```

**Rotate the vault password**: `ansible-vault rekey` every file containing
`!vault` values, then update both `~/.ansible-personal-key` and the
`ANSIBLE_VAULT_PASSWORD` secret.

---

## 7. Adding another server

The pipeline is deliberately hard to widen by accident. Adding a host takes
three reviewed changes:

1. **Pin its host key**, and eyeball the fingerprint against what you see when
   you SSH in manually:

   ```bash
   ssh-keyscan -t ed25519,ecdsa,rsa <hostname> >> ansible/known_hosts
   ```

   `Ansible CI` warns for every host in `$CI_MANAGED_GROUPS` without a pin, so
   step 4 below makes this one announce itself.

2. **Authorise the CI key** by setting `master_setup_ci_authorized_keys` in that
   host's vars file, then bootstrapping it from your laptop as in §4.3.

3. **Add the playbook** to the `playbook` input's `options:` list in
   `ansible-deploy.yml`, and — if the new host should have its own approval gate
   — give it a dedicated environment.

4. **Add its inventory group** to `CI_MANAGED_GROUPS` in `ansible-ci.yml`, which
   is what makes step 1 enforce itself for that host.

5. **Add a `{playbook, limit, lock}` entry to the drift matrix** in the
   `targets` job of `ansible-deploy.yml`. Without this the host is deployable by
   hand but never checked for drift, which is the easiest half of the setup to
   forget. Set `lock` to an existing target's lock if the host sets overlap —
   see §5 — otherwise to the limit.

   `CI_MANAGED_GROUPS` and the drift matrix are currently `openclaw`,
   `linux_servers` and `minecraft`.

Currently CI-managed: `openclaw` (`claw.farzad.tech`) and `linux_servers`
(`quassel.farzy.org`, `minecraft-01.farzad.tech`).

Servers absent from `CI_MANAGED_GROUPS` — currently `farzad-01.farzy.org` and
`k8S.farzad.tech` — are not deployable from CI and are not expected to have
pinned host keys. They are not warned about, so the warning stays worth
reading.

---

## 8. Local development

The linters CI runs are the same ones `pre-commit` runs, so a clean local run
means a green CI run:

```bash
uv sync --group lint
uv run pre-commit run --all-files
```

That equivalence is enforced, not just intended: `yamllint` and `ansible-lint`
are `repo: local` hooks running `uv run --group lint …`, so both sides take
their versions from `uv.lock`. They were previously upstream hooks carrying
their own `rev:` and `additional_dependencies:`, which silently drifted — the
hook pinned `ansible-lint` v26.6.0 and `ansible` 14.2.0 while `uv.lock` resolved
26.8.0 and 13.7.0. Bump them by editing `pyproject.toml` and re-running
`uv lock`; there is no `rev:` to keep in step any more.

`yamllint`'s ruleset lives in [`.github/yamllint.yml`](../.github/yamllint.yml)
rather than at the repository root: `ansible-lint` embeds its own `yamllint` and
auto-discovers a root `.yamllint`, which would make it start failing on
pre-existing long lines in the roles.

Workflow-specific linters, both wired into `pre-commit`:

* **`actionlint`** — shell and expression errors inside workflows.
* **`zizmor`** — security audit (template injection, over-broad permissions,
  unpinned actions). Its suppressions live in
  [`.github/zizmor.yml`](../.github/zizmor.yml), each with a written reason.

---

## 9. Controller-side paths: why the vault password lives at `~/.ansible-personal-key`

CI writes the vault password to `~/.ansible-personal-key` on the runner rather
than to a temporary file, because that exact path is a hard dependency of the
Ansible tree, not just a config default.

`openclaw_setup/templates/secrets.env.j2` reads it directly on the controller:

```jinja
ANSIBLE_VAULT_PASSWORD="{{ lookup('file', '~/.ansible-personal-key') | trim }}"
```

That value is shipped to `/etc/openclaw/secrets.env` so OpenClaw's own agents can
run Ansible on the box (see [openclaw.md](openclaw.md) §"Ansible Vault Password
Injection"). A `lookup()` runs on the controller and reads the literal path
given — it does **not** consult `ANSIBLE_VAULT_PASSWORD_FILE`. The first
check-mode run from CI got 80 tasks in and then failed on *Deploy OpenClaw
secrets environment file* with:

```
The lookup plugin 'file' failed: Unable to access the file
'~/.ansible-personal-key': File not found.
```

Putting the file where the repository already says it lives makes
`ansible.cfg`'s `vault_password_file`, its
`vault_identity_list = personal@~/.ansible-personal-key`, and that lookup all
resolve with no environment overrides at all. It is shredded in the same
`always()` step as the SSH key.

> [!IMPORTANT]
> When adding a role or template that needs something from the controller, a
> `lookup()` on an absolute path is invisible to CI's environment. Either keep
> the path repo-relative, or make CI provide it at the same location a laptop
> would. `grep -rn "lookup('file'" ansible/roles/` finds them; every other one
> in this tree is repo-relative.
