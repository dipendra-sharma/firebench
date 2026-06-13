# Contributing to firebench

Thanks for your interest in improving `firebench`. Contributions of all kinds
are welcome: bug reports, fixes, documentation, and features that fit the
package's scope (Sentry-style per-screen performance tracing reported to the
free Firebase Performance backend).

By participating you agree to abide by our [Code of Conduct](CODE_OF_CONDUCT.md).

## Getting started

```bash
git clone https://github.com/dipendra-sharma/firebench.git
cd firebench
flutter pub get
```

The example app lives in `example/` and has its own package:

```bash
cd example
flutter pub get
```

## Before opening a pull request

Run all checks locally and make sure they pass:

```bash
dart format .          # formatting must be clean
flutter analyze        # must report no issues
flutter test           # all tests must pass
```

Frame-timing behavior is only meaningful in profile/release builds; keep that in
mind when validating tracing changes.

## Pull request guidelines

- Keep PRs small and focused on a single change.
- Describe what changed and why. Link any related issue.
- Add or update tests for any behavior change.
- Update `CHANGELOG.md` under the next unreleased version.
- Match the existing code style. The codebase is self-documenting — prefer clear
  names over comments, and follow the lints in `analysis_options.yaml`.

## Commit messages

Use [Conventional Commits](https://www.conventionalcommits.org/):

```
<type>(<scope>): <description>
```

Examples: `fix(observer): finalize trace on pushReplacement`,
`feat(config): add ignoreRoutes option`, `docs(readme): clarify TTFD setup`.

## Reporting bugs and requesting features

Open an issue at
<https://github.com/dipendra-sharma/firebench/issues>. For security issues, do
not open a public issue — follow [SECURITY.md](SECURITY.md) instead.

## License

By contributing, you agree that your contributions will be licensed under the
[MIT License](LICENSE).
