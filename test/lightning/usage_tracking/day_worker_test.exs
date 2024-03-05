defmodule Lightning.UsageTracking.DayWorkerTest do
  use Lightning.DataCase

  import Lightning.ApplicationHelpers, only: [put_temporary_env: 3]

  alias Lightning.Repo
  alias Lightning.UsageTracking.ConfigurationManagementService
  alias Lightning.UsageTracking.DailyReportConfiguration
  alias Lightning.UsageTracking.DayWorker
  alias Lightning.UsageTracking.ReportWorker

  describe "tracking is enabled" do
    setup do
      put_temporary_env(:lightning, :usage_tracking, enabled: true)
    end

    test "enables the configuration" do
      DayWorker.perform(%{})

      %{tracking_enabled_at: enabled_at} = Repo.one(DailyReportConfiguration)

      assert DateTime.diff(DateTime.utc_now(), enabled_at, :second) < 5
    end

    test "it enqueues jobs to process outstanding days" do
      now = DateTime.utc_now()
      enabled_at = DateTime.add(now, -7, :day)
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
        DayWorker.perform(%{})

        for date <- expected_dates do
          assert_enqueued worker: ReportWorker, args: %{date: date}, queue: :background
        end
      end)
    end

    test "returns :ok" do
      assert DayWorker.perform(%{}) == :ok
    end
  end

  describe "tracking is not enabled" do
    setup do
      put_temporary_env(:lightning, :usage_tracking, enabled: false)
    end

    test "disables the configuration" do
      ConfigurationManagementService.enable(DateTime.utc_now())

      DayWorker.perform(%{})

      %{tracking_enabled_at: nil} = Repo.one(DailyReportConfiguration)
    end

    test "returns :ok" do
      assert DayWorker.perform(%{}) == :ok
    end
  end
end
