defmodule Skyscraper.ConsoleDisplay do
  alias Skyscraper.Display
  @behaviour Display

  @impl Display
  def elevator_state_changed(elevator) do
    elevator
    |> format_elevator_status()
    |> IO.puts()
  end

  @impl Display
  def dispatcher_state_changed({}) do
    :ok
  end

  defp format_elevator_status(elevator) do
    "Elevator ##{elevator.elevator_id} from #{elevator.building} currently on the #{
      elevator.current_floor
    } floor and #{elevator.status}. #{elevator.floor_buttons |> show_buttons()}"
  end

  defp show_buttons(buttons), do: buttons |> filter_active() |> display_floors()

  defp filter_active(buttons), do: for({floor, active} <- buttons, active, do: floor)

  defp display_floors([]), do: "No active buttons"
  defp display_floors(floors), do: "Active buttons: #{floors |> Enum.join(", ")}"
end
