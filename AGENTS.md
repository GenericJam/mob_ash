# AGENTS.md — orientation for AI agents working on mob_ash

You're in **mob_ash**, the framework-integration plugin that turns declared Ash resources into on-device Mob screens. Register your Ash domains in the host, and mob_ash generates a list / detail / create screen set per resource at build time. Ash itself runs **on-device** in the host BEAM — this is the first mob plugin with a heavyweight pure-Elixir runtime dependency (`:ash ~> 3.0`).

**Also read [`~/code/mob/AGENTS.md`](../mob/AGENTS.md)** and **`~/code/mob/MOB_PLUGINS.md`** for the plugin manifest schema, spec-v2 (code-generated plugins), `Mob.Nav.Registry`, and the mob-dev host-config audit that gates what a plugin can read. This file is mob_ash-specific.

> **Keep this file current.** When you change the resource → screen mapping, extend the generator, or hit a gotcha that would trip the next agent, fix it here in the same commit.

## What mob_ash is, in one paragraph

Spec-v2 (`plugin_spec_version: 2`), the code-generated screens lane — the manifest declares `screens_generator: {MobAsh.Generator, :generate, []}` and `host_config_keys: [:ash_domains]`. At build time mob_dev runs the generator inside the host app's Mix context; the generator reads `config :my_app, :ash_domains` (audited — only keys declared in `:host_config_keys` may be read), calls `Ash.Domain.Info.resources/1` on each domain, and emits three route entries per resource: `/ash/<segment>`, `/ash/<segment>/detail`, `/ash/<segment>/new`, all pointing at three shared parameterized screens (`MobAsh.ListScreen`, `MobAsh.DetailScreen`, `MobAsh.FormScreen`) with the resource module as **route-bound `:params`** delivered to `mount/3` by core navigation. `MobAsh.navigate(socket, resource, :list | :detail | :new, params \\ %{})` is the programmatic seam. Pure Elixir end to end — no native code, all screens hot-pushable, Ash runs on-device (use a device-friendly data layer like `Ash.DataLayer.Ets` or AshSqlite over the bundled SQLite).

## What mob_ash is NOT

* **Not a general ORM binding.** This is about **Ash resources becoming screens**, not about mapping arbitrary schemas or Ecto structs to a UI. If you want a generic list/detail generator for something that isn't an Ash resource, that is not this plugin.
* **Not a server-side Ash bridge.** Ash runs on-device in the host BEAM; the plugin doesn't sync with a remote Ash API or proxy `Ash.read/2` over the network. The data layer choice (Ets, AshSqlite over the bundled SQLite) is the host's — the plugin exposes screens over whatever the resource itself is configured with.
* **Not a form builder.** `FormScreen` is a create screen driven by the resource's public attributes via `MobAsh.Info`. If you need edit/update or complex validation UI beyond what Ash's own actions expose, that goes in the host, not here.
* **Not a capability plugin.** No `:nifs`, no `:android`, no `:ios`, no permissions. The framework-integration lane is intentionally pure Elixir + spec-v2.

## Anatomy of the plugin

* `lib/mob_ash.ex` — public API: `navigate/4`. Moduledoc is the canonical host-setup story (`config :mob, :plugins, [:mob_ash]` + `config :my_app, :ash_domains, [...]`).
* `lib/mob_ash/generator.ex` — the spec-v2 generator (`MobAsh.Generator.generate/0`). Runs inside the host's Mix context; `apply/3` into `MobDev.Plugin.host_config/3` so this module doesn't compile-depend on mob_dev.
* `lib/mob_ash/info.ex` — pure Ash-introspection helpers (`route_segment/1`, `title/1`, `display_attributes/1`). Side-effect free so the resource → UI mapping is unit-testable without a device or mob_dev.
* `lib/mob_ash/list_screen.ex` / `detail_screen.ex` / `form_screen.ex` — shared parameterized screens; the resource module rides in as `%{resource: MyApp.Blog.Post}`.
* `priv/mob_plugin.exs` — the manifest. `plugin_spec_version: 2`, `screens_generator: {MobAsh.Generator, :generate, []}`, `host_config_keys: [:ash_domains]`. No `:nifs`, no platform sections.
* `test/support/fixtures.ex` — Ash test fixtures (a small domain + resources) for exercising the generator without a real host.

