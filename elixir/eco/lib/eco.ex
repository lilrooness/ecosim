defmodule Eco do
  use Application
  def start(_type, _args) do
    EcoSupervisor.start_link()
  end
end

defmodule EcoSupervisor do
  use Supervisor

  def start_link() do
    Supervisor.start_link(__MODULE__, [], [name: __MODULE__])
  end

  def init([]) do

    children = [
      {Market, []},
      {BankSupervisor, []},
      {PeopleSupervisor, [1000]}
    ]
    Supervisor.init(children, strategy: :rest_for_one)
  end
end

defmodule Bank do
  use GenServer

  def start_link(id) do
    GenServer.start_link(__MODULE__, [id], [name: __MODULE__])
  end

  def init([id]) do
    {:ok, %{
      id: id,
      liquididy: 10000,
      liability: 0,
      accounts: %{},
      loans: []
    }}
  end

  def handle_cast({:open_account, id, funds}, state) do
    {:noreply, %{state | :accounts => Map.merge(state.accounts, %{id => funds})}}
  end

  def handle_cast({:deposit, id, funds}, state) do
    {:noreply,
      %{state | :accounts =>
        %{state.accounts | id => funds + state.accounts[id]}}}
  end

  def handle_call({:withdraw, id, funds}, _from, state) do
    if state.accounts[id] >= funds do
      {:reply, {:ok, funds},
        %{state | :accounts =>
	  %{state.accounts | id => state.accounts[id] - funds}}}
    else
      {:reply, {:error, :not_enough_funds}, state}
    end
  end

  def handle_call({:get_funds, id}, _from, state) do
    {:reply, {:ok, state.accounts[id]}, state}
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
end

defmodule Market do
  use GenServer

  def start_link([]) do
    GenServer.start_link(__MODULE__, [], [name: __MODULE__])
  end

  def init([]) do
    {:ok, %{
      buy_orders: [],
      sell_orders: [],
      cycle: 0
    }}
  end

  def handle_cast({from, {:sell_order, productId, number, pricePerProduct}}, state) do
    uuid = UUID.uuid1()
    {:noreply, %{state | 
      :sell_orders => state.sell_orders ++ [{uuid, {productId, {pricePerProduct, number}, from}}]
    }}
  end

  def handle_cast({from, {:buy_order, productId, number, pricePerProduct}}, state) do
    uuid = UUID.uuid1()
    {:noreply, %{state | 
      :buy_orders => state.buy_orders ++ [{uuid, {productId, {pricePerProduct, number}, from}}]
    }}
  end

  def handle_cast({:sell_product, sellId, amount, buyerPid}, state) do
    case :proplists.get_value(sellId, state.sell_orders) do
      :undefined ->
        :ok
      item ->
        {prodId, {price, _availableAmount}, sellerPid} = item
        funds = amount * price
	if funds == 0 do
	  IO.puts("funds: " <> inspect(funds))
          IO.puts("amount: " <> inspect(amount))
	  IO.puts("price: " <> inspect(price))
	end
	GenServer.cast(buyerPid, {:async_debit, funds})
	GenServer.cast(sellerPid, {:credit, funds})
	GenServer.cast(sellerPid, {:produce_sold, prodId, amount})
    
    end
    {:noreply, state}
  end

  def handle_call({:bid, {productId, bidPrice, amount}}, {from, _ref}, state) do
    {sold, purchased, spent}= List.foldl(state.sell_orders, {_sold=[], _purchased=0, _spent=0}, 
        fn(sellItem, {sold, purchased, spent}) ->
      {sellId, {sellProdId, {sellPrice, available}, _sellerPid}} = sellItem
      case sellPrice <= bidPrice && sellProdId == productId do
        true ->
          amountWanted = amount - purchased
          cond do
            amountWanted == 0 || available == 0 ->
              {sold ++ [0], purchased, spent}
            available >= amountWanted ->
              GenServer.cast(self(), {:sell_product, sellId, amountWanted, from})
              {sold ++ [amountWanted], amount, spent + amountWanted * sellPrice}
            available <= amountWanted ->
              GenServer.cast(self(), {:sell_product, sellId, available, from})
              {sold ++ [available], purchased + available, spent + available * sellPrice}
          end
        false ->
          {sold ++ [0], purchased, spent}
      end
    end)
    newSellOrders = for {sellAmount, _order = {uuid, {prodId, {price, available}, sellerPid}}}
        <- List.zip([sold, state.sell_orders]), do:
	{uuid, {prodId, {price, available - sellAmount}, sellerPid}}
    {:reply, {purchased, spent}, %{state | :sell_orders => newSellOrders}}
  end

  def handle_call(:get_cycle, _from, state) do
    {:reply, {:ok, state.cycle}, state}
  end

  def handle_call({:get_average_price, prodId}, _from, state) do
    prices = for {_uuid, {id, {price, _}, _}} <- state.sell_orders, id == prodId, do: price
    avg = case prices do
      [] ->
        0
      _ ->
        Enum.sum(prices) / length(prices)
    end
    {:reply, {:ok, avg}, state}
  end

  def get_cycle(marketId) do
    GenServer.call(marketId, :get_cycle)
  end

  def get_avg_price(marketId, prodId) do
    GenServer.call(marketId, {:get_average_price, prodId})
  end

  def place_bid(marketId, id, ppp, amount) do
    GenServer.call(marketId, {:bid, {id, ppp, amount}})
  end

  def child_spec() do
    %{
      id: __MODULE__,
      restart: :permanent,
      shutdown: 5000,
      start: {__MODULE__, :start_link, []},
      type: :worker
    }
  end
end

defmodule BankSupervisor do
  use Supervisor

  def start_link([]) do
    Supervisor.start_link(__MODULE__, [], [name: __MODULE__])
  end

  def init([]) do
    children = [{Bank, [1]}]
    Supervisor.init(children, strategy: :one_for_all)
  end

  def child_spec() do
    %{
      id: __MODULE__,
      restart: :permanent,
      shutdown: 5000,
      start: {__MODULE__, :start_link, []},
      type: :supervisor
    }
  end
end

defmodule PeopleSupervisor do
  use Supervisor

  def start_link([npeople]) do
    Supervisor.start_link(__MODULE__, [npeople], [name: __MODULE__])
  end
  
  def init([npeople]) do
    children = for id <- 1 .. npeople, do: {Person, [id]}
    Supervisor.init(children, strategy: :one_for_all)
  end

  def tick() do
    for {_, pid, _, _} <- Supervisor.which_children(__MODULE__), do: send(pid, :tick)
  end

  def consume() do
    for {_, pid, _, _} <- Supervisor.which_children(__MODULE__), do: send(pid, :consume)
  end

  def child_spec(nPeople) do
    %{
      id: __MODULE__,
      restart: :permanent,
      shutdown: 5000,
      start: {__MODULE__, :start_link, [nPeople]},
      type: :supervisor
    }
  end
end

