# Security Policy

## Supported Versions

GyroPlay is preparing its first public release. Security fixes are expected to target the latest `0.1.x` release line once `0.1.0` is published.

| Version | Supported |
| --- | --- |
| 0.1.x | Yes |
| Older builds | No |

## Reporting a Vulnerability

Use GitHub Security Advisories if they are enabled for this repository. If private advisories are not available, open a public issue that asks for a private maintainer contact, but do not include exploit details in the public issue.

Please include:

- Affected component: Android app, Python engine, WinUI desktop app, installer, or protocol.
- Steps to reproduce.
- Impact and affected versions.
- Any relevant logs or packet examples with secrets removed.

## Current Security Notes

- GyroPlay uses UDP on the local network.
- Pairing tokens are short-lived but traffic is not encrypted.
- Do not expose UDP port `5005` to the public internet.
- Treat QR pairing payloads as temporary local-network credentials.

