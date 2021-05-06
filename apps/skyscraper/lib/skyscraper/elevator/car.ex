defmodule Skyscraper.Elevator.Car do
  alias Skyscraper.Elevator.{Car, Queue}
  @default_step_duration 1000

  defstruct [
    :queue,
    :acceptable_floors,
    :current_floor,
    :destination,
    :step_durations,
    :direction,
    step: :idling,
    instructions: []
  ]

  defguardp is_open_doors(step) when step in ~w(opening_doors doors_open)a

  @doc """
    Builds a car struct
  """

  def build(opts \\ []) do
    %Car{
      queue: Queue.build(),
      acceptable_floors: Keyword.get(opts, :floors, 1..50 |> Enum.to_list()),
      current_floor: Keyword.get(opts, :current_floor, 1),
      step_durations: Keyword.get(opts, :step_durations, %{})
    }
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
    if floor in car.acceptable_floors do
      {car.step, car.destination, car.current_floor, {floor, determine_moving_choice(floor, car)}}
      |> accept_destination(car)
    else
      car
    end
    |> extract_instructions()
  end

  @doc """
    Returns current step duration
  """

  def step_duration(%Car{step_durations: durations} = car) do
    durations |> Map.get(car |> step(), @default_step_duration)
  end

  @doc """
    Returns acceptable floors for that car
  """
  def acceptable_floors(%Car{acceptable_floors: acceptable_floors}), do: acceptable_floors

  @doc """
    Returns floors which elevator must visit
  """
  def floors_to_handle(%Car{destination: nil}), do: []

  def floors_to_handle(%Car{destination: destination, queue: queue}) do
    [elem(destination, 0) | Queue.list(queue)]
  end

  @doc """
    Returns the current step
  """
  def step(%Car{step: :moving} = car), do: "moving_#{car.direction}" |> String.to_atom()
  def step(%Car{step: step}), do: step

  @doc """
    Returns the current floor
  """
  def current_floor(%Car{current_floor: current_floor}), do: current_floor

  @doc """
    Calculates delta of handling current destination directly from handling current destination through new request
  """

  def additional_handling_time(%Car{} = car, new_dest) do
    processing_time(car |> inject_destination(new_dest)) - processing_time(car)
  end

  @doc """
    Answer if car can handle moving request
  """
  def can_handle?(%Car{destination: nil} = car, {floor, _moving_choice}) do
    floor in car.acceptable_floors
  end

  def can_handle?(%Car{destination: {dest, _choice}}, {floor, :up}) when dest < floor, do: false

  def can_handle?(%Car{destination: {dest, _choice}}, {floor, :down}) when dest > floor,
    do: false

  def can_handle?(%Car{destination: {dest, choice1}}, {dest, choice2}), do: choice1 == choice2

  def can_handle?(%Car{step: step, current_floor: floor}, {floor, _moving_direction})
      when step != :moving,
      do: true

  def can_handle?(
        %Car{destination: {dest, _moving_choice1}, current_floor: curr},
        {floor, _moving_choice2}
      )
      when curr in floor..dest,
      do: false

  def can_handle?(%Car{destination: {dest, :down}} = car, {_floor, :up})
      when car.current_floor > dest,
      do: false

  def can_handle?(%Car{destination: {dest, :up}} = car, {_floor, :down})
      when car.current_floor < dest,
      do: false

  def can_handle?(car, {floor, _moving_choice}), do: floor in car.acceptable_floors

  defp inject_destination(car, new_dest) do
    car
    |> Map.put(:queue, Queue.push(car.queue, car.destination))
    |> Map.put(:destination, new_dest)
  end

  defp processing_time(%Car{step: :idling}), do: 0

  defp processing_time(car) do
    car = car |> process()
    [car |> step_duration() | processing_time(car)] |> Enum.sum()
  end

  defp determine_moving_choice(floor, %Car{current_floor: curr}) when floor > curr, do: :up
  defp determine_moving_choice(floor, %Car{current_floor: cur}) when floor < cur, do: :down
  defp determine_moving_choice(_floor, %Car{destination: nil}), do: :down
  defp determine_moving_choice(_floor, %Car{step: :moving, direction: :up}), do: :down
  defp determine_moving_choice(_floor, %Car{step: :moving, direction: :down}), do: :up

  defp determine_moving_choice(floor, %Car{destination: {dest, _moving_choice}}) do
    if floor < dest, do: :up, else: :down
  end

  defp accept_destination({:idling, _dest, _curr, floor}, car) do
    car |> Map.put(:destination, floor) |> check_destination()
  end

  defp accept_destination({_step, {dest, _choice1}, _curr, {dest, _choice2}}, car), do: car
  defp accept_destination({step, _dest, curr, {curr, _}}, car) when is_open_doors(step), do: car

  defp accept_destination({_step, nil, _curr, floor}, car) do
    car |> Map.put(:destination, floor)
  end

  defp accept_destination({_step, _dest, curr, {curr, choice}}, car) do
    car |> Map.put(:queue, Queue.push(car.queue, {curr, choice}))
  end

  defp accept_destination(
         {_step, {dest, _moving_choice}, curr, {floor, moving_choice}},
         car
       )
       when floor in curr..dest do
    car
    |> inject_destination({floor, moving_choice})
    |> add_instruction(:notify_new_destination)
  end

  defp accept_destination({_step, {dest, :down}, curr, {floor, moving_choice}}, car)
       when curr < dest and dest < floor do
    car
    |> inject_destination({floor, moving_choice})
    |> add_instruction(:notify_new_destination)
  end

  defp accept_destination({_step, {dest, :up}, curr, {floor, moving_choice}}, car)
       when curr > dest and dest > floor do
    car
    |> inject_destination({floor, moving_choice})
    |> add_instruction(:notify_new_destination)
  end

  defp accept_destination({_step, _dest, _curr, floor}, car) do
    car |> Map.put(:queue, Queue.push(car.queue, floor))
  end

  defp process(%Car{step: :opening_doors} = car) do
    car |> set_step(:doors_open)
  end

  defp process(%Car{step: :doors_open} = car) do
    car |> set_step(:closing_doors)
  end

  defp process(%Car{step: :closing_doors} = car), do: car |> close_doors()
  defp process(%Car{step: :moving, direction: :up} = car), do: car |> ascend()
  defp process(%Car{step: :moving, direction: :down} = car), do: car |> descend()

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

  defp check_destination(%Car{destination: {floor, moving_choice}, current_floor: floor} = car) do
    {dest, queue} = car.queue |> Queue.pop(moving_choice)

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

  defp actualize_moving_step(%Car{destination: {dest, _moving_choice}} = car) do
    cond do
      !(car.step == :moving && car.direction == :up) && dest > car.current_floor ->
        car
        |> Map.put(:direction, :up)
        |> set_step(:moving)

      !(car.step == :moving && car.direction == :down) && dest < car.current_floor ->
        car
        |> Map.put(:direction, :down)
        |> set_step(:moving)

      true ->
        car
        |> add_instruction(:reserve_step_time)
    end
  end

  # defp handling_time(start, finish) do
  #   abs(finish - start) * duration(:moving) +
  #     duration(:orening_doors) +
  #     duration(:doors_open) +
  #     duration(:closing_doors)
  # end

  defp set_step(car, :idling), do: car |> Map.put(:step, :idling)

  defp set_step(car, step) do
    car
    |> Map.put(:step, step)
    |> add_instruction(:reserve_step_time)
  end

  defp extract_instructions(%Car{instructions: instructions} = car) do
    {instructions |> Enum.reverse(), %{car | instructions: []}}
  end

  defp add_instruction(car, instruction) do
    car |> Map.put(:instructions, [instruction | car.instructions])
  end
end
