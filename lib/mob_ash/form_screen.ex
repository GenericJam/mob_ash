defmodule MobAsh.FormScreen do
  @moduledoc """
  Shared parameterized create form: one `<TextField>` per writable scalar
  attribute of the route-bound `:resource`; Create runs the resource's
  primary create action via `Ash.create!/1` and pops back.
  """
  use Mob.Screen

  alias MobAsh.Info

  @impl true
  def mount(%{resource: resource}, _session, socket) do
    {:ok,
     socket
     |> Mob.Socket.assign(:resource, resource)
     |> Mob.Socket.assign(:fields, Info.form_attributes(resource))
     |> Mob.Socket.assign(:values, %{})
     |> Mob.Socket.assign(:error, nil)}
  end

  @impl true
  def render(assigns) do
    title = "New #{Info.title(assigns.resource)}"
    create_tap = {self(), :create}

    ~MOB"""
    <Scroll background={:background}>
      <Column background={:background} padding={:space_lg}>
        <Text text={title} text_size={:xl} text_color={:on_surface} padding={:space_sm} />
        {field_inputs(assigns)}
        {error_row(assigns)}
        <Spacer size={16} />
        <Button text="Create" background={:primary} text_color={:on_primary}
                padding={:space_md} fill_width={true} on_tap={create_tap} />
      </Column>
    </Scroll>
    """
  end

  @impl true
  def handle_event("create", _p, socket) do
    %{resource: resource, values: values} = socket.assigns

    case resource |> Ash.Changeset.for_create(:create, values) |> Ash.create() do
      {:ok, _record} ->
        {:noreply, Mob.Socket.pop_screen(socket)}

      {:error, err} ->
        {:noreply, Mob.Socket.assign(socket, :error, Exception.message(err))}
    end
  end

  # TextField changes arrive as {tag, value} infos; tags are {:field, name}.
  @impl true
  def handle_info({{:field, name}, value}, socket) do
    {:noreply, Mob.Socket.assign(socket, :values, Map.put(socket.assigns.values, name, value))}
  end

  defp field_inputs(assigns) do
    for field <- assigns.fields do
      label = field |> to_string() |> String.capitalize()
      change = {self(), {:field, field}}
      value = Map.get(assigns.values, field, "")

      ~MOB"""
      <Column padding={4}>
        <Text text={label} text_size={:sm} text_color={:muted} />
        <TextField value={value} on_change={change} />
      </Column>
      """
    end
  end

  defp error_row(assigns) do
    if assigns.error do
      ~MOB"""
      <Text text={assigns.error} text_size={:sm} text_color={:error} padding={4} />
      """
    end
  end
end
