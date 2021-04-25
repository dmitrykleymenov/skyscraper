defmodule Skyscraper.Elevator.Car do
  alias Skyscraper.Elevator.{Car, Queue}
  @step_duration 1000

  defstruct [
    :current_floor,
    :destination,
    :queue,
    :step,
    :step_duration,
    :new_destination_callback,
    :processing_callback
  ]

  defguardp is_open_doors(step) when step in ~w(opening_doors doors_open)a

  @doc """
    Builds a car struct
  """

  def build(opts) do
    car = %Car{
      queue: Queue.build(Keyword.get(opts, :direction)),
      current_floor: Keyword.get(opts, :floor),
      destination: nil,
      new_destination_callback: Keyword.get(opts, :new_destination_callback),
      processing_callback: Keyword.get(opts, :processing_callback)
    }

    Keyword.get(opts, :destinations, [])
    |> Enum.reduce(car, &accept_destination(&2, &1))
    |> set_step(Keyword.get(opts, :step, :idling))
  end

  @doc """
    Completes current step
  """

  def complete_step(%Car{} = car) do
    car |> process()
  end

  @doc """
    Add a new destination floor by using inside-cabin interface
  """

  def push_button(%Car{} = car, floor) do
    accept_destination({car.step, car.destination, car.current_floor, floor}, car)
  end

  @doc """
    Returns current step duration
  """

  def step_duration(%Car{step_duration: step_duration}), do: step_duration

  defp accept_destination({:idling, _dest, curr, curr}, car) do
    car
    |> set_step(:opening_doors)
    |> run_new_destination_callback()
  end

  defp accept_destination({:idling, _dest, curr, floor}, car) do
    direction = if floor > curr, do: :up, else: :down

    car
    |> Map.put(:destination, {floor, direction})
    |> set_moving_direction(direction)
    |> set_step(:moving)
    |> run_new_destination_callback()
  end

  defp accept_destination({_step, {dest, _moving_choice}, _curr, dest}, car), do: car

  defp accept_destination({step, _dest, curr, curr}, car) when is_open_doors(step), do: car

  defp accept_destination({_step, nil, _curr, floor}, car) do
    car
    |> Map.put(:destination, floor)
    |> run_new_destination_callback()
  end

  defp accept_destination({_step, {dest, _moving_choice}, floor, floor}, car) do
    rel = if floor > dest, do: :up, else: :down

    car
    |> Map.put(:queue, Queue.push(car.queue, {floor, rel}))
  end

  defp accept_destination({_step, {dest, moving_choice}, curr, floor}, car)
       when floor in curr..dest do
    rel = if floor > dest, do: :down, else: :up

    car
    |> Map.put(:queue, Queue.push(car.queue, {dest, moving_choice}))
    |> Map.put(:destination, {floor, rel})
    |> run_new_destination_callback()
  end

  defp accept_destination({_step, {dest, _moving_choice}, _curr, floor}, car) do
    rel = if floor > dest, do: :up, else: :down

    car
    |> Map.put(:queue, Queue.push(car.queue, {floor, rel}))
  end

  defp process(%Car{step: :opening_doors} = car) do
    car |> set_step(:doors_open)
  end

  defp process(%Car{step: :doors_open} = car) do
    car |> set_step(:closing_doors)
  end

  defp process(%Car{step: :closing_doors} = car), do: car |> close_doors()
  defp process(%Car{step: :moving} = car), do: car |> move()
  defp process(%Car{step: :idling}), do: raise("Can't process idle step")

  defp move(car) do
    car
    |> change_floor()
    |> check_destination()
  end

  defp change_floor(%{destination: dest, current_floor: floor} = car) when floor < dest do
    car |> Map.put(:current_floor, floor + 1)
  end

  defp change_floor(%{destination: dest, current_floor: floor} = car) when floor > dest do
    car |> Map.put(:current_floor, floor - 1)
  end

  defp close_doors(car) do
    car
    |> check_destination()
    |> run_new_destination_callback()
  end

  defp check_destination(%Car{destination: floor, current_floor: floor} = car) do
    car |> start_to_open_doors()
  end

  defp check_destination(%Car{destination: nil} = car) do
    car |> set_step(:idling)
  end

  defp check_destination(car) do
    car |> set_step(:moving)
  end

  defp start_to_open_doors(%Car{queue: queue} = car) do
    {dest, queue} = queue |> Queue.pop()

    car
    |> Map.merge(%{destination: dest, queue: queue})
    |> set_step(:opening_doors)
  end

  defp set_step(car, :idling), do: car |> Map.put(:step, :idling)
  defp set_step(%{step: step} = car, step), do: car |> run_processing_callback()

  defp set_step(car, step) do
    car
    |> Map.merge(%{step: step, step_duration: duration(step)})
    |> run_processing_callback()
  end

  defp duration(_step) do
    @step_duration
  end

  defp set_moving_direction(car, direction) do
    car |> Map.put(:queue, Queue.set_moving_direction(car.queue, direction))
  end

  defp run_processing_callback(car) do
    car.processing_callback.(car)
    car
  end

  defp run_new_destination_callback(car) do
    car.new_destination_callback.(car)
    car
  end
end
