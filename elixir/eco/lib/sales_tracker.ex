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

  def reg_ask(trackerPid, askId, ppu, amount, productId) do
    GenServer.cast(trackerPid, {:reg_ask, askId, ppu, amount, productId})
    :ok
  end

  def reg_sale(trackerPid, askId, amount) do
    GenServer.cast(trackerPid, {:reg_sale, askId, amount})
    :ok
  end

  def get_most_successfull_price_for_product(trackerPid, productId) do
    case GenServer.call(trackerPid, {:most_succ_price, productId}) do
      nil ->
        nil
      askData ->
        askData.ppu
    end
  end

  def get_product_ids(trackerPid) do
    GenServer.call(trackerPid, :uniq_product_ids)
  end

  def handle_cast({:reg_sale, askId, amount}, state) do
    sold = state.asks_sales_data[askId].sold + amount
    asksData = state.asks_sales_data
    data = put_in(asksData[askId].sold, sold)

    {:noreply, %{state | asks_sales_data: data}}
  end

  def handle_cast({:reg_ask, askId, ppu, amount, productId}, state) do
    data = state.asks_sales_data
    |> Map.put(askId, %{ppu: ppu, amount: amount, sold: 0, prod_id: productId})

    {:noreply, %{state | asks_sales_data: data}}
  end

  def handle_call({:most_succ_price, productId}, _from, state) do
    res = state.asks_sales_data
    |> Enum.reduce([], fn({_askId, %{prod_id: prodId} = askData}, acc) ->
      if prodId == productId do
        [askData | acc]
      else
        acc
      end
    end)
    |> Enum.sort(&(&1.ppu > &2.ppu))
    |> Enum.find(&(0 == (&1[:amount] - &1[:sold])))

    {:reply, res, state}
  end

  def handle_call(:uniq_product_ids, _, state) do
    prodIds = state.asks_sales_data
    |> Stream.uniq_by(fn({_, %{prod_id: prodId}}) -> prodId end)
    |> Stream.map(fn({_, %{prod_id: prodId}}) -> prodId end)
    |> Enum.to_list

    {:reply, prodIds, state}
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