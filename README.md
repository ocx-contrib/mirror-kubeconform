# mirror-kubeconform

OCX mirror for [kubeconform](https://github.com/yannh/kubeconform), a fast
Kubernetes manifest validator. One repository, one spec directory per package.

| Package | Spec | Publishes to | Announced as | Upstream SPDX |
|---|---|---|---|---|
| [kubeconform](https://github.com/yannh/kubeconform) | [`kubeconform/mirror.yml`](kubeconform/mirror.yml) | `ghcr.io/ocx-contrib/kubeconform/kubeconform` | [`ocx.sh/kubeconform/kubeconform`](https://index.ocx.sh/kubeconform/kubeconform) | `Apache-2.0` |

Each upstream release is discovered, re-bundled, smoke-tested per
`(version, platform)` and only then pushed with cascade tags, after which the
result is announced into the OCX index.

`yannh` is a personal handle rather than a vendor, so the tool names itself: the
namespace is `kubeconform`, not the maintainer.

## Layout

```
mirror-base.yml         repo-wide policy the spec inherits via `extends:`
kubeconform/
├── mirror.yml          the spec — never at the repo root
├── metadata.json       bundle interface
├── CATALOG.md          → ocx package describe
├── logo.svg / logo.png describe assets, 512px PNG
└── tests/smoke.star    Starlark smoke test
```

`LICENSE` and `NOTICE.md` are shared at the root. The logo is **not** — it sits
beside the spec, because a repo-root `logo.*` sits in no workflow's `paths:`
filter, so replacing it would publish nothing until some unrelated edit
happened to fire.

⚠️ `extends:` is a **shallow** merge of top-level keys. A spec that restates
`platforms:` to change one runner drops every `containers:` entry with it, and
nothing reds — the legs simply stop existing, and every `os.features` claim
goes back to being asserted rather than verified. `kubeconform/mirror.yml` does
not restate `platforms:` at all; the measured matrix lives in `mirror-base.yml`.

## Platforms

Six platform entries: both Linux arches, both macOS arches, both Windows
arches. Every one of the six anchored asset patterns was checked against the
full asset list of **every** in-range release (v0.7.0, v0.8.0) and matches
exactly one asset each — a pattern matching zero is *silently skipped* by the
pipeline, not an error, and would ship a missing platform under a green run.

**Both Linux keys are bare, because nothing is dynamically linked.**
`os.features` states what an artifact requires *of the host*, never how it was
built:

| Key | Asset | Measured (v0.7.0 and v0.8.0) |
|---|---|---|
| `linux/amd64` | `kubeconform-linux-amd64.tar.gz` | `statically linked`, `INTERP` segments **0**, `DT_NEEDED` **0**, no `GLIBC_*` symbol versions → **bare** |
| `linux/arm64` | `kubeconform-linux-arm64.tar.gz` | identical on all three counts → **bare** |

CGO-free Go builds, so upstream ships no gnu/musl split in any filename — one
build per arch covers both userlands. `+libc.musl` would be a false requirement
hiding the package from every glibc host it in fact runs on. The `alpine:3.20`
container leg on **both** arches is what turns that universality claim into
evidence.

v0.8.0 dropped three legs that v0.7.0 and v0.6.7 shipped —
`kubeconform-linux-386.tar.gz`, `kubeconform-windows-386.zip`,
`kubeconform-windows-armv6.zip`. The regression is moot here: OCX's
`Architecture` enum is amd64 + arm64 only, so none of the three was ever
declarable, and the intersection of v0.7.0 and v0.8.0 over expressible
platforms is exactly the six keys above. No per-platform version window is
needed. `kubeconform-linux-armv6.tar.gz` is still published upstream and is
likewise not declarable.

Also published upstream and deliberately not carried: the `CHECKSUMS` sidecar —
an exact filename with no extension, kept out by the terminating `\.tar\.gz$` /
`\.zip$` in every pattern.

## The binaries claim

Every release archive — `.tar.gz` and `.zip` alike — is **flat**: exactly two
entries, `LICENSE` (0644) and `kubeconform` (`kubeconform.exe` on Windows, mode
0755), both at the archive root with **no wrapper directory**. So
`strip_components: 0` serves every platform — there is no top directory to
strip, and stripping one would consume the executable itself — and one
`metadata.json` serves them all.

After extraction the bundle's only PATH entry is a bare `${installPath}`: the
executable *is* the content root. `bin_scan` only looks *below* an
`${installPath}/<dir>` entry, so `auto`/`verify` is rejected at spec load with
exit 65 (*the verification would inspect no file and pass green whatever the
archive contains*). `kubeconform/mirror.yml` therefore sets `bin_scan: "off"`
and `kubeconform/metadata.json` hand-lists `binaries: ["kubeconform"]` — the
blessed shape for this layout, and `kubeconform` is the archive's only
mode-0755 entry.

## The smoke test is hermetic by construction

kubeconform's *default* schema source is a `raw.githubusercontent.com` fetch.
`kubeconform/tests/smoke.star` overrides it with `-schema-location` pointing at
a JSON Schema the script writes into scratch, so no leg touches the network —
measured, a run whose local schema is absent fails in ~6 ms with `could not find
schema for ConfigMap` rather than falling back to HTTP.

It asserts computed counts from `-output json -summary`, never prose: a
two-document valid stream must report `"valid": 2`, and a **negative control**
— the same manifest with `greeting: 42`, a number where the schema demands a
string — must report `"invalid": 1` at exit 1, naming the JSON pointer
`/data/greeting` the validator computed for itself. Without that second half a
validator that rubber-stamped everything would pass.

## Editing

| File | Edit | Regenerate after |
|------|------|------------------|
| `mirror-base.yml`, `kubeconform/mirror.yml` | hand | yes — see below |
| `kubeconform/{metadata.json,CATALOG.md,logo.*}` | hand | — |
| `kubeconform/tests/smoke.star` | hand | — |
| `.github/workflows/*.yml` | **generated — never hand-edit** | re-run when a spec changes |

```bash
ocx-mirror package pipeline generate ci --spec kubeconform/mirror.yml
```

**Name every spec.** `--spec` *appends* rather than replaces, so a command
naming a subset silently stops rendering the rest while staying green — and the
drift guard reds on a generated workflow the current spec set no longer
produces.

`verify-generated.yml` exits 65 on drift. If a generated workflow is wrong, the
spec or the renderer template is wrong — fix it there and regenerate.

Run `direnv allow` once to put the pinned toolchain on `PATH`, and invoke
`ocx-mirror` directly — never `ocx run -- ocx-mirror`, which pins
`OCX_BINARY_PIN` to the bootstrap `ocx` and false-reds the nested push.

## Required secrets

| Secret | Use |
|--------|-----|
| `OCX_ANNOUNCE_TOKEN` | opens the index pull request from the `ocx-contrib/index` fork |
| `OCX_MIRROR_DISCORD_HOOK` | notify-stage Discord webhook URL |

(Inherited from the `ocx-contrib` org with visibility ALL. GHCR pushes use the
run's own `GITHUB_TOKEN` — no registry secret needed.)

## License

Apache-2.0 — see [`LICENSE`](LICENSE). Upstream assets are out of scope; the
redistribution license is recorded in [`NOTICE.md`](NOTICE.md).
