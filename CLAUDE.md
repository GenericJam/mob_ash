# mob_ash — Agent Instructions

**Read [`AGENTS.md`](AGENTS.md) first**, then [`~/code/mob/AGENTS.md`](../mob/AGENTS.md) for the system view, and `~/code/mob/MOB_PLUGINS.md` for the plugin manifest schema (spec-v2, code-generated screens). Together they cover the resource → screen mapping, the mob_dev host-config audit, and the cross-repo work with mob / mob_dev / Ash. This file goes deeper on Claude Code-specific workflow detail.

> **Keep AGENTS.md up to date** when you extend the generator, change the resource → screen mapping, or hit a gotcha. Out-of-date guidance there causes wrong decisions downstream — fix it in the same commit.

## What this repo is

A NET-NEW Mob plugin (not a core extraction): the spec-v2 generated-screens lane with Ash as the resource layer. Declare Ash resources in the host, register the domains, and mob_ash emits list / detail / create screens per resource at build time. Ash runs **on-device** in the host BEAM — first mob plugin with a heavyweight pure-Elixir runtime dependency (`:ash ~> 3.0`).

## Pre-commit checklist

Before committing, run all in this order:

```bash
mix format
mix credo --strict                  # includes ExSlop + jump_credo_checks
mix compile --warnings-as-errors
mix test
```

Pre-push hook (`.githooks/pre-push`) adds format + credo strict + compile on every push and the full suite when `mix.exs` changes. Activate once per clone:

```bash
git config core.hooksPath .githooks
```

Pure Elixir — no native code, no zig / clang-format step. The generator + shared screens are entirely hot-pushable. Device verification is still worth doing for anything non-trivial: install into a host, declare a real Ash domain, `mix mob.deploy`, navigate to `/ash/<resource>` and confirm list / detail / create work end-to-end with the chosen data layer (Ets or AshSqlite over the bundled SQLite).

### Tests are part of the change

New behaviour ships with a test unless the change is small enough that a test would only restate it. For mob_ash specifically:

* Changes to `MobAsh.Generator.entries/1` or `MobAsh.Info` = a unit test using `test/support/fixtures.ex`. These are pure functions, no host needed.
* Changes to the manifest's `:host_config_keys` = an audit-level test, plus check the mob_dev side agrees.
* Changes to the three screen modules = a mount test that pins the `params.resource` contract.

### Adversarial review — before every non-trivial commit

Spawn a subagent, point it at the diff. Especially:

* **Host-config audit escapes.** Any key read from the host at build time must be declared in `:host_config_keys`. A subagent's job is to find the read that isn't.
* **Per-resource forking.** The three screens are shared parameterized modules; the resource module travels as `params.resource`. Do not fork per-resource modules — that defeats spec-v2's whole point.
* **Ash surface drift.** `Ash.Domain.Info.resources/1` and `Ash.Resource.Info.public_attributes/1` are the introspection contract. If a diff bumps `:ash`, review whether either has shifted.
* **`apply/3` into mob_dev.** Deliberate — mob_ash must not compile-depend on mob_dev. A cleanup to a direct call is a real regression.

Skip only for: formatting, a typo, a version bump, a changelog edit.

## Release flow

Canonical process in [`~/code/mob/RELEASE.md`](../mob/RELEASE.md). mob_ash specifics:

* `@version` in `mix.exs` is the trigger. Push to master, GH Actions handles tag / GitHub release / Hex publish, signed with the shared mob first-party key.
* Hot-pushable, no native rebuild needed — but the generator runs at build time, so the release preflight (`mix.exs`-triggered full test run) is where regressions get caught.
* Do NOT bump `:ash` across a major version without re-verifying the two Ash.*.Info calls the plugin depends on.
