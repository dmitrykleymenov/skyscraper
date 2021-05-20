defmodule SkyscraperOtp.Interface.Broadcast do
  alias SkyscraperOtp.Interface
  @behaviour Interface

  @impl Interface
  def elevator_state_changed(elevator) do
    Phoenix.PubSub.broadcast(
      SkyscraperOtp.PubSub,
      "building:#{elevator.building}:#{elevator.id}",
      {:elevator_state_changed, elevator.id, elevator}
    )
  end

  @impl Interface
  def dispatcher_state_changed(dispatcher) do
    Phoenix.PubSub.broadcast(
      SkyscraperOtp.PubSub,
      "building:#{dispatcher.building}",
      {:dispatcher_state_changed, dispatcher}
    )
  end
end
