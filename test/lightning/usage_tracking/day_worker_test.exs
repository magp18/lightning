defmodule Lightning.UsageTracking.DayWorkerTest do
  use Lightning.DataCase

  import Lightning.ApplicationHelpers, only: [put_temporary_env: 3]

  alias Lightning.Repo
  alias Lightning.UsageTracking.ConfigurationManagementService
  alias Lightning.UsageTracking.DailyReportConfiguration
  alias Lightning.UsageTracking.DayWorker
  alias Lightning.UsageTracking.ReportWorker

  @batch_size 10
  @range_in_days 7
  @number_of_report_dates @range_in_days - 1

  describe "tracking is enabled" do
    setup do
      put_temporary_env(:lightning, :usage_tracking, enabled: true)
    end

    test "enables the configuration" do
      perform_job(DayWorker, %{batch_size: @batch_size})

      %{tracking_enabled_at: enabled_at} = Repo.one(DailyReportConfiguration)

      assert DateTime.diff(DateTime.utc_now(), enabled_at, :second) < 5
    end

    test "enqueues jobs to process outstanding days" do
      now = DateTime.utc_now()
      enabled_at = DateTime.add(now, -@range_in_days, :day)
      first_report_date =
        enabled_at
        |> DateTime.add(1, :day)
        |> DateTime.to_date()
      last_report_date =
        now
        |> DateTime.add(-1, :day)
        |> DateTime.to_date()

      expected_dates = Date.range(first_report_date, last_report_date)

      ConfigurationManagementService.enable(enabled_at)

      Oban.Testing.with_testing_mode(:manual, fn->
        perform_job(DayWorker, %{batch_size: @batch_size})

        for date <- expected_dates do
          assert_enqueued worker: ReportWorker, args: %{date: date}, queue: :background
        end
      end)
    end

    test "does not enqueue more than the batch size" do
      batch_size = @number_of_report_dates - 2
      now = DateTime.utc_now()
      enabled_at = DateTime.add(now, -@range_in_days, :day)
      first_report_date =
        enabled_at
        |> DateTime.add(1, :day)
        |> DateTime.to_date()
      last_report_date =
        now
        |> DateTime.add(-1, :day)
        |> DateTime.to_date()
      all_dates_within_range = Date.range(first_report_date, last_report_date)
      included_dates =
        all_dates_within_range |> Enum.take(batch_size)
      excluded_dates = 
        all_dates_within_range |> Enum.take(batch_size - @number_of_report_dates)

      ConfigurationManagementService.enable(enabled_at)

      Oban.Testing.with_testing_mode(:manual, fn->
        perform_job(DayWorker, %{batch_size: batch_size})

        for date <- included_dates do
          assert_enqueued worker: ReportWorker, args: %{date: date}, queue: :background
        end

        for date <- excluded_dates do
          refute_enqueued worker: ReportWorker, args: %{date: date}, queue: :background
        end
      end)
    end

    test "returns :ok" do
      assert perform_job(DayWorker, %{batch_size: @batch_size}) == :ok
    end
  end

  describe "tracking is not enabled" do
    setup do
      put_temporary_env(:lightning, :usage_tracking, enabled: false)
    end

    test "disables the configuration" do
      ConfigurationManagementService.enable(DateTime.utc_now())

      perform_job(DayWorker, %{batch_size: @batch_size})

      %{tracking_enabled_at: nil} = Repo.one(DailyReportConfiguration)
    end

    test "returns :ok" do
      assert perform_job(DayWorker, %{batch_size: @batch_size}) == :ok
    end
  end
end
