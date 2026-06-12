# Security Policy

## Supported Versions

GyroPlay is preparing its first public release. Security fixes target the latest `0.1.x` release line after `0.1.0` is published.

| Version | Supported |
| --- | --- |
| 0.1.x | Yes |
| Older builds | No |

## Reporting a Vulnerability

Use GitHub private vulnerability reporting or repository security advisories if they are enabled:

https://github.com/saiusesgithub/GyroPlay/security/advisories

If private reporting is not available, open a public issue asking for a private maintainer contact, but do not include exploit details, pairing tokens, packet captures, or proof-of-concept code in the public issue.

Issue tracker:

https://github.com/saiusesgithub/GyroPlay/issues

## Please Include

- Affected component: Android app, Windows desktop app, Python engine, installer, or protocol.
- Affected version.
- Impact and expected attacker position.
- Reproduction steps.
- Logs or packet examples with secrets removed.
- Whether the issue requires local-network access.

## Local-Network Threat Model

GyroPlay is designed for trusted local networks.

- The Android app and Windows engine communicate over UDP.
- Pairing tokens are short-lived.
- Session IDs are used after pairing succeeds.
- Traffic is not encrypted in v0.1.0.
- UDP port `5005` should not be exposed to the public internet.
- Guest Wi-Fi, VPNs, and isolated networks may block pairing.

## Privacy Model

- GyroPlay does not require an account.
- GyroPlay does not use a cloud backend.
- Runtime settings, logs, and pairing state are stored locally.
- Logs may include technical connection details; remove pairing tokens before sharing logs.

## Expected Response Process

The maintainer will aim to:

1. Acknowledge valid reports when they are seen.
2. Confirm affected versions and components.
3. Prepare a fix or mitigation.
4. Credit reporters when appropriate and requested.
5. Publish release notes for user-impacting security fixes.

Do not publicly disclose sensitive pairing or protocol issues before a fix or mitigation is available.
