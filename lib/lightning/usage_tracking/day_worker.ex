defmodule Lightning.UsageTracking.DayWorker do
  @moduledoc """
  Worker to manage per-day report generation

  """
  use Oban.Worker,
    queue: :background,
    max_attempts: 1

  alias Lightning.UsageTracking.ConfigurationManagementService

  @impl Oban.Worker
  def perform(_opts) do
    env = Application.get_env(:lightning, :usage_tracking)

    if env[:enabled] do
      ConfigurationManagementService.enable(DateTime.utc_now())
    else
      ConfigurationManagementService.disable()
    end

    :ok
  end
end
