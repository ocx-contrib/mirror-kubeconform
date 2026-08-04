# kubeconform/tests/smoke.star — stable across upstream kubeconform releases.
#
# Asserts the contract (exit code, version shape, the COMPUTED validation
# counts over a hermetic manifest set, and the JSON-pointer of a deliberately
# introduced type violation), never help/version prose.
#
# HERMETIC BY CONSTRUCTION. kubeconform's default schema source is
# https://raw.githubusercontent.com/yannh/kubernetes-json-schema/… — a network
# fetch. Every invocation below passes `-schema-location` pointing at a
# JSON Schema this script writes into scratch, which overrides that default
# outright: measured, a run whose local schema is absent fails in ~6 ms with
# `could not find schema for ConfigMap` rather than falling back to HTTP. So
# nothing here touches the network, in a bare `alpine:3.20` container or
# anywhere else.
#
# The schema deliberately omits a `$schema` key: the validator then uses its
# built-in default draft and can never reach out for a meta-schema. Every
# keyword used (type/required/properties/const/minLength/additionalProperties)
# is draft-agnostic.

KUBECONFORM = "kubeconform.exe" if ocx.target_platform.os == ocx.os.Windows else "kubeconform"

# Tier 1 + 2: liveness on the composed PATH + version SHAPE (not the banner,
# not the exact version — the digits are the contract). `-v` is answered by
# `fmt.Println(version)` in cmd/kubeconform/main.go and returns 0.
r_version = ocx.run(KUBECONFORM, "-v")
expect.ok(r_version)
expect.matches(r_version.stdout, r"\d+\.\d+\.\d+")

# ─── Hermetic fixtures ──────────────────────────────────────────────────────
#
# One local schema, resolved through kubeconform's own path template
# (`{{ .ResourceKind }}` lowercases the manifest's `kind`, so ConfigMap →
# configmap.json). The path is RELATIVE and the run's cwd defaults to the
# scratch root, which keeps it correct on Windows too — no separator juggling.
ocx.mkdir("schemas")
ocx.write_file("schemas/configmap.json", """{
  "type": "object",
  "required": ["apiVersion", "kind", "metadata", "data"],
  "properties": {
    "apiVersion": { "const": "v1" },
    "kind": { "const": "ConfigMap" },
    "metadata": {
      "type": "object",
      "required": ["name"],
      "properties": { "name": { "type": "string", "minLength": 1 } }
    },
    "data": { "type": "object", "additionalProperties": { "type": "string" } }
  }
}
""")

# TWO documents in one stream, so the asserted count is something the binary
# had to compute rather than a constant it could print unconditionally. It also
# forces the multi-document YAML splitter, which a single-document fixture
# would leave untouched.
ocx.write_file("valid.yaml", """apiVersion: v1
kind: ConfigMap
metadata:
  name: smoke-one
data:
  greeting: hello
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: smoke-two
data:
  farewell: bye
""")

# The NEGATIVE CONTROL's fixture. Structurally identical to the valid one but
# for `greeting: 42` — YAML decodes a bare 42 as a number, which the schema's
# `additionalProperties: {"type": "string"}` forbids. A validator that
# rubber-stamped its input, or one whose embedded schema engine never ran,
# would report this file valid.
ocx.write_file("invalid.yaml", """apiVersion: v1
kind: ConfigMap
metadata:
  name: smoke-bad
data:
  greeting: 42
""")

SCHEMA_LOCATION = "schemas/{{ .ResourceKind }}.json"

# Tier 3a: the positive case. `-output json -summary` emits a machine-readable
# tally, so the assertion is on computed integers rather than on text.
r_valid = ocx.run(
    KUBECONFORM,
    "-schema-location", SCHEMA_LOCATION,
    "-summary", "-output", "json",
    "valid.yaml",
)
expect.ok(r_valid)
expect.matches(r_valid.stdout, r'"valid":\s*2')
expect.matches(r_valid.stdout, r'"invalid":\s*0')
expect.matches(r_valid.stdout, r'"errors":\s*0')
# `skipped: 0` is load-bearing: it is what separates "validated against the
# local schema" from "silently declined to validate anything".
expect.matches(r_valid.stdout, r'"skipped":\s*0')

# Tier 3b: THE NEGATIVE CONTROL. Exit 1 is source-verified, not guessed —
# cmd/kubeconform/main.go's `kubeconform()` returns 1 on `!success` and 0
# otherwise, and `main` exits with it.
r_invalid = ocx.run(
    KUBECONFORM,
    "-schema-location", SCHEMA_LOCATION,
    "-summary", "-output", "json",
    "invalid.yaml",
)
expect.eq(r_invalid.exit_code, 1)
expect.matches(r_invalid.stdout, r'"valid":\s*0')
expect.matches(r_invalid.stdout, r'"invalid":\s*1')
expect.matches(r_invalid.stdout, r'"errors":\s*0')
# `statusInvalid` is the enum wire value (pkg/validator), and `/data/greeting`
# is a JSON pointer the validator COMPUTED from the violation's location —
# neither string appears anywhere in this script's inputs, so emitting them is
# proof the schema engine actually walked the document.
expect.contains(r_invalid.stdout, "statusInvalid")
expect.matches(r_invalid.stdout, r'"path":\s*"/data/greeting"')

# No Tier 4: metadata.json declares PATH only (proven by Tier 1 liveness).
