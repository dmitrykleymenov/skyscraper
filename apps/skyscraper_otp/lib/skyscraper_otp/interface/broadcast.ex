defmodule SkyscraperOtp.Interface.Broadcast do
  alias SkyscraperOtp.Interface
  alias SkyscraperOtp.PubSub
  @behaviour Interface

  @impl Interface
  def elevator_state_changed(elevator) do
    Phoenix.PubSub.broadcast(
      SkyscraperOtp.PubSub,
      topic(elevator.building),
      {:elevator_state_changed, elevator.id, elevator}
    )
  end

  @impl Interface
  def dispatcher_state_changed(dispatcher) do
    Phoenix.PubSub.broadcast(
      SkyscraperOtp.PubSub,
      topic(dispatcher.building),
      {:dispatcher_state_changed, dispatcher}
    )
  end

  defp topic(building) do
    "building:#{building}"
  end
end
