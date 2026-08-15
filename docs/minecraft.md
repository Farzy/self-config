# Minecraft servers on `minecraft-01.farzad.tech`

Two independent Minecraft servers run on one Scaleway host, in Docker
containers, reachable on different ports behind SRV records so players can use
a hostname without a port.

This deployment was built by hand and adopted into IaC afterwards. That history
matters when reading the role: it *describes* what was already running rather
than defining it from scratch, and it deliberately leaves the game worlds alone.

---

## 1. What runs where

| | `mc01` | `mc02` |
|---|---|---|
| Purpose | Farzad's world | Faustine's world |
| MOTD | `Serveur Minecraft de Farzad` | `Faustine's own Minecraft world` |
| Port | 25565 | 25566 |
| Players connect to | `minecraft-01.farzad.tech` | `minecraft-02.farzad.tech` |
| Data | `/srv/minecraft/mc01` | `/srv/minecraft/mc02` |
| Container | `minecraft-mc01-1` | `minecraft-mc02-1` |

Both use the [`itzg/minecraft-server`](https://github.com/itzg/docker-minecraft-server)
image, tag `java25` — that pins the *Java runtime*, not the game. The game
version comes from `VERSION`, currently `LATEST`.

Host resources are the real constraint: **3 vCPU and 3.8 GB RAM** for two JVMs
plus the OS. Each server gets `MEMORY: 1G`. Adding a third instance means
revisiting that, not just adding a list entry.

### There is no `minecraft` systemd unit

The servers are *not* started by a unit of their own. What survives a reboot is:

* `docker.service` is enabled, and
* both containers carry `restart: always`.

Docker brings them back. Looking for a `minecraft.service` will find nothing —
that is by design, not a missing piece.

---

## 2. How players reach two servers on one host

Minecraft clients look up a `SRV` record before falling back to a plain `A`
lookup, so a second server on a non-default port can still be joined by
hostname alone. Both records live in
[`terraform/dns-farzad.tech.tf`](../terraform/dns-farzad.tech.tf):

```
_minecraft._tcp.minecraft-01.farzad.tech  SRV  0 5 25565  minecraft-01.farzad.tech.
_minecraft._tcp.minecraft-02.farzad.tech  SRV  0 5 25566  minecraft-01.farzad.tech.
```

Note that **`minecraft-02` is not a host**. It exists only as an SRV name that
points back at the single `minecraft-01` A record on port 25566. There is one
server, one IP, two ports.

Consequence: changing an instance's port means changing DNS as well as Ansible.
The port lives in `minecraft_server_instances` (Ansible) and in the SRV rrdata
(Terraform), and nothing enforces that they agree.

---

## 3. What is and is not under IaC

Docker itself is managed by [`roles/docker`](../ansible/roles/docker), which
`playbooks/minecraft.yml` runs first: the Docker CE repository, the daemon and
its packages — including `docker-compose-plugin`, which is not a dependency of
`docker-ce` and which this whole deployment depends on. The kernel tuning that
role applies by default is for `kind`/`microk8s` and is switched off here.

Managed by [`roles/minecraft_server`](../ansible/roles/minecraft_server):

* `/srv/minecraft/docker-compose.yml` — rendered from the role's template.
* The data directory for each instance — its existence and ownership only.
* `whitelist.json` and `ops.json` for each instance.
* Server settings, applied as `itzg` environment variables in the compose file.

Explicitly **not** managed:

* **World data** (`world/`, `logs/`, `libraries/`, `versions/`, `.cache/`).
  Hundreds of megabytes of live game state; Ansible never walks it.
* **`server.properties`**. The image writes it on every start from the
  environment variables above. Editing it by hand works until the next restart.
  Change settings in the role, not in the file.

### Settings live in environment variables, not `server.properties`

The `itzg` image maps environment variables onto `server.properties` at
startup. The names are not guessable and are taken from the image's own
`/image/property-definitions.json`:

| `server.properties` | Environment variable |
|---|---|
| `motd` | `MOTD` |
| `difficulty` | `DIFFICULTY` |
| `gamemode` | `MODE` |
| `max-players` | `MAX_PLAYERS` |
| `online-mode` | `ONLINE_MODE` |
| `view-distance` | `VIEW_DISTANCE` |
| `white-list` | **`WHITELIST_PROP`** |
| `enforce-whitelist` | `ENFORCE_WHITELIST` |
| `enable-rcon` | `ENABLE_RCON` |
| `rcon.password` | `RCON_PASSWORD` |
| `rcon.port` | `RCON_PORT` |
| `level-name` | `LEVEL` |
| `server-port` | `SERVER_PORT` |

> [!IMPORTANT]
> `white-list` maps to `WHITELIST_PROP`, **not** `WHITELIST` — in this image
> `WHITELIST` is the list of *players*, and using it where you meant the
> on/off switch silently does something else.

`white-list-players` has no environment variable at all; the whitelist is
managed as a file instead.

### `SERVER_PORT` is load-bearing

`mc02` ran `unhealthy` for as long as it existed, while working perfectly for
players. Its port was set only in `server.properties`, so the container's
healthcheck kept probing the default 25565:

```
failed to ping localhost:25565 : connection refused
```

The role sets `SERVER_PORT` from the same value it uses for the host port
mapping, so the server and its healthcheck cannot disagree.

---

## 4. Secrets and personal data

[`ansible/vars/minecraft.yml`](../ansible/vars/minecraft.yml) is fully
vault-encrypted, for two distinct reasons:

* **RCON passwords** are genuine secrets. RCON is enabled on port 25575, but it
  is *not* published to the host — it is reachable only from inside the
  container network.
* **`whitelist.json` and `ops.json`** are not secrets, but they are personal
  data: real player names and Mojang UUIDs, including a family member's. This
  repository is public, so they are encrypted too.

Because `ansible-vault encrypt_string` only handles scalars, both lists are
stored as JSON *text*, and the role parses them with `from_json` before writing.

> [!WARNING]
> Do not pass those variables straight to `to_nice_json` — that serialises the
> *string*, producing a quoted JSON document. With `enforce-whitelist=true`,
> a malformed `whitelist.json` locks every player out. The role asserts they
> parse before writing anything.

Edit them with:

```bash
uv run ansible-vault edit --vault-id personal@~/.ansible-personal-key ansible/vars/minecraft.yml
```

### Applying a list change actually reaches the server — for the whitelist

Minecraft reads `whitelist.json` and `ops.json` at startup and keeps them in
memory. Writing the file is therefore not enough on its own: without a reload
the server keeps the old list and overwrites the file from memory the next time
anyone runs `/whitelist` in game, silently undoing the change.

The role notifies a handler that runs `rcon-cli whitelist reload` on each
instance, so whitelist changes take effect immediately.

> [!IMPORTANT]
> There is no equivalent for `ops.json` — Minecraft has no `op reload`. An
> operator change is written to disk but does not take effect until the server
> restarts:
>
> ```bash
> cd /srv/minecraft && docker compose restart mc01
> ```

### In-game changes show up as drift

`/whitelist add` and `/op` rewrite these files on the server. Since the
repository is now the source of truth, an in-game change appears as `changed`
on the next check run. That is the intended behaviour: reconcile by editing the
vault, not by leaving the server authoritative.

---

## 5. Operating it

Everything runs as the `debian` user from `/srv/minecraft`. That account is in
the `docker` group — added by `roles/docker` via `docker_admin_users` — so none
of these need `sudo`.

```bash
# state of both servers
docker ps

# does a server actually answer? (better than the health status)
docker exec minecraft-mc01-1 mc-monitor status --host localhost --port 25565
docker exec minecraft-mc02-1 mc-monitor status --host localhost --port 25566

# logs
cd /srv/minecraft && docker compose logs -f mc01

# server console
docker exec minecraft-mc01-1 rcon-cli
docker exec minecraft-mc01-1 mc-send-to-console say Hello

# restart one server
cd /srv/minecraft && docker compose restart mc01
```

### Deploying

```bash
cd ansible
ansible-playbook playbooks/minecraft.yml --check --diff   # review
ansible-playbook playbooks/minecraft.yml                  # apply
```

> [!CAUTION]
> Changing anything in the compose file — any setting, since settings *are*
> environment variables — recreates the affected container and **disconnects
> everyone playing on it**. `docker compose up -d` only touches services whose
> definition changed, so a change scoped to one instance leaves the other's
> players alone. Deploy when nobody is on.

`playbooks/minecraft.yml` owns this host entirely — base OS configuration
(`master_setup`, `iterm2_integration`) as well as Docker and the game servers.
One playbook per server is deliberate: the deploy workflow selects a playbook
and nothing else, so a playbook's `hosts:` is the only thing that decides which
machine is touched.

---

## 6. Version upgrades and config migration

`VERSION: LATEST` means the game updates whenever the container is recreated
with a newer image. The container was last upgraded by hand on 2026-08-15 after
sitting on a year-old version.

Minecraft migrates `server.properties` itself on first start of a new version:
it adds keys it has gained and drops ones it has retired, rewriting the file.
Both files were rewritten at 17:39 on 2026-08-15, i.e. by that upgrade, and
they carry the current key set — `management-server-*`, `accepts-transfers`,
`pause-when-empty-seconds` — with no retired keys left behind:

```
snooper-enabled: 0   texture-pack: 0   announce-player-achievements: 0
max-build-height: 0  spawn-animals: 0  spawn-npcs: 0
```

So no manual key migration is outstanding. To re-check after a future upgrade:

```bash
ssh debian@minecraft-01.farzad.tech \
  'sudo grep -cE "^(snooper-enabled|texture-pack|announce-player-achievements)=" \
     /srv/minecraft/mc01/server.properties'
```

> [!NOTE]
> Do not compare against the image's own `/image/server.properties`. That is a
> seed template for brand-new servers and is itself stale — it still lists
> `snooper-enabled` and `texture-pack`. Comparing a live file against it makes
> a correctly-migrated config look wrong.

Because settings are applied from environment variables, a *removed* key that
this role still sets would be written back on every start. If a future version
retires one of the settings in `minecraft_server_common_env`, drop it from the
role rather than from `server.properties`.

---

## 7. Known gaps

* **No backups.** Nothing copies the worlds anywhere — not to another disk, not
  off-host. A corrupt world or a lost instance loses everything since the world
  was created. This is the largest risk in the deployment and IaC does not
  address it.
* **`/srv/minecraft/01-20250405/` is 450 MB of orphaned data** from an earlier
  layout. Nothing references it: it is not in the compose file and no container
  mounts it. Left in place deliberately — deleting a former world is not a call
  to make from a config-management change — but it can go once you are sure.
* **Ports and DNS can drift apart.** See §2.
* **Memory headroom is thin.** 2.7 GB of 3.8 GB is in use with both servers
  idle and no players connected.
