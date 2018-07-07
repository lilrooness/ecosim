defmodule EcoSup do
  @behaviour Supervisor

  def start_link do
    Supervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init [] do
    children = [
      %{id: BotSup,
      type: :supervisor,
      start: {BotSup, :start_link, []},
      restart: :permanent},

      %{id: ControllerSup,
      type: :supervisor,
      start: {ControllerSup, :start_link, []},
      restart: :permanent},

      %{id: TurnMarket,
      type: :worker,
      start: {TurnMarket, :start_link, []},
      restart: :permanent}
    ]

    Supervisor.init(children, strategy: :one_for_all)
  end
end