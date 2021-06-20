defmodule SkyscraperOtp.Cache do
  use GenServer

  @moduledoc """
    Caches dispatcher state and elevator states for buildings
  """

  @doc false
  def start_link(arg) do
    name = arg |> Keyword.get(:name, __MODULE__)

    GenServer.start_link(__MODULE__, name, name: name)
  end

  @doc """
    Sets cache for dispatcher from `building` to `dispatcher`
  """
  def update_dispatcher(building, dispatcher, name \\ __MODULE__) do
    GenServer.cast(name, {:update_dispatcher, building, dispatcher})
  end

  @doc """
    Sets cache for elevator with `id` from `building` to `elevator`
  """
  def update_elevator(building, id, elevator, name \\ __MODULE__) do
    GenServer.cast(name, {:update_elevator, building, id, elevator})
  end

  @doc """
    Clears cache for elevators and dispatcher from `building`
  """
  def clear_building(building, name \\ __MODULE__) do
    GenServer.cast(name, {:clear_building, building})
  end

  @doc """
    Fetches cached dispatcher state from `building`
  """
  def get_dispatcher(building, name \\ __MODULE__) do
    case :ets.lookup(:"#{name}_dispatchers", building) do
      [] -> nil
      [{_key, dispatcher}] -> dispatcher
    end
  end

  @doc """
    Fetches cached state for elevator with `id` from `building`
  """
  def get_elevator(building, id, name \\ __MODULE__) do
    case :ets.lookup(:"#{name}_elevators", {building, id}) do
      [] -> nil
      [{_key, elevator}] -> elevator
    end
  end

  @impl true
  def init(name) do
    :ets.new(:"#{name}_dispatchers", [:named_table])
    :ets.new(:"#{name}_elevators", [:named_table])

    {:ok, name}
  end

  @impl true
  def handle_cast({:update_dispatcher, building, dispatcher}, name) do
    true = :ets.insert(:"#{name}_dispatchers", {building, dispatcher})
    {:noreply, name}
  end

  @impl true
  def handle_cast({:update_elevator, building, id, elevator}, name) do
    true = :ets.insert(:"#{name}_elevators", {{building, id}, elevator})
    {:noreply, name}
  end

  @impl true
  def handle_cast({:clear_building, building}, name) do
    true = :ets.delete(:"#{name}_dispatchers", building)
    true = :ets.match_delete(:"#{name}_elevators", {{building, :_}, :_})
    {:noreply, name}
  end
end
