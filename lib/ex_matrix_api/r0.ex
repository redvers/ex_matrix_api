defmodule ExMatrixApi.R0 do

  def connect(ref), do: GenServer.call(ref, :connect)
  def versions(ref), do: GenServer.call(ref, :r0_versions)
  def login_post(ref), do: GenServer.call(ref, :login)
  def logout(ref), do: GenServer.call(ref, :r0_logout)
  def whoami(ref), do: GenServer.call(ref, :r0_whoami)
  def capabilities(ref), do: GenServer.call(ref, :r0_capabilities)
  def joined_rooms(ref), do: GenServer.call(ref, :r0_joined_rooms)
  def sync(ref, since), do: GenServer.call(ref, {:r0_sync, since})
  def sync(ref), do: GenServer.call(ref, :r0_sync)
  def send(ref, roomid, eventtype, txnID, content), do: GenServer.call(ref, {:r0_send_event, roomid, eventtype, txnID, content})



end
