defmodule MobAsh do
  @moduledoc """
  Resource-driven Mob screens from Ash.

  Declare Ash resources in your host app, register the domains, and mob_ash
  generates a list / detail / create screen set per resource — Ash runs
  on-device in the host BEAM (use a device-friendly data layer such as
  `Ash.DataLayer.Ets` or AshSqlite over the bundled SQLite).

  ## Host setup

      # mix.exs
      {:mob_ash, "~> 0.1"}

      # mob.exs
      config :mob, :plugins, [:mob_ash]

      # config/config.exs
      config :my_app, :ash_domains, [MyApp.Blog]

  The build's screens generator (spec v2) introspects each domain's resources
  and emits routes:

      /ash/post          MobAsh.ListScreen   (params: %{resource: MyApp.Blog.Post})
      /ash/post/detail   MobAsh.DetailScreen
      /ash/post/new      MobAsh.FormScreen

  All three are SHARED parameterized screens — the resource module rides the
  route as route-bound params (`Mob.Nav.Registry.register/3`), so
  `push_screen(socket, :"/ash/post")` works with no extra arguments, and
  `MobAsh.navigate/3` works without routes at all.

  ## Navigating programmatically

      MobAsh.navigate(socket, MyApp.Blog.Post, :list)
      MobAsh.navigate(socket, MyApp.Blog.Post, :new)
  """

  @doc """
  Push the mob_ash screen for `resource`: `:list`, `:detail` (needs `id:` in
  `params`), or `:new`.
  """
  @spec navigate(Mob.Socket.t(), module(), :list | :detail | :new, map()) :: Mob.Socket.t()
  def navigate(socket, resource, action, params \\ %{}) do
    screen =
      case action do
        :list -> MobAsh.ListScreen
        :detail -> MobAsh.DetailScreen
        :new -> MobAsh.FormScreen
      end

    Mob.Socket.push_screen(socket, screen, Map.put(params, :resource, resource))
  end
end
