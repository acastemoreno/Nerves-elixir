defmodule Fw.TecladoManager do
  use GenServer
  alias ElixirALE.GPIO

  ## API
  ####

  def start_link(gpio_button_number, gpio_led_teclado) do
    GenServer.start_link(__MODULE__, [gpio_button_number, gpio_led_teclado], name: __MODULE__)
  end

  def iniciar_teclado() do
    GenServer.call(__MODULE__, :iniciar_teclado)
  end

  def hacer_disponible() do
    GenServer.call(__MODULE__, :hacer_disponible)
  end

  ## Implementación GenServer
  ####

  def init([gpio_button_number, gpio_led_teclado]) do
    {:ok, pid_in} = GPIO.start_link(gpio_button_number, :input)
    {:ok, pid_led_teclado} = GPIO.start_link(gpio_led_teclado, :output)
    spawn fn -> loop(gpio_button_number, pid_in) end
    {:ok, %{estado: :disponible, pid_led_teclado: pid_led_teclado}}
  end

  def handle_call(:iniciar_teclado, _from, estado = %{estado: :disponible, pid_led_teclado: pid_led_teclado}) do
    GPIO.write(pid_led_teclado, 1)
    Ui.Endpoint.broadcast! "teclado:eventos", "ingreso_contraseña", %{texto: "Presionaste por primera vez"}
    spawn fn -> esperar_teclado({:procesando, ""}, 0, pid_led_teclado) end
    {:reply, :iniciando, estado |> Map.put(:estado, :procesando)}
  end

  def handle_call(:iniciar_teclado, _from, estado = %{estado: :procesando}) do
    {:reply, :procesando, estado}
  end

  def handle_call(:hacer_disponible, _from, estado = %{estado: :procesando}) do
    Ui.Endpoint.broadcast! "teclado:eventos", "ingreso_contraseña", %{texto: "Nuevamente disponible"}
    {:reply, :procesando, estado |> Map.put(:estado, :disponible)}
  end

  ## Implementación Loop
  ####

  def loop(gpio_button_number, pid_in) do
    GPIO.set_int(pid_in, :both)
    do_loop(gpio_button_number, pid_in)
  end

  def do_loop(gpio_button_number, pid_in) do
    receive do
      {:gpio_interrupt, ^gpio_button_number, :falling} ->
        iniciar_teclado()
    end
    do_loop(gpio_button_number, pid_in)
  end

  def esperar_teclado({:procesando, _texto_acumulado}, tiempo_acumulado, pid_led_teclado) when tiempo_acumulado>=20000 do  ## Se paso el limite del tiempo
    :timer.sleep(100)
    Ui.Endpoint.broadcast! "teclado:eventos", "ingreso_contraseña", %{texto: "Apagando Led"}
    GPIO.write(pid_led_teclado, 0)
    Fw.Teclado.terminar()
    hacer_disponible()
  end

  def esperar_teclado({:procesando, texto_acumulado}, tiempo_acumulado, pid_led_teclado) when tiempo_acumulado<20000 do  ##2 minutos de tolerancia 120000
    :timer.sleep(100)
    Ui.Endpoint.broadcast! "teclado:eventos", "ingreso_contraseña", %{texto: "#{tiempo_acumulado+100}"}
    respuesta = Fw.Teclado.cambiar_estado()
      |> procesar_respuesta(texto_acumulado)
    Ui.Endpoint.broadcast! "teclado:eventos", "ingreso_contraseña", %{texto: "Respuesta Recibida"}
    esperar_teclado(respuesta, tiempo_acumulado+100, pid_led_teclado)
  end

  def esperar_teclado({:terminado, texto_acumulado}, _tiempo_acumulado, pid_led_teclado) do  ## Se obtuvieron los 6 digitos
    :timer.sleep(100)
    Ui.Endpoint.broadcast! "teclado:eventos", "ingreso_contraseña", %{texto: texto_acumulado}
    GPIO.write(pid_led_teclado, 0)
    Fw.Alarma.cambiar_estado(texto_acumulado)
    hacer_disponible()
  end

  def procesar_respuesta({:procesando, nil}, texto_acumulado) do
    Ui.Endpoint.broadcast! "teclado:eventos", "ingreso_contraseña", %{texto: "Texto acumulado: #{texto_acumulado}"}
    {:procesando, texto_acumulado}
  end

  def procesar_respuesta({:procesando, letra}, texto_acumulado) do
    Ui.Endpoint.broadcast! "teclado:eventos", "ingreso_contraseña", %{texto: "Texto acumulado: #{texto_acumulado}"}
    {:procesando, texto_acumulado<>letra}
  end

  def procesar_respuesta({:terminado, letra}, texto_acumulado) do
    Ui.Endpoint.broadcast! "teclado:eventos", "ingreso_contraseña", %{texto: "Texto acumulado: #{texto_acumulado}"}
    {:terminado, texto_acumulado<>letra}
  end

  def procesar_respuesta(:ningun_caso, texto_acumulado) do
    Ui.Endpoint.broadcast! "teclado:eventos", "ingreso_contraseña", %{texto: "Ningun caso: #{texto_acumulado}"}
    {:terminado, texto_acumulado}
  end
end
