# STACloudMultiEgg

STACloudMultiEgg is a collection of Docker images and Pterodactyl eggs maintained by STACloud.

This repository contains:

- shared runtime images for Pterodactyl
- generic eggs for common stacks
- game and service eggs
- OpenClaw runtime and egg support

Main registries used in this repo:

- `ghcr.io/sta-cloud-dev/deverlopment`
- `ghcr.io/sta-cloud-dev/ai`
- `ghcr.io/sta-cloud-dev/stacloud-freemium`
- `ghcr.io/sta-cloud-dev/stacloud-premium`

---

## Repository layout

### Runtime image folders

- [python](python)
- [bun](bun)
- [java](java)
- [nodejs](nodejs)
- [c](c)
- [golang](golang)
- [openclaw](openclaw)
- [docker-freemium](docker-freemium)
- [docker-premium](docker-premium)

### Egg JSON files

Generic eggs:

- [PythonGeneric.json](PythonGeneric.json)
- [BunGeneric.json](BunGeneric.json)
- [JavaGeneric.json](JavaGeneric.json)
- [NodejsGeneric.json](NodejsGeneric.json)
- [CGeneric.json](CGeneric.json)
- [GolangGeneric.json](GolangGeneric.json)

Game and service eggs:

- [egg-paper.json](egg-paper.json)
- [egg-fabric.json](egg-fabric.json)
- [egg-folia.json](egg-folia.json)
- [egg-forge-enhanced.json](egg-forge-enhanced.json)
- [egg-vanilla-minecraft.json](egg-vanilla-minecraft.json)
- [egg-vanilla-bedrock.json](egg-vanilla-bedrock.json)
- [egg-bungeecord.json](egg-bungeecord.json)
- [egg-canvas-mc.json](egg-canvas-mc.json)
- [egg-pterodactyl-pocketmine-m-p.json](egg-pterodactyl-pocketmine-m-p.json)
- [LavaLink.json](LavaLink.json)
- [OpenClaw.json](OpenClaw.json)

Multi-egg launchers:

- [stacloud-multiegg-freemium.json](stacloud-multiegg-freemium.json)
- [stacloud-multiegg-premium.json](stacloud-multiegg-premium.json)

### Build workflows

- [python.yml](.github/workflows/python.yml)
- [bun.yml](.github/workflows/bun.yml)
- [java.yml](.github/workflows/java.yml)
- [nodejs.yml](.github/workflows/nodejs.yml)
- [c.yml](.github/workflows/c.yml)
- [golang.yml](.github/workflows/golang.yml)
- [openclaw.yml](.github/workflows/openclaw.yml)
- [docker-freemium.yml](.github/workflows/docker-freemium.yml)
- [docker-premium.yml](.github/workflows/docker-premium.yml)

---

## Image catalog

### Python

Namespace: `ghcr.io/sta-cloud-dev/deverlopment`

- `python_2.7`
- `python_3.7`
- `python_3.8`
- `python_3.9`
- `python_3.10`
- `python_3.11`
- `python_3.12`
- `python_3.13`
- `python_3.14`

### Bun

Namespace: `ghcr.io/sta-cloud-dev/deverlopment`

- `bun_latest`
- `bun_canary`

### Debian

Namespace: `ghcr.io/sta-cloud-dev/oses`

- `debian_bookworm`
- `debian`

### Java

Namespace: `ghcr.io/sta-cloud-dev/deverlopment`

- `java_8`
- `java_8j9`
- `java_11`
- `java_11j9`
- `java_13`
- `java_16`
- `java_16j9`
- `java_17`
- `java_18`
- `java_18j9`
- `java_19`
- `java_19j9`
- `java_21`
- `java_21j9`
- `java_22`
- `java_23`
- `java_24`
- `java_25`

### Node.js

Namespace: `ghcr.io/sta-cloud-dev/deverlopment`

- `nodejs_12`
- `nodejs_14`
- `nodejs_16`
- `nodejs_17`
- `nodejs_18`
- `nodejs_19`
- `nodejs_20`
- `nodejs_21`
- `nodejs_22`
- `nodejs_23`
- `nodejs_24`
- `nodejs_25`

### .NET

Namespace: `ghcr.io/sta-cloud-dev/deverlopment`

