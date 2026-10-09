defmodule MobAsh.SelfTest do
  @moduledoc """
  The plugin's on-device proof (`Mob.Plugin.SelfTest`), run by
  `mix mob.selftest` and mob_ci for every activated plugin.

  mob_ash is pure Elixir, so the proof is its three shared screens driven
  through their real callbacks in the device's BEAM (no rendering on the
  phone's display), against a resource the plugin ships for the purpose
  (`MobAsh.SelfTest.Note`, a private ETS table owned by the test process):

    1. `MobAsh.Refresh`, the registry the plugin's application starts, must
       be running; without it `ListScreen` crashes on mount and the form
       and detail screens crash when they broadcast.
    2. `MobAsh.ListScreen.mount/3` subscribes to refreshes and lists no
       records.
    3. `MobAsh.FormScreen`: `mount/3`, a title typed through its
       `{:field, :title}` info, then the Create event. It must not report an
       error, and its own `MobAsh.Refresh.broadcast/1` must reach the list's
       subscription as `:mob_ash_refresh` within 1 s.
    4. `MobAsh.ListScreen.handle_info(:mob_ash_refresh, _)` re-reads: exactly
       the created record, and `render/1` must show it as a row labelled by
       `MobAsh.Info.row_label/2`.
    5. `MobAsh.DetailScreen`: `mount/3` by id must load the record, then the
       Delete event; its broadcast must reach the list again, and the list
       re-reads empty.

  A screen that raises (its bang calls) is reported by the runner as a
  failure with the exception. It never touches the host's own
  `:ash_domains` resources, and the private table dies with the test
  process.
  """
  @behaviour Mob.Plugin.SelfTest

  alias MobAsh.{DetailScreen, FormScreen, Info, ListScreen}

  @title "mob_ash self-test"
  @refresh_timeout 1_000

  @impl true
  def run(%{platform: platform}), do: exercise(MobAsh.SelfTest.Note, @title, platform)

  @doc false
  # The proof for any resource with a :title form field; public so the unit
  # tests can drive the failure branches with a resource or input that breaks.
  @spec exercise(module(), String.t() | nil, :ios | :android) :: Mob.Plugin.SelfTest.result()
  def exercise(resource, title, platform) do
    with :ok <- registry(),
         {:ok, list} <- mount_list(resource, platform),
         :ok <- create(resource, title, platform),
         :ok <- refreshed("FormScreen's create"),
         {:ok, list, record} <- listed_once(list, title),
         :ok <- delete(resource, record, platform),
         :ok <- refreshed("DetailScreen's delete") do
      listed_none(list)
    end
  end

  defp registry do
    if Process.whereis(MobAsh.Refresh) do
      :ok
    else
      {:fail,
       "the MobAsh.Refresh registry is not running: " <>
         "the mob_ash application (MobAsh.Application) was not started"}
    end
  end

  defp mount_list(resource, platform) do
    {:ok, list} = ListScreen.mount(%{resource: resource}, %{}, socket(ListScreen, platform))

    case list.assigns.records do
      [] -> {:ok, list}
      records -> {:fail, "ListScreen mounted with #{length(records)} records, expected none"}
    end
  end

  defp create(resource, title, platform) do
    {:ok, form} = FormScreen.mount(%{resource: resource}, %{}, socket(FormScreen, platform))
    {:noreply, form} = FormScreen.handle_info({{:field, :title}, title}, form)
    {:noreply, form} = FormScreen.handle_event("create", %{}, form)

    case form.assigns.error do
      nil -> :ok
      error -> {:fail, "FormScreen's Create on #{inspect(resource)} reported: #{error}"}
    end
  end

  defp refreshed(what) do
    receive do
      :mob_ash_refresh -> :ok
    after
      @refresh_timeout ->
        {:fail,
         "#{what} sent no :mob_ash_refresh to the ListScreen subscription " <>
           "within #{@refresh_timeout} ms"}
    end
  end

  defp listed_once(list, title) do
    {:noreply, list} = ListScreen.handle_info(:mob_ash_refresh, list)
    resource = list.assigns.resource

    case list.assigns.records do
      [%{title: ^title} = record] ->
        label = Info.row_label(resource, record)

        if label in button_texts(ListScreen.render(list.assigns)),
          do: {:ok, list, record},
          else: {:fail, "ListScreen.render/1 shows no row labelled #{inspect(label)}"}

      records ->
        {:fail,
         "after the create ListScreen listed #{length(records)} records, " <>
           "expected the one titled #{inspect(title)}"}
    end
  end

  defp delete(resource, record, platform) do
    {:ok, detail} =
      DetailScreen.mount(
        %{resource: resource, id: record.id},
        %{},
        socket(DetailScreen, platform)
      )

    if detail.assigns.record.id == record.id do
      {:noreply, _detail} = DetailScreen.handle_event("delete", %{}, detail)
      :ok
    else
      {:fail, "DetailScreen mounted #{inspect(detail.assigns.record.id)}, expected #{record.id}"}
    end
  end

  defp listed_none(list) do
    {:noreply, list} = ListScreen.handle_info(:mob_ash_refresh, list)

    case list.assigns.records do
      [] -> :pass
      left -> {:fail, "after DetailScreen's delete ListScreen still listed #{length(left)}"}
    end
  end

  defp socket(screen, platform), do: Mob.Socket.new(screen, platform: platform)

  defp button_texts(nodes) when is_list(nodes), do: Enum.flat_map(nodes, &button_texts/1)

  defp button_texts(%{} = node) do
    own = if node[:type] == :button, do: [get_in(node, [:props, :text])], else: []
    own ++ button_texts(Map.get(node, :children, []))
  end

  defp button_texts(_other), do: []
end
