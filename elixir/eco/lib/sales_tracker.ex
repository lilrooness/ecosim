defmodule SalesTracker do
  @behaviour GenServer

  defstruct(
    asks_sales_data: %{}
  )

  def start_link do
    GenServer.start_link(__MODULE__, [], [])
  end

  def start do
    GenServer.start(__MODULE__, [], [])
  end

  def init([]) do
    {:ok, %SalesTracker{}}
  end

  def reg_ask(pId, askId, ppu, amount) do
    GenServer.cast(pId, {:reg_ask, askId, ppu, amount})
    :ok
  end

  def reg_sale(pId, askId, amount) do
    GenServer.cast(pId, {:reg_sale, askId, amount})
    :ok
  end

  def handle_cast({:reg_sale, askId, amount}, state) do
    sold = state.asks_sales_data[askId].sold + amount
    asksData = state.asks_sales_data
    data = put_in(asksData[askId].sold, sold)

    {:noreply, %{state | asks_sales_data: data}}
  end

  def handle_cast({:reg_ask, askId, ppu, amount}, state) do
    data = state.asks_sales_data
    |> Map.put(askId, %{ppu: ppu, amount: amount, sold: 0})

    {:noreply, %{state | asks_sales_data: data}}
  end

  def handle_call(_, _, state) do
    {:reply, :ok, state}
  end

  def handle_info(_, state) do
    {:noreply, state}
  end

  def code_change(_, state, _) do
    {:ok, state}
  end

  def terminate(_, _) do
    :ok
  end
end