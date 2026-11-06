# Bazel Non-Hermetic Test Example

This project demonstrates how to run a Bazel test that reaches out to an external system by opting out of the [sandbox](https://bazel.build/docs/sandboxing) with [tags](https://bazel.build/reference/be/common-definitions#common.tags).

## Problem

Bazel runs tests in a sandbox to keep them hermetic. When network access is disabled for the sandbox, a test that calls an external HTTP endpoint cannot connect. Bazel also caches test results, so a test that depends on the state of an external system may report a stale result.

## Solution

The test target is annotated with two tags:

| Tag | Effect |
|-----|--------|
| `external` | Marks the test as depending on an external system, so its result is never cached and it runs on every invocation. |
| `no-sandbox` | Runs the test outside of the sandbox, giving it unrestricted access to the network. |

The [`.bazelrc`](.bazelrc) sets `--sandbox_default_allow_network=false` to block network access for all sandboxed actions. Only targets that opt out of the sandbox can reach external systems.

```starlark
load("@rules_shell//shell:sh_test.bzl", "sh_test")

sh_test(
    name = "external_http_test",
    size = "small",
    srcs = ["external_http_test.sh"],
    tags = [
        "external",
        "no-sandbox",
    ],
)
```

If the test should stay sandboxed but still be allowed network access, use the `requires-network` tag instead of `no-sandbox`.

## Project Structure

```
├── .bazelrc                    # Disables network access in the sandbox
├── .bazelversion               # Uses the latest Bazel release via Bazelisk
├── MODULE.bazel                # Bzlmod config: rules_shell
└── test/
    ├── BUILD.bazel             # sh_test with "external" and "no-sandbox" tags
    └── external_http_test.sh   # Calls https://example.com with curl
```

## Usage

Run the test:

```sh
bazelisk test //test:external_http_test
```

Run it again. The test executes again instead of returning a cached result:

```sh
bazelisk test //test:external_http_test
```

```
//test:external_http_test                                                PASSED in 0.1s

Executed 1 out of 1 test: 1 test passes.
```

Remove the `no-sandbox` tag from `test/BUILD.bazel` and run the test again. It fails because the sandbox blocks network access:

```
curl: (7) Failed to connect to example.com port 443 after 2 ms: Couldn't connect to server
//test:external_http_test                                                FAILED in 0.1s
```

## CI Verification

A [GitHub Actions workflow](.github/workflows/test.yml) runs `bazel test //...` on every push and pull request using [setup-bazel](https://github.com/bazel-contrib/setup-bazel), which installs Bazelisk to pick up the latest Bazel release.
