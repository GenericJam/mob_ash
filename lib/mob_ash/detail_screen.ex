defmodule MobAsh.DetailScreen do
  @moduledoc """
  Shared parameterized detail screen: `Ash.get!/2` of the route-bound
  `:resource` by `:id`, one labelled row per display attribute, plus Delete
  (`Ash.destroy!/1` → pop).
  """
  use Mob.Screen

  alias MobAsh.Info

  @impl true
  def mount(%{resource: resource, id: id}, _session, socket) do
    record = Ash.get!(resource, id)

    {:ok,
     socket
     |> Mob.Socket.assign(:resource, resource)
     |> Mob.Socket.assign(:record, record)}
  end

  @impl true
  def render(assigns) do
    title = Info.title(assigns.resource)
    delete_tap = {self(), :delete}
    back_tap = {self(), :back}

    ~MOB"""
    <Scroll background={:background}>
      <Column background={:background} padding={:space_lg}>
        <Text text={title} text_size={:xl} text_color={:on_surface} padding={:space_sm} />
        {field_rows(assigns)}
        <Spacer size={16} />
        <Button text="Delete" background={:error} text_color={:on_primary}
                padding={:space_md} fill_width={true} on_tap={delete_tap} />
        <Spacer size={8} />
        <Button text="Back" background={:surface_raised} text_color={:on_surface}
                padding={:space_md} fill_width={true} on_tap={back_tap} />
      </Column>
    </Scroll>
    """
  end

  @impl true
  def handle_event("delete", _p, socket) do
    :ok = Ash.destroy!(socket.assigns.record)
    # Wake any live ListScreen for this resource so it re-reads before
    # the pop-back paints. See MOB-56.
    MobAsh.Refresh.broadcast(socket.assigns.resource)
    {:noreply, Mob.Socket.pop_screen(socket)}
  end

  @impl true
  def handle_event("back", _p, socket), do: {:noreply, Mob.Socket.pop_screen(socket)}

  defp field_rows(assigns) do
    for field <- Info.display_attributes(assigns.resource) do
      label = field |> to_string() |> String.capitalize()
      value = Info.field_value(assigns.record, field)

      ~MOB"""
      <Column padding={4}>
        <Text text={label} text_size={:sm} text_color={:muted} />
        <Text text={value} text_size={:base} text_color={:on_surface} />
      </Column>
      """
    end
  end
end
