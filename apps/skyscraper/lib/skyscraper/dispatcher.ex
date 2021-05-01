defmodule Skyscraper.Dispatcher do
  use GenServer

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: Keyword.fetch!(opts, :dispatcher_id) |> name())
  end

  def notify_new_destination(id, elevator_id) do
    id
    |> name()
    |> GenServer.cast({:elevator_changed_destination, elevator_id})
  end

  def init(args) do
    {:ok,
     %{
       id: Keyword.fetch!(args, :dispatcher_id),
       elevator_ids: Keyword.fetch!(args, :elevator_ids),
       callback_mod: Keyword.fetch!(args, :callback_mod)
     }}
  end

  def handle_cast({:elevator_changed_destination, _elevator}, state) do
    {:noreply, state}
  end

  defp name(id) do
    {:via, Registry, {Skyscraper.Registry, {__MODULE__, id}}}
  end
end
