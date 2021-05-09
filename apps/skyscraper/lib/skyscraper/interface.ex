defmodule Skyscraper.Interface do
  alias Skyscraper.Elevator.Display, as: Elevator
  alias Skyscraper.Dispatcher.Display, as: Dispatcher

  @callback elevator_state_changed(Elevator.t()) :: :ok
  @callback dispatcher_state_changed({}) :: :ok

  def change_elevator_state(interface_mod, building, id, car) do
    apply(interface_mod, :elevator_state_changed, [Elevator.build(building, id, car)])
  end

  def change_dispatcher_state(interface_mod, dispatcher, building) do
    apply(interface_mod, :dispatcher_state_changed, [Dispatcher.build(dispatcher, building)])
  end
end
