# Bazel Non-Hermetic Test Example

This project demonstrates how to run a Bazel test that reaches out to an external system by granting it network access inside the [sandbox](https://bazel.build/docs/sandboxing) with [tags](https://bazel.build/reference/be/common-definitions#common.tags).

## Problem

Bazel runs tests in a sandbox to keep them hermetic. When network access is disabled for the sandbox, a test that calls an external HTTP endpoint cannot connect. Bazel also caches test results, so a test that depends on the state of an external system may report a stale result.

## Solution

The test target is annotated with two tags:

| Tag | Effect |
|-----|--------|
| `external` | Marks the test as depending on an external system, so its result is never cached and it runs on every invocation. |
| `requires-network` | Allows the test to access the network while keeping all other sandbox restrictions in place. |

The [`.bazelrc`](.bazelrc) sets `--sandbox_default_allow_network=false` to block network access for all sandboxed actions. Only targets tagged with `requires-network` can reach external systems.

```starlark
load("@rules_shell//shell:sh_test.bzl", "sh_test")

sh_test(
    name = "external_http_test",
    size = "small",
    srcs = ["external_http_test.sh"],
    tags = [
        "external",
        "requires-network",
    ],
)
```

If the test needs to bypass the sandbox entirely, for example to access undeclared files on the host, use the `no-sandbox` tag instead of `requires-network`.

## Project Structure

```
├── .bazelrc                    # Disables network access in the sandbox
├── .bazelversion               # Uses the latest Bazel release via Bazelisk
├── MODULE.bazel                # Bzlmod config: rules_shell
└── test/
    ├── BUILD.bazel             # sh_test with "external" and "requires-network" tags
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

Remove the `requires-network` tag from `test/BUILD.bazel` and run the test again. It fails because the sandbox blocks network access:

```
curl: (7) Failed to connect to example.com port 443 after 2 ms: Couldn't connect to server
//test:external_http_test                                                FAILED in 0.1s
```

On Linux, the failure shows up earlier as `curl: (6) Could not resolve host: example.com` because the sandbox has no network interface for DNS resolution.

## CI Verification

A [GitHub Actions workflow](.github/workflows/test.yml) runs the commands from the [Usage](#usage) section on every push and pull request using [setup-bazel](https://github.com/bazel-contrib/setup-bazel), which installs Bazelisk to pick up the latest Bazel release. It verifies the outcome of each command:

1. **Run the test** checks that the test passes.
2. **Run the test again without a cached result** checks that the test executes again instead of being reported as cached.
3. **Run the test without the requires-network tag** removes the tag and checks that the test fails with exit code 3 because `curl` cannot connect.

The workflow runs each command with `--spawn_strategy=linux-sandbox`, which forces Bazel to use the Linux sandbox that isolates the network. Without the flag, Bazel silently falls back to `processwrapper-sandbox` when the Linux sandbox is unavailable, and the test would pass even without the `requires-network` tag. The Linux sandbox relies on unprivileged user namespaces, so the workflow enables them on the runner first:

```sh
sudo sysctl -w kernel.apparmor_restrict_unprivileged_userns=0
```
