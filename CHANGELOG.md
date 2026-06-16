# Changelog

All notable changes to **mob_ash** are documented here.

Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Versioning: [SemVer](https://semver.org/spec/v2.0.0.html).

---

## [0.1.1] - 2026-06-16

### Changed
- Signed release: the published package now carries a verified Ed25519
  signature (shared mob first-party key, regenerated in CI on every
  release). Generated apps trust it via `config :mob, :trusted_plugins`,
  so it clears the plugin signature gate without `acknowledge_unsafe_plugins`.

## [0.1.0] - 2026-06-12

Initial release. Resource-driven Mob screens from Ash: declare Ash resources, get list / detail / create screens on device.

- Generates spec-v2 screens from your Ash resources via `mix mob_ash.gen`.
- Net-new package built on the mob plugin system (spec-v2 generated-screens lane).
- Requires `mob ~> 0.7`.
