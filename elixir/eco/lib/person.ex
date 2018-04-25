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
    newState = produce(state, products) |> auction |> consume
    {:noreply, newState}
  end

  def handle_info({:won, info}, state) do
    productId = info[:product_id]
    amount = info[:amount]
    totalPrice = info[:total_price]
    newInventory = %{state.inventory | productId => state.inventory[productId] + amount}
    {:noreply, %{state | :inventory => newInventory,
               :funds => state.funds - totalPrice}}
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
    
  end

  def auction(state) do
    
  end

  def produce(state, products) do
    
  end

  def produce_product(productId, state, products) do
    
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


