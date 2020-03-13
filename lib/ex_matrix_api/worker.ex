require Logger
defmodule ExMatrixApi.Worker do
  defstruct [:id, :homeserver, :port, :sessionid, :deviceid, :username, :password, :gunpid]

  use GenStateMachine
 
  def start_link(state = %ExMatrixApi.Worker{id: id}) when is_atom(id) do
    {:ok, pid} = GenStateMachine.start_link(__MODULE__, {:init, state})
    Process.register(pid, state.id)

    {:ok, pid}
  end

 
  def handle_event({:call, from}, :connect,         :init,          state), do: connect_action({:call, from}, :connect, :init, state)
  def handle_event({:call, from}, :r0_versions,     :connected,     state), do: version_action(state, from)
  def handle_event({:call, from}, :login,           :connected,     state), do:   login_action({:call, from}, :login, :connected, state)

  def handle_event({:call, from}, :r0_logout,       :authenticated, state), do: logout_r0_action(from, state)
  def handle_event({:call, from}, :r0_whoami,       :authenticated, state), do: whoami_r0_action(from, state)
  def handle_event({:call, from}, :r0_capabilities, :authenticated, state), do: capabi_r0_action(from, state)
  def handle_event({:call, from}, :r0_joined_rooms, :authenticated, state), do: join_r_r0_action(from, state)
  def handle_event({:call, from}, :r0_sync,         :authenticated, state), do: sync_r0_action(from, state)
  def handle_event({:call, from}, {:r0_sync, t},    :authenticated, state), do: sync_r0_action(from, t, state)

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






  def sync_r0_action(from, state), do: {:next_state, :authenticated, state, [{:reply, from, get_authed(state, "/_matrix/client/r0/sync")}]}
  def sync_r0_action(from, t, state), do: {:next_state, :authenticated, state, [{:reply, from, get_authed(state, "/_matrix/client/r0/sync?since=#{t}")}]}
  def join_r_r0_action(from, state), do: {:next_state, :authenticated, state, [{:reply, from, get_authed(state, '/_matrix/client/r0/joined_rooms')}]}
  def capabi_r0_action(from, state), do: {:next_state, :authenticated, state, [{:reply, from, get_authed(state, '/_matrix/client/r0/capabilities')}]}

  def logout_r0_action(from, state) do
    newstate =
      state
      |> Map.put(:deviceid, nil)
      |> Map.put(:sessionid, nil)
    {:next_state, :connected, newstate, [{:reply, from, post_authed(state, '/_matrix/client/r0/logout', "")}]}
  end

  def whoami_r0_action(from, state), do: {:next_state, :authenticated, state, [{:reply, from, get_authed(state, '/_matrix/client/r0/account/whoami')}]}

  def version_action(state, from), do: {:next_state, :connected, state, [{:reply, from, get_noauth(state, '/_matrix/client/versions')}]}
  def login_action({:call, from}, :login, :connected, state = %ExMatrixApi.Worker{gunpid: gunpid}) do
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

  def connect_action({:call, from}, :connect, :init, state = %ExMatrixApi.Worker{gunpid: nil, homeserver: hs, port: port}) do
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

