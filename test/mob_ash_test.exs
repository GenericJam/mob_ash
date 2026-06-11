defmodule MobAshTest do
  use ExUnit.Case, async: false

  alias MobAsh.Fixtures.{Blog, Post}
  alias MobDev.Plugin.{Manifest, Validator}

  @plugin_dir Path.expand("..", __DIR__)

  describe "plugin manifest (spec v2)" do
    setup do
      {:ok, manifest} = Manifest.load(@plugin_dir)
      %{manifest: manifest}
    end

    test "loads and validates clean (round-trips)", %{manifest: m} do
      assert {:ok, ^m} = Manifest.validate(m)
    end

    test "passes the full pre-publish validator", %{manifest: m} do
      assert %{errors: []} = Validator.validate_plugin(m, @plugin_dir)
    end

    test "is the spec-v2 generated lane: generator + audited host-config key, no native",
         %{manifest: m} do
      assert m.plugin_spec_version == 2
      assert m.screens_generator == {MobAsh.Generator, :generate, []}
      assert m.host_config_keys == [:ash_domains]
      refute Map.has_key?(m, :nifs)
      refute Map.has_key?(m, :android)
      refute Map.has_key?(m, :ios)
    end
  end

  describe "Generator.entries/1 (the resource→routes mapping)" do
    test "emits list/detail/new routes sharing the parameterized screens" do
      assert [list, detail, form] = MobAsh.Generator.entries(Post)

      assert list == %{
               module: MobAsh.ListScreen,
               default_route: "/ash/post",
               params: %{resource: Post}
             }

      assert detail.default_route == "/ash/post/detail"
      assert detail.module == MobAsh.DetailScreen
      assert form.default_route == "/ash/post/new"
      assert form.module == MobAsh.FormScreen
      assert form.params == %{resource: Post}
    end
  end

  describe "Info (Ash introspection → UI mapping)" do
    test "route_segment + title derive from the resource module name" do
      assert MobAsh.Info.route_segment(Post) == "post"
      assert MobAsh.Info.title(Post) == "Post"
    end

    test "display_attributes lists public attributes, pk last" do
      attrs = MobAsh.Info.display_attributes(Post)
      assert :title in attrs and :body in attrs and :views in attrs
      assert List.last(attrs) == :id
    end

    test "form_attributes excludes the pk and keeps writable scalars" do
      attrs = MobAsh.Info.form_attributes(Post)
      assert :title in attrs and :body in attrs and :views in attrs
      refute :id in attrs
    end

    test "row_label prefers the first non-pk attribute" do
      post = seed!(title: "Hello", body: "world")
      assert MobAsh.Info.row_label(Post, post) == "Hello"
    end
  end

  describe "screens against a live (ETS) Ash resource" do
    test "ListScreen mounts with the records and renders a row per record" do
      seed!(title: "First post")
      seed!(title: "Second post")

      {:ok, socket} =
        MobAsh.ListScreen.mount(%{resource: Post}, %{}, new_socket(MobAsh.ListScreen))

      assert length(socket.assigns.records) == 2

      rendered = MobAsh.ListScreen.render(socket.assigns) |> inspect(limit: :infinity)
      assert rendered =~ "First post"
      assert rendered =~ "Second post"
      assert rendered =~ "New"
    end

    test "DetailScreen mounts the record by id and renders its fields" do
      post = seed!(title: "Readable", body: "the body text", views: 7)

      {:ok, socket} =
        MobAsh.DetailScreen.mount(
          %{resource: Post, id: post.id},
          %{},
          new_socket(MobAsh.DetailScreen)
        )

      rendered = MobAsh.DetailScreen.render(socket.assigns) |> inspect(limit: :infinity)
      assert rendered =~ "Readable"
      assert rendered =~ "the body text"
      assert rendered =~ "7"
      assert rendered =~ "Delete"
    end

    test "FormScreen field-change infos accumulate and Create persists via Ash" do
      {:ok, socket} =
        MobAsh.FormScreen.mount(%{resource: Post}, %{}, new_socket(MobAsh.FormScreen))

      assert socket.assigns.fields == MobAsh.Info.form_attributes(Post)

      {:noreply, socket} =
        MobAsh.FormScreen.handle_info({{:field, :title}, "From the form"}, socket)

      {:noreply, socket} = MobAsh.FormScreen.handle_info({{:field, :body}, "typed"}, socket)
      {:noreply, _socket} = MobAsh.FormScreen.handle_event("create", %{}, socket)

      assert [%{title: "From the form", body: "typed"}] = Ash.read!(Post)
    end

    test "FormScreen surfaces a create error instead of crashing" do
      {:ok, socket} =
        MobAsh.FormScreen.mount(%{resource: Post}, %{}, new_socket(MobAsh.FormScreen))

      # :title is allow_nil?: false — creating with no values must fail.
      {:noreply, socket} = MobAsh.FormScreen.handle_event("create", %{}, socket)
      assert socket.assigns.error =~ "title"
    end

    test "DetailScreen Delete destroys the record" do
      post = seed!(title: "Doomed")

      {:ok, socket} =
        MobAsh.DetailScreen.mount(
          %{resource: Post, id: post.id},
          %{},
          new_socket(MobAsh.DetailScreen)
        )

      {:noreply, _} = MobAsh.DetailScreen.handle_event("delete", %{}, socket)
      assert Ash.read!(Post) == []
    end
  end

  # ── helpers ────────────────────────────────────────────────────────────────

  setup do
    # ETS data layer is global per resource — wipe between tests.
    on_exit(fn -> Post |> Ash.read!() |> Enum.each(&Ash.destroy!/1) end)
    Post |> Ash.read!() |> Enum.each(&Ash.destroy!/1)
    :ok
  end

  defp seed!(attrs) do
    Post |> Ash.Changeset.for_create(:create, Map.new(attrs)) |> Ash.create!()
  end

  defp new_socket(module), do: Mob.Socket.new(module, platform: :android)
end
