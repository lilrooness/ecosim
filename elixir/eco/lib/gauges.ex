defmodule TimeGauge do
  use GenServer

  def start_link(timeStep) do
    GenServer.start_link(__MODULE__, [timeStep], [])
  end

  def init([_timeStep]) do
    {:ok, %{}}
    # TODO: start timer
  end

  def handle_call({:add_metric, name}, _from, state) do
    {:reply, :ok, Map.put(state, name, {0, []})}
  end

  def handle_call({:get_latest, name}, _from, state) do
    {_, [latest | _]} = state[name]
    {:reply, {:ok, latest}, state}
  end

  def handle_call({:get_record, name}, _from, state) do
    {_, record} = state[name]
    {:reply, {:ok, record}, state}
  end

  def handle_cast({:report, name, metric}, state) do
    {acc, record} = state[name]
    {:noreply, %{state | name => {acc + metric, record}}}
  end

  def handle_info(:tick, state) do
    newState = List.foldl(Map.keys(state), %{}, fn(key, acc) ->
      {sum, record} = state[key]
      Map.put(acc, key, {0, [sum | record]})
    end)
    # TODO: restart timer
    {:noreply, newState}
  end
end

defmodule ValueGauge do
    use GenServer

  def start_link() do
    GenServer.start_link(__MODULE__, [], [])
  end

  def init([]) do
    {:ok, %{}}
  end

  def handle_call({:add_metric, name}, _from, state) do
    {:reply, :ok, Map.put(state, name, [])}
  end

  def handle_call({:get_latest, name}, _from, state) do
    [latest | _] = state[name]
    {:reply, {:ok, latest}, state}
  end

  def handle_call({:get_record, name}, _from, state) do
    record = state[name]
    {:reply, {:ok, record}, state}
  end

  def handle_cast({:report, name, metric}, state) do
    record = state[name]
    {:noreply, %{state | name => [metric | record]}}
  end
end

defmodule GaugeC do

  def start_gauge(:time, [timeStep]) do
    TimeGauge.start_link(timeStep)
  end

  def start_gauge(:value, []) do
    ValueGauge.start_link()
  end

  def get_latest(gaugePid, name) do
    {:ok, x} = GenServer.call(gaugePid, {:get_latest, name})
    x
  end

  def get_record(gaugePid, name) do
    GenServer.call(gaugePid, {:get_record, name})
  end

  def add_metric(gaugePid, name) do
    GenServer.call(gaugePid, {:add_metric, name})
  end

  def report(gaugePid, name, value) do
    GenServer.cast(gaugePid, {:report, name, value})
  end
end
