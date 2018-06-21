defmodule Bot do

  defstruct(
    prefs: [],
    prods: [],
    money: 0,
    inventory: %{},
    labour: 0,
    turn: 0
  )
  
  
  def start_link() do
    GenServer.start_link(__MODULE__, [], [])
  end

  def init([]) do
    prodIds = for {id, _} <- Application.get_env(:eco, :products), do: id
    # prepare inventory
    inventory = List.foldl(prodIds, %{},
      fn(elem, acc) ->
	Map.put(acc, elem, 0)
      end)
    # prepare productivities
    prods = List.foldl(prodIds, %{},
      fn(elem, acc) ->
	Map.put(acc, elem, :rand.uniform)
      end)
    maxLabour = Application.get_env(:eco, :max_labour)
    {:ok, %Bot{
	prefs: generate_preferences(prodIds),
	prods: prods,
	inventory: inventory,
	money: 1000,
	labour: maxLabour
     }}
  end

  def handle_info({:won, productId, amount, ppu}, state) do
    paid = ppu * amount
    newAmount = state.inventory[productId] + amount
    newInventory = %{state.inventory | :productId => newAmount}
    {:noreply, %{state |
		 :money => state.money - paid,
		 :inventory => newInventory}}
  end
  
  def handle_info({:sold, _productId, amount, ppu}, state) do
    money = state.money + (amount * ppu)
    {:noreply, %{state |
		 :money => money}}
  end

  def handle_info(:tick, state) do
    prodId = get_best_production_option(state)
    newState = create(prodId, state)
    {:noreply, newState}
  end
  
  #generate prefences adding up to 1
  def generate_preferences(prodIds) do
    nums = for _ <- 1..length(prodIds), do: :rand.uniform
    sum = Enum.sum(nums)

    prefs = (for n <- nums, do: n / sum)
    List.zip([prodIds, prefs])
    |> List.foldl(%{},
      fn({k, v}, prefMap) ->
	Map.put(prefMap, k, v)
      end)
  end

  def get_best_production_option(%Bot{turn: 0} = state) do
    state.prods
  end

  def get_best_production_option(state) do
    products = Application.get_env(:eco, :products)

    creatables = for {id, product} <- products,
    (can_create(product, state) > 0),
      do: {id, product}

    [prevTurn | rest] = TurnMarket.get_past_turns()

    # group amounts: %{prodId => [amount, . . .]}
    groupedAsks = Enum.group_by(prevTurn.asks,
      fn({_, {prodId, _, _}}) -> prodId end,
      fn({_, {_, _, amount, _}}) -> amount end)

    # sum amounts of products left: [prodId: spare, . . .]
    summedGroupedAsks = for {prodId, amounts} <- groupedAsks,
      do: {prodId, Enum.sum(amounts)}

    # sorted product excess. Low to high
    productExcesses = Enum.sort(summedGroupedAsks,
      fn({_, amount1}, {_, amount2}) ->
	amount1 > amount2
      end)

    creatable = for {prodId, _} <- productExcesses,
      do: {prodId, can_create(get_product_by_id(prodId), state)}

    
    case length(creatable) do
      0 ->
	nil
      _ ->
	[{prodId, _} | _] = creatable
	prodId
    end
  end
  
  
  def can_create(product, state) do
    case product.raw do
      true ->
	:math.floor(state.labour / product.labour_cost)
      false ->
	0.0
    end
  end


  def create(productId, state) do
    product = (Application.get_env(:eco, :products))[productId]
    if product.raw do
      amount = :math.floor(state.labour / product.labour_cost)
      labour_cost = amount * product.labour_cost
      %{state |
	:labour => state.labour - labour_cost,
	:inventory => %{state.inventory |
			productId => amount}}
    else
      state
    end
  end

  
  def get_product_by_id(prodId) do
    (Application.get_env(:eco, :products))[prodId]
  end 
  
end
