require Logger
defmodule ExMatrixApi.Worker do
  defstruct [:id, :homeserver, :port, :sessionid, :deviceid, :username, :password, :userstate, :gunpid]

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


  def get_noauth(state, url) do
    ref = :gun.get(state.gunpid, url)
    :gun.await_body(state.gunpid, ref)
  end

    

  def handle_call(:r0_versions, _from, state), do: {:reply, get_noauth(state, '/_matrix/client/versions'), state}



  def post_authed(state, url, body) do
    ref = :gun.post(state.gunpid, url, [{"Authorization", "Bearer #{state.sessionid}"}], body)
    {:ok, json} = :gun.await_body(state.gunpid, ref)
    Poison.decode!(json)
  end
  def get_authed(state, url) do
    ref = :gun.get(state.gunpid, url, [{"Authorization", "Bearer #{state.sessionid}"}])
    {:ok, json} = :gun.await_body(state.gunpid, ref)
    Poison.decode!(json)
  end
  def put_authed(state, url, body) do
    ref = :gun.put(state.gunpid, url, [{"Authorization", "Bearer #{state.sessionid}"},{"Content-type", "application/json"}], body)
    {:ok, json} = :gun.await_body(state.gunpid, ref)
    Poison.decode!(json)
  end

  def handle_call({:r0_send_event, roomid, eventtype, txnID, content}, _from, state), do: {:reply, put_authed(state, "/_matrix/client/r0/rooms/#{roomid}/send/#{eventtype}/#{txnID}", content), state}


  def handle_call(:r0_logout, _from, state), do: {:reply, post_authed(state, '/_matrix/client/r0/logout', ""), state}

  def handle_call(:r0_whoami, _from, state), do: {:reply, get_authed(state, '/_matrix/client/r0/account/whoami'), state}

  def handle_call(:r0_capabilities, _from, state), do: {:reply, get_authed(state, '/_matrix/client/r0/capabilities'), state}

  def handle_call(:r0_joined_rooms, _from, state), do: {:reply, get_authed(state, '/_matrix/client/r0/joined_rooms'), state}

  def handle_call(:r0_sync, _from, state), do: {:reply, get_authed(state, "/_matrix/client/r0/sync"), state}
  def handle_call({:r0_sync, since}, _from, state), do: {:reply, get_authed(state, "/_matrix/client/r0/sync?since=#{since}"), state}

##############################################################################
# Special Cases
##############################################################################

  def handle_call(:connect, _from, state =
    %ExMatrixApi.Worker{userstate: nil,
                        gunpid: nil,
                        homeserver: hs, port: port}) do

   homeserver = String.to_charlist(hs)

   {:ok, pid} = :gun.open(homeserver, port, %{transport: :tls})
   case :gun.await_up(pid) do
     {:error, error} -> Logger.debug(inspect(error))
                        :gun.close(pid)
                        {:reply, {:error, error}, state}
     {:ok, :http}    -> Logger.debug("Connected...")
                        newstate = state
                                   |> Map.put(:gunpid, pid)
                                   |> Map.put(:userstate, :connected)
                        {:reply, :ok, newstate}
   end
  end
  def handle_call(:login, _from, state = 
      %ExMatrixApi.Worker{userstate: :connected, gunpid: gunpid}) do
      body = 
      %{identifier: %{type: "m.id.user", user: state.username},
        password: state.password,
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





  defp check_connection(state = %ExMatrixApi.Worker{gunpid: pid}) when is_pid(pid), do: {:ok, state}
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

