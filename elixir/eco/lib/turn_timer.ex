defmodule TurnTimer do
  @behaviour GenServer

  def start_link do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init [] do
    send self, :end_turn
    {:ok, {}}
  end

  def handle_info(:end_turn, state) do
    IO.puts("Starting next turn")
    TurnMarket.settle TurnMarket
    :timer.send_after 10*1000, :start_turn
    {:noreply, state}
  end

  def handle_info(:start_turn, state) do
    IO.puts("triggering bots")
    BotSup.tick
    :timer.send_after 60*1000, :end_turn
    {:noreply, state}
  end

end