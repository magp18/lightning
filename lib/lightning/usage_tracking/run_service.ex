defmodule Lightning.UsageTracking.RunService do
  def finished_runs(all_runs, date) do
    all_runs
    |> Enum.filter(fn
      %{finished_at: nil} ->
        false
      %{finished_at: finished_at} ->
        finished_at |> DateTime.to_date() == date
    end)
  end

  def finished_steps(runs, date) do
    runs
    |> Enum.flat_map(& &1.steps)
    |> Enum.filter(fn
      %{finished_at: nil} ->
        false
      %{finished_at: finished_at} ->
        finished_at |> DateTime.to_date() == date
    end)
  end
end
