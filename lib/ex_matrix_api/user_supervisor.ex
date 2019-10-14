defmodule ExMatrixApi.UserSupervisor do
  use DynamicSupervisor

  def start_link(ignored_state) do
    DynamicSupervisor.start_link(__MODULE__, ignored_state, name: __MODULE__)
  end

  @impl true
  def init(_) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end
end
