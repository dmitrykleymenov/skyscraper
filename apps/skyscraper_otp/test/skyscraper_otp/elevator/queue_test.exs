defmodule SkyscraperOtp.Elevator.QueueTest do
  alias SkyscraperOtp.Elevator.Queue
  use ExUnit.Case, async: true

  test "builds empty queue" do
    assert Queue.build() |> Queue.list() == []
  end

  test "returns list of all queued destinations" do
    result =
      %Queue{up_queue: Prioqueue.new([1, 2, 3]), down_queue: Prioqueue.new([5, 6, 7])}
      |> Queue.list()

    assert result |> Enum.sort() == [1, 2, 3, 5, 6, 7]
  end

  describe ".push/2" do
    setup do
      %{queue: %Queue{up_queue: Prioqueue.new([1, 2, 3]), down_queue: Prioqueue.new([5, 6, 7])}}
    end

    test "ignores when destination is nil", %{queue: queue} do
      assert queue == queue |> Queue.push(nil)
    end

    test "ignores when destination is in up queue", %{queue: queue} do
      assert queue == queue |> Queue.push({2, :up})
    end

    test "ignores when destination is in down queue", %{queue: queue} do
      assert queue == queue |> Queue.push({6, :down})
    end

    test "puts new destination floor into down queue when destination choice is descending", %{
      queue: queue
    } do
      queue = queue |> Queue.push({8, :down})
      assert queue.down_queue |> Prioqueue.to_list() == [5, 6, 7, 8]
    end

    test "puts new destination floor into up queue when destination choice is ascending", %{
      queue: queue
    } do
      queue = queue |> Queue.push({8, :up})
      assert queue.up_queue |> Prioqueue.to_list() == [1, 2, 3, 8]
    end
  end

  describe ".pop/2" do
    setup do
      %{queue: %Queue{up_queue: Prioqueue.new([1, 2, 3]), down_queue: Prioqueue.new([5, 6, 7])}}
    end

    test "returns nil when query is empty" do
      {dest, queue} = Queue.build() |> Queue.pop(:up)
      assert dest |> is_nil()
      assert queue |> Queue.list() |> Enum.empty?()
    end

    test "pops first destination from up query when ascending request", %{queue: queue} do
      {dest, queue} = queue |> Queue.pop(:up)
      assert dest == {1, :up}
      assert queue |> Queue.list() |> Enum.sort() == [2, 3, 5, 6, 7]
    end

    test "pops first destination from down query when descending request", %{queue: queue} do
      {dest, queue} = queue |> Queue.pop(:down)
      assert dest == {5, :down}
      assert queue |> Queue.list() |> Enum.sort() == [1, 2, 3, 6, 7]
    end

    test "pops first destination from down query when ascending request and up queue is empty", %{
      queue: queue
    } do
      {dest, queue} = queue |> Map.put(:up_queue, Prioqueue.new()) |> Queue.pop(:up)
      assert dest == {5, :down}
      assert queue |> Queue.list() |> Enum.sort() == [6, 7]
    end

    test "pops first destination from up query when descending request and down queue is empty",
         %{
           queue: queue
         } do
      {dest, queue} = queue |> Map.put(:down_queue, Prioqueue.new()) |> Queue.pop(:down)
      assert dest == {1, :up}
      assert queue |> Queue.list() |> Enum.sort() == [2, 3]
    end
  end
end
