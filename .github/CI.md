# Validation workflow

The existing patch-applies, pkgbuild-sanity, and mainline-merged checks are retained. A new shell-syntax check uses bash -n on tracked shell scripts and PKGBUILD without executing them. Validation uses Ubuntu 24.04, immutable Node-24-compatible checkout actions, read-only access, no persisted Git credentials, bounded timeouts, and stale-run cancellation.

Only pull requests whose entire diff is Markdown or LICENSE skip the substantive jobs. Every other path, an empty/unknown diff, default-branch pushes, and manual runs take the full route. The always-running CI result accepts skipped jobs only for that confirmed documentation-only route; routing failure, test failure, or cancellation fails it.

## What this does not prove

No kernel build, installer, package installation, ISO generation, or hardware test is run. The existing patch applicability check uses a temporary downloaded source tree. Its existing fallback to torvalds/linux master remains visible in logs and does not establish compatibility with the pinned CachyOS source when that source could not be fetched. Existing release/upstream-watch workflows are untouched. Hardware keyboard/trackpad and suspend checks remain manual.

The kernel must remain linux-cachyos-mb81, keep GENERIC_V3, and must not replace official linux-cachyos, as documented in AGENTS.md. Those rules and current PKGBUILD checks are unchanged.

## Local checks

Run bash -n on changed scripts and kernel/linux-cachyos-mb81/PKGBUILD. Do not execute the build/install/cleanup scripts just to test CI. The workflow's existing PKGBUILD grep checks can be run read-only; patch applicability needs the documented upstream source download.

[Workflow syntax](https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax) · [Secure action use](https://docs.github.com/en/actions/reference/security/secure-use)
