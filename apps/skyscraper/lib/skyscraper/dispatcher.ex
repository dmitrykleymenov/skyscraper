defmodule Skyscraper.Dispatcher do
  use GenServer

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  def handle_cast({:ready_to_new_destination, _elevator}, state) do
    {:noreply, state}
  end
end
