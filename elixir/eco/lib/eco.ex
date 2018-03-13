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
      preferences: (for prod <- products, do: {prod.id, :rand.uniform(10)/10}),
      produce: (for prod <- products, do: {prod.id, 0}),
      resources: (for prod <- products, do: {prod.id, 0}),
      productionProportion: 0.5
    }}
  end

  def handle_info(:tick, state) do
    {id, {amount, cost}} = produce(state)
    newAmount = :proplists.get_value(id, state.produce, 0) + amount
    newProduce = :proplists.delete(id, state.produce) ++ [{id, amount}]
    {:noreply, %{state | :produce => newProduce}}
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
	  ({_newId, {x, newCost}}, {_id, {max, _}} = acc) when x <= max -> acc
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

  def handle_call(:get_cycle, _from, state) do
    {:reply, {:ok, state.cycle}, state}
  end

  def handle_cast({:sell_order, productId, number, pricePerProduct}, state) do
    
  end

  def get_cycle(marketId) do
    GenServer.call(marketId, :get_cycle)
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

