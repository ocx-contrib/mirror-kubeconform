# NOTICE

This repository packages and redistributes upstream software published by the
[kubeconform](https://github.com/yannh/kubeconform) project. The Apache-2.0
license in [`LICENSE`](LICENSE) covers the OCX pipeline files authored here. It
does **not** cover any upstream-derived asset — the redistributed bytes carry
their own license, recorded below.

The package logo is an original mark authored for this repository — upstream
publishes none — and is used for catalog identification only. No endorsement is
implied.

| Package | GHCR path | Upstream SPDX |
|---|---|---|
| `kubeconform` | `ghcr.io/ocx-contrib/kubeconform/kubeconform` | `Apache-2.0` |

---

## `kubeconform`

Upstream: <https://github.com/yannh/kubeconform>
Published to `ghcr.io/ocx-contrib/kubeconform/kubeconform`.

| Component | SPDX | Holder |
|---|---|---|
| kubeconform | **Apache-2.0** | Yann Hamon |

Verified at the Phase 1.5 license gate:

```
$ gh api repos/yannh/kubeconform/license --jq '{spdx: .license.spdx_id, path: .path}'
{"path":"LICENSE","spdx":"Apache-2.0"}
```

Apache-2.0 is permissive and grants redistribution of the compiled binary
subject to its notice-retention conditions. Those are satisfied in place: every
upstream release archive ships the full `LICENSE` text beside the executable,
and it is republished unmodified inside the OCX bundle. The canonical text is
<https://github.com/yannh/kubeconform/blob/master/LICENSE>.

The published binaries are statically linked CGO-free Go builds that vendor
third-party Go modules under permissive licenses, enumerated in upstream's
`go.mod` / `vendor/` tree.

No modifications are made to any upstream artifact in this repository; they are
republished byte-for-byte inside an OCX bundle.
