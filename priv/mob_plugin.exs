%{
  name: :mob_ash,
  mob_version: "~> 0.6",
  # Spec v2: contributions are GENERATED from the host's configuration at
  # build time — the lane this plugin exists to exercise (MOB_PLUGINS.md
  # "Code-generated plugins"). Ash was the motivating example for v2; this is
  # the real thing.
  plugin_spec_version: 2,
  description:
    "Resource-driven Mob screens from Ash: declare Ash resources in the host, " <>
      "get list/detail/create screens generated per resource",
  # The generator reads the HOST's :ash_domains config (audited — only keys
  # declared here may be read) and emits three route entries per resource, all
  # pointing at mob_ash's shared parameterized screens with the resource module
  # carried as ROUTE-BOUND params (Mob.Nav.Registry.register/3).
  screens_generator: {MobAsh.Generator, :generate, []},
  host_config_keys: [:ash_domains]
  # Pure Elixir end to end: no nifs / android / ios sections — every screen is
  # hot-pushable, and Ash itself runs on-device in the host BEAM.
}
