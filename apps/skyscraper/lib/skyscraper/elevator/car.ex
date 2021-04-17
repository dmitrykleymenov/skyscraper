defmodule Skyscraper.Elevator.Car do
  alias Skyscraper.Elevator.Car
  @step_duration 1000
  defstruct [:down_query, :up_query, :current_floor, :moving_direction, :step, :step_duration]

  @doc """
    Builds a car struct
  """

  def build(floor: floor) do
    %Car{
      down_query: Prioqueue.new([], cmp_fun: &Prioqueue.Helper.cmp_inverse/2),
      up_query: Prioqueue.new(),
      current_floor: floor,
      moving_direction: nil,
      step: nil,
      step_duration: nil
    }
  end

  @doc """
    Completes current step
  """

  def complete_step(%Car{} = car) do
    car
    |> process
    |> update_step_duration()
  end

  @doc """
    Checks if car is ready to handle new destination requests
  """

  def ready_to_new_destination?(%Car{step: step}), do: step == :doors_closing

  @doc """
    Add new destination point by using inside-cabin interface
  """

  def push_button(%Car{step: nil, current_floor: current_floor} = car, current_floor) do
    car
    |> Map.put(:step, :doors_opening)
    |> update_step_duration()
  end

  def push_button(%Car{step: nil, current_floor: current_floor} = car, floor) do
    if floor > current_floor do
      %{
        car
        | moving_direction: :up,
          step: :moving,
          up_query: Prioqueue.insert(car.up_query, floor)
      }
    else
      %{
        car
        | moving_direction: :down,
          step: :moving,
          down_query: Prioqueue.insert(car.down_query, floor)
      }
    end
    |> update_step_duration()
  end

  def push_button(%Car{step: step, current_floor: current_floor} = car, current_floor)
      when step in ~w(doors_opening doors_opened)a,
      do: car

  def push_button(%Car{current_floor: current_floor, moving_direction: :up} = car, floor) do
    if floor > current_floor do
      Map.put(car, :up_query, Prioqueue.insert(car.up_query, floor))
    else
      Map.put(car, :down_query, Prioqueue.insert(car.down_query, floor))
    end
  end

  def push_button(%Car{current_floor: current_floor, moving_direction: :down} = car, floor) do
    if floor < current_floor do
      Map.put(car, :down_query, Prioqueue.insert(car.down_query, floor))
    else
      Map.put(car, :up_query, Prioqueue.insert(car.up_query, floor))
    end
  end

  defp process(%Car{step: :doors_opening} = car), do: Map.put(car, :step, :doors_opened)
  defp process(%Car{step: :doors_opened} = car), do: Map.put(car, :step, :doors_closing)
  defp process(%Car{step: :doors_closing} = car), do: close_doors(car)
  defp process(%Car{step: :moving} = car), do: move(car)
  defp process(%Car{step: nil}), do: raise("Can't complete idle step")

  defp move(%Car{moving_direction: :up} = car) do
    current_floor = car.current_floor + 1

    case Prioqueue.extract_min!(car.up_query) do
      {^current_floor, up_query} ->
        %{car | current_floor: current_floor, up_query: up_query, step: :doors_opening}

      _ ->
        %{car | current_floor: current_floor}
    end
  end

  defp move(%Car{moving_direction: :down} = car) do
    current_floor = car.current_floor - 1

    case Prioqueue.extract_min!(car.down_query) do
      {^current_floor, down_query} ->
        %{car | current_floor: current_floor, down_query: down_query, step: :doors_opening}

      _ ->
        %{car | current_floor: current_floor}
    end
  end

  defp close_doors(car) do
    case({peek(car.up_query), peek(car.down_query), car.moving_direction}) do
      {nil, nil, _} -> %{car | moving_direction: nil, step: nil}
      {nil, _, :up} -> %{car | moving_direction: :down, step: :moving}
      {_, nil, :down} -> %{car | moving_direction: :up, step: :moving}
      _ -> %{car | step: :moving}
    end
  end

  defp peek(queue) do
    case Prioqueue.peek_min(queue) do
      {:error, :empty} -> nil
      {:ok, value} -> value
    end
  end

  defp update_step_duration(car) do
    Map.put(car, :step_duration, step_duration(car.step))
  end

  defp step_duration(_step) do
    @step_duration
  end
end
