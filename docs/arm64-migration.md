# Apple Silicon (arm64) migration runbook

Migrating the workstation toolchain from Intel/Rosetta to native `arm64` on the
M5 Pro. The machine was carried over from an Intel Mac (Migration Assistant), so
Homebrew, the language runtimes and several apps are still `x86_64` and run under
Rosetta.

**Scope:** Homebrew, Rust, Node, Ruby, Python, and the GUI apps in the list
below. Everything is driven from this repo where it can be, because
`ansible/roles/laptop_setup` templates the dotfiles and the Homebrew package
list.

---

## 0. State at start of migration (2026-09-05)

| Component | Current | Target |
|---|---|---|
| Homebrew | `x86_64` @ `/usr/local` (Homebrew 6.0.22), ~140 formulae, 8 casks, 7 taps | `arm64` @ `/opt/homebrew` |
| Rust | brew `rust` + brew `rustup` **and** `~/.rustup` (default-host `x86_64`, `stable`+`nightly` both x86) + ~20 `~/.cargo/bin` tools | single rustup, host `aarch64-apple-darwin` |
| Node | nvm `v24.14.0` + `v12.16.3` (both x86); brew `node` + brew `nvm`; global npm = `corepack`, `npm` only | nvm arm64 builds; drop 12.x |
| Ruby | rbenv `2.1.4` / `2.3.0` / `2.4.1` (2.4.1 = EOL 2020), x86; `RBENV_ROOT=/usr/local/var/rbenv`; `rbenv-bundler` plugin | rbenv arm64, Ruby latest 3.x, `RBENV_ROOT=$HOME/.rbenv` |
| Python | brew `python@3.11` + `@3.12` (x86); `pyenv` installed but only `system`; project `.venv` dirs are x86 | arm64 after brew; recreate venvs with `uv` |
| Terminal / shell | iTerm2 universal, running native `arm64`; login zsh native | unchanged |

### Apps

| Verdict | Apps |
|---|---|
| **Universal already** — just quit + relaunch native, confirm "Open using Rosetta" is unchecked | iTerm2, Google Chrome, Telegram, WhatsApp, VS Code, Ghostty, Obsidian, GZDoom |
| **Intel-only — reinstall arm build** (cask available: `signal`, `vlc`, `notion`, `docker-desktop`, `jetbrains-toolbox`) | Signal, VLC, Notion, Docker Desktop, JetBrains Toolbox → IntelliJ IDEA → RustRover, `~/Applications/Air.app` |

No app is force-pinned to Rosetta in LaunchServices — good.

### Ansible-managed paths that still hardcode `/usr/local`

- `templates/dotfiles/.profile` — L65 (`PATH` prepend), L68 (`go/libexec/bin`), L71 (`RBENV_ROOT`), L105 (`virtualenvwrapper.sh`)
- `templates/dotfiles/.zshrc` — L61 (`RBENV_ROOT`)
- `templates/dotfiles/.gitconfig` — L68 (`git-credential-manager`)
- `vars/laptop.yml` — the declared formula list (~50) is a subset of what's actually installed (~140); casks list omits `obsidian`, `hashicorp-vagrant`, `go-task`

The dotfile templates already prefer `/opt/homebrew` for `brew shellenv`, so the
main risk is the four hardcoded paths above, not the brew bootstrap.

---

## 1. Prep and safety (no changes yet)

```bash
mkdir -p ~/arm64-migration && cd ~/arm64-migration

# Full Intel Homebrew manifest — this is the source of truth for phase 3,
# NOT the Ansible list (which is incomplete).
/usr/local/bin/brew bundle dump --file=Brewfile.intel --force --describe
/usr/local/bin/brew list --formula --versions > formulae.intel.txt
/usr/local/bin/brew list --cask --versions    > casks.intel.txt
/usr/local/bin/brew leaves --installed-on-request > leaves.intel.txt
/usr/local/bin/brew tap                        > taps.intel.txt

# Runtime manifests
ls ~/.nvm/versions/node                              > nvm-versions.txt
ls /usr/local/var/rbenv/versions ~/.rbenv/versions 2>/dev/null > rbenv-versions.txt
~/.cargo/bin/rustup toolchain list                  > rustup-toolchains.txt
ls ~/.cargo/bin                                      > cargo-bins.txt
comm -23 <(ls ~/.cargo/bin | sort) \
         <(rustup component list --installed 2>/dev/null | sed 's/-.*//' | sort) \
  > cargo-bins-standalone.txt   # roughly: tools you cargo-installed yourself

# Docker: note images/volumes in case the VM is rebuilt
docker image ls > docker-images.txt 2>/dev/null || true
docker volume ls > docker-volumes.txt 2>/dev/null || true

# VS Code extensions (if `code` on PATH)
code --list-extensions > vscode-extensions.txt 2>/dev/null || true
```

