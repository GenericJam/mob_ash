defmodule MobAsh.ListScreen do
  @moduledoc """
  Shared parameterized list screen: reads every record of the route-bound
  `:resource` via `Ash.read!/1` and renders one tappable row per record
  (tap → detail). The `:resource` arrives in `mount/3` params either from the
  generated route (route-bound params) or `MobAsh.navigate/3`.
  """
  use Mob.Screen

  alias MobAsh.Info

  @impl true
  def mount(%{resource: resource}, _session, socket) do
    {:ok, load(socket, resource)}
  end

  @impl true
  def render(assigns) do
    title = Info.title(assigns.resource)
    new_tap = {self(), :new}

    ~MOB"""
    <Scroll background={:background}>
      <Column background={:background} padding={:space_lg}>
        <Text text={title} text_size={:xl} text_color={:on_surface} padding={:space_sm} />
        <Button text="New" background={:primary} text_color={:on_primary}
                padding={:space_md} fill_width={true} on_tap={new_tap} />
        <Spacer size={12} />
        {rows(assigns)}
      </Column>
    </Scroll>
    """
  end

  @impl true
  def handle_event("new", _p, socket) do
    {:noreply, MobAsh.navigate(socket, socket.assigns.resource, :new)}
  end

  @impl true
  def handle_event("row_" <> id, _p, socket) do
    {:noreply, MobAsh.navigate(socket, socket.assigns.resource, :detail, %{id: id})}
  end

  # Re-read when a child form/detail pops back with a mutation behind it.
  @impl true
  def handle_info(:mob_ash_refresh, socket) do
    {:noreply, load(socket, socket.assigns.resource)}
  end

  defp load(socket, resource) do
    # Subscribe to :mob_ash_refresh broadcasts for this resource. Idempotent
    # per pid, so re-entry on a manual reload doesn't stack registrations.
    # See MOB-56.
    :ok = MobAsh.Refresh.subscribe(resource)

    socket
    |> Mob.Socket.assign(:resource, resource)
    |> Mob.Socket.assign(:records, Ash.read!(resource))
  end

  defp rows(assigns) do
    for record <- assigns.records do
      label = Info.row_label(assigns.resource, record)
      tap = {self(), :"row_#{primary_key_value(assigns.resource, record)}"}

      ~MOB"""
      <Column>
        <Button text={label} background={:surface_raised} text_color={:on_surface}
                padding={:space_md} fill_width={true} on_tap={tap} />
        <Spacer size={8} />
      </Column>
      """
    end
  end

  defp primary_key_value(resource, record) do
    [pk | _] = Ash.Resource.Info.primary_key(resource)
    Map.get(record, pk)
  end
end
