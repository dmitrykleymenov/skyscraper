defmodule Skyscraper.Elevator.QueueTest do
  alias Skyscraper.Elevator.Queue
  use ExUnit.Case, async: true

  test "returns list of all queued destinations" do
    result =
      %Queue{up_queue: Prioqueue.new([5, 6, 7]), down_queue: Prioqueue.new([1, 2, 3])}
      |> Queue.list()

    assert result |> Enum.sort() == [1, 2, 3, 5, 6, 7]
  end

  describe ".push/2" do
    setup do
      %{queue: %Queue{up_queue: Prioqueue.new([5, 6, 7]), down_queue: Prioqueue.new([1, 2, 3])}}
    end

    test "ignores when destination is nil", %{queue: queue} do
      assert queue == queue |> Queue.push(nil)
    end

    test "ignores when destination is in up queue", %{queue: queue} do
      assert queue == queue |> Queue.push({7, :up})
    end

    test "ignores when destination is in down queue", %{queue: queue} do
      assert queue == queue |> Queue.push({2, :down})
    end

    test "puts new destination floor into down queue when destination choice is descending", %{
      queue: queue
    } do
      queue = queue |> Queue.push({8, :down})
      assert queue.down_queue |> Prioqueue.to_list() == [1, 2, 3, 8]
    end

    test "puts new destination floor into up queue when destination choice is ascending", %{
      queue: queue
    } do
      queue = queue |> Queue.push({8, :up})
      assert queue.up_queue |> Prioqueue.to_list() == [5, 6, 7, 8]
    end
  end

  describe ".pop/2" do
    setup do
      %{queue: %Queue{up_queue: Prioqueue.new([5, 6, 7]), down_queue: Prioqueue.new([1, 2, 3])}}
    end

    test "ignores when destination is nil", %{queue: queue} do
      assert queue == queue |> Queue.push(nil)
    end

    test "ignores when destination is in up queue", %{queue: queue} do
      assert queue == queue |> Queue.push({7, :up})
    end

    test "ignores when destination is in down queue", %{queue: queue} do
      assert queue == queue |> Queue.push({2, :down})
    end

    test "puts new destination floor into down queue when destination choice is descending", %{
      queue: queue
    } do
      queue = queue |> Queue.push({8, :down})
      assert queue.down_queue |> Prioqueue.to_list() == [1, 2, 3, 8]
    end

    test "puts new destination floor into up queue when destination choice is ascending", %{
      queue: queue
    } do
      queue = queue |> Queue.push({8, :up})
      assert queue.up_queue |> Prioqueue.to_list() == [5, 6, 7, 8]
    end
  end
end
