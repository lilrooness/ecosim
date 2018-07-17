defmodule ActorUtils do
  def can_create(product, state) do
    case product.raw do
      true ->
        :math.floor(state.labour / product.labour_cost)

      false ->
        0.0
    end
  end

  def create(productId, amount, state) do
    product = Application.get_env(:eco, :products)[productId]

    if product.raw do
      creating = min(amount, :math.floor(state.labour / product.labour_cost))
      labour_cost = creating * product.labour_cost
      newAmount = creating + Map.get(state.created, productId, 0)

      %{
        state
        | :labour => state.labour - labour_cost,
          :created => Map.put(state.created, productId, newAmount)
      }
    else
      state
    end
  end

  def get_best_production_option(state) do
    {id, amount} =
      Application.get_env(:eco, :products)
      |> Enum.map(fn {id, prod} ->
        {id, can_create(prod, state)}
      end)
      |> Enum.sort(fn {_, v1}, {_, v2} ->
        v1 > v2
      end)
      |> hd

    {id, amount}
  end

  def spread_ask(marketPid, prodId, amount, meanPrice, bucketSize, state) do
    generate_bucket_list(amount, bucketSize)
    |> Enum.each(fn(bucket) -> 
      ppu = :rstats.rnormal(meanPrice, 10)
      askId = TurnMarket.ask(marketPid, prodId, bucket, ppu)
      SalesTracker.reg_ask(state.tracker_pid, askId, ppu, bucket, prodId)
    end)
  end

  def normal_random_above_zero(mean, sigma) do
    value = :rstats.rnormal(mean, sigma)
    if value >= 0 do
      value
    else
      0
    end
  end

  defp generate_bucket_list(amount, bucketSize) do
    generate_bucket_list([], amount, bucketSize)
  end

  defp generate_bucket_list(buckets, amount, bucketSize) when amount > 0 do
    newBucket = min(amount, bucketSize)
    newAmount = amount - newBucket
    generate_bucket_list([newBucket | buckets], newAmount, bucketSize)
  end

  defp generate_bucket_list(buckets, _amount, _bucketSize) do
    buckets
  end
end
