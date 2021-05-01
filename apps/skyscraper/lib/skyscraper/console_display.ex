defmodule Skyscraper.ConsoleDisplay do
  alias Skyscraper.Display
  @behaviour Display

  @impl Display
  def elevator_state_changed(elevator) do
    elevator
    |> elevator_status()
    |> IO.puts()

    # apply(callback_mod, :elevator_state_changed, Elevator.build(dispatcher, id, car))
  end

  defp elevator_status(elevator) do
    "Elevator ##{elevator.elevator_id} from #{elevator.building} currently on the #{
      elevator.current_floor
    } floor and #{elevator.status}"
  end
end
