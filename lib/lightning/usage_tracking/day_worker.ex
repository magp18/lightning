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
  def perform(%{args: %{"reference_time" => reference_time_string} = args}) do
    {:ok, reference_time, _offset} =
      DateTime.from_iso8601(reference_time_string)

    %{"batch_size" => batch_size} = args

    env = Application.get_env(:lightning, :usage_tracking)

    if env[:enabled] do
      %{start_reporting_after: start_after} =
        ConfigurationManagementService.enable(reference_time)

      dates =
        ReportDateService.reportable_dates(
          start_after,
          DateTime.to_date(reference_time),
          batch_size
        )

      update_configuration(dates)

      for date <- dates, do: Oban.insert(Lightning.Oban, ReportWorker.new(%{date: date}))
    else
      ConfigurationManagementService.disable()
    end

    :ok
  end

  defp update_configuration(_dates = [earliest_report_date | _other]) do
    start_reporting_after = Date.add(earliest_report_date, -1)

    ConfigurationManagementService.start_reporting_after(start_reporting_after)
  end

  defp update_configuration([]), do: nil
end
