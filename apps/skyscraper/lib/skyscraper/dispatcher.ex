defmodule Skyscraper.Dispatcher do
  alias Skyscraper.Dispatcher

  defstruct [:queue, :elevators]

  def build(args) do
    %Dispatcher{
      elevators: Keyword.fetch!(args, :elevator_ids) |> map_elevators(),
      queue: []
    }
  end

  def push_button(%Dispatcher{} = disp, _button) do
    disp
  end

  defp map_elevators(elevators), do: for(el_id <- elevators, do: {el_id, nil}, into: %{})
end
