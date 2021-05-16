defmodule SkyscraperOtp.Interface.Console do
  alias SkyscraperOtp.Interface
  @behaviour Interface

  @impl Interface
  def elevator_state_changed(elevator) do
    elevator
    |> format_elevator_status()
    |> IO.puts()
  end

  @impl Interface
  def dispatcher_state_changed(dispatcher) do
    dispatcher
    |> format_dispatcher_status()
    |> IO.puts()
  end

  defp format_elevator_status(elevator) do
    "Elevator ##{elevator.elevator_id} from #{elevator.building} currently on the #{
      elevator.current_floor
    } floor and #{elevator.status}. #{elevator.floor_buttons |> show_elevator_buttons()}"
  end

  defp format_dispatcher_status(dispatcher) do
    "In #{dispatcher.building} #{dispatcher.buttons |> show_dispatcher_buttons()}"
  end

  defp show_elevator_buttons(buttons) do
    for({floor, active} <- buttons, active, do: floor)
    |> display_buttons()
  end

  defp show_dispatcher_buttons(buttons) do
    for({{floor, direction}, active} <- buttons, active, do: "#{floor}-#{direction}")
    |> display_buttons
  end

  defp display_buttons([]), do: "No active buttons"
  defp display_buttons(floors), do: "Active buttons: #{floors |> Enum.join(", ")}"
end
