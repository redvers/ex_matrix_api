require Logger
defmodule ExMatrixApi.Worker do
  defstruct [:id, :homeserver, :port, :sessionid, :deviceid, :username, :password, :userstate, :gunref]

  use GenServer

  def start_link(state = %ExMatrixApi.Worker{id: id}) when is_atom(id) do
    GenServer.start_link(__MODULE__, state, [])
  end

  def init(state) do
    Process.register(self(), state.id)
    Logger.debug(inspect(state.id))
    {:ok, state}
  end


##############################################################################
#connect - requires host & port
##############################################################################

  def handle_call(:connect, _from, state =
    %ExMatrixApi.Worker{userstate: nil,
                        gunref: nil,
                        homeserver: hs, port: port}) do

   homeserver = String.to_charlist(hs)

   {:ok, pid} = :gun.open(homeserver, port, %{transport: :tls})
   case :gun.await_up(pid) do
     {:error, error} -> Logger.debug(inspect(error))
                        :gun.close(pid)
                        {:reply, {:error, error}, state}
     {:ok, :http}    -> Logger.debug("Connected...")
                        newstate = state
                                   |> Map.put(:gunref, pid)
                                   |> Map.put(:userstate, :connected)
                        {:reply, :ok, newstate}
   end
  end


  def handle_call(:r0_versions, _from, state =
    %ExMatrixApi.Worker{userstate: :connected, gunref: gunpid}) do
    ref = :gun.get(gunpid, '/_matrix/client/versions')
    res = :gun.await_body(gunpid, ref)
    {:reply, res, state}
  end

  def handle_call(:login, _from, state = 
      %ExMatrixApi.Worker{userstate: :connected, gunref: gunpid}) do
      body = 
      %{identifier: %{type: "m.id.user", user: "@redelixir:evil.red"},
        password: "redacted",
        type: "m.login.password"}
      |> Poison.encode!

    ref = :gun.post(gunpid, '/_matrix/client/r0/login', [{"content-type", "application/json"}], body)
    {:ok, json} = :gun.await_body(gunpid, ref)
    res = Poison.decode!(json)

    newstate = state
               |> Map.put(:userstate, :authenticated)
               |> Map.put(:username, Map.get(res, "user_id"))
               |> Map.put(:deviceid, Map.get(res, "device_id"))
               |> Map.put(:sessionid, Map.get(res, "access_token"))

    {:reply, res, newstate}

  end











  defp check_connection(state = %ExMatrixApi.Worker{gunref: pid}) when is_pid(pid), do: {:ok, state}
  defp check_connection(_), do: {:error, :noconnection}


  def handle_info({:gun_up, _, _}, state), do: {:noreply, state}
  def handle_info({:gun_down, _, _}, state), do: {:noreply, state}
  def handle_info({:gun_up, _, _,_,_,_}, state), do: {:noreply, state}
  def handle_info({:gun_down, _, _,_,_,_}, state), do: {:noreply, state}

  def handle_info({:gun_response,_pid,_ref, _, 200, headers}, state) do
    inspect(headers) |> Logger.info
    {:noreply, state}
  end


  def handle_info(foo, state) do
    Logger.debug(inspect(foo)) 
    {:noreply, state}
  end


end

