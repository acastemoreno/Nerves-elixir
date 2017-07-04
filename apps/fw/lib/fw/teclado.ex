defmodule Fw.Teclado do
  use GenServer
  alias ElixirALE.GPIO

  ## API
  ####

  def start_link(gpio_output, gpio_input, gpio_led_tecla) do
    GenServer.start_link(__MODULE__, [gpio_output, gpio_input, gpio_led_tecla], name: __MODULE__)
  end

  def cambiar_estado() do
    GenServer.call(__MODULE__, :cambiar_estado)
  end

  def terminar() do
    GenServer.call(__MODULE__, :terminar)
  end

  ## Implementación GenServer
  ####

  def init([{output1, output2, output3, output4}, {input1, input2, input3, input4}, gpio_led_tecla]) do
    {:ok, pin_out1} = GPIO.start_link(output1, :output)
    {:ok, pin_out2} = GPIO.start_link(output2, :output)
    {:ok, pin_out3} = GPIO.start_link(output3, :output)
    {:ok, pin_out4} = GPIO.start_link(output4, :output)
    {:ok, pid_led_tecla} = GPIO.start_link(gpio_led_tecla, :output)
    GPIO.write(pin_out1, 0)
    GPIO.write(pin_out2, 0)
    GPIO.write(pin_out3, 0)
    GPIO.write(pin_out4, 0)
    {:ok, pin_in1} = GPIO.start_link(input1, :input)
    {:ok, pin_in2} = GPIO.start_link(input2, :input)
    {:ok, pin_in3} = GPIO.start_link(input3, :input)
    {:ok, pin_in4} = GPIO.start_link(input4, :input)
    {:ok, %{o1: pin_out1, o2: pin_out2, o3: pin_out3, o4: pin_out4, outputs: [pin_in1, pin_in2, pin_in3, pin_in4], pid_led_tecla: pid_led_tecla, estado: :disponible, paso: {:o1, 0}, last_hit: nil}}
  end

  def handle_call(:cambiar_estado, _from, estado = %{o1: pin_out1, paso: {:o1, longitud_texto}, outputs: [pin_in1, pin_in2, pin_in3, pin_in4], last_hit: last_hit, estado: :disponible, pid_led_tecla: pid_led_tecla}) do
    GPIO.write(pin_out1, 1)
    letra = numero_letra?({1,0,0,0}, {GPIO.read(pin_in1), GPIO.read(pin_in2), GPIO.read(pin_in3), GPIO.read(pin_in4)})
    letra |> String.length
          |> siguiente?(estado, longitud_texto, :o1, :o2, {last_hit, letra}, pid_led_tecla)
  end

  def handle_call(:cambiar_estado, _from, estado = %{o4: pin_out4, o1: pin_out1, paso: {:o1, longitud_texto}, outputs: [pin_in1, pin_in2, pin_in3, pin_in4], last_hit: last_hit, estado: :procesando, pid_led_tecla: pid_led_tecla}) do
    GPIO.write(pin_out4, 0)
    GPIO.write(pin_out1, 1)
    letra = numero_letra?({1,0,0,0}, {GPIO.read(pin_in1), GPIO.read(pin_in2), GPIO.read(pin_in3), GPIO.read(pin_in4)})
    letra |> String.length
          |> siguiente?(estado, longitud_texto, :o1, :o2, {last_hit, letra}, pid_led_tecla)

  end

  def handle_call(:cambiar_estado, _from, estado = %{o1: pin_out1, o2: pin_out2, paso: {:o2, longitud_texto}, outputs: [pin_in1, pin_in2, pin_in3, pin_in4], last_hit: last_hit, estado: :procesando, pid_led_tecla: pid_led_tecla}) do
    GPIO.write(pin_out1, 0)
    GPIO.write(pin_out2, 1)
    letra = numero_letra?({0,1,0,0}, {GPIO.read(pin_in1), GPIO.read(pin_in2), GPIO.read(pin_in3), GPIO.read(pin_in4)})
    letra |> String.length
          |> siguiente?(estado, longitud_texto, :o2, :o3, {last_hit, letra}, pid_led_tecla)

  end

  def handle_call(:cambiar_estado, _from, estado = %{o2: pin_out2, o3: pin_out3, paso: {:o3, longitud_texto}, outputs: [pin_in1, pin_in2, pin_in3, pin_in4], last_hit: last_hit, estado: :procesando, pid_led_tecla: pid_led_tecla}) do
    GPIO.write(pin_out2, 0)
    GPIO.write(pin_out3, 1)
    letra = numero_letra?({0,0,1,0}, {GPIO.read(pin_in1), GPIO.read(pin_in2), GPIO.read(pin_in3), GPIO.read(pin_in4)})
    letra |> String.length
          |> siguiente?(estado, longitud_texto, :o3, :o4, {last_hit, letra}, pid_led_tecla)

  end

  def handle_call(:cambiar_estado, _from, estado = %{o3: pin_out3, o4: pin_out4, paso: {:o4, longitud_texto}, outputs: [pin_in1, pin_in2, pin_in3, pin_in4], last_hit: last_hit, estado: :procesando, pid_led_tecla: pid_led_tecla}) do
    GPIO.write(pin_out3, 0)
    GPIO.write(pin_out4, 1)
    letra = numero_letra?({0,0,0,1}, {GPIO.read(pin_in1),GPIO.read(pin_in2),GPIO.read(pin_in3),GPIO.read(pin_in4)})
    letra |> String.length
          |> siguiente?(estado, longitud_texto, :o4, :o1, {last_hit, letra}, pid_led_tecla)

  end

  def handle_call(:cambiar_estado, _from, estado) do
    {:reply, :ningun_caso, estado}

  end

  def handle_call(:terminar, _from, estado) do
    {:reply, :terminado, estado |> Map.put(:estado, :disponible)
                                |> Map.put(:paso, {:o1, 0})
                                |> Map.put(:last_hit, nil)}
  end

  defp siguiente?(0, estado, longitud_texto, _paso_actual, siguiente_paso, {_last_hit, _letra}, pid_led_tecla) do  ## NO detecta ninguna letra, pasa a la siguiente fila
    GPIO.write(pid_led_tecla, 0)
    {:reply, {:procesando, nil}, estado |> Map.put(:estado, :procesando)
                                          |> Map.put(:paso, {siguiente_paso, longitud_texto})
                                          |> Map.put(:last_hit, nil)}
  end

  defp siguiente?(1, estado, longitud_texto, paso_actual, _siguiente_paso, {last_hit, letra}, _pid_led_tecla) when last_hit == letra do ## SI detecta letra, es el ultimo hit, sigue en paso actual, longitud igual
    {:reply, {:procesando, nil}, estado |> Map.put(:estado, :procesando)
                                        |> Map.put(:paso, {paso_actual, longitud_texto})}
  end

  defp siguiente?(1, estado, 5, _paso_actual, _siguiente_paso, {_last_hit, letra}, pid_led_tecla) do  ## SI detecta letra, no es el ultimo hit, sigue en paso actual, longitud + 1
    GPIO.write(pid_led_tecla, 0)
    {:reply, {:terminado, letra}, estado |> Map.put(:estado, :disponible)
                                          |> Map.put(:paso, {:o1, 0})
                                          |> Map.put(:last_hit, nil)}
  end

  defp siguiente?(1, estado, longitud_texto, paso_actual, _siguiente_paso, {_last_hit, letra}, pid_led_tecla) do  ## SI detecta letra, no es el ultimo hit, sigue en paso actual, longitud + 1
    GPIO.write(pid_led_tecla, 1)
    {:reply, {:procesando, letra}, estado |> Map.put(:estado, :procesando)
                                          |> Map.put(:paso, {paso_actual, longitud_texto+1})
                                          |> Map.put(:last_hit, letra)}
  end

  def numero_letra?(_, {0, 0, 0, 0}), do: ""
  def numero_letra?({1, 0, 0, 0}, {1, 0, 0, 0}), do: "1"
  def numero_letra?({1, 0, 0, 0}, {0, 1, 0, 0}), do: "2"
  def numero_letra?({1, 0, 0, 0}, {0, 0, 1, 0}), do: "3"
  def numero_letra?({1, 0, 0, 0}, {0, 0, 0, 1}), do: "A"
  def numero_letra?({0, 1, 0, 0}, {1, 0, 0, 0}), do: "4"
  def numero_letra?({0, 1, 0, 0}, {0, 1, 0, 0}), do: "5"
  def numero_letra?({0, 1, 0, 0}, {0, 0, 1, 0}), do: "6"
  def numero_letra?({0, 1, 0, 0}, {0, 0, 0, 1}), do: "B"
  def numero_letra?({0, 0, 1, 0}, {1, 0, 0, 0}), do: "7"
  def numero_letra?({0, 0, 1, 0}, {0, 1, 0, 0}), do: "8"
  def numero_letra?({0, 0, 1, 0}, {0, 0, 1, 0}), do: "9"
  def numero_letra?({0, 0, 1, 0}, {0, 0, 0, 1}), do: "C"
  def numero_letra?({0, 0, 0, 1}, {1, 0, 0, 0}), do: "*"
  def numero_letra?({0, 0, 0, 1}, {0, 1, 0, 0}), do: "0"
  def numero_letra?({0, 0, 0, 1}, {0, 0, 1, 0}), do: "#"
  def numero_letra?({0, 0, 0, 1}, {0, 0, 0, 1}), do: "D"
  def numero_letra?(_, _), do: ""
end
