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

- `templates/dotfiles/.zshrc` — `RBENV_ROOT`, and the gcloud SDK path
- `templates/dotfiles/.profile` / `.bash_profile` — same issues, but these were
  **never deployed by `laptop_setup`** (the "Install personal config files"
  loop only covers `.gitconfig*`, `.gitignore_global`, `.tmux.conf`, `.zshrc`)
  and had drifted hard from the live files — so they were **removed** from the
  role rather than fixed
- `templates/dotfiles/.gitconfig` — `git-credential-manager` path turned out to
  be correct (GCM's `.pkg` always lands in `/usr/local`); no change
- `vars/laptop.yml` — the declared formula list (~50) is a subset of what's
  actually installed (~145); the cask list omitted the GUI apps entirely

The `.zshrc` template already prefers `/opt/homebrew` for `brew shellenv`, so
the brew bootstrap itself was never at risk.

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

> **Side note:** shell startup exports a couple of API tokens (Vault-templated,
> not committed). Unrelated to the migration; if you ever rebuild that setup,
> fine-grained tokens or `gh auth` are preferable to classic PATs.

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

## 4. Fix the Ansible role — DONE 2026-09-05

All on branch `feat/arm64-homebrew-migration` (`self-config` uses PRs, never
commits to `main`).

### 4a. `homebrew_prefix` fact — `roles/laptop_setup/tasks/main.yml`

A `stat /opt/homebrew/bin/brew` fact (tags `always`):

```yaml
homebrew_prefix: "{{ '/opt/homebrew' if _brew_arm.stat.exists else '/usr/local' }}"
```

> An earlier attempt used a computed var `'/opt/homebrew' if
> ansible_facts['architecture'] == 'arm64' else '/usr/local'` — **wrong**:
> `ansible_facts['architecture']` reads `x86_64` whenever Ansible's Python runs
> under Rosetta (which it does until phase 9), so it resolved to `/usr/local` on
> this arm machine. The `stat` form is safe here because this playbook only ever
> runs where Homebrew already exists (ansible ← uv ← Homebrew).

### 4b. `templates/dotfiles/.zshrc`

`RBENV_ROOT` → `$HOME/.rbenv`; the gcloud SDK is sourced from
`{{ homebrew_prefix }}/share/google-cloud-sdk` (the `gcloud-cli` cask's layout,
fixed in phase 9); the Go block keeps its `[[ -d "$HOME/go" ]]` guard and lost
only the `g`-version-manager cruft.

### 4c. `templates/dotfiles/.profile` / `.bash_profile` — removed

`laptop_setup` never deployed these (the "Install personal config files" loop
covers `.gitconfig*`, `.gitignore_global`, `.tmux.conf`, `.zshrc` only), and the
live `~/.profile` had drifted far from the template. Rather than reconcile a
dead template, both were deleted from the role. The live `~/.bash_profile` /
`~/.profile` stay as-is, unmanaged; `bash -l` is the only shell affected.

### 4d. `templates/dotfiles/.gitconfig` — NO CHANGE NEEDED

GCM's `.pkg` always installs to `/usr/local/share/gcm-core` + a
`/usr/local/bin/git-credential-manager` symlink **regardless of Homebrew
prefix**, and after the phase-3 cask reinstall that binary is arm64. The
template's existing helper path is correct and survives phase 9.

### 4e. `vars/laptop.yml` + `hosts`

- `laptop_serial_personal` → `GC29C491K2`; `laptop_hostname` personal branch →
  `Serenity`.
- `hosts`: `[laptops]` entry `delerium` → `serenity`; pin
  `ansible_python_interpreter=/opt/homebrew/bin/python3.12` (see phase 8).
- Added to `laptop_setup_homebrew_packages`: `go`, `rbenv`, `ruby-build`.
- Added to `homebrew_cask_packages`: `docker-desktop`, `jetbrains-toolbox`,
  `notion`, `obsidian`, `signal`, `vlc` (unconditional — they also land on the
  professional laptop, which is fine).

Still outstanding, not blocking: the declared formula list is still a subset of
what's installed; `gemini-cli` (deprecated) could move to `cask
"antigravity-cli"`.

### 4f. Dry-run + apply

```bash
cd ~/src/personal/self-config/ansible
ansible-playbook playbooks/laptop.yml --limit serenity --check --diff -t configuration   # review
ansible-playbook playbooks/laptop.yml --limit serenity        --diff -t configuration    # apply
```

`-t configuration` and `-t configuration,hostname` both settle at `changed=0`.
Matching the serial enables `integration_personal_laptop` (personal
`AGENTS.md` / `CLAUDE.md` drift-checks); matching `laptop_hostname` to the
already-set machine name keeps the hostname tasks idempotent.

---

## 5. Rust — DONE 2026-09-05

`~/.cargo/bin/rustup` was itself an x86_64 binary, so `rustup set default-host`
+ `rustup self update` was **not** enough — `rustup toolchain install
stable-aarch64-apple-darwin` refused ("may not be able to run on this system")
because rustup-under-Rosetta still saw an x86 host. The fix was a native
reinstall:

```bash
rustup set default-host aarch64-apple-darwin
rustup toolchain uninstall stable-x86_64-apple-darwin nightly-x86_64-apple-darwin
# native reinstall — re-lays every ~/.cargo/bin proxy as arm64, keeps toolchains
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
  | sh -s -- -y --default-host aarch64-apple-darwin --no-modify-path --profile default
hash -r
rustup toolchain install nightly --no-self-update
rustup component add rust-analyzer rust-src        # clippy + rustfmt come with the default profile
rm -f ~/.cargo/bin/rls ~/.cargo/bin/rust-analyzer  # rls is dead; rust-analyzer is now a rustup component
cargo install --locked cargo-edit cargo-expand drill rustlings
brew uninstall rust                                # Intel formula; also autoremoved llvm@22 (~1.6 GB)
```

**Result:** every `~/.cargo/bin/*` is arm64; `rustc -vV` → `host:
aarch64-apple-darwin` (1.98.1); toolchains `stable-aarch64` + `nightly-aarch64`.
`rustlings` went from a local path install (`~/src/personal/RUST/rustlings`,
v5.6.1) to crates.io v6.5.0. No repo change needed — `vars/laptop.yml` already
lists `rustup`, not `rust`.

---

## 6. Node — DONE 2026-09-05

The blocker: `~/.nvm/nvm.sh` and `~/.nvm/nvm-exec` were **symlinks into
`/usr/local/opt/nvm/libexec/`** (the Intel `nvm` formula, created Jan 2022).
`NVM_DIR=~/.nvm` (data) but the loader was Intel. The oh-my-zsh `nvm` plugin
sources `$NVM_DIR/nvm.sh`, so it kept loading the x86 nvm and x86 nodes.

```bash
command rm -f ~/.nvm/nvm.sh ~/.nvm/nvm-exec        # `rm` is aliased to `rm -i`
ln -s /opt/homebrew/opt/nvm/libexec/nvm.sh   ~/.nvm/nvm.sh
ln -s /opt/homebrew/opt/nvm/libexec/nvm-exec ~/.nvm/nvm-exec

export NVM_DIR="$HOME/.nvm"; source ~/.nvm/nvm.sh
nvm install --lts        # v24.20.0 (krypton), arm64
nvm install node         # v26.8.1 current, arm64
nvm alias default 'lts/*'
nvm use --lts
nvm uninstall v24.14.0   # x86; must switch off it first
nvm uninstall v12.16.3   # x86, EOL 2022

rm -f ~/.nvmrc           # stale: pinned node 16.7 (Aug 2021, EOL, not installed)
```

**Result:** login shell `node` → `v24.20.0` arm64; `~/.nvm/nvm.sh` →
`/opt/homebrew/opt/nvm/libexec/nvm.sh`. `corepack` (0.35.0) is bundled with the
LTS node (Node 24 still ships it; 26 doesn't — use LTS if you need it). Brew
`node` formula stays as the separate "system" node (`v26.7.0`, arm64).

**Repo changes (committed):** `laptop_setup/tasks/main.yml` gains
`Ensure NVM_DIR exists` + `Link ~/.nvm shims to the Homebrew nvm` (so a fresh
machine is set up right), and the `homebrew_prefix` detection was moved from a
`vars/laptop.yml` expression (broken — `ansible_facts['architecture']` reads
`x86_64` under a Rosetta Python) to a `stat /opt/homebrew/bin/brew` fact in
`main.yml`.

---

## 7. Ruby — DONE 2026-09-05

`rbenv` + `ruby-build` were already arm (phase 3 Brewfile); `RBENV_ROOT` was
already moved to `$HOME/.rbenv` (phase 4).

```bash
export RBENV_ROOT="$HOME/.rbenv"
rbenv install 3.4.10          # compiles ~90s; --with-openssl-dir picks up brew openssl@3
rbenv global 3.4.10 && rbenv rehash
gem install bundler --no-document
rm -rf /usr/local/var/rbenv   # old Intel root: 2.1.4 / 2.3.0 / 2.4.1, all EOL, ~1 GB
```

**Result:** login shell `ruby -v` → `3.4.10 … +PRISM [arm64-darwin25]`, bundler
4.0.20. No `rbenv-bundler` (dropped from the Brewfile in phase 3; nothing under
`~/.rbenv/plugins`).

The only `.ruby-version` pins on disk are two dead Kapten elasticsearch roles
pinning `2.3.0` (EOL 2019) — not rebuilt; deal with them only if those projects
ever come back.

**Repo change (committed):** `rbenv` + `ruby-build` added to
`laptop_setup_homebrew_packages` (they were unmanaged before).

---

## 8. Python and virtualenvs — DONE 2026-09-05

brew `python@3.11` / `@3.12` / `@3.14` are arm after phase 3. Two gotchas:

1. **`uv` itself.** The `uv` on the stale PATH was Intel `/usr/local/bin/uv`, so
   the first `uv sync` rebuilt an x86 venv. Use `/opt/homebrew/bin/uv`
   explicitly until phase 9, and purge uv's x86 managed CPythons:

   ```bash
   UV=/opt/homebrew/bin/uv
   $UV python list --only-installed | grep x86_64        # the uv-downloaded ones
   $UV python uninstall cpython-3.12.7-macos-x86_64-none  # ...and the rest
   $UV python install 3.12 3.13 3.14                      # arm managed builds
   ```

2. **Projects pinning Python 3.14** (`ca-organizer`, `farzad-wiki`) resolved
   against Intel `/usr/local/opt/python@3.14` until `uv python install 3.14`
   gave uv an arm 3.14 to prefer.

Then, per project: `rm -rf .venv && uv sync` (or `uv venv && uv pip install -r
requirements.txt`). **14 of 15 venvs under `~/src` are now arm64**;
`~/src/personal/ML/machine-learning-crash-course` fails because its
`pyproject.toml` has `requires-python == "3.12"` (a constraint that matches no
release — needs `~=3.12.0` or `>=3.12,<3.13`).

uv tools reinstalled arm: `uv tool install --reinstall --editable
~/src/personal/books/babelio-automation` (and `ca-organizer`).

pyenv: only `system`, nothing to do. No pipenv/poetry/virtualenvwrapper envs.

**Repo change (committed):** `hosts` pins
`ansible_python_interpreter=/opt/homebrew/bin/python3.12` on `serenity` (Ansible
was auto-discovering the Intel `python@3.14` under Rosetta).

---

## 9. Remove the Intel Homebrew — DONE 2026-09-05

```bash
curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/uninstall.sh -o /tmp/brew-uninstall.sh
chmod +x /tmp/brew-uninstall.sh
/tmp/brew-uninstall.sh --path /usr/local --dry-run   # review
/tmp/brew-uninstall.sh --path /usr/local             # sudo, interactive confirm

# The uninstaller removes Cellar/Homebrew/Caskroom/caches but leaves the
# formula-created symlinks (now broken). Sweep only the broken ones:
sudo find /usr/local/bin /usr/local/sbin /usr/local/lib /usr/local/include \
          /usr/local/share /usr/local/opt /usr/local/etc /usr/local/Frameworks \
     -type l ! -exec test -e {} \; -print -delete
sudo rm -rf /usr/local/share/google-cloud-sdk        # stale old-cask SDK dir
```

**Result:** `/usr/local/{Homebrew,Cellar,Caskroom,var/homebrew}` gone;
`brew --prefix` → `/opt/homebrew` only. `/usr/local/bin` down to 108 entries —
all non-Homebrew (Docker.app symlinks, MacGPG2, Wireshark, Vagrant, VirtualBox,
`git-credential-manager`, and years of loose pip/gem scripts); prune those
separately.

Fresh login shell now resolves `node`/`npm`/`ruby`/`rustc`/`go`/`python3`/
`gcloud`/`kubectl`/`helm`/`terraform` to arm64 (nvm / rbenv / cargo / brew).
`docker` and `gpg` still point into `/usr/local` — that's Docker Desktop
(phase 10) and MacGPG2 (independent), both fine.

### Caught during phase 9

- **`~/.go` (487 MB, x86 Go 1.22.1) via the `g` version manager** was shadowing
  brew's arm `go` 1.27.1 through `$GOPATH/bin`. Removed `~/.go` + `~/go/bin/{g,
  go,gofmt}`; brew `go` takes over. `.zshrc` Go block simplified (dropped the
  `g` cruft); `go` added to `laptop_setup_homebrew_packages`.
- **`gcloud-cli` cask SDK path** — fixed in the previous commit (share/ not
  Caskroom/).
- **Ansible `command`/`shell` tasks couldn't find `brew`/`helm`** once the Intel
  copies were gone — Ansible's minimal PATH has neither prefix. Added
  `environment: PATH: "/opt/homebrew/bin:/usr/local/bin:{{ ansible_env.PATH }}"`
  to `playbooks/laptop.yml`.

---

## 10. GUI apps — DONE 2026-09-05

Casks added to `homebrew_cask_packages` (committed): `docker-desktop`,
`jetbrains-toolbox`, `notion`, `obsidian`, `signal`, `vlc`.

- `vlc`, `notion` reinstalled arm64 via `brew install --cask --force`.
- `signal`, `docker-desktop`, `jetbrains-toolbox` — quit first, then
  `brew install --cask --force …` (the `community.general.homebrew` cask module
  has no `--force`, so it errors on a pre-existing non-brew `.app`; this is a
  one-time migration condition, `-t packages` is green afterward). All arm64.
- **IntelliJ IDEA** + **RustRover** reinstalled as Apple Silicon via the (now
  arm) JetBrains Toolbox. Config in `~/Library/Application Support/JetBrains`
  survived. In RustRover, confirm Settings → Rust points at `~/.rustup`.
- Docker Desktop: `~/Library/Containers/com.docker.docker` and the
  `desktop-linux` context persisted; images intact.
- `~/Applications/Air.app` was removed (its stale `/usr/local/bin/air` link was
  swept in phase 11).

**Universal apps** (iTerm2, Chrome, VS Code, Telegram, WhatsApp, Ghostty,
Obsidian) carry an arm64 slice — quit fully (⌘Q; Chrome also needs its helpers
killed) and relaunch. On Apple Silicon they run arm64 unless "Open using
Rosetta" is ticked in Get Info. Confirm in **Activity Monitor → Kind** =
"Apple".

---

## 11. Final verification — DONE 2026-09-05

| Runtime | Result |
|---|---|
| node | `v24.20.0` arm64 (nvm) |
| ruby | `3.4.10` `arm64-darwin25` (rbenv, `~/.rbenv`) |
| rustc / cargo | `1.98.1` host `aarch64-apple-darwin` (rustup) |
| go | `go1.27.1` `arm64` (Homebrew) |
| python3 | `3.14.7` arm64 (Homebrew); 14 project venvs arm64 |
| terraform | `1.14.8` `darwin_arm64` (tfenv) |
| Homebrew | `/opt/homebrew` only; `/usr/local/{Homebrew,Cellar,Caskroom}` gone |
| broken `/usr/local` symlinks | 0 (removed `hyperkit`, `air`) |
| uv x86 managed CPythons | 0 |
| Rosetta | kept (fallback for occasional x86) |

**Apps** — single-arch **arm64**: Signal, Docker, VLC, Notion, JetBrains
Toolbox, IntelliJ IDEA, RustRover. **Universal** (run arm64 after a native
relaunch): iTerm2, Chrome, VS Code, Telegram, WhatsApp, Ghostty, Obsidian.
Confirm running arch in **Activity Monitor → Kind** = "Apple".

### Caught during phase 11

- **tfenv terraform was x86_64.** The Homebrew `tfenv` shim uses
  `TFENV_CONFIG_DIR=${XDG_CONFIG_HOME:-~/.config}/tfenv`, so versions live under
  `~/.config/tfenv/versions/` (not `~/.tfenv/`). Fixed:
  `rm -rf ~/.config/tfenv/versions/1.14.8 && tfenv install 1.14.8` → arm64.
- `~/Applications/Air.app` was removed; its `/usr/local/bin/air` symlink and a
  dead 2019 `hyperkit` link were swept.

---

## Rollback notes

- The Intel Homebrew is untouched until phase 9. If phase 3 goes wrong, delete
  `/opt/homebrew`, open a shell (falls back to `/usr/local`), and retry.
- rustup: `rustup set default-host x86_64-apple-darwin` + reinstall the x86
  toolchains restores the old state.
- nvm: `nvm install 24.14.0` rebuilds; nothing destructive about the reinstall.
- Ansible edits live on a branch — revert the branch, `-t configuration`
  re-renders the old dotfiles.

---

## Appendix: GUI apps still on Rosetta — audit 2026-09-06

A full-disk `lipo -archs` sweep of every `.app` in `/Applications`,
`/Applications/Utilities`, and `~/Applications` a day after the merge. 25
x86_64-only bundles were found; **none were Apple/system apps** — all
third-party. Triaged as follows.

### Reinstalled native arm64 (Homebrew casks)

`antigravity` 2.12, `zoom` 7.1, `postman` 12.26, `wireshark-app` 4.6
(universal), `gimp` 3.2 (new `GIMP.app`), `lens` 2026.9, `strawberry`
(universal), `r` (`r-app`) 4.6. All now cask-managed and self-updating. The
old `GIMP-2.10.app` was left behind by the `gimp` cask and is swept by the
cleanup script.

### Deleted (dead / unmovable)

| App | Reason |
|---|---|
| Carbon Copy Cloner 3.5.2 | 2013 build; cask download 403s on Bombich's CDN; not worth keeping a 13-year-old backup tool |
| Kindle | Amazon dropped the Homebrew cask; MAS build is universal if ever needed again |
| Antigravity IDE 2.1.1 | stale preview bundle, superseded by the `antigravity` cask |
| FinanceQuote Update (2009, `ppc7400`), PDF Toolkit (2013), Application Loader (2014), Android File Transfer (2018), Save to Pocket (2019, Pocket EOL), OpenEmu 2.2, Google Earth Pro | abandonware / discontinued; removed via `intel-app-cleanup.sh` |
| `~/Applications/Windows 10 Applications.app` | orphaned VM stub — no Parallels/VMware installed |

### Kept on Rosetta — vendor ships no arm64 build

| App | Note |
|---|---|
| Steam | Valve has no native Apple Silicon client |
| Brother `ControlCenter.app`, `Brother iPrint&Scan.app` | no arm64 build — same reason Rosetta stays for the printer (phase 9) |
| Logi Bolt, Logi Bolt Uninstaller, `FirmwareUpdateTool.app` | Logitech receiver / firmware utilities, infrequent use |
| Adobe Genuine Service (`AdobeGCClient`, `AdobeCleanUpUtility`) | background daemon bundled with the installed Adobe apps (Creative Cloud, Lightroom CC, Photoshop Elements 10) |

Chrome PWA shims under `~/Applications/Chrome Apps.localized/` are x86 but
regenerated by Chrome — ignored.

> Cleanup performed by `intel-app-cleanup.sh` (not committed — one-off, kept
> with the migration scratch). Trashes via Finder (restorable), dry-run by
> default, `--apply` to execute.
