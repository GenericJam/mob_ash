defmodule MobAsh.SelfTest do
  @moduledoc """
  The plugin's on-device proof (`Mob.Plugin.SelfTest`), run by
  `mix mob.selftest` and mob_ci for every activated plugin.

  mob_ash is pure Elixir, so the proof is its real API path running in the
  device's BEAM against a resource it ships for the purpose
  (`MobAsh.SelfTest.Note`, a private ETS table owned by the test process):

    1. `MobAsh.Refresh.subscribe/1`, which needs the `MobAsh.Refresh`
       registry the plugin's application starts. Not running: fail.
    2. The create `MobAsh.FormScreen` runs: `Ash.Changeset.for_create/3`
       with the resource's primary `:create` action, then `Ash.create/1`.
    3. `MobAsh.Refresh.broadcast/1`, as `FormScreen` does after a create;
       the subscription must deliver `:mob_ash_refresh` within 1 s.
    4. `Ash.read/1` (what `MobAsh.ListScreen` lists) must return exactly
       the created record, and `MobAsh.Info.row_label/2` must label it with
       its title; `Ash.get/2` (what `MobAsh.DetailScreen` shows) must find
       it by id.
    5. `Ash.destroy/1`, then `Ash.read/1` must be empty.

  It does not touch the host's own `:ash_domains` resources: their data
  layer and data are the host's, and the test leaves the device as it found
  it.
  """
  @behaviour Mob.Plugin.SelfTest

  alias MobAsh.{Info, Refresh}

  @title "mob_ash self-test"
  @refresh_timeout 1_000

  @impl true
  def run(_ctx), do: exercise(MobAsh.SelfTest.Note, %{title: @title})

  @doc false
  # The proof for any resource with a :title attribute; public so the unit
  # tests can drive the failure branches with input that breaks.
  @spec exercise(module(), map()) :: Mob.Plugin.SelfTest.result()
  def exercise(resource, attrs) do
    with :ok <- subscribe(resource),
         {:ok, record} <- create(resource, attrs),
         :ok <- refresh(resource),
         :ok <- read_back(resource, record),
         :ok <- get_back(resource, record) do
      destroy(resource, record)
    end
  end

  defp subscribe(resource) do
    if Process.whereis(Refresh) do
      Refresh.subscribe(resource)
    else
      {:fail,
       "the MobAsh.Refresh registry is not running: " <>
         "the mob_ash application (MobAsh.Application) was not started"}
    end
  end

  defp create(resource, attrs) do
    case resource |> Ash.Changeset.for_create(:create, attrs) |> Ash.create() do
      {:ok, record} ->
        {:ok, record}

      {:error, error} ->
        {:fail, "Ash.create/1 on #{inspect(resource)} failed: #{Exception.message(error)}"}
    end
  end

  defp refresh(resource) do
    Refresh.broadcast(resource)

    receive do
      :mob_ash_refresh -> :ok
    after
      @refresh_timeout ->
        {:fail,
         "MobAsh.Refresh.broadcast/1 delivered no :mob_ash_refresh to a subscriber " <>
           "within #{@refresh_timeout} ms"}
    end
  end

  defp read_back(resource, %{id: id} = record) do
    case Ash.read(resource) do
      {:ok, [%{id: ^id} = read]} ->
        label = Info.row_label(resource, read)

        if label == Map.get(record, :title),
          do: :ok,
          else: {:fail, "MobAsh.Info.row_label/2 labelled the record #{inspect(label)}"}

      {:ok, records} ->
        {:fail, "Ash.read/1 returned #{length(records)} records, expected the one just created"}

      {:error, error} ->
        {:fail, "Ash.read/1 on #{inspect(resource)} failed: #{Exception.message(error)}"}
    end
  end

  defp get_back(resource, %{id: id}) do
    case Ash.get(resource, id) do
      {:ok, %{id: ^id}} -> :ok
      {:error, error} -> {:fail, "Ash.get/2 by id failed: #{Exception.message(error)}"}
    end
  end

  defp destroy(resource, record) do
    with :ok <- Ash.destroy(record),
         {:ok, []} <- Ash.read(resource) do
      :pass
    else
      {:ok, left} -> {:fail, "Ash.read/1 after Ash.destroy/1 still returned #{length(left)}"}
      {:error, error} -> {:fail, "Ash.destroy/1 failed: #{Exception.message(error)}"}
    end
  end
end