**Rosetta stays installed.** Do not remove it — `gdb`, the occasional x86-only
cask, and old binaries still need it. Confirm it is present:

```bash
/usr/bin/pgrep -q oahd && echo "Rosetta OK" || softwareupdate --install-rosetta --agree-to-license
```

**Xcode Command Line Tools** — universal, keep. Update if stale:
`softwareupdate -l` then install any "Command Line Tools" item.

> **Side note (security):** `~/.zshrc` exports two classic GitHub PATs
> (`GITHUB_TOKEN`, `HOMEBREW_GITHUB_API_TOKEN`), templated from Ansible Vault
> (`github_token`, `github_homebrew_token`). They render into the plaintext
> dotfile and were visible in this session. Rotate both at some point and
> consider fine-grained tokens or `gh auth` for the API one. Not part of this
> migration.

---

## 2. Bootstrap arm64 Homebrew

The official installer always targets `/opt/homebrew` on Apple Silicon, so it
installs alongside the Intel one without touching it.

```bash
NONINTERACTIVE=1 /bin/bash -c \
  "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

eval "$(/opt/homebrew/bin/brew shellenv)"
```

**Checkpoint:**

```bash
which brew            # /opt/homebrew/bin/brew
brew --prefix         # /opt/homebrew
file "$(brew --repository)/bin/brew" ; brew config | grep -E 'HOMEBREW_PREFIX|Rosetta|CPU'
```

Open a **new** shell tab — `.zshrc` L37-40 auto-selects `/opt/homebrew` now that
it exists. Confirm `echo $HOMEBREW_PREFIX` is `/opt/homebrew`.

---

## 3. Restore packages into arm64 Homebrew — DONE 2026-09-05

Worked from `~/arm64-migration/Brewfile` (a trimmed copy of `Brewfile.intel`),
`brew bundle install`. **145 packages** on arm64, `brew bundle check` green.

Five edits were needed before it went clean:

| Issue | Fix in the working `Brewfile` |
|---|---|
| `brew bundle dump` silently dropped `go`, `make`, `ninja`, `llvm`, `maturin` (demoted to "installed as dependency" during the Intel years) | re-added by name; `rust` deliberately left out (→ phase 5), `usage` returns with `mise` |
| `tap "homebrew/core"` / `tap "homebrew/cask"` — no longer tappable | removed (built-in) |
| `brew "gdb"` — no arm64 support on macOS | removed; use `lldb` |
| `brew "rbenv-bundler"` — unmaintained | removed (→ phase 7) |
| `brew "tflint"` — deleted from homebrew-core | now `tap "terraform-linters/tap", trusted: true` + `cask "terraform-linters/tap/tflint"` |
| `npm "corepack"` — collides with `brew "yarn"` on `/opt/homebrew/bin/yarn` | dropped; `npm i -g corepack --force` if a project ever needs it |
| `brew "go-task"` **and** `cask "go-task/tap/go-task"` both present | dropped the formula line; the cask provides `task` |

VS Code extensions (54) split out to `Brewfile.vscode` (already installed,
Settings Sync covers them); the 4 `cargo "…"` lines deferred to phase 5 (need the
arm toolchain first).

Deprecation seen in passing: `gemini-cli` disables 2026-12-18, replacement
`cask "antigravity-cli"` — fold into phase 4e.

**Checkpoint (clean login shell):** `brew`, `git`, `helm`, `jq`, `kubectl`,
`go`, `fd`, `rg`, `bat` → all arm64 from `/opt/homebrew`. Still Intel by design:
`node` (nvm, phase 6), `ruby` (rbenv, phase 7), `rustc` (`~/.cargo`, phase 5),
project `.venv` pythons (phase 8).

