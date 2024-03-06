defmodule Lightning.UsageTracking.ReportQueueingService do

  alias Lightning.UsageTracking.ConfigurationManagementService
  alias Lightning.UsageTracking.ReportDateService
  alias Lightning.UsageTracking.ReportWorker

  def enqueue_reports(_enabled = true, reference_time, batch_size) do
    %{start_reporting_after: start_after} =
      ConfigurationManagementService.enable(reference_time)

    dates =
      ReportDateService.reportable_dates(
        start_after,
        DateTime.to_date(reference_time),
        batch_size
      )

    update_configuration(dates)

    for date <- dates do
      Oban.insert(Lightning.Oban, ReportWorker.new(%{date: date}))
    end

    :ok
  end

  def enqueue_reports(_enabled = false, _reference_time, _batch_size) do
    ConfigurationManagementService.disable()

    :ok
  end

  defp update_configuration(_dates = [earliest_report_date | _other]) do
    start_reporting_after = Date.add(earliest_report_date, -1)

    ConfigurationManagementService.start_reporting_after(start_reporting_after)
  end

  defp update_configuration([]), do: nil
end
