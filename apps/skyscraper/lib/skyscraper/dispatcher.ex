defmodule Skyscraper.Dispatcher do
  alias Skyscraper.Dispatcher
  require IEx
  defstruct [:queue, :elevators, :instructions, :buttons]

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

  def button_active?(%Dispatcher{queue: queue}, button), do: button in queue

  def active_buttons(%Dispatcher{queue: queue}), do: queue

  def available_buttons(%Dispatcher{buttons: buttons}), do: buttons

  def push_button(%Dispatcher{} = disp, button, elevators_handle_time) do
    disp
    |> Map.put(:queue, [button | disp.queue])
    |> add_proposal_instruction(optimal_elevator(elevators_handle_time), [button])
    |> extract_instructions()
  end

  def elevator_ids(%Dispatcher{elevators: elevators}), do: elevators |> Map.keys()

  def elevator_accepted(%Dispatcher{} = dispatcher, el_id, button) do
    # IEx.pry()
    %{dispatcher | elevators: dispatcher.elevators |> Map.put(el_id, button)}
  end

  def set_time_to_destination(%Dispatcher{} = dispatcher, el_id, dest_info) do
    # IEx.pry()
    %{dispatcher | elevators: Map.put(dispatcher.elevators, el_id, dest_info)}
  end

  def request_handled(%Dispatcher{} = dispatcher, el_id, button) do
    dispatcher
    |> Map.put(:queue, dispatcher.queue |> List.delete(button))
    |> Map.put(:elevators, dispatcher.elevators |> Map.put(el_id, nil))
  end

  defp map_elevators(elevators), do: for(el_id <- elevators, do: {el_id, nil}, into: %{})

  defp optimal_elevator(elevators_handle_time) do
    # IEx.pry()

    elevators_handle_time
    |> Enum.filter(&elem(&1, 1))
    |> Enum.min_by(&elem(&1, 1), fn -> {nil, nil} end)
    |> elem(0)
  end

  defp add_proposal_instruction(dispatcher, nil, _buttons), do: dispatcher

  defp add_proposal_instruction(dispatcher, el_id, buttons) do
    # IEx.pry()
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