---

## 4. Fix the Ansible role (so the next converge doesn't re-pin Intel paths)

Branch first (`self-config` uses PRs, never commits to `main`):

```bash
cd ~/src/personal/self-config
git switch -c feat/arm64-homebrew-migration
```

### 4a. Prefix var — `ansible/vars/laptop.yml` — DONE

Added next to `is_macos` (a computed var, not a task — `ansible_facts` is already
templated lazily there):

```yaml
homebrew_prefix: "{{ '/opt/homebrew' if ansible_facts['architecture'] == 'arm64' else '/usr/local' }}"
```

### 4b. `templates/dotfiles/.zshrc` — DONE, applied

`export RBENV_ROOT=/usr/local/var/rbenv` → `export RBENV_ROOT=$HOME/.rbenv`

### 4c. `templates/dotfiles/.profile` — edited, NOT deployed

Same `RBENV_ROOT` fix plus `{{ homebrew_prefix }}` for the `PATH` prepend, the
`go/libexec/bin` path, and a `[ -f … ]` guard on the legacy
`virtualenvwrapper.sh` source. **But `laptop_setup` does not deploy `.profile`
or `.bash_profile`** — the "Install personal config files" loop only covers
`.gitconfig*`, `.gitignore_global`, `.tmux.conf`, `.zshrc`. The live `~/.profile`
(148 lines) has diverged hard from the template (184) — effectively unmanaged.
Only `bash -l` is affected. Separate cleanup: either re-add `.profile` +
`.bash_profile` to the loop (after reconciling the live file) or hand-patch the
three Intel paths in `~/.profile`.

### 4d. `templates/dotfiles/.gitconfig` — NO CHANGE NEEDED

GCM's `.pkg` always installs to `/usr/local/share/gcm-core` + a
`/usr/local/bin/git-credential-manager` symlink **regardless of Homebrew
prefix**, and after the phase-3 cask reinstall that binary is arm64. The
template's existing `helper = /usr/local/bin/git-credential-manager` is correct
and survives phase 9 (GCM is not Homebrew-owned). Applying the template does
drop two duplicate `helper =` lines the GCM pkg-postinstall appended — harmless.

### 4e. `vars/laptop.yml` reconciliation (optional — kill the drift)

The declared `laptop_setup_homebrew_packages` (~50) is a subset of what's
installed (~145). A `-t packages` converge is currently a **no-op** (check-mode
confirmed: `changed_pkgs: []`), so this is housekeeping, not blocking:

- Add relied-on formulae missing from the list: `go`, `tmux`, `tree`, `cmake`,
  `gh`, `git`, `graphviz`, `kubeseal`, `syft`, `grype`, `trivy`, `make`,
  `ninja`, `llvm`, `maturin`, `rbenv`, `ruby-build`.
- Swap `gemini-cli` (deprecated) → `cask "antigravity-cli"`.
- `homebrew_cask_packages`: add `obsidian`, `terraform-linters/tap/tflint`, and
  the phase-10 apps (`signal`, `vlc`, `notion`, `docker-desktop`,
  `jetbrains-toolbox`).
- Also add `tap "terraform-linters/tap"` to the tap list.

### 4f. Dry-run + apply — DONE for `-t configuration`

This machine (`Serenity`, serial `GC29C491K2`) is not in inventory; the
`[laptops]` entry `delerium` is `ansible_connection=local`, so:

```bash
cd ~/src/personal/self-config/ansible
ansible-playbook playbooks/laptop.yml --limit delerium --check --diff -t configuration   # review
ansible-playbook playbooks/laptop.yml --limit delerium        --diff -t configuration   # apply
```

Applied: `~/.zshrc` (`RBENV_ROOT`), `~/.gitconfig` (dupe helpers removed).
Personal integrations (`integration_personal_laptop`) stay **off** because
`laptop_serial_personal` in `vars/laptop.yml` is still the old Delerium serial
`C02YG6X6JG5J` — see "Inventory / serial drift" below.

---

## Inventory / serial drift (decide separately)

This M5 Pro is a **new machine**, not the Intel "Delerium":

