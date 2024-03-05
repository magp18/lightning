defmodule Lightning.UsageTracking.ReportWorker do
  @moduledoc """
  Worker to generate report for given day

  """
  use Oban.Worker,
    queue: :background,
    max_attempts: 1

  @impl Oban.Worker
  def perform(_opts) do
  end
end
