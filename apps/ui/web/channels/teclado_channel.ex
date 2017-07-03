defmodule Ui.TecladoChannel do
  use Phoenix.Channel

  def join("teclado:eventos", _message, socket) do
    {:ok, socket}
  end
  def join("teclado:" <> _private_room_id, _params, _socket) do
    {:error, %{reason: "unauthorized"}}
  end
end
