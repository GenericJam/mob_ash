defmodule MobAsh.Refresh do
  @moduledoc """
  Per-resource pubsub for `:mob_ash_refresh` messages. Screens showing a
  list of records subscribe; screens that mutate records dispatch. The
  underlying `Registry` is started by `MobAsh.Application`.

  See MOB-56 — before this module the `ListScreen`'s
  `handle_info(:mob_ash_refresh, ...)` clause existed but nothing ever
  sent it, so lists stayed stale after a create/delete pop-back.
  """

  @registry MobAsh.Refresh

  @doc """
  Subscribe the calling process to refresh events for `resource`.
  Pids auto-unregister when they die, so `ListScreen`s don't need to
  clean up explicitly. Safe to call multiple times — a duplicate
  registration is a no-op at the Registry level.
  """
  @spec subscribe(module()) :: :ok
  def subscribe(resource) when is_atom(resource) do
    case Registry.register(@registry, resource, nil) do
      {:ok, _pid} -> :ok
      {:error, {:already_registered, _pid}} -> :ok
    end
  end

  @doc """
  Send `:mob_ash_refresh` to every process subscribed to `resource`.
  """
  @spec broadcast(module()) :: :ok
  def broadcast(resource) when is_atom(resource) do
    Registry.dispatch(@registry, resource, fn entries ->
      for {pid, _value} <- entries, do: send(pid, :mob_ash_refresh)
    end)

    :ok
  end
end
