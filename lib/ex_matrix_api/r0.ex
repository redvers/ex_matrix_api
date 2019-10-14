defmodule ExMatrixApi.R0 do

  def connect(ref), do: GenServer.call(ref, :connect)
  def versions(ref), do: GenServer.call(ref, :r0_versions)
  def login_post(ref), do: GenServer.call(ref, :login)



end
