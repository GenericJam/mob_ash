# Changelog

All notable changes to **mob_ash** are documented here.

Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Versioning: [SemVer](https://semver.org/spec/v2.0.0.html).

---

## [Unreleased]

### Fixed

- **List screens re-read after a create/delete in a child screen**
  (MOB-56). `ListScreen`'s `handle_info(:mob_ash_refresh, ...)`
  clause had been waiting for a message nothing was sending —
  `FormScreen.handle_event("create")` and
  `DetailScreen.handle_event("delete")` popped back on success but
  never notified the list. Result: after a create or delete, the
  list stayed stale until the screen was rebuilt from scratch
  (usually by navigating away and back). New
  `MobAsh.Refresh.subscribe/1` + `broadcast/1` route through a
  `Registry` supervised by a new `MobAsh.Application`; `ListScreen`
  subscribes on mount (pids auto-unregister when they die),
  `FormScreen` / `DetailScreen` broadcast on the success path. Four
  revert-verified tests cover the pubsub layer.

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
