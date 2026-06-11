defmodule MobAsh.Generator do
  @moduledoc """
  Spec-v2 screens generator: runs at BUILD time inside the host project (under
  mob_dev's host-config audit) and emits three route entries per Ash resource,
  each pointing at a shared parameterized screen with the resource module as
  route-bound `:params` (delivered to `mount/3` by core navigation).
  """

  @doc "Emits `[%{module, default_route, params}]` for every resource of every configured domain."
  @spec generate() :: [map()]
  def generate do
    # The generator executes inside the HOST app's mix context (mob_dev runs it
    # during `mix mob.regen_plugin_manifest` / the native-build regen hook), so
    # Mix.Project IS the host project — no hardcoded app name (the prototype
    # gen_screens hardcoded its host; a published plugin can't).
    host_app = Mix.Project.config()[:app]

    # apply/3 so this module needn't compile-depend on mob_dev (it isn't a
    # runtime dep of the plugin); the audit enforces :ash_domains is declared
    # in the manifest's :host_config_keys.
    domains = apply(MobDev.Plugin, :host_config, [host_app, :ash_domains, []])

    for domain <- domains, resource <- domain_resources(domain), entry <- entries(resource) do
      entry
    end
  end

  @doc "The three route entries for one resource (pure; public for tests)."
  @spec entries(module()) :: [map()]
  def entries(resource) do
    base = "/ash/#{MobAsh.Info.route_segment(resource)}"
    params = %{resource: resource}

    [
      %{module: MobAsh.ListScreen, default_route: base, params: params},
      %{module: MobAsh.DetailScreen, default_route: base <> "/detail", params: params},
      %{module: MobAsh.FormScreen, default_route: base <> "/new", params: params}
    ]
  end

  defp domain_resources(domain), do: Ash.Domain.Info.resources(domain)
end
