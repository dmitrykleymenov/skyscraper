defmodule SkyscraperOtp.Interface do
  alias SkyscraperOtp.Elevator.Display, as: Elevator
  alias SkyscraperOtp.Dispatcher.Display, as: Dispatcher

  @callback elevator_state_changed(Elevator.t()) :: :ok
  @callback dispatcher_state_changed(Dispatcher.t()) :: :ok

  def change_elevator_state(interface_mod, building, id, car) do
    apply(interface_mod, :elevator_state_changed, [Elevator.build(building, id, car)])
  end

  def change_dispatcher_state(interface_mod, building, dispatcher) do
    apply(interface_mod, :dispatcher_state_changed, [Dispatcher.build(building, dispatcher)])
  end
end
