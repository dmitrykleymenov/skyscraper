defmodule SkyscraperOtp.BuildingSupervisor do
  use Supervisor
  alias SkyscraperOtp.Dispatcher.Server, as: Dispatcher
  alias SkyscraperOtp.Elevator.Server, as: Elevator

  @moduledoc """
    Root supervisor for whole new buildings dispatcher and elevators
  """

  @doc false
  def start_link(arg) do
    building = Keyword.fetch!(arg, :building)
    registry = Keyword.get(arg, :registry, SkyscraperOtp.Registry)

    Supervisor.start_link(__MODULE__, arg,
      name: {:via, Registry, {registry, registry_key(building)}}
    )
  end

  @doc """
    Returns registry key for supervisor with name `building`
  """
  def registry_key(building) do
    {__MODULE__, building}
  end

  @impl true
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
