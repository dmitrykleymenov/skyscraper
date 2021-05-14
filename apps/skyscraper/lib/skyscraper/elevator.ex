defmodule Skyscraper.Elevator do
  alias __MODULE__
  alias Skyscraper.Elevator.Queue
  @default_step_duration 1000
  require IEx

  defstruct [
    :queue,
    :acceptable_floors,
    :current_floor,
    :destination,
    :outer_request,
    :step_durations,
    :direction,
    step: :idling,
    instructions: []
  ]

  defguardp is_open_doors(step) when step in ~w(opening_doors doors_open)a

  @doc """
    Builds a elevator struct
  """

  def build(opts \\ []) do
    %Elevator{
      queue: Queue.build(),
      acceptable_floors: Keyword.get(opts, :floors, 1..50 |> Enum.to_list()),
      current_floor: Keyword.get(opts, :current_floor, 1),
      step_durations: Keyword.get(opts, :step_durations, %{})
    }
  end

  @doc """
    Completes current step
  """

  def complete_step(%Elevator{} = elevator) do
    elevator
    |> process()
    |> actualize_destination_time_notification()
    |> extract_instructions()
  end

  @doc """
    Add a new destination floor by using inside-cabin interface
  """

  def push_button(%Elevator{} = elevator, floor) do
    if floor in elevator.acceptable_floors do
      {elevator.step, elevator.destination, elevator.current_floor,
       {floor, determine_moving_choice(floor, elevator)}}
      |> accept_destination(elevator)
    else
      elevator
    end
    |> extract_instructions()
  end

  @doc """
    Returns current step duration
  """

  def step_duration(%Elevator{step_durations: durations} = elevator) do
    durations |> Map.get(elevator |> step(), @default_step_duration)
  end

  @doc """
    Returns acceptable floors for that elevator
  """
  def acceptable_floors(%Elevator{acceptable_floors: acceptable_floors}), do: acceptable_floors

  @doc """
    Returns floors which elevator must visit
  """
  def floors_to_handle(%Elevator{destination: nil}), do: []
  def floors_to_handle(%Elevator{queue: queue, outer_request: true}), do: Queue.list(queue)

  def floors_to_handle(%Elevator{destination: destination, queue: queue}) do
    [elem(destination, 0) | Queue.list(queue)]
  end

  @doc """
    Returns the current step
  """
  def step(%Elevator{step: :moving} = elevator),
    do: "moving_#{elevator.direction}" |> String.to_atom()

  def step(%Elevator{step: step}), do: step

  @doc """
    Returns the current floor
  """
  def current_floor(%Elevator{current_floor: current_floor}), do: current_floor

  @doc """
    Calculates delta of handling current destination directly from handling current destination through `new_dest` for `elevator`
  """

  def additional_handling_time(%Elevator{} = elevator, new_dest) do
    processing_time(elevator |> inject_destination(new_dest, true)) - processing_time(elevator)
  end

  @doc """
    Answers if `elevator` can handle moving request
  """
  def can_handle?(%Elevator{destination: nil} = elevator, {floor, _moving_choice}) do
    floor in elevator.acceptable_floors
  end

  def can_handle?(%Elevator{destination: {dest, _choice}}, {floor, :up}) when dest < floor,
    do: false

  def can_handle?(%Elevator{destination: {dest, _choice}}, {floor, :down}) when dest > floor,
    do: false

  def can_handle?(%Elevator{destination: {dest, choice1}}, {dest, choice2}),
    do: choice1 == choice2

  def can_handle?(%Elevator{step: step, current_floor: floor}, {floor, _moving_direction})
      when step != :moving,
      do: true

  def can_handle?(
        %Elevator{destination: {dest, _moving_choice1}, current_floor: curr},
        {floor, _moving_choice2}
      )
      when curr in floor..dest,
      do: false

  def can_handle?(%Elevator{destination: {dest, :down}} = elevator, {_floor, :up})
      when elevator.current_floor > dest,
      do: false

  def can_handle?(%Elevator{destination: {dest, :up}} = elevator, {_floor, :down})
      when elevator.current_floor < dest,
      do: false

  def can_handle?(elevator, {floor, _moving_choice}), do: floor in elevator.acceptable_floors

  @doc """
    Proposes `elevator` to change destination to one from `buttons` list
  """

  def propose(%Elevator{} = elevator, buttons) do
    buttons
    |> Enum.reduce(elevator, fn {button, time}, el ->
      if el |> can_handle?(button) &&
           (is_nil(time) || el |> additional_handling_time(button) < time) do
        el |> inject_destination(button, true)
      else
        el
      end
    end)
    |> actualize_destination_time_notification()
    |> extract_instructions()
  end

  def cancel_request(%Elevator{destination: dest, outer_request: true} = elevator, dest) do
    elevator
    |> cancel_destination()
    |> Map.put(:outer_request, nil)
    |> add_instruction(:notify_new_destination)
    |> extract_instructions()
  end

  def cancel_request(%Elevator{} = elevator, _dest), do: elevator |> extract_instructions()

  defp actualize_destination_time_notification(%{outer_request: nil} = elevator), do: elevator

  defp actualize_destination_time_notification(elevator) do
    elevator
    |> add_instruction(
      {:send_time_for_destination,
       {elevator.destination, elevator |> skip_destination_handling_time()}}
    )
  end

  defp skip_destination_handling_time(elevator) do
    first = processing_time(elevator)
    second = processing_time(elevator |> cancel_destination())
    # IEx.pry()
    first - second
  end

  defp cancel_destination(%Elevator{destination: {_floor, moving_choice}} = elevator) do
    {dest, queue} = elevator.queue |> Queue.pop(moving_choice)
    %{elevator | destination: dest, queue: queue}
  end

  defp inject_destination(elevator, new_dest, outer_request \\ nil)

  defp inject_destination(%{outer_request: true} = elevator, new_dest, outer_request) do
    elevator
    |> Map.put(:destination, new_dest)
    |> Map.put(:outer_request, outer_request)
  end

  defp inject_destination(%{step: :idling} = elevator, new_dest, outer_request) do
    elevator
    |> Map.put(:destination, new_dest)
    |> Map.put(:outer_request, outer_request)
    |> check_destination()
  end

  defp inject_destination(elevator, new_dest, outer_request) do
    elevator
    |> Map.put(:queue, Queue.push(elevator.queue, elevator.destination))
    |> Map.put(:destination, new_dest)
    |> Map.put(:outer_request, outer_request)
  end

  defp processing_time(%Elevator{step: :idling}), do: 0

  defp processing_time(elevator) do
    (elevator |> step_duration()) + processing_time(elevator |> process())
  end

  defp determine_moving_choice(floor, %Elevator{current_floor: curr}) when floor > curr, do: :up
  defp determine_moving_choice(floor, %Elevator{current_floor: curr}) when floor < curr, do: :down
  defp determine_moving_choice(_floor, %Elevator{destination: nil}), do: :down
  defp determine_moving_choice(_floor, %Elevator{step: :moving, direction: :up}), do: :down
  defp determine_moving_choice(_floor, %Elevator{step: :moving, direction: :down}), do: :up

  defp determine_moving_choice(floor, %Elevator{destination: {dest, _moving_choice}}) do
    if floor < dest, do: :up, else: :down
  end

  defp accept_destination({:idling, _dest, _curr, floor}, elevator) do
    elevator |> Map.put(:destination, floor) |> check_destination()
  end

  defp accept_destination(
         {_step, {dest, _choice1}, _curr, {dest, moving_choice}},
         %{outer_request: true} = elevator
       ),
       do: elevator |> Map.put(:queue, elevator.queue |> Queue.push({dest, moving_choice}))

  defp accept_destination({_step, {dest, _choice1}, _curr, {dest, _choice2}}, elevator),
    do: elevator

  defp accept_destination({step, _dest, curr, {curr, _}}, elevator) when is_open_doors(step),
    do: elevator

  defp accept_destination({_step, nil, _curr, floor}, elevator) do
    elevator |> Map.put(:destination, floor)
  end

  defp accept_destination({_step, _dest, curr, {curr, choice}}, elevator) do
    elevator |> Map.put(:queue, Queue.push(elevator.queue, {curr, choice}))
  end

  defp accept_destination(
         {_step, {dest, _moving_choice}, curr, {floor, moving_choice}},
         elevator
       )
       when floor in curr..dest do
    elevator
    |> inject_destination({floor, moving_choice})
    |> add_instruction(:notify_new_destination)
  end

  defp accept_destination({_step, {dest, :down}, curr, {floor, moving_choice}}, elevator)
       when curr < dest and dest < floor do
    elevator
    |> inject_destination({floor, moving_choice})
    |> add_instruction(:notify_new_destination)
  end

  defp accept_destination({_step, {dest, :up}, curr, {floor, moving_choice}}, elevator)
       when curr > dest and dest > floor do
    elevator
    |> inject_destination({floor, moving_choice})
    |> add_instruction(:notify_new_destination)
  end

  defp accept_destination({_step, _dest, _curr, floor}, elevator) do
    elevator |> Map.put(:queue, Queue.push(elevator.queue, floor))
  end

  defp process(%Elevator{step: :opening_doors} = elevator) do
    elevator |> set_step(:doors_open)
  end

  defp process(%Elevator{step: :doors_open} = elevator) do
    elevator |> set_step(:closing_doors)
  end

  defp process(%Elevator{step: :closing_doors} = elevator), do: elevator |> close_doors()
  defp process(%Elevator{step: :moving, direction: :up} = elevator), do: elevator |> ascend()
  defp process(%Elevator{step: :moving, direction: :down} = elevator), do: elevator |> descend()

  defp ascend(%{current_floor: floor} = elevator) do
    elevator
    |> Map.put(:current_floor, floor + 1)
    |> check_destination()
  end

  defp descend(%{current_floor: floor} = elevator) do
    elevator
    |> Map.put(:current_floor, floor - 1)
    |> check_destination()
  end

  defp close_doors(elevator) do
    elevator
    |> check_destination()
    |> add_instruction(:notify_new_destination)
  end

  defp check_destination(
         %Elevator{destination: {floor, moving_choice}, current_floor: floor} = elevator
       ) do
    {dest, queue} =
      case elevator.queue |> Queue.pop(moving_choice) do
        {{^floor, choice}, queue} when elevator.outer_request ->
          queue |> Queue.pop(choice)

        res ->
          res
      end

    elevator
    |> actualize_destination_reached_notification(elevator.outer_request)
    |> Map.merge(%{destination: dest, queue: queue, outer_request: nil})
    |> set_step(:opening_doors)
  end

  defp check_destination(%Elevator{destination: nil} = elevator) do
    elevator |> set_step(:idling)
  end

  defp check_destination(elevator) do
    elevator |> actualize_moving_step()
  end

  defp actualize_destination_reached_notification(elevator, true) do
    elevator |> add_instruction({:destination_reached, elevator.destination})
  end

  defp actualize_destination_reached_notification(elevator, _outer_request), do: elevator

  defp actualize_moving_step(%Elevator{destination: {dest, _moving_choice}} = elevator) do
    cond do
      !(elevator.step == :moving && elevator.direction == :up) && dest > elevator.current_floor ->
        elevator
        |> Map.put(:direction, :up)
        |> set_step(:moving)

      !(elevator.step == :moving && elevator.direction == :down) && dest < elevator.current_floor ->
        elevator
        |> Map.put(:direction, :down)
        |> set_step(:moving)

      true ->
        elevator
        |> add_instruction(:reserve_step_time)
    end
  end

  defp set_step(elevator, :idling), do: elevator |> Map.put(:step, :idling)

  defp set_step(elevator, step) do
    elevator
    |> Map.put(:step, step)
    |> add_instruction(:reserve_step_time)
  end

  defp add_instruction(elevator, instruction) do
    elevator |> Map.put(:instructions, [instruction | elevator.instructions])
  end

  defp extract_instructions(%Elevator{instructions: instructions} = elevator) do
    {instructions |> Enum.reverse(), %{elevator | instructions: []}}
  end
end