- `dotnet_8`
- `dotnet_7`
- `dotnet_6`
- `dotnet_5`
- `dotnet_3.1`
- `dotnet_2.1`

### Golang

Namespace: `ghcr.io/sta-cloud-dev/deverlopment`

- `golang1.24`

### OpenClaw

Namespace: `ghcr.io/sta-cloud-dev/ai`

- `openclaw_latest`

### Multi-egg launcher

- `ghcr.io/sta-cloud-dev/stacloud-freemium:latest`
- `ghcr.io/sta-cloud-dev/stacloud-premium:latest`

---

## Generic eggs

### Python Generic

File: [PythonGeneric.json](PythonGeneric.json)

Key variables:

- `PY_FILE`
- `PY_PACKAGES`
- `REQUIREMENTS_FILE`
- `GIT_ADDRESS`
- `BRANCH`
- `USERNAME`
- `ACCESS_TOKEN`
- `USER_UPLOAD`
- `AUTO_UPDATE`

### Bun Generic

File: [BunGeneric.json](BunGeneric.json)

Key variables:

- `MAIN_FILE`
- `GIT_ADDRESS`
- `BRANCH`
- `USERNAME`
- `ACCESS_TOKEN`
- `USER_UPLOAD`
- `AUTO_UPDATE`

### Java Generic

File: [JavaGeneric.json](JavaGeneric.json)

Key variables:

- `JARFILE`

### Node.js Generic

File: [NodejsGeneric.json](NodejsGeneric.json)

Key variables:

- `JS_FILE`
- `GIT_ADDRESS`
- `BRANCH`
- `USERNAME`
- `ACCESS_TOKEN`
- `USER_UPLOAD`
- `AUTO_UPDATE`

### C# / .NET Generic

File: [CGeneric.json](CGeneric.json)

Key variables:

- `PROJECT_FILE`
- `PROJECT_DIR`
- `GIT_ADDRESS`
- `BRANCH`
- `USERNAME`
- `ACCESS_TOKEN`
- `USER_UPLOAD`
- `AUTO_UPDATE`

### Golang Generic

File: [GolangGeneric.json](GolangGeneric.json)

Key variables:

- `GO_PACKAGE`
- `EXECUTABLE`

---

## OpenClaw

File: [OpenClaw.json](OpenClaw.json)

OpenClaw stores persistent state in:

- `/home/container/.openclaw`

Image:

- `ghcr.io/sta-cloud-dev/ai:openclaw_latest`

Important variables:

- `OPENCLAW_BIND`
- `OPENCLAW_GATEWAY_TOKEN`
- `OPENCLAW_VERBOSE`
- `OPENCLAW_AUTO_UPDATE`
- `OPENCLAW_UPDATE_OPENCLAW_VERSION`
- `OPENCLAW_ALLOWED_ORIGINS`
- `OPENCLAW_ALLOW_HOST_HEADER_ORIGIN_FALLBACK`
- `OPENCLAW_PROXY_UPSTREAM_HOST`
- `OPENCLAW_ARGS`

Recommended production setup behind HTTPS reverse proxy:

- `OPENCLAW_BIND=lan`
- `OPENCLAW_ALLOWED_ORIGINS=https://ai.user.com`
- `OPENCLAW_ALLOW_HOST_HEADER_ORIGIN_FALLBACK=false`
- `OPENCLAW_GATEWAY_TOKEN=<token>`

The runtime also writes helper files for orchestration:

- `/home/container/.openclaw/public-endpoint.json`
- `/home/container/.openclaw/caddy-route.caddy`

Custom-domain notes:

- [docs/openclaw-custom-domain.md](docs/openclaw-custom-domain.md)
- [docs/pterodactyl-openclaw-domain-manager-spec.md](docs/pterodactyl-openclaw-domain-manager-spec.md)

---

## Importing eggs into Pterodactyl

Basic flow:

1. Sign in to the Pterodactyl admin panel
2. Go to `Nests`
3. Select an existing nest or create a new one
4. Choose `Import Egg`
5. Upload the target JSON file from this repository

---

## Contributing

When adding a new runtime or version:

1. Create the matching runtime folder, for example `python/3.15/`
2. Add or update the `Dockerfile`
3. Update the matching workflow in `.github/workflows/`
4. Update any affected egg JSON files
5. Update this README when the public behavior changes

---

## License

This project is released under the [MIT License](LICENSE).
