defmodule Data do

  def to_view(thing, fields) do
    fields
    |> Enum.reduce(%{}, fn(field, acc) ->
      value = Map.get(thing, field)
      Map.put(acc, field, value)
    end)
  end
  
end


defmodule Bid do

  @json_fields [
    :ask_id,
    :amount
  ]
  
  defstruct(
    ask_id: 0,
    amount: 0,
    from: 0
  )

  def new(askId \\0, amount \\0, from \\0) do
    %Bid{
      ask_id: askId,
      amount: amount,
      from: from
    }
  end

  def to_view(%Bid{} = bid) do
    Data.to_view(bid, @json_fields)
  end
  
end

defmodule Ask do
  @behaviour Access

  @json_fields [
    :id,
    :product_id,
    :amount,
    :ppu
  ]
  
  defstruct(
    id: 0,
    product_id: 0,
    from: 0,
    amount: 0,
    ppu: 0
  )

  def new(productId \\0, from \\0, amount \\0, ppu \\0) do
    %Ask{
      product_id: productId,
      from: from,
      amount: amount,
      ppu: ppu
    }
  end

  def to_view(%Ask{} = bid) do
    Data.to_view(bid, @json_fields)
  end
  
  def fetch(%Ask{} = ask, field) do
    case Map.get(ask, field, nil) do
      nil ->
	:error
      value ->
	{:ok, value}
    end
  end

  def get(%Ask{} = ask, field, default) do
    case fetch(ask, field) do
      {:ok, value} -> value
      :error -> default
    end
  end
  
  def get_and_update(%Ask{} = ask, field, fun) do
    get(ask, field, nil)
    |> fun.()
    |> update_or_pop(ask, field)
  end

  defp update_or_pop({get_value, update_value}, %Ask{} = ask, field) do
    newAsks = Map.put(ask, field, update_value)
    {get_value, newAsks}
  end
  
  defp update_or_pop(:pop, %Ask{} = ask, field) do
    pop(ask, field)
  end
  
  def pop(%Ask{} = ask, field) do
    value = Map.get(ask, field)
    newAsk = Map.delete(ask, field)
    {value, newAsk}
  end
    
end


defmodule AskList do
  @behaviour Access
  
  defstruct(
    id: 0,
    asks: %{}
  )


  # API FUNCTIONS
  def new() do
    %AskList{}
  end

  def get_last_id(%AskList{id: id}) do
    id
  end

  def to_view(%AskList{asks: asks}) do
    asks
    |> Map.values
    |> Enum.map(fn(ask) -> Ask.to_view(ask) end)
  end

  def list_asks(%AskList{asks: asks}) do
    for {_id, ask} <- asks, into: [], do: ask
  end
  
  def add(%AskList{} = askList, %Ask{} = ask) do
    newId = askList.id + 1
    ask = %{ask | id: newId}
    asks = Map.put(askList.asks, newId, ask)
    %{askList | :id => newId, :asks => asks}
  end

  def add(%AskList{} = askList, productId, from, amount, ppu) do
    ask = %Ask{
      product_id: productId,
      from: from,
      amount: amount,
      ppu: ppu
    }

    add(askList, ask)
  end
  
  # ACCESS CALLBACKS
  def fetch(%AskList{} = asks, askId) do
    if Map.has_key?(asks.asks, askId) do
      {:ok, asks.asks[askId]}
    else
      :error
    end
  end

  def get(%AskList{} = asks, askId, default) do
    case fetch(asks, askId) do
      {:ok, value} -> value
      :error -> default
    end
  end

  def get_and_update(%AskList{} = asks, askId, fun) do
    get(asks, askId, nil)
    |> fun.()
    |> update_or_pop(asks, askId)
  end

  def pop(%AskList{} = asks, askId) do
    value = get(asks, askId, nil)
    poppedAsksMap = Map.delete(asks.asks, askId)
    newData = %{asks | :asks => poppedAsksMap}
    {value, newData}
  end

  defp update_or_pop({get_value, update_value}, %AskList{} = asks, askId) do
    newAsksMap = %{asks.asks | askId => update_value}
    newAsks = %{asks | :asks => newAsksMap}
    {get_value, newAsks}
  end

  defp update_or_pop(:pop, %AskList{} = asks, askId) do
    pop(asks, askId)
  end
end

defimpl Collectable, for: AskList do
  def into(%AskList{} = orig) do
    {orig, &into_callback/2}
  end

  def into_callback(orig, {:cont, entry}) do
    AskList.add(orig, entry)
  end

  def into_callback(askList, :done) do
    askList
  end

  def into_callback(_askList, :halt) do
    :ok
  end
end
