defmodule SkyscraperOtp.Dispatcher do
  alias SkyscraperOtp.Dispatcher
  defstruct [:queue, :elevators, :instructions, :buttons]

  @moduledoc """
    Includes whole inner logic for dispatcher
  """

  @doc """
    Builds a dispatcher struct from `arg`
  """
  def build(args) do
    %Dispatcher{
      elevators: Keyword.fetch!(args, :elevator_ids) |> map_elevators(),
      queue: [],
      instructions: [],
      buttons:
        Keyword.fetch!(args, :floors)
        |> Enum.flat_map(&[{&1, :down}, {&1, :up}])
        |> List.delete_at(0)
        |> List.delete_at(-1)
    }
  end

  @doc """
    Answers if `button` is marked as pushed in `dispatcher`
  """
  def button_active?(%Dispatcher{queue: queue}, button), do: button in queue

  @doc """
    Returns all pushed buttons for `dispatcher`
  """
  def active_buttons(%Dispatcher{queue: queue}), do: queue

  @doc """
    Returns all possible buttons to push from `dispatcher`
  """
  def available_buttons(%Dispatcher{buttons: buttons}), do: buttons

  @doc """
    Tells `dispatcher` about pushed `button` and `elevators_handle_time` for that possible request
  """
  def push_button(%Dispatcher{} = dispatcher, button, elevators_handle_time) do
    dispatcher
    |> Map.put(:queue, [button | dispatcher.queue])
    |> add_proposal_instruction(optimal_elevator(elevators_handle_time), [button])
    |> extract_instructions()
  end

  @doc """
    Returns all elevator ids for `dispatcher`
  """
  def elevator_ids(%Dispatcher{elevators: elevators}), do: elevators |> Map.keys()

  @doc """
    Sets `dest_info` as handling request for `el_id`
  """
  def set_time_to_destination(%Dispatcher{} = dispatcher, el_id, {dest, new_time} = dest_info) do
    dispatcher.elevators
    |> Enum.reduce(dispatcher, fn
      {^el_id, _dest_info}, disp ->
        disp
        |> put_elevator_destination(el_id, dest_info)

      {id, {^dest, time}}, disp when time > new_time ->
        disp
        |> add_instruction({:cancel_request, id, dest})
        |> put_elevator_destination(id, nil)

      _, disp ->
        disp
    end)
    |> extract_instructions()
  end

  @doc """
    Tells `dispatcher` about handled `button` request by elevator with `el_id`
  """
  def request_handled(%Dispatcher{} = dispatcher, el_id, button) do
    dispatcher
    |> Map.put(:queue, dispatcher.queue |> List.delete(button))
    |> Map.put(:elevators, dispatcher.elevators |> Map.put(el_id, nil))
  end

  @doc """
    Propose all pending in `dispatcher` requests to elevator with `el_id`
  """
  def propose_requests(%Dispatcher{} = dispatcher, el_id) do
    dispatcher |> add_proposal_instruction(el_id, dispatcher.queue) |> extract_instructions()
  end

  defp map_elevators(elevators), do: for(el_id <- elevators, do: {el_id, nil}, into: %{})

  defp optimal_elevator(elevators_handle_time) do
    elevators_handle_time
    |> Enum.filter(&elem(&1, 1))
    |> Enum.min_by(&elem(&1, 1), fn -> {nil, nil} end)
    |> elem(0)
  end

  defp put_elevator_destination(dispatcher, el_id, dest_info) do
    dispatcher |> Map.put(:elevators, dispatcher.elevators |> Map.put(el_id, dest_info))
  end

  defp add_proposal_instruction(dispatcher, nil, _buttons), do: dispatcher

  defp add_proposal_instruction(dispatcher, el_id, buttons) do
    active = for {_id, button} <- dispatcher.elevators, button, into: %{}, do: button

    dispatcher
    |> add_instruction({:propose_to_handle, el_id, buttons |> Enum.map(&{&1, active[&1]})})
  end

  defp add_instruction(dispatcher, instruction) do
    dispatcher |> Map.put(:instructions, [instruction | dispatcher.instructions])
  end

  defp extract_instructions(%{instructions: instructions} = dispatcher) do
    {instructions |> Enum.reverse(), %{dispatcher | instructions: []}}
  end
end
