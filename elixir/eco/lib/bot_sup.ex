defmodule BotSup do
  @behaviour Supervisor

  def start_link do
    bots = Application.get_env(:eco, :number_of_bots)
    Supervisor.start_link(__MODULE__, [bots], name: __MODULE__)
  end

  def init([nbots]) do
    children = for botId <- 1..nbots, do: Bot.child_spec([botId])
    Supervisor.init(children, strategy: :one_for_one)
  end

  def tick(msg) do
    Supervisor.which_children(BotSup)
    |> Enum.each(fn {_id, botPid, _, _} -> send(botPid, msg) end)
    :ok
  end
end
