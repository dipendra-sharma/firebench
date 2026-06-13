# Security Policy

## Supported Versions

`firebench` is currently in alpha. Security fixes are applied to the latest
released alpha and shipped in a new alpha or patch release.

| Version  | Supported          |
| -------- | ------------------ |
| 0.1.x    | :white_check_mark: |
| < 0.1.0  | :x:                |

## Reporting a Vulnerability

Please report security vulnerabilities privately. **Do not open a public
GitHub issue for security problems.**

You have two private channels:

- Email **dipendra.sharma@thefleetlabs.com** with details and, if possible, a
  reproduction.
- Open a private advisory via GitHub Security Advisories:
  <https://github.com/dipendra-sharma/firebench/security/advisories>.

Please include:

- A description of the issue and its impact.
- Steps to reproduce or a proof of concept.
- The `firebench` version, Flutter/Dart version, and platform.

### What to expect

- We will acknowledge your report within **5 business days**.
- We will keep you informed of progress toward a fix and a release.
- We will credit you in the release notes if you wish.

## Security model

`firebench` is a thin instrumentation layer over `firebase_performance`. It
collects per-screen timing and frame metrics and sends them **only to your own
Firebase project** — there is no third-party backend, telemetry endpoint, or
data collection by the maintainers. No screen contents, user input, or
personal data are captured; traces contain route names and numeric timing
metrics only.

The SDK is designed to **never throw into the host app**: all Firebase calls
are guarded, and failures are caught and (in debug) logged rather than
propagated. A bug that causes `firebench` to crash or throw into the host
application is treated as a security-relevant defect.
