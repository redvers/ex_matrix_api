defmodule ExMatrixApi do
  @moduledoc """
  Documentation for ExMatrixApi.
  """

  @doc """
  Hello world.

  ## Examples
  ExMatrixApi.t("password")
  ExMatrixApi.R0.connect(:test)
  
  """

  def t(password) do
    %ExMatrixApi.Worker{
    id: :test,
    homeserver: "evil.red",
    deviceid: "elixir",
    password: password,
    port: 8448,
    sessionid: nil,
    username: "@redelixir:evil.red"}

    |> initialize
  end

  def tt(), do: ExMatrixApi.R0.connect(:test)






  def initialize(state = %ExMatrixApi.Worker{}) do
    DynamicSupervisor.start_child(ExMatrixApi.UserSupervisor, {ExMatrixApi.Worker, state})
  end







end
