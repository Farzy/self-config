# User Profile & Directives: Farzad Farid

## 1. Persona & Context
**Role**: Technical Manager / Head of SRE / Head of DevOps @ Market Pay  
**Experience**: 30+ years (Started 1995). Dual Ladder profile (Manager + Technical Expert).  
**Personality**: Analytical, Pragmatic, Introverted but experienced in Public Speaking.

**Perspective**:
I am a Senior Technical Manager who still codes (with basic level) and designs & creates IT infrastructure (seasoned).
- **Tone**: Professional, Direct, Technical.
- **Goal**: Solutions should be high-level yet detailed, respecting the "Senior" level of expertise.

## 2. Interaction Guidelines
### Language
- **English Query**: Answer in **English**.
- **French Query**: Answer in **French**.
  - *Exception*: If the output involves code or documentation meant to be shared, ask if I want the final artifact translated to English.

### Style
- **No Fluff**: Go straight to the point.
- **Contextual**: Take into account my expertise (Manager/SRE Leader).

## 3. Management & Collaboration Style
**Core Philosophy**: Collaborative. Anti-Micromanagement.

- **Discovery Phase** (New team/mission): Explicit control allowed to learn context.
- **Cruising Phase** (Established trust): Delegation and autonomy.
- **Anti-Pattern**: Micro-management is strictly prohibited once trust is established.

## 4. Technical Stack & Preferences
### Active Stack
- **Languages**: Python 3, Bash, Go, Rust.
- **IaC/Ops**: Terraform / Terragrunt, Ansible.
- **Systems**: Linux (Servers), macOS (Workstation).
- **Tools**: JetBrains IntelliJ, Google Antigravity.

### Deprecated / Avoid
- **Languages**: Ruby / Rails.
- **Tools**: Zabbix, Hugo.

### Programming Language Usage Rules
1.  **Bash**:
    - Use for simple one-liners or non-reusable commands.
2.  **Python 3**:
    - Use for complex scripts where Bash is too ambiguous or unsafe.
3.  **Go / Rust**:
    - Use only for complex performance-critical tasks or when **explicitly requested**.

## 5. Development Standards

### Documentation

- Always update documentation when making major changes or adding features.

### Python Development
- **Package Manager**: Always use **UV** (https://docs.astral.sh/uv/).
- **Configuration**: `pyproject.toml`.
- **Lockfile**: `uv.lock`.
- **Checking**: Always create a `pre-commit` configuration with relevant plugins for Python (like Ruff), but also for linting JSON, YAML, etc.

### Git Workflow
- **Branching**: Never commit fixes or new developments on the main branch (whether it's name is `main` or `master`). If you already are on a feature branch, and the existing changes in this branch are compatible with the new changes you want to commit, use this branch. Otherwise, ask me if you should create a new branch.
- **Commits**: Must follow **Conventional Commits** (e.g., `feat:`, `fix:`, `chore:`).
- **GitHub**: If using GitHub for the current project, use the GitHub MCP or the `gh` tool to interact with GitHub.
- **Pull Requests**: 
  - if the current project is hosted on GitHub, try to check is there already is an open pull request for the current branch, otherwise create a new PR using the GitHub MCP or the `gh` tool. The PR description must be very detailled and ready to use as a final commit message.
  - When pushing major changes to the branch / PR, update the PR description.

### Git Pager Configuration

The user's environment has `core.pager` configured as `less -FRX`.
Because the agent runs in a non-interactive shell without TTY capabilities, git commands that produce long output (e.g., `git status`, `git diff`, `git log`) will invoke `less` and prompt:

> WARNING: terminal is not fully functional

To prevent the agent's workflow from stalling and requiring a manual `RETURN` input, the agent **MUST** explicitly bypass the pager whenever running Git commands in this workspace.

#### Solution
Always suffix `git` with `--no-pager`, for example:
- `git --no-pager diff`
- `git --no-pager log`
- `git --no-pager status`

Alternatively, prepend `GIT_PAGER=cat` when running git commands.

### Source code management
- Never delete existing comments, unless they are deprecated.
- Document all classes, methods, functions, constants, global variables, and complex structures.
- Use docstrings in the case of Python code
- For Go and Rust, use a comment format that can be turned into and online, interactive, documentation, following the language's standards.
