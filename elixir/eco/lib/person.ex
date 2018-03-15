defmodule Person do
  use GenServer

  def start_link(id) do
    GenServer.start_link(__MODULE__, [id], [])
  end

  def init([id]) do
    GenServer.cast(Bank, {:open_account, id, 10000})
    {:ok, products} = Application.fetch_env(:eco, :products)
    
    {:ok, %{
      id: id,
      labour: 1000, 
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
    {:noreply, state}
  end

  def handle_cast({:async_debit, amount}, state) do
    GenServer.call(Bank, {:withdraw, state.id, amount})
    {:noreply, state}
  end

  def handle_call({:debit, amount}, _from, state) do
    result = GenServer.call(Bank, {:withdraw, state.id, amount})
    {:reply, result, state}
  end

  def handle_info(:tick, state) do
    send(self(), :produce)
    {:noreply, state}
  end

  def handle_info(:produce, state) do
    {id, {amount, cost}} = produce(state)
    newAmount = :proplists.get_value(id, state.produce, 0) + amount
    newProduce = :proplists.delete(id, state.produce) ++ [{id, newAmount}]
    sellPrice = get_sell_price(state)
    GenServer.cast(Market, {self(), {:sell_order, id, newAmount, sellPrice}})
    {:noreply, %{state | :produce => newProduce, :labour => state.labour - cost}}
  end

  def handle_info(:consume, state) do
    {:ok, liquidity} = GenServer.call(Bank, {:get_funds, state.id})
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
    for bid <- bids, bid != :no_buy, Keyword.get(bid, :amount),
      do: Market.place_bid(Market,
                           Keyword.get(bid, :id),
			   Keyword.get(bid, :ppp),
			   Keyword.get(bid, :amount))
    {:noreply, state}
  end

  defp get_sell_price(state) do
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