- serial `GC29C491K2` ≠ `laptop_serial_personal: "C02YG6X6JG5J"` in `vars/laptop.yml`
- `LocalHostName`/`ComputerName` = `Serenity`; not in `ansible/hosts` `[laptops]`
- so `integration_personal_laptop` is false → personal `AGENTS.md` / `CLAUDE.md`
  drift-checks skip, `laptop_hostname` falls back to the OS hostname

To adopt this machine properly: update `laptop_serial_personal` to `GC29C491K2`,
add `serenity ansible_connection=local ansible_become=false` to `[laptops]` (and
retire/keep `delerium`), and decide the `laptop_hostname` personal branch
(`Delerium` → `Serenity`). Flipping the serial also enables the personal
`AGENTS.md`/`CLAUDE.md` tasks — intended, but a behaviour change.

---

## 5. Rust

Keep the official rustup toolchain manager; drop the redundant brew `rust`
compiler.

```bash
brew uninstall rust 2>/dev/null || true    # keep brew "rustup" (arm now) OR use curl installer

rustup set default-host aarch64-apple-darwin
rustup toolchain install stable aarch64-apple-darwin
rustup toolchain install nightly            # only if you use it
rustup toolchain uninstall stable-x86_64-apple-darwin nightly-x86_64-apple-darwin
rustup default stable
rustup component add rust-analyzer clippy rustfmt rust-src

# Rebuild the tools you cargo-installed yourself (see cargo-bins-standalone.txt).
# Typical set from the audit:
cargo install --locked cargo-expand cargo-edit drill
# rustlings: reinstall from its installer if you still use it
# rls: dead, drop it
```

**Checkpoint:**

```bash
rustc -vV | grep host        # host: aarch64-apple-darwin
file ~/.cargo/bin/cargo ~/.rustup/toolchains/stable-aarch64-apple-darwin/bin/rustc
cargo install --list
```

---

## 6. Node

```bash
nvm deactivate
nvm uninstall 12.16.3        # EOL 2022 — drop unless a project pins it
nvm uninstall 24.14.0
nvm install --lts            # default alias is lts/*
nvm install 24               # current, if you want it
nvm alias default 'lts/*'
corepack enable
```

**Checkpoint:**

```bash
node -p "process.arch"       # arm64
file "$(nvm which current)"
```

The brew `node` formula (arm after phase 3) is the separate "system" node —
leave it.

---

## 7. Ruby

```bash
brew install rbenv ruby-build          # arm; add to vars/laptop.yml (phase 4e)
mkdir -p ~/.rbenv
export RBENV_ROOT=$HOME/.rbenv          # matches the fixed dotfiles
eval "$(rbenv init - zsh)"

rbenv install -l | grep -E '^\s*3\.[0-9]+\.[0-9]+$' | tail -1   # pick latest 3.x
rbenv install 3.4.5                     # <-- use the version from the line above
rbenv global 3.4.5
gem install bundler
```

Retire the old tree once the new one works:

```bash
rbenv versions
rbenv uninstall -f 2.1.4 2.3.0 2.4.1
rm -rf /usr/local/var/rbenv             # old RBENV_ROOT
brew uninstall rbenv-bundler 2>/dev/null || true   # unmaintained plugin
```

**Checkpoint:** `ruby -v` → `... [arm64-darwin25]` (or newer).

---

## 8. Python and virtualenvs

brew `python@3.11` / `@3.12` are arm after phase 3. Every existing venv still
has x86 symlinks — recreate:

```bash
# self-config repo itself
cd ~/src/personal/self-config
rm -rf .venv && uv sync
file .venv/bin/python3          # arm64

# pyenv: only "system" is installed, so nothing to rebuild unless you add versions
# uv will auto-download an arm64 CPython for .python-version (3.12.7) if needed

# Other projects — find and recreate:
fd -HI -t d -g '.venv' ~/src   # then `uv sync` / `python -m venv` per project
# pipenv:  pipenv --rm && pipenv install
# poetry:  poetry env remove --all && poetry install
# virtualenvwrapper (~/.virtualenvs/*): recreate with `mkvirtualenv`
```

---

## 9. Remove the Intel Homebrew

Only after phases 3–8 verify green.

