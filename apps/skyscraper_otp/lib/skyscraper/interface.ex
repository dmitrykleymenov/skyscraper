defmodule SkyscraperOtp.Interface do
  alias SkyscraperOtp.Elevator.Display, as: Elevator
  alias SkyscraperOtp.Dispatcher.Display, as: Dispatcher

  @callback elevator_state_changed(Elevator.t()) :: :ok
  @callback dispatcher_state_changed(Dispatcher.t()) :: :ok

  def change_elevator_state(interface_mods, building, id, car) do
    apply(interface_mods, :elevator_state_changed, [Elevator.build(building, id, car)])
  end

  def change_dispatcher_state(interface_mods, dispatcher, building) do
    apply(interface_mods, :dispatcher_state_changed, [Dispatcher.build(dispatcher, building)])
  end
end
