defmodule SkyscraperWeb.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      # Start the Telemetry supervisor
      SkyscraperWeb.Telemetry,
      # Start the Endpoint (http/https)
      SkyscraperWeb.Endpoint
      # Start a worker by calling: SkyscraperWeb.Worker.start_link(arg)
      # {SkyscraperWeb.Worker, arg}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: SkyscraperWeb.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    SkyscraperWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
