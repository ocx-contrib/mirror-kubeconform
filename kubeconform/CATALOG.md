---
title: kubeconform
description: A fast Kubernetes manifest validator that checks resources against JSON Schemas, with Custom Resource support
keywords: kubeconform,kubernetes,k8s,manifest,validation,json-schema,crd,yaml,lint,cli,go
---

# kubeconform

[kubeconform](https://github.com/yannh/kubeconform) validates Kubernetes
manifests and Custom Resources against JSON Schemas derived from the Kubernetes
OpenAPI specification. It is a self-contained static binary that validates
locally — no cluster connection, no `kubectl`, no API server round-trip — which
makes it a natural pre-commit or CI gate.

Validation is schema-driven rather than cluster-driven: point `-schema-location`
at the bundled default registry, at a local directory, or at your own converted
CRD schemas, and every resource in a file, a directory tree or a stdin stream is
checked against the schema its `apiVersion`/`kind` selects. `-strict` rejects
properties absent from the schema and duplicated YAML keys; `-kubernetes-version`
pins the target API version; `-skip` and `-reject` filter by kind or GVK.

Output is machine-readable on demand — `-output json`, `junit`, `tap`, `text` or
`pretty` — so it drops into a CI report without post-processing.

## What's included

- **kubeconform** — the validator. `kubeconform manifest.yaml` validates one
  file; a directory argument recurses; `-` reads a manifest stream from stdin.
  `-summary` adds the valid/invalid/errors/skipped tally, `-output json` makes
  the whole result machine-readable, and `-ignore-missing-schemas` downgrades an
  unknown Custom Resource from an error to a skip.

The release archive also ships upstream's `LICENSE` beside the binary; it is
inside the bundle but not on `PATH`.

## Install with ocx

```sh
ocx install ocx.sh/kubeconform/kubeconform
```

```sh
# or pin a specific version
ocx install ocx.sh/kubeconform/kubeconform:0.8.0
```

## Links

- [kubeconform on GitHub](https://github.com/yannh/kubeconform)
- [Documentation site](https://kubeconform.mandragor.org/)
- [CRD support / JSON Schema conversion](https://kubeconform.mandragor.org/docs/crd-support/)
