defmodule Skyscraper.Elevator.Queue do
  alias Skyscraper.Elevator.Queue
  defstruct [:down_queue, :up_queue, :moving_direction]

  @doc """
    builds a queue struct with defaults
  """

  def build(direction \\ :up) do
    %Queue{
      moving_direction: direction,
      down_queue: Prioqueue.empty(cmp_fun: &Prioqueue.Helper.cmp_inverse/2),
      up_queue: Prioqueue.empty()
    }
  end

  @doc """
    Pushes a destination to queue dependend of direction
  """

  def push(%Queue{up_queue: up_queue} = queue, {floor, :up}) do
    queue
    |> Map.put(:up_queue, Prioqueue.insert(up_queue, floor))
  end

  def push(%Queue{down_queue: down_queue} = queue, {floor, :down}) do
    queue
    |> Map.put(:down_queue, Prioqueue.insert(down_queue, floor))
  end

  @doc """
    Sets new moving direction
  """
  def set_moving_direction(%Queue{} = queue, moving_direction) do
    queue
    |> Map.put(:moving_direction, moving_direction)
  end

  @doc """
    Returns next destination and the rest queue
  """
  def pop(queue) do
    queues = direction_queues(queue)

    case {Prioqueue.empty?(queues.forward.queue), Prioqueue.empty?(queues.backward.queue)} do
      {false, _} ->
        {value, prioqueue} = extract(queues.forward.queue)
        {{value, queues.forward.direction}, queue |> Map.put(queues.forward.name, prioqueue)}

      {true, false} ->
        queue |> reverse_moving_direction() |> pop()

      {true, true} ->
        {nil, queue}
    end
  end

  @doc """
    returns all requests in queue
  """
  def list(%Queue{down_queue: down_queue, up_queue: up_queue}) do
    Prioqueue.to_list(down_queue) ++ Prioqueue.to_list(up_queue)
  end

  defp extract(prioqueue) do
    case prioqueue |> Prioqueue.extract_min() do
      {:error, :empty} -> {nil, prioqueue}
      {:ok, result} -> result
    end
  end

  defp reverse_moving_direction(%Queue{moving_direction: :down} = queue) do
    queue |> set_moving_direction(:up)
  end

  defp reverse_moving_direction(%Queue{moving_direction: :up} = queue) do
    queue |> set_moving_direction(:down)
  end

  defp direction_queues(%Queue{moving_direction: :up} = queue) do
    %{
      forward: %{queue: queue.up_queue, name: :up_queue, direction: :up},
      backward: %{queue: queue.down_queue, name: :down_queue, direction: :down}
    }
  end

  defp direction_queues(%Queue{moving_direction: :down} = queue) do
    %{
      forward: %{queue: queue.down_queue, name: :down_queue, direction: :down},
      backward: %{queue: queue.up_queue, name: :up_queue, direction: :up}
    }
  end
end
