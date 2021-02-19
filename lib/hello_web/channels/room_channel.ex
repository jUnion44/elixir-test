import Application
import Phoenix.Socket
# Registry.start_link(keys: :unique, name: Registry.GameValues)
# Registry.register(Registry.GameValues,"France",10000)
# Registry.start_link(keys: :unique, name: Registry.GameValues)
# IO.puts(hd(tl(Tuple.to_list(hd(Registry.lookup(Registry.GameValues,"France"))))))

defmodule Stack do
  use GenServer

  def start_link(state) do
    GenServer.start_link(__MODULE__, state, name: __MODULE__)
  end

  @impl true
  def init(init_arg) do
    Process.flag(:trap_exit, true)
    {:ok, init_arg}
  end

  def getProcess() do
    Application.get_env(:hello,:gameData)
  end

  def put(key, value) do
    # Send the server a :put "instruction"
    GenServer.call(getProcess(), {:put, key, value})
  end

  def get(key) do
    # Send the server a :put "instruction"
    GenServer.call(getProcess(), {:get, key})
  end
  
  # Server callback
  @impl true
  def handle_call({:put, key, value}, _from, state) do
    {:reply, :ok, Map.put(state, key, value)}
  end

  @impl true
  def handle_call({:get, key}, _from, state) do
    {:reply, Map.get(state, key), state}
  end

  @impl true
  def terminate(reason, state) do
    IO.puts("stopped")
  end
end

