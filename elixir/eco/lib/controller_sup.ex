defmodule ControllerSup do
  use Supervisor

    def start_link do
      Supervisor.start_link(__MODULE__, [], name: __MODULE__)
    end

    def init(_) do
      supervise([], strategy: :one_for_one)
    end

    def new_controller id do
      Supervisor.start_child(ControllerSup, worker(Controller, [id]))
    end
end
