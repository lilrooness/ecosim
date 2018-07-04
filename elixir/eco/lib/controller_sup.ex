defmodule ControllerSup do
  use DynamicSupervisor
  require Supervisor

  @counter_name "controller"

    def start_link do
      DynamicSupervisor.start_link(__MODULE__, [], name: __MODULE__)
    end

    def init([]) do
      :gproc.add_local_counter(@counter_name, 0)
      DynamicSupervisor.init(strategy: :one_for_one)
    end

    def new_controller do
      supPid = :erlang.whereis ControllerSup
      currentCount = Integer.to_string(:gproc.get_value({:c, :l, @counter_name}, supPid))
      :gproc.update_counter({:c, :l, @counter_name}, supPid, 1)

      childSpec = {Controller, id: currentCount}
      
      {:ok, childPid} = DynamicSupervisor.start_child(ControllerSup, childSpec)
      :gproc.reg_other({:n, :l, currentCount}, supPid, childPid)
      currentCount
    end

    def get_pid_by_id id do
      :gproc.where({:n, :l, id})
    end
end