## Cross-repo work

**mob (framework):** the screens use `Mob.Nav.Registry` route-bound params to carry the resource module. If mob core evolves how parameterized screens receive route params in `mount/3`, `list_screen.ex` / `detail_screen.ex` / `form_screen.ex` re-verify here. See [`~/code/mob/AGENTS.md`](../mob/AGENTS.md).

**mob_dev:** owns the host-config audit and the `mix mob.regen_plugin_manifest` / native-build regen hook that runs the generator. **Any change to `:host_config_keys` here needs a matching mental model of what mob_dev will permit** — a key not declared in the manifest is silently unavailable, no matter how it looks in the host's `config/config.exs`. `apply/3` into `MobDev.Plugin.host_config/3` is deliberate to keep mob_dev out of the plugin's runtime dep graph.

**Ash:** runtime dep, real one. Bump `~> 3.0` only after checking that `Ash.Resource.Info.public_attributes/1` + `Ash.Domain.Info.resources/1` haven't shifted. On-device data layer is the host's choice; the plugin doesn't ship one.

## Testing

Elixir suite (generator output + `Info` helpers + fixtures):

```bash
mix deps.get
mix test
```

Focus areas:

* `MobAsh.Generator.entries/1` returns the three-entry list for a resource — pure, no host needed.
* `MobAsh.Info.display_attributes/1` orders public attrs correctly (primary key + timestamps last).
* Full generator via `test/support/fixtures.ex` — a small Ash domain exercising `:ash_domains` audit.

Device test = install into a Mob host, declare a real Ash domain in `config :my_app, :ash_domains`, `mix mob.deploy`, navigate to `/ash/<resource>`, confirm list + detail + create work end-to-end with the chosen data layer.

## The pre-empt-failure rules that matter here

1. **`:host_config_keys` is the audit boundary.** Only keys declared here may be read from the host at build time; adding a config knob means updating this list AND the mob_dev audit's expectations. Silently reading anything else is a bug you won't see until a real host uses it.
2. **`apply/3` for mob_dev calls is deliberate.** `MobDev.Plugin.host_config/3` is invoked via `apply/3` so mob_ash doesn't compile-depend on mob_dev. Do not "clean this up" to a direct call — mob_dev is a build-time-only dep of the host, not a runtime dep of this plugin.
3. **Screens are shared parameterized.** All three screens are one instance each — the resource module travels as `params.resource`, not as three-copy generated modules. Do not fork per-resource screen modules; that defeats spec-v2's whole point.
4. **`Ash.Domain.Info.resources/1` is the introspection contract.** Cache it in the generator if you must, but if Ash changes shape at a major version, this plugin re-verifies before bumping.
5. **The generator runs inside the host's Mix context.** Do not hard-code `:mob_ash` as `Mix.Project.config()[:app]` inside the generator — the host is the current project at that call site. A copy-paste from a prototype that hardcodes the host app name is a real footgun; check `generator.ex`'s comment for context.

## Pre-commit + release

Standard mob gate (pure Elixir — no zig / clang-format):

```bash
mix format
mix credo --strict
mix compile --warnings-as-errors
mix test
```

Activate the pre-push hook once per clone: `git config core.hooksPath .githooks`. Pre-push runs format / credo strict / compile on every push and the full suite when `mix.exs` changes.

Release = `mix.exs` `@version` bump on master. GH Actions handles tag + GitHub release + Hex publish, signed with the shared mob first-party key. Do NOT bump without explicit permission.
