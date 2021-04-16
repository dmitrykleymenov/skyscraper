defmodule Skyscraper.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      # Start the Ecto repository
      Skyscraper.Repo,
      # Start the PubSub system
      {Phoenix.PubSub, name: Skyscraper.PubSub}
      # Start a worker by calling: Skyscraper.Worker.start_link(arg)
      # {Skyscraper.Worker, arg}
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: Skyscraper.Supervisor)
  end
end
