require Logger
defmodule ExMatrixApi.Worker do
  defstruct [:id, :homeserver, :port, :sessionid, :deviceid, :username, :password, :gunpid]

  use GenStateMachine
 
  def start_link(state = %ExMatrixApi.Worker{id: id}) when is_atom(id) do
    {:ok, pid} = GenStateMachine.start_link(__MODULE__, {:init, state})
    Process.register(pid, state.id)

    {:ok, pid}
  end

 
  def handle_event({:call, from}, :connect,         :init,          state), do: connect_action(from, state)
  def handle_event({:call, from}, :r0_versions,     :connected,     state), do: version_action(from, state)
  def handle_event({:call, from}, :login,           :connected,     state), do:   login_action(from, state)

  def handle_event({:call, from}, :r0_logout,       :authenticated, state), do: logout_r0_action(from, state)

  def handle_event({:call, from}, :r0_whoami,       f=:authenticated, state), do: get_authd_action(from, f, state, "account/whoami")
  def handle_event({:call, from}, :r0_capabilities, f=:authenticated, state), do: get_authd_action(from, f, state, "capabilities")
  def handle_event({:call, from}, :r0_joined_rooms, f=:authenticated, state), do: get_authd_action(from, f, state, "joined_rooms")
  def handle_event({:call, from}, :r0_sync,         f=:authenticated, state), do: get_authd_action(from, f, state, "sync")
  def handle_event({:call, from}, {:r0_sync, t},    f=:authenticated, state), do: get_authd_action(from, f, state, "sync?since=#{t}")

  def handle_event(:info, {:gun_up,_,_},         fsm, state), do: {:next_state, fsm, state}
  def handle_event(:info, {:gun_down,_,_},       fsm, state), do: {:next_state, fsm, state}
  def handle_event(:info, {:gun_up,_,_,_,_,_},   fsm, state), do: {:next_state, fsm, state}
  def handle_event(:info, {:gun_down,_,_,_,_,_}, fsm, state), do: {:next_state, fsm, state}

  def handle_event(:info, {:gun_response,_pid,_ref, _, _httpcode, headers}, fsm, state) do
    inspect(headers) |> Logger.info
    {:next_state, fsm, state}
  end


  def handle_event(foo, state) do
    Logger.debug(inspect(foo)) 
    {:noreply, state}
  end



  def get_authd_action(from, fsm, state, url) do
    {:next_state, fsm, state, [{:reply, from, get_authed(state, "/_matrix/client/r0/#{url}")}]}
  end



  def logout_r0_action(from, state) do
    newstate =
      state
      |> Map.put(:deviceid, nil)
      |> Map.put(:sessionid, nil)
    {:next_state, :connected, newstate, [{:reply, from, post_authed(state, '/_matrix/client/r0/logout', "")}]}
  end

  def version_action(from, state), do: {:next_state, :connected, state, [{:reply, from, get_noauth(state, '/_matrix/client/versions')}]}
  def login_action(from, state = %ExMatrixApi.Worker{gunpid: gunpid}) do
      body = 
      %{identifier: %{type: "m.id.user", user: state.username},
        password: state.password,
        type: "m.login.password"}
      |> Poison.encode!

    ref = :gun.post(gunpid, '/_matrix/client/r0/login', [{"content-type", "application/json"}], body)
    {:ok, json} = :gun.await_body(gunpid, ref)
    res = Poison.decode!(json)

    case Map.get(res, "access_token", :fail) do
      :fail -> {:next_state, :connected, state, [{:reply, from, res}]}
          _ -> newstate = state
               |> Map.put(:username, Map.get(res, "user_id"))
               |> Map.put(:deviceid, Map.get(res, "device_id"))
               |> Map.put(:sessionid, Map.get(res, "access_token"))

               {:next_state, :authenticated, newstate, [{:reply, from, res}]}
    end

  end

  def connect_action(from, state = %ExMatrixApi.Worker{gunpid: nil, homeserver: hs, port: port}) do
   homeserver = String.to_charlist(hs)

   {:ok, pid} = :gun.open(homeserver, port, %{transport: :tls})
   case :gun.await_up(pid) do
     {:error, error} -> Logger.debug(inspect(error))
                        :gun.close(pid)
                        {:next_state, :init, state, [{:reply, from, {:error, error}}]}
     {:ok, :http}    -> Logger.debug("Connected...")
                        newstate = state
                                   |> Map.put(:gunpid, pid)
                        {:next_state, :connected, newstate, [{:reply, from, :ok}]}
     {:ok, :http2}   -> Logger.debug("Connected :http2")
                        newstate = state
                                   |> Map.put(:gunpid, pid)
                        {:next_state, :connected, newstate, [{:reply, from, :ok}]}
    end
  end

  def get_noauth(state, url) do
    ref = :gun.get(state.gunpid, url)
    :gun.await_body(state.gunpid, ref)
  end
 
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
#   def put_authed(state, url, body) do
#     ref = :gun.put(state.gunpid, url, [{"Authorization", "Bearer #{state.sessionid}"},{"Content-type", "application/json"}], body)
#     {:ok, json} = :gun.await_body(state.gunpid, ref)
#     Poison.decode!(json)
#   end
# 
#   def handle_call({:r0_send_event, roomid, eventtype, txnID, content}, _from, state), do: {:reply, put_authed(state, "/_matrix/client/r0/rooms/#{roomid}/send/#{eventtype}/#{txnID}", content), state}


end

