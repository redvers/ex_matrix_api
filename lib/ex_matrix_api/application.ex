defmodule ExMatrixApi.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      # Starts a worker by calling: ExMatrixApi.Worker.start_link(arg)
      {ExMatrixApi.UserSupervisor, nil}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: ExMatrixApi.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
