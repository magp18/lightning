defmodule Lightning.UsageTracking.ReportQueueingService do
  @moduledoc """
  Service that enqueues jobs to generate report data for given days.

  """

  alias Lightning.UsageTracking.ConfigurationManagementService
  alias Lightning.UsageTracking.ReportDateService
  alias Lightning.UsageTracking.ReportWorker

  def enqueue_reports(true = _enabled, reference_time, batch_size) do
    %{start_reporting_after: start_after} =
      ConfigurationManagementService.enable(reference_time)

    today = DateTime.to_date(reference_time)

    start_after
    |> ReportDateService.reportable_dates(today, batch_size)
    |> update_configuration()
    |> Enum.each(&enqueue/1)

    :ok
  end

  def enqueue_reports(false = _enabled, _reference_time, _batch_size) do
    ConfigurationManagementService.disable()

    :ok
  end

  defp update_configuration([earliest_report_date | _other] = dates) do
    start_reporting_after = Date.add(earliest_report_date, -1)

    ConfigurationManagementService.start_reporting_after(start_reporting_after)

    dates
  end

  defp update_configuration([] = dates), do: dates

  defp enqueue(date) do
    Oban.insert(Lightning.Oban, ReportWorker.new(%{date: date}))
  end
end
