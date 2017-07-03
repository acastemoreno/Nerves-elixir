defmodule Fw.Alarma do
  use GenServer
  alias ElixirALE.GPIO

  ## API
  ####

  def start_link(gpio_button_number) do
    GenServer.start_link(__MODULE__, [gpio_button_number], name: __MODULE__)
  end

  def iniciar_teclado() do
    GenServer.call(__MODULE__, :iniciar_teclado)
  end

  ## Implementación GenServer
  ####

  def init([gpio_button_number]) do
    {:ok, pin_in} = GPIO.start_link(gpio_button_number, :input)
    GPIO.set_int(pin_in, :both)
    Ui.Endpoint.broadcast! "teclado:eventos", "ingreso_contraseña", %{texto: "boton en gpio #{gpio_button_number}"}
    spawn fn -> loop_button(gpio_button_number) end
    {:ok, %{estado: :disponible}}
  end

  def handle_call(:iniciar_teclado, _from, estado = %{estado: :disponible}) do
    Ui.Endpoint.broadcast! "teclado:eventos", "ingreso_contraseña", %{texto: "Presionaste por primera vez"}
    spawn fn -> esperar_teclado({:procesando, ""}, 0) end
    {:reply, :iniciando, estado |> Map.put(:estado, :procesando)}
  end

  def handle_call(:iniciar_teclado, _from, estado = %{estado: :procesando}) do
    Ui.Endpoint.broadcast! "teclado:eventos", "ingreso_contraseña", %{texto: "Precionaste de nuevo"}
    {:reply, :procesando, estado}
  end

  ## Implementación Loop
  ####

  def loop_button(gpio_button_number) do
    receive do
      {:gpio_interrupt, ^gpio_button_number, :rising} ->
        Ui.Endpoint.broadcast! "teclado:eventos", "ingreso_contraseña", %{texto: "Presionaste el boton"}
        iniciar_teclado()
      {:gpio_interrupt, ^gpio_button_number, :falling} ->
        Ui.Endpoint.broadcast! "teclado:eventos", "ingreso_contraseña", %{texto: "Soltaste el teclado"}
    end
    loop_button(gpio_button_number)
  end

  def esperar_teclado({:procesando, texto_acumulado}, tiempo_acumulado) when tiempo_acumulado<120000 do  ##2 minutos de tolerancia
    :timer.sleep(20)
    Fw.Teclado.cambiar_estado()
      |> procesar_respuesta(texto_acumulado)
      |> esperar_teclado(tiempo_acumulado+20)
  end

  def esperar_teclado({:procesando, _texto_acumulado}, _tiempo_acumulado) do  ## Se paso el limite del tiempo
    :timer.sleep(20)
    Fw.Teclado.terminar()
  end

  def esperar_teclado({:terminado, texto_acumulado}, _tiempo_acumulado) do  ## Se obtuvieron los 6 digitos
    :timer.sleep(20)
    Ui.Endpoint.broadcast! "teclado:eventos", "ingreso_contraseña", %{texto: texto_acumulado}
  end

  def procesar_respuesta({:procesando, nil}, texto_acumulado), do: {:procesando, texto_acumulado}
  def procesar_respuesta({:procesando, letra}, texto_acumulado), do: {:procesando, texto_acumulado<>letra}
  def procesar_respuesta({:terminado, letra}, texto_acumulado), do: {:terminado, texto_acumulado<>letra}
end
