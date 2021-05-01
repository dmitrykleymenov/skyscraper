defmodule Skyscraper.Display do
  alias Skyscraper.Display.Elevator
  @callback elevator_state_changed(Elevator.t()) :: :ok
  @callback dispatcher_state_changed({}) :: :ok

  def change_elevator_state(callback_mod, dispatcher, id, car) do
    apply(callback_mod, :elevator_state_changed, [Elevator.build(dispatcher, id, car)])
  end
end
