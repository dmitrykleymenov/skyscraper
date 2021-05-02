defmodule Skyscraper.Elevator.Car do
  alias Skyscraper.Elevator.{Car, Queue}
  @step_duration 1000

  defstruct [
    :current_floor,
    :acceptable_floors,
    :destination,
    :queue,
    :step,
    :step_duration,
    :instructions
  ]

  defguardp is_open_doors(step) when step in ~w(opening_doors doors_open)a

  @doc """
    Builds a car struct
  """

  def build(opts) do
    floors = Keyword.fetch!(opts, :floors)

    car = %Car{
      queue: Queue.build(Keyword.get(opts, :direction)),
      acceptable_floors: floors,
      current_floor: Keyword.get(opts, :current_floor, Enum.min(floors)),
      destination: nil,
      instructions: []
    }

    Keyword.get(opts, :destinations, [])
    |> Enum.reduce(car, &accept_destination(&2, &1))
    |> set_step(Keyword.get(opts, :step, :idling))
  end

  @doc """
    Completes current step
  """

  def complete_step(%Car{} = car) do
    car
    |> process()
    |> extract_instructions()
  end

  @doc """
    Add a new destination floor by using inside-cabin interface
  """

  def push_button(%Car{} = car, floor) do
    {car.step, car.destination, car.current_floor, floor}
    |> accept_destination(car)
    |> extract_instructions()
  end

  @doc """
    Returns current step duration
  """

  def step_duration(%Car{step_duration: step_duration}), do: step_duration

  @doc """
    Returns acceptable floors for that car
  """
  def acceptable_floors(%Car{acceptable_floors: acceptable_floors}), do: acceptable_floors

  @doc """
    returns floors which elevator must visit
  """
  def floors_to_handle(%Car{destination: nil}), do: []

  def floors_to_handle(%Car{destination: destination, queue: queue}) do
    [elem(destination, 0) | Queue.list(queue)]
  end

  @doc """
    returns the current step
  """
  def step(%Car{step: step}), do: step

  @doc """
    returns the current floor
  """
  def current_floor(%Car{current_floor: current_floor}), do: current_floor

  defp accept_destination({:idling, _dest, curr, curr}, car) do
    car
    |> set_step(:opening_doors)
    |> add_instruction(:notify_new_destination)
  end

  defp accept_destination({:idling, _dest, curr, floor}, car) do
    direction = if floor > curr, do: :up, else: :down

    car
    |> Map.put(:destination, {floor, direction})
    |> set_moving_direction(direction)
    |> set_step(String.to_atom("moving_#{direction}"))
    |> add_instruction(:notify_new_destination)
  end

  defp accept_destination({_step, {dest, _moving_choice}, _curr, dest}, car), do: car

  defp accept_destination({step, _dest, curr, curr}, car) when is_open_doors(step), do: car

  defp accept_destination({_step, nil, curr, floor}, car) do
    direction = if floor > curr, do: :up, else: :down

    car
    |> Map.put(:destination, {floor, direction})
    |> add_instruction(:notify_new_destination)
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
    |> add_instruction(:notify_new_destination)
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
  defp process(%Car{step: :moving_up} = car), do: car |> ascend()
  defp process(%Car{step: :moving_down} = car), do: car |> descend()

  defp process(%Car{step: :idling}), do: raise("Can't process idle step")

  defp ascend(%{current_floor: floor} = car) do
    car
    |> Map.put(:current_floor, floor + 1)
    |> check_destination()
  end

  defp descend(%{current_floor: floor} = car) do
    car
    |> Map.put(:current_floor, floor - 1)
    |> check_destination()
  end

  defp close_doors(car) do
    car
    |> check_destination()
    |> add_instruction(:notify_new_destination)
  end

  defp check_destination(%Car{destination: {floor, _moving_choice}, current_floor: floor} = car) do
    {dest, queue} = car.queue |> Queue.pop()

    car
    |> Map.merge(%{destination: dest, queue: queue})
    |> set_step(:opening_doors)
  end

  defp check_destination(%Car{destination: nil} = car) do
    car |> set_step(:idling)
  end

  defp check_destination(car) do
    car |> actualize_moving_step()
  end

  defp actualize_moving_step(
         %Car{destination: {dest, _moving_choice}, current_floor: floor} = car
       ) do
    cond do
      car.step != :moving_up && dest > floor -> car |> set_step(:moving_up)
      car.step != :moving_down && dest < floor -> car |> set_step(:moving_down)
      true -> car |> add_instruction(:reserve_step_time)
    end
  end

  defp set_step(car, :idling), do: car |> Map.put(:step, :idling)

  defp set_step(car, step) do
    car
    |> Map.merge(%{step: step, step_duration: duration(step)})
    |> add_instruction(:reserve_step_time)
  end

  defp duration(_step) do
    @step_duration
  end

  defp set_moving_direction(car, direction) do
    car |> Map.put(:queue, Queue.set_moving_direction(car.queue, direction))
  end

  defp extract_instructions(%Car{instructions: instructions} = car) do
    {instructions |> Enum.reverse(), %{car | instructions: []}}
  end

  defp add_instruction(car, instruction) do
    car |> Map.put(:instructions, [instruction | car.instructions])
  end
end