```bash
cd ~/arm64-migration
NONINTERACTIVE=1 /bin/bash -c \
  "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/uninstall.sh)" \
  -- --path /usr/local

# The script lists what it could not delete. Review, then clean the brew-owned
# leftovers (do NOT blind `rm -rf /usr/local` — check each first):
ls /usr/local/{Homebrew,Caskroom,Cellar,Frameworks,var,opt} 2>/dev/null
sudo rm -rf /usr/local/{Homebrew,Caskroom,Cellar} /usr/local/var/homebrew
```

Then clean the last Intel references in the templated `.profile` (the stale
`python@3.8` PATH line, `/usr/local/opt/go`) if the phase 4 edits missed any,
and re-run the role `-t configuration`.

---

## 10. GUI apps

### Cask-managed (done in phase 3 if added to the Brewfile)

```bash
for c in signal vlc notion docker-desktop jetbrains-toolbox; do
  brew install --cask "$c"
done
```

- **Docker Desktop:** quit fully first. Data in
  `~/Library/Containers/com.docker.docker` and the `desktop-linux` context
  persist; re-pull images only if the Linux VM resets.
- **JetBrains Toolbox:** must be arm **before** you touch the IDEs. Then in
  Toolbox: uninstall IntelliJ IDEA and RustRover, reinstall — Toolbox now
  offers the "Apple Silicon" build automatically. Settings/projects in
  `~/Library/Application Support/JetBrains` survive. In RustRover, re-point the
  toolchain to `~/.rustup` (Settings → Rust) — it should auto-detect the arm
  `stable`.
- **`~/Applications/Air.app`:** x86-only, not in Homebrew. Check the vendor for
  an Apple Silicon build; low priority.

### Universal — quit and relaunch native

iTerm2, Chrome, Telegram, WhatsApp, VS Code, Ghostty, Obsidian, GZDoom.

For each: **Finder → app → Get Info → "Open using Rosetta" unchecked**, then
fully quit (⌘Q, not just close window) and reopen. Chrome in particular is
sticky — quit every `Google Chrome Helper` too.

---

## 11. Final verification

```bash
#!/usr/bin/env bash
# ~/arm64-migration/verify.sh — re-audit
set -u
echo "== toolchain =="
printf 'brew prefix : %s\n' "$(brew --prefix)"
for x in "$(brew --prefix)/bin/bat" "$(nvm which current)" ~/.cargo/bin/cargo \
         "$(rbenv which ruby)" "$(brew --prefix)/bin/python3.12" ~/.local/bin/uv; do
  printf '%-46s %s\n' "$x" "$(file -b "$x" 2>/dev/null | grep -o 'arm64\|x86_64' || echo missing)"
done
rustc -vV | grep host
node -p '"node " + process.arch'

echo "== no Intel Homebrew =="
[ -d /usr/local/Homebrew ] && echo "STILL PRESENT: /usr/local/Homebrew" || echo "clean"

echo "== apps (static archs) =="
for a in iTerm "Google Chrome" Signal Telegram WhatsApp "Visual Studio Code" \
         Ghostty Obsidian VLC Notion "Docker Desktop" "JetBrains Toolbox"; do
  p="/Applications/$a.app/Contents/MacOS"
  exe="$p/$(defaults read "/Applications/$a.app/Contents/Info" CFBundleExecutable 2>/dev/null)"
  printf '%-22s %s\n' "$a" "$(lipo -archs "$exe" 2>/dev/null || echo 'n/a')"
done

echo "== still running translated? (want: only Rosetta helper, no app) =="
pgrep -x oahd >/dev/null && echo "oahd present (fine if no x86 app is running)"
```

For **running** GUI apps, the reliable human check is **Activity Monitor → View
→ Columns → Kind** ("Apple" vs "Intel" vs "Universal"). Anything still "Intel"
after a relaunch needs the "Open using Rosetta" box cleared.

---

## Rollback notes

- The Intel Homebrew is untouched until phase 9. If phase 3 goes wrong, delete
  `/opt/homebrew`, open a shell (falls back to `/usr/local`), and retry.
- rustup: `rustup set default-host x86_64-apple-darwin` + reinstall the x86
  toolchains restores the old state.
- nvm: `nvm install 24.14.0` rebuilds; nothing destructive about the reinstall.
- Ansible edits live on a branch — revert the branch, `-t configuration`
  re-renders the old dotfiles.
