defmodule HelloWeb.UserSocket do
  use Phoenix.Socket

  ## Channels
  channel "room:*", HelloWeb.RoomChannel

  # Socket params are passed from the client and can
  # be used to verify and authenticate a user. After
  # verification, you can put default assigns into
  # the socket that will be set for all channels, ie
  #
  #     {:ok, assign(socket, :user_id, verified_user_id)}
  #
  # To deny connection, return `:error`.
  #
  # See `Phoenix.Token` documentation for examples in
  # performing token verification on connect.
  @impl true
  def connect(_params, socket, _connect_info) do
    idtoassign = Stack.get("idassign")
    Stack.put("idassign",idtoassign+1)
    IO.puts(idtoassign)
    {:ok, assign(socket, :user_id, Integer.to_string(idtoassign))}
  end

  

  # Socket id's are topics that allow you to identify all sockets for a given user:
  #
  #     def id(socket), do: "user_socket:#{socket.assigns.user_id}"
  #
  # Would allow you to broadcast a "disconnect" event and terminate
  # all active sockets and channels for a given user:
  #
  #     HelloWeb.Endpoint.broadcast("user_socket:#{user.id}", "disconnect", %{})
  #
  # Returning `nil` makes this socket anonymous.
  @impl true
  def id(socket), do: "users_socket:#{socket.assigns.user_id}"
end

#HelloWeb.Endpoint.broadcast("users_socket:" <> user.id, "disconnect", %{})