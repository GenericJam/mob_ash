defmodule MobAsh.Fixtures.Post do
  @moduledoc "Test resource: the shape a host app's Ash resource would have."
  use Ash.Resource,
    domain: MobAsh.Fixtures.Blog,
    data_layer: Ash.DataLayer.Ets

  attributes do
    uuid_primary_key(:id)
    attribute(:title, :string, public?: true, allow_nil?: false)
    attribute(:body, :string, public?: true)
    attribute(:views, :integer, public?: true, default: 0)
  end

  actions do
    defaults([:read, :destroy, create: :*, update: :*])
  end
end

defmodule MobAsh.Fixtures.Blog do
  @moduledoc "Test domain registering the fixture resource."
  # Test-only fixture domain — intentionally not in any `:ash_domains` config, so
  # opt out of Ash's config-inclusion check (else it warns, and CI compiles the
  # test env with --warnings-as-errors).
  use Ash.Domain, validate_config_inclusion?: false

  resources do
    resource(MobAsh.Fixtures.Post)
  end
end
