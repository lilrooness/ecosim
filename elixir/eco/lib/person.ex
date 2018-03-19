defmodule Person do
  use GenServer

  def start_link(id) do
    GenServer.start_link(__MODULE__, [id], [])
  end

  def init([id]) do
    {:ok, products} = Application.fetch_env(:eco, :products)
    send(self(), {:open_bank_acount, 10000})
    {:ok, %{
      id: id,
      labour: 1000, 
      liquidity_tracker: 0,
      productivities: random_productivities(products),
      preferences: random_preferences(products),
      produce: (for prod <- products, do: {prod.id, 0}),
      resources: (for prod <- products, do: {prod.id, 0}),
      productionProportion: 0.5
    }}
  end

  def handle_cast({:produce_sold, id, amount}, state) do
    newAmount = :proplists.get_value(id, state.produce) - amount
    newProduce = :proplists.delete(id, state.produce) ++ [{id, newAmount}]
    {:noreply, %{state | :produce => newProduce}}
  end

  def handle_cast({:credit, amount}, state) do
    GenServer.cast(Bank, {:deposit, state.id, amount})
    {:noreply, %{state | :liquidity_tracker => state.liquidity_tracker + amount}}
  end

  def handle_cast({:tracking_debit, amount}, state) do
    GenServer.call(Bank, {:withdraw, state.id, amount})
    {:noreply, %{state | :liquidity_tracker => state.liquidity - amount}}
  end

  def handle_cast({:debit, amount}, state) do
    GenServer.call(Bank, {:withdraw, state.id, amount})
    {:noreply, state}
  end
 
  def handle_info({:open_bank_acount, liquidity}, state) do
    GenServer.cast(Bank, {:open_account, state.id, liquidity})
    {:noreply, %{state | :liquidity_tracker => liquidity}}
  end

  def handle_info({:tick_produce, caller}, state) do
    onDone = fn ->
      send(caller, :tick_complete) 
    end
    send(self(), {:produce, onDone})
    {:noreply, state}
  end

  def handle_info({:tick_consume, caller}, state) do
    onDone = fn -> send(caller, :tick_complete) end
    send(self(), {:consume, onDone})
    {:noreply, state}
  end

  def handle_info({:produce, onDone}, state) do
    {id, {amount, _cost}} = produce(state)
    newAmount = :proplists.get_value(id, state.produce, 0) + amount
    newProduce = :proplists.delete(id, state.produce) ++ [{id, newAmount}]
    sellPrice = get_sell_price(state)
    GenServer.cast(Market, {self(), {:sell_order, id, newAmount, sellPrice}})
    onDone.()
    {:noreply, %{state | :produce => newProduce}}
  end

  def handle_info({:consume, onDone}, state) do
    liquidity = state.liquidity_tracker
    maxSpend = liquidity - liquidity*state.productionProportion
    # state.preferences all should add up to 1
    spendingVector = (for {id, pref} <- state.preferences, do: {id, pref * maxSpend})
    amountsfun = fn(id, spend) ->
      case Market.get_avg_price(Market, id) do
        {:ok, 0} ->
          :no_buy
        {:ok, avg} ->
          # willing to pay a normal distribution around the average price  
	  ppp = :rand.normal(avg, avg/2)
	  [ppp: ppp, amount: trunc(spend / ppp), id: id]
      end
    end
    bids = (for {id, spend} <- spendingVector, do: amountsfun.(id, spend))
    biddingResults = for bid <- bids, bid != :no_buy, Keyword.get(bid, :amount),
      do: Market.place_bid(Market,
                           Keyword.get(bid, :id),
			   Keyword.get(bid, :ppp),
			   Keyword.get(bid, :amount))
    actualSpend = Enum.sum(for {_, s} <- biddingResults, do: s)
    onDone.()
    {:noreply, %{state | :liquidity_tracker => state.liquidity_tracker - actualSpend}}
  end

  defp get_sell_price(_state) do
    case Market.get_cycle(Market) do
      {:ok, 0} ->
        :rand.normal(200, 90)
      {:ok, _} ->
        :rand.normal(200, 90)
    end
  end

  defp produce(state) do
    {:ok, products} = Application.fetch_env(:eco, :products)
    case Market.get_cycle(Market) do
      {:ok, 0} ->
        costs = Products.get_production_costs(products,state.resources,
                                              state.labour,
                                              state.productivities)
         
	maxfun = fn
	  (e, []) -> e
	  ({newId, {x, newCost}}, {_id, {max, _}} = _acc) when x > max -> {newId, {x, newCost}}
	  ({_, {x, _}}, {_id, {max, _}} = acc) when x <= max -> acc
	end
	List.foldl((for {id, {amount, cost}} <- costs, do: {id, {amount, cost}}),[], maxfun)
      {:ok, _} ->
        []
    end
  end
 
  def child_spec([id]) do
    %{
      id: id,
      restart: :permanent,
      shutdown: 5000,
      start: {__MODULE__, :start_link, [id]},
      type: :worker
    }
  end

  defp random_productivities(products) do
    randomVals = for _ <- 1..length(products), do: :rand.uniform(10)
    sum = List.foldl(randomVals, 0, &(&1 + &2))
    for {n, prod} <- List.zip([randomVals, products]), do: {prod.id, n/sum}
  end

  defp random_preferences(products) do
    randomVals = for _ <- 1..length(products), do: :rand.uniform(10)
    sum = List.foldl(randomVals, 0, &(&1 + &2))
    for {n, prod} <- List.zip([randomVals, products]), do: {prod.id, n/sum}
  end
end