defmodule HelloWeb.RoomChannel do
  require Logger
  require Phoenix.Socket
    use Phoenix.Channel


    intercept ["new_msg"]

    def handle_out("new_msg", payload, socket) do
      socket = Map.get(Stack.get("sockets"),socket.assigns.user_id)
      gameId = (if socket.assigns.gameId do
        socket.assigns.gameId
      else
        0
      end)
      payloadId = Map.get(payload,"game_id",0)

      ttype = Map.get(payload,"messagetype","chatMessage")
      #IO.puts(ttype)
      payload=Map.put(payload,"messagetype",ttype)
      IO.puts(Map.get(payload,"messagetype"))
      #IO.puts(List.to_string(Map.to_list(payload) ))
      # payload=Map.put(payload,"assign_id", (if (socket.assigns.gameId > 0) do
      #   socket.assigns.country
      # else
      #   Map.get(payload,"assign_id")
      # end ))
      if (gameId == payloadId) do
        push(socket, "new_msg", payload)
      end
      
      IO.puts("INTERCEPTED")
      {:noreply, socket}
    end

    #Module.put_attribute(__MODULE__, :gameData, %{})
    #Registry.start_link(keys: :unique, name: Registry.GameValues)
    
    
    @after_compile __MODULE__
    def __after_compile__(_e,_f) do
      IO.puts("started")
    end

    @impl true
    def init(init_arg) do
      Process.flag(:trap_exit, true)
      {:ok, init_arg}
    end

    # def makeGame() do
    #   if Stack.get("lobbyPlayers") = 6 do
        
    #   end
    # end

    def checkId(toReturn,gameIdSearch,iterId) do
      stackDict = Stack.get("sockets")
      keys = Map.keys(stackDict)
      IO.puts(List.to_string(keys))
      IO.puts(length(keys))
      IO.puts(iterId)
      if (length(keys) <= iterId) do
        toReturn
      else
        socketDictId = Map.get(Stack.get("sockets"),Enum.at(keys,iterId))
        if (socketDictId.assigns.gameId === gameIdSearch) do
          toReturn = toReturn ++ [Enum.at(keys,iterId)]
          checkId(toReturn,gameIdSearch,iterId+1)
        else
          checkId(toReturn,gameIdSearch,iterId+1)
        end

      end
    end

    # def setGameId(key,args) do
    #   s=key
    #   IO.puts(s)
    #   socketDict = Map.get(Stack.get("sockets"),s)
    #   #IO.puts(List.to_string(Map.to_list(socketDict)))
    #   socketDict = Map.put(socketDict, s, %{:gameId => args})
    #   IO.puts("Assigning id " <> Integer.to_string(args))
    #   Stack.put("sockets",socketDict)
    # end


    def getPlayersInLobby() do
      toReturn = checkId([],0,0)
      
      
      IO.puts(List.to_string(toReturn))
      toReturn
    end

    def broadcastIds(playerIdList,payload) do
      Enum.each(playerIdList, fn(s) ->
        socket = Map.get(Stack.get("sockets"),s)
        push(socket, "new_msg", payload)
      end)
    end

    def conductDay(gameId,playerIdList,dayNum) do
      Stack.put("game"<>Integer.to_string(gameId),:day)
      broadcastIds(playerIdList,%{"gameId" => gameId,"messagetype" => "server", "body" => "Welcome to the day phase.  Take some time to be nationalist and bully the other team!" })

      if (dayNum==1) do
        broadcastIds(playerIdList,%{"gameId" => gameId,"messagetype" => "server", "body" => "This game is based of the alternative Congress of Vienna, where part of Austria formed Patrickstan and is pitted against the rest of it!  Your goal is to CRUSH the opposing alliance by killing countries that are NOT your teammates." })
      end

      Enum.map(1..40,fn(i)->
        Process.sleep(1000)
        broadcastIds(playerIdList,%{"gameId" => gameId,"messagetype" => "timeUpdate", "body" => "Day " <> Integer.to_string(dayNum) <> ": " <> Integer.to_string(40-i) })
      end)

      Stack.put("game"<>Integer.to_string(gameId),:night)
      broadcastIds(playerIdList,%{"gameId" => gameId,"messagetype" => "server", "body" => "Welcome to the night phase.  Type in the exact name of the country you wish to attack (if any)." })
      Enum.map(1..40,fn(i)->
        Process.sleep(1000)
        broadcastIds(playerIdList,%{"gameId" => gameId,"messagetype" => "timeUpdate", "body" => "Night " <> Integer.to_string(dayNum) <> ": " <> Integer.to_string(40-i) })
        

      end)

      Enum.each([0,1,2,3,4,5], fn(i) ->
        s = Enum.at(playerIdList,i)
        socket = Map.get(Stack.get("sockets"),s)
        target = socket.assigns.killTarget
        Enum.each([0,1,2,3,4,5], fn(i) ->
          s = Enum.at(playerIdList,i)
          socket2 = Map.get(Stack.get("sockets"),s)
          target = socket.assigns.killTarget
          if (target == socket2.assigns.country and socket2.assigns.dead == :false) do
            push(socket2, "new_msg", %{"messagetype" => "server", "body" => "You have been killed" })
            socket2 = Phoenix.Socket.assign(socket2,:dead,true)
            Stack.put("sockets",Map.put(Stack.get("sockets"),s,socket2))
            broadcast(socket, "new_msg", %{"messagetype" => "server", "game_id" => socket2.assigns.gameId, "body" => "<b style='color:red'>" <> socket2.assigns.country <> " was killed.  They died!</b>"  })
            broadcast(socket, "new_msg", %{"messagetype" => "deathUpdate", "game_id" => socket2.assigns.gameId, "body" => socket2.assigns.country })
          end
          #socket = Phoenix.Socket.assign(s,:topic,"room:"<>Integer.to_string(gameId))
          
        end)
        #socket = Phoenix.Socket.assign(s,:topic,"room:"<>Integer.to_string(gameId))
        
      end)

      socket = Map.get(Stack.get("sockets"),Enum.at(playerIdList,0))
      if (Enum.all?([0,1,2,3,4,5], fn i -> 
        s = Enum.at(playerIdList,i)
        socket = Map.get(Stack.get("sockets"),s)
        socket.assigns.dead == true

        end)) do
        
          broadcast(Map.get(Stack.get("sockets"),Enum.at(playerIdList,0)), "new_msg", %{"messagetype" => "server", "game_id" => socket.assigns.gameId, "body" => "<b style='color:red'>All countries have died.  Stalemate.</b>"  })
      else if (Enum.all?([0,1,2,3,4,5], fn i -> 
        s = Enum.at(playerIdList,i)
        socket = Map.get(Stack.get("sockets"),s)
        socket.assigns.team == :a or socket.assigns.dead == true

        end)) do
          broadcast(Map.get(Stack.get("sockets"),Enum.at(playerIdList,0)), "new_msg", %{"messagetype" => "server", "game_id" => socket.assigns.gameId, "body" => "<b style='color:green'>Patrickstan, Prussia, and Great Britain won!</b>"  })
        else if (Enum.all?([0,1,2,3,4,5], fn i -> 
          s = Enum.at(playerIdList,i)
          socket = Map.get(Stack.get("sockets"),s)
          socket.assigns.team == :b or socket.assigns.dead == true
  
          end)) do
            broadcast(Map.get(Stack.get("sockets"),Enum.at(playerIdList,0)), "new_msg", %{"messagetype" => "server", "game_id" => socket.assigns.gameId, "body" => "<b style='color:green'>France, Austria, and Russia won!</b>"  })
          else
            conductDay(gameId,playerIdList,dayNum+1)
          end
        end
    end

      


    end

    def handleGame(playerIdList) do
      #Get game id
      gameId = Stack.get("gameidassign")
      Stack.put("gameidassign",gameId+1)

      #iterList(playerIdList,setGameId,0,0)
      #Move players to game id
      countries = ["Austria","Patrickstan","France","Prussia","Great Britain","Russia"]
      teams = [:b,:a,:b,:a,:a,:b]
      teammates = ["France and Russia","Great Britain and Prussia","Russia and Austria","Great Britain and Patrickstan","Prussia and Patrickstan","France and Austria"]

      Enum.each([0,1,2,3,4,5], fn(i) ->
        s = Enum.at(playerIdList,i)
        socket = Map.get(Stack.get("sockets"),s)
        socket = Phoenix.Socket.assign(socket,:gameId,gameId)
        socket = Phoenix.Socket.assign(socket,:killTarget,"")
        socket = Phoenix.Socket.assign(socket,:country,Enum.at(countries,i))
        socket = Phoenix.Socket.assign(socket,:team,Enum.at(teams,i))
        socket = Phoenix.Socket.assign(socket,:teammates,Enum.at(teammates,i))
        socket = Phoenix.Socket.assign(socket,:dead,false)
        socket = Phoenix.Socket.assign(socket,:topics, ["room:"<>Integer.to_string(gameId)])
        Stack.put("sockets",Map.put(Stack.get("sockets"),s,socket))
        #socket = Phoenix.Socket.assign(s,:topic,"room:"<>Integer.to_string(gameId))
        IO.puts("You are now "<> socket.assigns.country)
        
        #broadcast(socket,"new_msg", %{ "body" => "The game has begun."  })
        push(socket, "new_msg", %{"messagetype" => "server", "body" => "You are now "<> socket.assigns.country })
        push(socket, "new_msg", %{"messagetype" => "gameCreate", "country" => socket.assigns.country , "teammates" => socket.assigns.teammates})
      end)

      conductDay(gameId,playerIdList,1)




    end

    def makeGame() do
      lobbyPlayers = getPlayersInLobby()
      if length(lobbyPlayers) == 6 do
        IO.puts("Game starting lol")
        spawn fn -> handleGame(lobbyPlayers) end
      else
        IO.puts("Game not lol")
        IO.puts(Integer.to_string(length(lobbyPlayers)))
      end
    end

    def join("room:lobby", _message, socket) do
      
      
      # val = Registry.lookup(Registry.GameValues,"lobby_list")
      # IO.puts(length(val))
      # lobby_list = hd(tl(Tuple.to_list(hd(val))))
      # lobby_list = lobby_list ++ socket
      
      toPut = Stack.get("lobbyPlayers") + 1
      Stack.put("lobbyPlayers",toPut)
      
      #broadcast!(socket, "new_msg", %{body: "There are " <> Integer.to_string(Stack.get("lobbyPlayers")) <> " players connected."})

      # Registry.register(Registry.GameValues,"lobby_list",lobby_list)

      send(self, :after_join)
     
      {:ok, socket}
    end

    def countLobbyPlayers() do
      lp = getPlayersInLobby()
      length(lp)
    end


    def handle_info(:after_join, socket) do
      socket = Phoenix.Socket.assign(socket,:gameId,0)
      Stack.put("sockets",Map.put(Stack.get("sockets"),socket.assigns.user_id,socket))
      
      broadcast!(socket, "new_msg", %{"messagetype" => "server","body" => "There are " <> Integer.to_string(countLobbyPlayers) <> " player(s) in the lobby."})
      stackDict = Stack.get("sockets")
      makeGame()
      #Enum.each(Map.keys(stackDict), fn(s) -> broadcast!(socket, "new_msg", %{body: s}) end)
      {:noreply, socket}
    end


    def join("room:" <> _private_room_id, _params, _socket) do
      {:error, %{reason: "unauthorized"}}
    end


      
    def terminate(reason, socket) do
      socket = Map.get(Stack.get("sockets"),socket.assigns.user_id)
      if (socket.assigns.gameId>0) do
        socket = Phoenix.Socket.assign(socket,:dead,true)
        broadcast(socket, "new_msg", %{"messagetype" => "server", "game_id" => socket.assigns.gameId, "body" => "<b style='color:red'>" <> socket.assigns.country <> " left the game.  They died!</b>"  })
        broadcast(socket, "new_msg", %{"messagetype" => "deathUpdate", "game_id" => socket.assigns.gameId, "body" => socket.assigns.country })
      else
        broadcast(socket, "new_msg", %{"messagetype" => "server", "game_id" => socket.assigns.gameId, "body" => "Player " <> socket.assigns.user_id <> " left the lobby."  })
      end
      
      IO.puts(socket.assigns.user_id)


      #Stack.put("sockets",Map.delete(Stack.get("sockets"),socket.assigns.user_id))
      {:ok, reason}
    end

    def handle_in("new_msg", %{"body" => body}, socket) do
      socket = Map.get(Stack.get("sockets"),socket.assigns.user_id)
      IO.puts(Integer.to_string(socket.assigns.gameId))
      if (socket.assigns.gameId>0) do
        if (socket.assigns.dead == false) do
          if (Stack.get("game"<>Integer.to_string(socket.assigns.gameId))==:night) do

            socket = Phoenix.Socket.assign(socket,:killTarget,body)
            Stack.put("sockets",Map.put(Stack.get("sockets"),socket.assigns.user_id,socket))
            push(socket, "new_msg", %{"messagetype" => "server", "body" => "You are targetting "<>body })

          else
            broadcast!(socket, "new_msg",%{"game_id" => socket.assigns.gameId, "assign_id" => socket.assigns.country, "body" => body})
          end
        else
          push(socket, "new_msg", %{"messagetype" => "server", "body" => "Dead players may not talk." })
        end
        
      else
        broadcast!(socket, "new_msg",%{"game_id" => socket.assigns.gameId, "assign_id" => "Player "<> socket.assigns.user_id, "body" => body})
      end
        
      # broadcast!(socket, "new_msg", (if socket.assigns.gameId>0 do
      #   %{"game_id" => socket.assigns.gameId, "assign_id" => socket.assigns.country, "body" => body}
      # else
      #   %{"game_id" => socket.assigns.gameId, "assign_id" => "Player "<> socket.assigns.user_id, "body" => body}
      # end))
      {:noreply, socket}
      
      
    end


  end