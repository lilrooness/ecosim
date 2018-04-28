defmodule Person do
  use GenServer

  def start_link(id) do
    GenServer.start_link(__MODULE__, [id], [])
  end

  def init([id]) do
    products = for {id, _} <- Application.get_env(:eco, :products), do: id
    inventory = List.foldl(products, %{}, fn(elem, acc) ->
      Map.put(acc, elem, 0)
    end)
    {:ok, %{
      :funds => 1000,
      :max_labour => 1000,
      :labour => 1000,
      :id => id,
      :preferences => generate_preferences(products),
      :productivities => generate_productivities(products),
      :inventory => inventory,
      :product_path => false
    }}
  end

  def handle_info(:tick, state) do
    products = Application.get_env(:eco, :products)
    newState = consume(state) |> produce(products) |> auction
    {:noreply, newState}
  end

  def handle_info({:won, info}, state) do
    productId = info[:product_id]
    amount = info[:amount]
    newInventory = %{state.inventory | productId => state.inventory[productId] + amount}
    {:noreply, %{state | :inventory => newInventory}}
  end

  def handle_info({:lost, info}, state) do
    %{state | :funds => state.funds + info.total_spend}
  end

  def handle_info({:sold, info}, state) do
    productId = info[:product_id]
    amount = info[:amount]
    netGain = info[:net_gain]
    newInventory = %{state.inventory | productId => state.inventory[productId] - amount}
    {:noreply, %{state | :inventory => newInventory,
               :funds => state.funds + netGain}}
  end

  def consume(state) do
    labourNeeded = state.max_labour - state.labour
    {:ok, foodAsks} = SMarket.get_asks_of_type(SMarket, :food)
    sortedAsks = Enum.sort(foodAsks, fn({_, %{:unit_price => ap}} = _a, {_, %{:unit_price => bp}} = _b) ->
      ap >= bp
    end)
    newState = place_food_bids(sortedAsks, labourNeeded, state)
    %{newState | :labour => newState.labour + newState.inventory["calories"],
                 :inventory => %{newState.inventory | "calories" => 0}}
  end

  def auction(state) do
    prodIds = for {prodId, _} <- state.inventory, do: prodId
    auction_inventory(prodIds, state)
  end

  defp auction_inventory([], state) do
    state
  end

  defp auction_inventory([prodId| rest], state) do

    unitPrice = calculate_sell_price(prodId, state)

    if state.inventory[prodId] > 0 do
      SMarket.ask(SMarket, prodId, unitPrice, state.inventory[prodId], self())
    end

    newInventory = %{state.inventory | prodId => 0}
    auction_inventory(rest, %{state | :inventory => newInventory})
  end

  def calculate_sell_price(_produtId, _state) do
    1
  end

  def bid({askId, ask}, amount, state) do
    SMarket.bid(SMarket, askId, amount, amount * ask.unit_price, self())
    %{state | :funds => state.funds - (amount * ask.unit_price)}
  end

  def produce(state, products) do
    productId = calculate_best_option(state, products)
    if can_produce_now(productId, state, products) do
      produce_product(productId, state, products)
    else
      state
    end
  end

  def place_food_bids([], _labourNeeded, state) do
    state
  end

  def place_food_bids(_asks, _labourNeeded, %{:funds => 0} = state) do
    state
  end

  def place_food_bids(_asks, 0, state) do
    state
  end

  def place_food_bids([{askId, ask} | rest], labourNeeded, %{:funds => funds} = state) do
    maxPurchaseAmount = min(Float.floor(funds / ask.unit_price), labourNeeded)
    purchaseAmount = min(ask.amount, maxPurchaseAmount)
    spent = purchaseAmount * ask.unit_price
    bid({askId, ask}, purchaseAmount, state)
    newState = %{state | :funds => state.funds - spent}
    place_food_bids(rest, labourNeeded - purchaseAmount, newState)
  end

  def produce_product(productId, state, products) do
    produced = get_production_amount(productId, state.inventory, products, state.labour)
    labourCost = products[productId][:labour_cost] * produced
    newProductAmount = state.inventory[productId] + produced
    newInventory = %{state.inventory | productId => newProductAmount}
    %{state | :inventory => newInventory, :labour => state.labour - labourCost}
  end

  def get_production_amount(productId, inventory, products, labour) do
    if products[productId][:raw] do
      Float.floor(labour / products[productId][:labour_cost])
    else
      deps = products[productId][:deps]
      productionLimits = Enum.map(deps, fn(dep) ->
        inventory[:proplists.get_value(:id, dep)] / :proplists.get_value(:amount, dep)
      end)
      [maxProduceable | _] = Enum.sort(productionLimits)
      min(Float.floor(maxProduceable), Float.floor(labour / products[productId][:labour_cost]))
    end
  end

  def can_produce_now(productId, state, products) do
    product = products[productId]
    if product.raw do
      true
    else
      has_nessecary_resources(product.deps, state.inventory)
    end
  end

  def has_nessecary_resources(productDeps, inventory) do
    has_nessecary_resources(productDeps, inventory, true)
  end

  def has_nessecary_resources(_, _, false) do
    false
  end

  def has_nessecary_resources([], _, true) do
    true
  end

  def has_nessecary_resources([dep | rest], inventory, true) do
    depId = :proplists.get_value(:id, dep)
    result = if :proplists.get_value(:amount, dep) >= inventory[depId] do
      true
    else
      false
    end
    has_nessecary_resources(rest, inventory, result)
  end

  def calculate_best_option(state, products) do
    if state.product_path != false do
      state.product_path.choice
    else
      amounts = for {id, _p} <- products,
        do: {id, get_production_amount(id, state.inventory, products, state.labour)}
      [{bestChoice, _}| _] = Enum.sort(amounts, fn({_, a}, {_, b}) -> a >= b end)
      bestChoice
    end
  end

  def generate_productivities(products) do
    numbers = for p <- products, do: {p, :rand.uniform(100)}
    sum = Enum.sum(for {_, s} <- numbers, do: s)
    List.foldl(numbers, %{}, fn({p, x}, map) ->
      Map.put(map, p, x/sum)
    end)
  end

  def generate_preferences(productIds) do
    ps = for id <- productIds, do: {id, :rand.uniform(100)}
    sum = Enum.sum((for {_, s} <- ps, do: s))
    List.foldl(ps, %{}, fn({p, x}, map) ->
      Map.put(map, p, x/sum)
    end)
  end
end
