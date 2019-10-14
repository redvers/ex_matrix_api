defmodule ExMatrixApi do
  @moduledoc """
  Documentation for ExMatrixApi.
  """

  @doc """
  Hello world.

  ## Examples

      iex> ExMatrixApi.hello()
      :world

  """

  def t do
    %ExMatrixApi.Worker{
    id: :test,
    homeserver: "evil.red",
    deviceid: "elixir",
    password: "redacted",
    port: 8448,
    sessionid: nil,
    username: "redelixir"}

    |> initialize
  end

  def tt(), do: ExMatrixApi.R0.connect(:test)






  def initialize(state = %ExMatrixApi.Worker{}) do
    DynamicSupervisor.start_child(ExMatrixApi.UserSupervisor, {ExMatrixApi.Worker, state})
  end







end
