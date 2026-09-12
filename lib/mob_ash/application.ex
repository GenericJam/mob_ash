defmodule MobAsh.Application do
  @moduledoc """
  Supervises `MobAsh.Refresh`, the pubsub `Registry` used to route
  post-mutation refresh messages between screens (MOB-56).

  Before this module the plugin had no supervision tree; `FormScreen`
  and `DetailScreen` created / deleted records but never notified
  `ListScreen` to re-read, so the list stayed stale after a pop-back
  until the screen was rebuilt from scratch. `ListScreen` already had a
  `handle_info(:mob_ash_refresh, ...)` clause waiting for a message
  nothing was sending.
  """
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Registry keyed by resource module (an atom); each ListScreen
      # subscribes on mount, each FormScreen / DetailScreen dispatches
      # into it on a successful mutation. `:duplicate` because the same
      # resource may be visible in multiple concurrent screens (e.g.
      # opened twice in a tabbed workflow).
      {Registry, keys: :duplicate, name: MobAsh.Refresh}
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: MobAsh.Supervisor)
  end
end
