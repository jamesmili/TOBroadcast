defmodule TOBroadcast do
  def start(name, participants) do
    #create state with name, prticipants, pending msgs, and time
    state = %{
      pname: name,
      parent: self(),
      participants: participants,
      pending: [],
      time: for participant <- participants, into: %{} do
            {participant, 0}
            end
    }
    pid = spawn(fn -> TOBroadcast.run(state) end)
    case :global.register_name(name,pid) do
      :yes -> pid
      :no -> IO.puts("User is already in register")
    end
    pid
  end

  def bc_send(msg, origin) do
    send(origin,{:input, :bc_initiate, msg})
  end

  def run(state) do
    state = receive do
      {:input, :bc_initiate, msg} -> 
        #time[i]++
        state = update_in(state,[:time,state.pname], fn(time) -> time+1 end)
        time_i = state[:time][state.pname]        
        #invoke ssf-bc-send(m,time[i],origin)
        for p <- state.participants do
          pid = :global.whereis_name(p)
          send(pid, {:bc_msg, msg, time_i, state.pname})
        end
        state

      {:ts_up, t, origin_name} ->
        #time[j] = t
        state = update_in(state,[:time, origin_name], fn(time) -> t end)
        state

      {:bc_msg, msg, t, origin_name} ->
        #time[j] = T
        state = update_in(state,[:time, origin_name], fn(time) -> t end)
        #add (msg, time[i], j) to pending set
        state = update_in(state, [:pending], fn(list)-> list ++ [{msg, t, origin_name}] end)
        # if T > time[i]
        time_i = state[:time][state.pname]
        if t > time_i do
          #time[i] = T 
          state = update_in(state,[:time, state.pname], fn(time) -> t end)
          #invoke ssf-bc-sendi("ts_up", T, state.pname)
          for p <- state.participants do
            pid = :global.whereis_name(p)
            if p != state.pname do
              send(pid, {:ts_up, t, state.pname})
            end
          end
        end
        #enable to-bc-recv(m,j)
        for p <- state.participants do
          if t <= state.time[:p] do
            #remove item from list
            state = update_in(state, [:pending], fn(item) -> List.delete(state[:pending], {msg,t,origin_name}) end)
            if origin_name == p do
              #send to parent
              send(state.parent, {:output, :tp_bcast_rcvd, msg, origin_name})
            end
          end
        end
        state

      {:output, :tp_bcast_rcvd, msg, origin} ->
        IO.puts("Message: " <> inspect(msg) <> " from process " <> inspect(origin))
        state
    end
    run(state)
  end
end

#p1 = TOBroadcast.start("p1", ["p1","p2"])
#p2 = TOBroadcast.start("p2", ["p1","p2"])
#TOBroadcast.bc_send("hello",p1)
#TOBroadcast.bc_send("hello p1",p2)