defmodule MobAsh.RefreshTest do
  # async: false — the underlying Registry is a process-global resource
  # started by MobAsh.Application, and this test group registers pids
  # against it. Concurrency would race distinct tests using the same
  # resource key.
  use ExUnit.Case, async: false

  # A stand-in resource-module atom. MobAsh.Refresh treats the key as
  # opaque — no need to declare an actual Ash resource just to test
  # the pubsub layer.
  defmodule DummyResource, do: nil

  describe "subscribe/1 + broadcast/1 (MOB-56)" do
    test "a subscribed process receives :mob_ash_refresh on broadcast" do
      # Before MOB-56 this whole event never landed — FormScreen /
      # DetailScreen mutated but never notified. Revert-verify: comment
      # out `MobAsh.Refresh.broadcast(resource)` in the tests below (or
      # delete `subscribe/1`) and the receive block times out.
      :ok = MobAsh.Refresh.subscribe(DummyResource)
      :ok = MobAsh.Refresh.broadcast(DummyResource)

      assert_receive :mob_ash_refresh, 100
    end

    test "multiple subscribers each receive the broadcast" do
      parent = self()

      pids =
        for _ <- 1..3 do
          spawn_link(fn ->
            :ok = MobAsh.Refresh.subscribe(DummyResource)
            send(parent, {:ready, self()})

            receive do
              :mob_ash_refresh -> send(parent, {:got, self()})
            after
              200 -> send(parent, {:timeout, self()})
            end
          end)
        end

      for pid <- pids, do: assert_receive({:ready, ^pid})

      :ok = MobAsh.Refresh.broadcast(DummyResource)

      for pid <- pids, do: assert_receive({:got, ^pid}, 200)
    end

    test "a broadcast for a resource with no subscribers is a no-op (not an error)" do
      # Cleanest signal for the FormScreen path when nothing is listening:
      # the create succeeds, dispatch runs against zero entries, no crash.
      assert :ok = MobAsh.Refresh.broadcast(SomeUnknownResource)
    end

    test "a dead subscriber does not receive the broadcast (auto-cleanup)" do
      # Registry drops entries when the pid dies. FormScreen creates a
      # record, ListScreen has been popped and gone — the broadcast must
      # not try to send to a dead pid (which would silently succeed but
      # signals a book-keeping bug).
      pid =
        spawn(fn ->
          :ok = MobAsh.Refresh.subscribe(DummyResource)
          Process.sleep(50)
        end)

      # Wait for the subscription to register + the pid to die.
      Process.sleep(100)
      refute Process.alive?(pid)

      # Broadcast should still be :ok with no crash.
      assert :ok = MobAsh.Refresh.broadcast(DummyResource)
    end
  end
end
