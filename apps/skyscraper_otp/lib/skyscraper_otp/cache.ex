defmodule SkyscraperOtp.Cache do
  use GenServer

  @moduledoc """
    Caches dispatcher and elevators state for buildings
  """

  def start_link(_arg) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def update_dispatcher(building, dispatcher) do
    GenServer.cast(__MODULE__, {:update_dispatcher, building, dispatcher})
  end

  def update_elevator(building, id, elevator) do
    GenServer.cast(__MODULE__, {:update_elevator, building, id, elevator})
  end

  def get_dispatcher(building) do
    case :ets.lookup(:dispatchers, building) do
      [] -> nil
      [{_key, dispatcher}] -> dispatcher
    end
  end

  def get_elevator(building, id) do
    case :ets.lookup(:elevators, {building, id}) do
      [] -> nil
      [{_key, elevator}] -> elevator
    end
  end

  @impl true
  def init([]) do
    :ets.new(:dispatchers, [:named_table])
    :ets.new(:elevators, [:named_table])

    {:ok, nil}
  end

  @impl true
  def handle_cast({:update_dispatcher, building, dispatcher}, state) do
    :ets.insert(:dispatchers, {building, dispatcher})
    {:noreply, state}
  end

  @impl true
  def handle_cast({:update_elevator, building, id, elevator}, state) do
    :ets.insert(:elevators, {{building, id}, elevator})
    {:noreply, state}
  end
end
