defmodule MobAsh.SelfTest.Note do
  @moduledoc false
  # The resource `MobAsh.SelfTest` drives on the device: the shape a host's
  # resource has (uuid key, a required string, an integer with a default), on
  # a PRIVATE ETS table, so its rows live only in the self-test's own process
  # and vanish with it.
  use Ash.Resource,
    domain: MobAsh.SelfTest.Domain,
    data_layer: Ash.DataLayer.Ets

  ets do
    private?(true)
  end

  attributes do
    uuid_primary_key(:id)
    attribute(:title, :string, public?: true, allow_nil?: false)
    attribute(:count, :integer, public?: true, default: 0)
  end

  actions do
    defaults([:read, :destroy, create: :*])
  end
end

defmodule MobAsh.SelfTest.Domain do
  @moduledoc false
  # Not in any host's `:ash_domains`: the generator never makes screens for
  # it, so opt out of Ash's config-inclusion check.
  use Ash.Domain, validate_config_inclusion?: false

  resources do
    resource(MobAsh.SelfTest.Note)
  end
end
