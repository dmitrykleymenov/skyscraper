defmodule Skyscraper.BuildingSupervisor do
  use Supervisor
  alias Skyscraper.Dispatcher.Server, as: Dispatcher
  alias Skyscraper.Elevator.Server, as: Elevator

  def start_link(arg) do
    Supervisor.start_link(__MODULE__, arg)
  end

  def init(arg) do
    children = [
      {Dispatcher, arg},
      elevators_supervisor_spec(arg)
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  defp elevators_supervisor_spec(arg) do
    children =
      arg
      |> Keyword.fetch!(:elevator_ids)
      |> Enum.map(fn id ->
        Supervisor.child_spec(
          {Elevator, Keyword.put(arg, :id, id)},
          id: id
        )
      end)

    %{
      id: ElevatorsSupervisor,
      start: {Supervisor, :start_link, [children, [strategy: :one_for_one]]},
      type: :supervisor
    }
  end
end
