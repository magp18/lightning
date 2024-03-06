defmodule Lightning.UsageTracking.DayWorker do
  @moduledoc """
  Worker to manage per-day report generation

  """
  use Oban.Worker,
    queue: :background,
    max_attempts: 1

  alias Lightning.UsageTracking.ConfigurationManagementService
  alias Lightning.UsageTracking.ReportDateService
  alias Lightning.UsageTracking.ReportWorker

  @impl Oban.Worker
  def perform(_opts) do
    env = Application.get_env(:lightning, :usage_tracking)

    now = DateTime.utc_now()

    if env[:enabled] do
      %{start_reporting_after: start_after} =
        ConfigurationManagementService.enable(now)

      dates =
        ReportDateService.reportable_dates(start_after, DateTime.to_date(now))

      for date <- dates, do: Oban.insert(Lightning.Oban, ReportWorker.new(%{date: date}))
    else
      ConfigurationManagementService.disable()
    end

    :ok
  end
end
