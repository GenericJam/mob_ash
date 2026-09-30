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

  Idempotent: the Registry uses `keys: :duplicate`, so this checks the
  caller's existing keys and registers only once per resource.
  `ListScreen.load/2` calls it on mount and on every refresh, so without
  the check each broadcast would double the caller's registrations
  (MOB-296). Entries are dropped when the subscribing process exits.
  """
  @spec subscribe(module()) :: :ok
  def subscribe(resource) when is_atom(resource) do
    if resource in Registry.keys(@registry, self()) do
      :ok
    else
      {:ok, _owner} = Registry.register(@registry, resource, nil)
      :ok
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
