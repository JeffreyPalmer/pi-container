<h1 align="center">pi-container</h1>

<p align="center">
  <strong>A sovereign, npm-free local coding agent on macOS.</strong><br>
  The <code>pi</code> coding agent runs in a disposable Apple <code>container</code> micro-VM and talks to a local
  MLX-Swift model on the host — no Node, no npm, no agent binary on your work machine.
</p>

---

## Overview

A modern coding agent reads your files, runs shell commands, and installs whatever it decides it needs. On a work machine in a regulated context that is an unacceptable blast radius. This repository contains a **runnable setup** that closes it:

- **Inference stays native on the host** — MLX-Swift needs Apple Silicon's Metal/ANE, which a Linux VM does not expose.
- **The agent runtime is sandboxed in its own VM** — Apple `container` gives each container a lightweight VM, not shared-kernel namespaces.
- **The host stays clean** — no Node, no npm, no `pi` binary; the agent lives only inside an image and is discarded on exit.

The full step-by-step walkthrough is the article **[`en-pi-apple-container.md`](https://medium.com/@michael.hannecke/a-sovereign-coding-agent-on-macos-pi-in-an-apple-container-zero-npm-on-the-host-46f62ffade0a)** (English companion to a German MLX-Swift writing series). The files in this repo are the runnable reference for that article — change one, change the other.

## Architecture

```
┌─────────────────────────────┐        ┌──────────────────────────────┐
│ Host (macOS, Apple Silicon) │        │ Apple Container (Linux VM)   │
│                             │        │                              │
│  MLX-Swift server           │◄──────►│  pi-coding-agent             │
│  /v1/chat/completions       │ Bridge │  (Node 22, ripgrep, git)     │
│  gemma-4-26b-4bit           │        │  Workspace: /workspace       │
└─────────────────────────────┘        └──────────────────────────────┘
```

- **Inference** runs outside of the container (on the host or elsewhere). It has to — no Metal/ANE in a Linux VM.
- **Tool-calling sandbox** runs in the container — a clean split between model runtime and agent runtime.
- **pi** reaches the host only over the container bridge; the gateway IP is environment-dependent and discovered at runtime, never hardcoded.

## Table of contents

- [Repository structure](#repository-structure)
- [Prerequisites](#prerequisites)
- [Quickstart](#quickstart)
- [Troubleshooting](#troubleshooting)
- [License](#license)

## Repository structure

```
.
├── Containerfile                                 # node:22-bookworm-slim + pi installed globally
├── pi-config/
└── scripts/
    ├── build.sh                                  # container build
    └── run.sh                                    # container run with the right mounts
```

`pi-config/` is mounted into the container at runtime as the agent's config directory. Its `sessions/`, `cache/`, and `logs/` subdirectories are produced by pi during a session and are git-ignored — runtime artifacts, not configuration.

## Prerequisites

- **macOS 26 (Tahoe) on Apple Silicon, recommended.** `container` technically runs on macOS 15, but its networking is significantly limited there and this whole setup lives or dies on container-to-host networking. Treat macOS 15 as unsupported here.
- Apple `container` CLI installed (`container --version` must answer).
- **macOS Local Network permission grantable** — recent macOS gates local traffic behind a privacy prompt; it must be allowed for the container runtime.
- A local model server running **on the host** with an OpenAI-compatible `/v1/chat/completions` endpoint, serving the model you've loaded (e.g. `gemma-4-26b-a4b-it-4bit`), bound to `0.0.0.0:8080` (not only `127.0.0.1`). Native tool-calling is model-dependent — verify it for an agent workflow.
- **No Node and no npm on the host** — that is the point; the agent lives only in the image.

## Quickstart

### 1. Build the image

```bash
./scripts/build.sh
```

Produces `pi-coding-agent:local` (override the tag with `IMAGE_TAG=...`).

### 2. Discover the host bridge IP

From inside the container, the host is reachable via the bridge's default gateway. The address is environment-dependent, so discover it instead of assuming a subnet. The image's entrypoint is `pi`, so override it with `--entrypoint sh` for a one-off command (otherwise `pi` starts and reports "No API key found for the selected model"):

```bash
container run --rm --entrypoint sh pi-coding-agent:local -c "ip route | awk '/default/ {print \$3}'"
```

If the printed gateway differs from the default in `pi-config/models.json`, update `providers.mlx-local.baseUrl` accordingly (keep the `:8080/v1` suffix).

### 3. Run the agent

```bash
PROJECT_DIR=~/projects/your-repo ./scripts/run.sh --model mlx-local/gemma4-instruct
```

`run.sh` mounts exactly two things, and nothing else crosses the boundary:

- `pi-config/` → `/home/pi/.pi/agent` (provider config, `AGENTS.md`, extensions)
- `$PROJECT_DIR` → `/workspace` (the project being worked on)

`--rm` discards the VM and its writable layer on exit. The host is byte-for-byte unchanged.

## Troubleshooting

| Symptom | Cause & fix |
|---|---|
| Requests hang/fail with no error, empty reply | **Local Network permission not granted.** *System Settings → Privacy & Security → Local Network* — enable the container runtime, then fully quit and reopen the requesting app. Most common first-run failure on recent macOS. |
| "Can't reach the model" | **Host bound to loopback.** The container is a separate VM and cannot reach host `127.0.0.1`. Bind the model server to `0.0.0.0:8080`. |
| Connection refused / wrong address | **Wrong bridge IP.** `192.168.64.1` is only a default — re-run the `ip route` discovery and use the actual gateway. |
| Files not owned by your macOS user | **Expected.** The container writes as UID 1000; your host user is typically UID 501. In the pi workflow (edits go through the `edit` tool) this is acceptable. |
| Agent answers but never edits | **No native tool-calling.** pi has no `toolCalling` flag — it relies on the model doing OpenAI function-calling. Some instruct builds (Gemma included) may not, and silently no-op. Verify with a real session. |
| `models.json` loads but chat fails on role/params | Some local servers reject the `developer` role or `reasoning_effort`. Add provider-level `"compat": { "supportsDeveloperRole": false, "supportsReasoningEffort": false }` (see pi's `models.md`). |

## License

No license specified. The contents and code in this repository are **draft material**.
