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

  describe "perform/1 with reference time passed in - tracking is enabled" do
    setup do
      put_temporary_env(:lightning, :usage_tracking, enabled: true)

      %{reference_time: DateTime.utc_now()}
    end

    test "enables the configuration", config do
      %{reference_time: reference_time} = config

      perform_job(
        DayWorker,
        %{batch_size: @batch_size, reference_time: reference_time}
      )

      %{tracking_enabled_at: enabled_at} = Repo.one(DailyReportConfiguration)

      assert DateTime.diff(DateTime.utc_now(), enabled_at, :second) < 5
    end

    test "enqueues jobs to process outstanding days", config do
      %{reference_time: reference_time} = config

      enabled_at = DateTime.add(reference_time, -@range_in_days, :day)
      first_report_date =
        enabled_at
        |> DateTime.add(1, :day)
        |> DateTime.to_date()
      last_report_date =
        reference_time
        |> DateTime.add(-1, :day)
        |> DateTime.to_date()

      expected_dates = Date.range(first_report_date, last_report_date)

      ConfigurationManagementService.enable(enabled_at)

      Oban.Testing.with_testing_mode(:manual, fn->
        perform_job(
          DayWorker,
          %{batch_size: @batch_size, reference_time: reference_time}
        )

        for date <- expected_dates do
          assert_enqueued worker: ReportWorker, args: %{date: date}, queue: :background
        end
      end)
    end

    test "does not enqueue more than the batch size", config do
      %{reference_time: reference_time} = config

      enabled_at = DateTime.add(reference_time, -@range_in_days, :day)
      first_report_date =
        enabled_at
        |> DateTime.add(1, :day)
        |> DateTime.to_date()
      last_report_date =
        reference_time
        |> DateTime.add(-1, :day)
        |> DateTime.to_date()
      all_dates_within_range =
        first_report_date
        |> Date.range(last_report_date)
        |> Enum.to_list()
      batch_size = length(all_dates_within_range) - 2
      included_dates =
        all_dates_within_range |> Enum.take(batch_size)
      excluded_dates = 
        all_dates_within_range |> Enum.take(-2)

      ConfigurationManagementService.enable(enabled_at)

      Oban.Testing.with_testing_mode(:manual, fn->
        perform_job(
          DayWorker,
          %{batch_size: batch_size, reference_time: reference_time}
        )

        for date <- included_dates do
          assert_enqueued worker: ReportWorker, args: %{date: date}, queue: :background
        end

        for date <- excluded_dates do
          refute_enqueued worker: ReportWorker, args: %{date: date}, queue: :background
        end
      end)
    end

    test "updates the config based on reportable dates", config do
      %{reference_time: reference_time} = config

      enabled_at = DateTime.add(reference_time, -@range_in_days, :day)
      first_report_date =
        enabled_at
        |> DateTime.add(1, :day)
        |> DateTime.to_date()
      last_report_date =
        reference_time
        |> DateTime.add(-1, :day)
        |> DateTime.to_date()
      
      [report_date_1 | [report_date_2 | _other_dates]] =
        first_report_date
        |> Date.range(last_report_date)
        |> Enum.to_list()

      # Add some existing reports so that the start_reporting_after will take
      # these into account
      insert(:usage_tracking_report, report_date: report_date_1)
      insert(:usage_tracking_report, report_date: report_date_2)

      ConfigurationManagementService.enable(enabled_at)

      Oban.Testing.with_testing_mode(:manual, fn->
        perform_job(
          DayWorker,
          %{batch_size: @batch_size, reference_time: reference_time}
        )
      end)

      report_config = DailyReportConfiguration |> Repo.one!()

      assert report_config.start_reporting_after == report_date_2
    end

    test "does not update config if there are no reportable dates", config do
      %{reference_time: reference_time} = config

      enabled_at = DateTime.add(reference_time, -1, :day)

      %{start_reporting_after: existing_date} =
        ConfigurationManagementService.enable(enabled_at)

      Oban.Testing.with_testing_mode(:manual, fn->
        perform_job(
          DayWorker,
          %{batch_size: @batch_size, reference_time: reference_time}
        )
      end)

      report_config = DailyReportConfiguration |> Repo.one!()

      assert report_config.start_reporting_after == existing_date
    end

    test "returns :ok", config do
      %{reference_time: reference_time} = config

      assert(
        perform_job(
          DayWorker,
          %{batch_size: @batch_size, reference_time: reference_time}
        ) == :ok
      )
    end
  end

  describe "perform/1 with reference time passed in - tracking is disabled" do
    setup do
      reference_time = DateTime.utc_now()

      put_temporary_env(:lightning, :usage_tracking, enabled: false)

      ConfigurationManagementService.enable(reference_time)

      %{reference_time: reference_time}
    end

    test "disables the configuration", config do
      %{reference_time: reference_time} = config

      assert(
        perform_job(
          DayWorker,
          %{batch_size: @batch_size, reference_time: reference_time}
        )
      )

      %{tracking_enabled_at: nil} = Repo.one(DailyReportConfiguration)
    end

    test "returns :ok", config do
      %{reference_time: reference_time} = config

      assert(
        perform_job(
          DayWorker,
          %{batch_size: @batch_size, reference_time: reference_time}
        ) == :ok
      )
    end
  end
end
