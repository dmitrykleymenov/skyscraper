defmodule SkyscraperOtp.Dispatcher.Display do
  alias __MODULE__
  alias SkyscraperOtp.Dispatcher
  defstruct [:building, :buttons]

  def build(building, dispatcher) do
    %Display{
      building: building,
      buttons: dispatcher |> buttons()
    }
  end

  defp buttons(dispatcher) do
    active = dispatcher |> Dispatcher.active_buttons()

    for button <- dispatcher |> Dispatcher.available_buttons(), do: {button, button in active}
  end
end
