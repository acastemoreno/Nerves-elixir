defmodule Fw.Alarma do
  use GenServer
  alias ElixirALE.GPIO

  ## API
  ####

  def start_link(gpio_normal, gpio_alerta, gpio_intruso, gpio_sensor) do
    GenServer.start_link(__MODULE__, [gpio_normal, gpio_alerta, gpio_intruso, gpio_sensor], name: __MODULE__)
  end

  def cambiar_estado(texto_acumulado) do
    GenServer.call(__MODULE__, {:cambiar_estado, texto_acumulado})
  end

  def intruso?() do
    GenServer.call(__MODULE__, :intruso?)
  end

  ## Implementación GenServer
  ####

  def init([gpio_normal, gpio_alerta, gpio_intruso, gpio_sensor]) do
    {:ok, pid_normal} = GPIO.start_link(gpio_normal, :output)
    {:ok, pid_alerta} = GPIO.start_link(gpio_alerta, :output)
    {:ok, pid_intruso} = GPIO.start_link(gpio_intruso, :output)
    {:ok, pid_sensor} = GPIO.start_link(gpio_sensor, :input)
    GPIO.write(pid_normal, 1)
    {:ok, %{pid_normal: pid_normal, pid_alerta: pid_alerta, pid_intruso: pid_intruso, sensor: {pid_sensor, gpio_sensor}, password: "123456", estado: :normal}}
  end

  def handle_call({:cambiar_estado, texto_acumulado}, _from, estado = %{estado: :normal, password: password, pid_normal: pid_normal, pid_alerta: pid_alerta, sensor: {pid_sensor, gpio_sensor}}) when texto_acumulado == password do
    spawn fn -> esperar_sensor(pid_normal, {pid_sensor, gpio_sensor}, pid_alerta) end
    {:reply, :esperando, estado |> Map.put(:estado, :esperando)}
  end

  def handle_call({:cambiar_estado, texto_acumulado}, _from, estado = %{estado: :normal, password: password}) when texto_acumulado != password do
    {:reply, :normal, estado}
  end

  def handle_call({:cambiar_estado, texto_acumulado}, _from, estado = %{estado: :esperando, password: password, pid_normal: pid_normal, pid_alerta: pid_alerta}) when texto_acumulado == password do
    GPIO.write(pid_alerta, 0)
    GPIO.write(pid_normal, 1)
    {:reply, :esperando, estado |> Map.put(:estado, :normal)}
  end

  def handle_call({:cambiar_estado, texto_acumulado}, _from, estado = %{estado: :esperando, password: password}) when texto_acumulado != password do
    {:reply, :esperando, estado}
  end

  def handle_call({:cambiar_estado, texto_acumulado}, _from, estado = %{estado: :intruso, password: password, pid_normal: pid_normal, pid_intruso: pid_intruso}) when texto_acumulado == password do
    GPIO.write(pid_intruso, 0)
    GPIO.write(pid_normal, 1)
    {:reply, :esperando, estado |> Map.put(:estado, :normal)}
  end

  def handle_call({:cambiar_estado, texto_acumulado}, _from, estado = %{estado: :intruso, password: password}) when texto_acumulado != password do
    {:reply, :intruso, estado}
  end

  def handle_call(:intruso?, _from, estado = %{estado: :esperando, pid_alerta: pid_alerta, pid_intruso: pid_intruso}) do
    GPIO.write(pid_alerta, 0)
    GPIO.write(pid_intruso, 1)
    {:reply, :normal, estado |> Map.put(:estado, :intruso)}
  end

  def handle_call(:intruso?, _from, estado = %{estado: :normal}) do
    {:reply, :normal, estado}
  end

  defp esperar_sensor(pid_normal, {pid_sensor, gpio_sensor}, pid_alerta) do
    spawn fn -> tintinear_pid_normal(pid_normal, 0) end
    :timer.sleep(10000)
    Ui.Endpoint.broadcast! "teclado:eventos", "ingreso_contraseña", %{texto: "Tiempo 20 seg"}
    GPIO.set_int(pid_sensor, :both)
    receive do
      {:gpio_interrupt, ^gpio_sensor, :rising} ->  ## Detecto movimiento
        Ui.Endpoint.broadcast! "teclado:eventos", "ingreso_contraseña", %{texto: "Rising"}
        GPIO.write(pid_alerta, 1)
        Ui.Endpoint.broadcast! "teclado:eventos", "ingreso_contraseña", %{texto: "Esperando tiempo"}
        :timer.sleep(25000)
        intruso?()
    end
    GPIO.set_int(pid_sensor, :none)
  end

  defp tintinear_pid_normal(pid_normal, 10000) do
    GPIO.write(pid_normal, 0)
  end

  defp tintinear_pid_normal(pid_normal, acc) when acc<10000 do
    GPIO.write(pid_normal, 0)
    :timer.sleep(500)
    GPIO.write(pid_normal, 1)
    :timer.sleep(500)
    tintinear_pid_normal(pid_normal, acc+1000)
  end
end
