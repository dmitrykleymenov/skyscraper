defmodule Skyscraper.Elevator.Queue do
  alias Skyscraper.Elevator.Queue
  defstruct [:down_queue, :up_queue]

  @doc """
    builds a queue struct with defaults
  """

  def build() do
    %Queue{
      down_queue: Prioqueue.empty(cmp_fun: &Prioqueue.Helper.cmp_inverse/2),
      up_queue: Prioqueue.empty()
    }
  end

  @doc """
    Pushes a destination to queue dependend of direction
  """

  def push(%Queue{up_queue: up_queue} = queue, {floor, :up}) do
    if up_queue |> Prioqueue.member?(floor) do
      queue
    else
      queue |> Map.put(:up_queue, Prioqueue.insert(up_queue, floor))
    end
  end

  def push(%Queue{down_queue: down_queue} = queue, {floor, :down}) do
    if down_queue |> Prioqueue.member?(floor) do
      queue
    else
      queue |> Map.put(:down_queue, Prioqueue.insert(down_queue, floor))
    end
  end

  @doc """
    Returns next destination and the rest queue
  """

  def pop(queue, :up) do
    case {Prioqueue.empty?(queue.up_queue), Prioqueue.empty?(queue.down_queue)} do
      {false, _} ->
        {:ok, {value, prioqueue}} = Prioqueue.extract_min(queue.up_queue)
        {{value, :up}, queue |> Map.put(:up_queue, prioqueue)}

      {true, false} ->
        queue |> pop(:down)

      {true, true} ->
        {nil, queue}
    end
  end

  def pop(queue, :down) do
    case {Prioqueue.empty?(queue.down_queue), Prioqueue.empty?(queue.up_queue)} do
      {false, _} ->
        {:ok, {value, prioqueue}} = Prioqueue.extract_min(queue.down_queue)
        {{value, :down}, queue |> Map.put(:down_queue, prioqueue)}

      {true, false} ->
        queue |> pop(:up)

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
end
