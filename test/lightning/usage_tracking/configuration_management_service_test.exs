defmodule Lightning.UsageTracking.ConfigurationManagementServiceTest do
  use Lightning.DataCase

  alias Lightning.Repo
  alias Lightning.UsageTracking.ConfigurationManagementService
  alias Lightning.UsageTracking.DailyReportConfiguration

  describe ".enable/1 - no configuration exists" do
    setup do
      {:ok, tracking_enabled_at, _offset} =
        DateTime.from_iso8601("2024-03-01T18:23:23.000000Z")

      start_reporting_after = Date.from_iso8601!("2024-03-01")

      %{
        tracking_enabled_at: tracking_enabled_at,
        start_reporting_after: start_reporting_after
      }
    end

    test "creates record", config do
      %{
        tracking_enabled_at: tracking_enabled_at,
        start_reporting_after: start_reporting_after
      } = config

      ConfigurationManagementService.enable(tracking_enabled_at)

      report_config = Repo.one!(DailyReportConfiguration)

      assert(
        %{
          tracking_enabled_at: ^tracking_enabled_at,
          start_reporting_after: ^start_reporting_after
        } = report_config
      )
    end

    test "returns the configuration", config do
      %{
        tracking_enabled_at: tracking_enabled_at,
        start_reporting_after: start_reporting_after
      } = config

      report_config = ConfigurationManagementService.enable(tracking_enabled_at)

      assert(
        %DailyReportConfiguration{
          tracking_enabled_at: ^tracking_enabled_at,
          start_reporting_after: ^start_reporting_after
        } = report_config
      )
    end
  end

  describe ".enable/1 - configuration exists with populated dates" do
    setup do
      {:ok, tracking_enabled_at, _offset} =
        DateTime.from_iso8601("2024-03-01T18:23:23.000000Z")

      {:ok, existing_tracking_enabled_at, _offset} =
        DateTime.from_iso8601("2024-02-01T10:10:10.000000Z")

      existing_start_reporting_after = Date.from_iso8601!("2024-02-01")

      %{
        tracking_enabled_at: tracking_enabled_at,
        existing_start_reporting_after: existing_start_reporting_after,
        existing_tracking_enabled_at: existing_tracking_enabled_at
      }
    end

    test "does not update the record", config do
      %{
        tracking_enabled_at: tracking_enabled_at,
        existing_tracking_enabled_at: existing_tracking_enabled_at,
        existing_start_reporting_after: existing_start_reporting_after
      } = config

      %DailyReportConfiguration{
        tracking_enabled_at: existing_tracking_enabled_at,
        start_reporting_after: existing_start_reporting_after
      }
      |> Repo.insert!()

      ConfigurationManagementService.enable(tracking_enabled_at)

      report_config = Repo.one!(DailyReportConfiguration)

      assert(
        %{
          tracking_enabled_at: ^existing_tracking_enabled_at,
          start_reporting_after: ^existing_start_reporting_after
        } = report_config
      )
    end

    test "returns the config", config do
      %{
        tracking_enabled_at: tracking_enabled_at,
        existing_tracking_enabled_at: existing_tracking_enabled_at,
        existing_start_reporting_after: existing_start_reporting_after
      } = config

      %DailyReportConfiguration{
        tracking_enabled_at: existing_tracking_enabled_at,
        start_reporting_after: existing_start_reporting_after
      }
      |> Repo.insert!()

      report_config = ConfigurationManagementService.enable(tracking_enabled_at)

      assert(
        %{
          tracking_enabled_at: ^existing_tracking_enabled_at,
          start_reporting_after: ^existing_start_reporting_after
        } = report_config
      )
    end
  end

  describe ".enable/1 - record exists but dates are not populated" do
    setup do
      {:ok, tracking_enabled_at, _offset} =
        DateTime.from_iso8601("2024-03-01T18:23:23.000000Z")

      start_reporting_after = Date.from_iso8601!("2024-03-01")

      %{
        tracking_enabled_at: tracking_enabled_at,
        start_reporting_after: start_reporting_after
      }
    end

    test "updates the record", config do
      %{
        tracking_enabled_at: tracking_enabled_at,
        start_reporting_after: start_reporting_after
      } = config

      %DailyReportConfiguration{} |> Repo.insert!()

      ConfigurationManagementService.enable(tracking_enabled_at)

      report_config = Repo.one!(DailyReportConfiguration)

      assert(
        %{
          tracking_enabled_at: ^tracking_enabled_at,
          start_reporting_after: ^start_reporting_after
        } = report_config
      )
    end

    test "returns the updated record", config do
      %{
        tracking_enabled_at: tracking_enabled_at,
        start_reporting_after: start_reporting_after
      } = config

      %DailyReportConfiguration{} |> Repo.insert!()

      report_config = ConfigurationManagementService.enable(tracking_enabled_at)

      assert(
        %{
          tracking_enabled_at: ^tracking_enabled_at,
          start_reporting_after: ^start_reporting_after
        } = report_config
      )
    end
  end

  describe "disable/1 - record exists" do
    setup do
      {:ok, existing_tracking_enabled_at, _offset} =
        DateTime.from_iso8601("2024-02-01T10:10:10.000000Z")

      existing_start_reporting_after = Date.from_iso8601!("2024-02-01")

      %{
        existing_start_reporting_after: existing_start_reporting_after,
        existing_tracking_enabled_at: existing_tracking_enabled_at
      }
    end

    test "sets the dates to nil", config do
      %{
        existing_tracking_enabled_at: existing_tracking_enabled_at,
        existing_start_reporting_after: existing_start_reporting_after
      } = config

      %DailyReportConfiguration{
        tracking_enabled_at: existing_tracking_enabled_at,
        start_reporting_after: existing_start_reporting_after
      }
      |> Repo.insert!()

      ConfigurationManagementService.disable()

      report_config = Repo.one!(DailyReportConfiguration)

      assert(
        %{tracking_enabled_at: nil, start_reporting_after: nil} = report_config
      )
    end

    test "returns the updated record", config do
      %{
        existing_tracking_enabled_at: existing_tracking_enabled_at,
        existing_start_reporting_after: existing_start_reporting_after
      } = config

      %DailyReportConfiguration{
        tracking_enabled_at: existing_tracking_enabled_at,
        start_reporting_after: existing_start_reporting_after
      }
      |> Repo.insert!()

      report_config = ConfigurationManagementService.disable()

      assert(
        %{tracking_enabled_at: nil, start_reporting_after: nil} = report_config
      )
    end
  end

  describe "disable/1 - no record exists" do
    test "returns nil" do
      assert ConfigurationManagementService.disable() == nil
    end
  end

  describe "start_reporting_after/1 - enabled configuration exists" do
    setup do
      %DailyReportConfiguration {
        tracking_enabled_at: DateTime.utc_now(),
        start_reporting_after: ~D[2024-03-01]
      }
      |> Repo.insert!()

      %{date: ~D[2024-03-05]}
    end

    test "updates the start_reporting_after date", %{date: date} do
      ConfigurationManagementService.start_reporting_after(date) 

      assert(
        %{start_reporting_after: ^date} = Repo.one!(DailyReportConfiguration)
      )
    end

    test "returns :ok", %{date: date} do
      assert ConfigurationManagementService.start_reporting_after(date) == :ok
    end
  end

  describe "start_reporting_after/1 - no configuration exists" do
    setup do
      %{date: ~D[2024-03-05]}
    end

    test "does nothing", %{date: date} do
      ConfigurationManagementService.start_reporting_after(date)

      assert Repo.one(DailyReportConfiguration) == nil
    end

    test "returns :error", %{date: date} do
      assert(
        ConfigurationManagementService.start_reporting_after(date) == :error
      )
    end
  end

  describe "start_reporting_after/1 - disabled configuration exists" do
    setup do
      existing_date = ~D[2024-03-01]

      %DailyReportConfiguration {
        tracking_enabled_at: nil,
        start_reporting_after: existing_date
      }
      |> Repo.insert!()

      %{date: ~D[2024-03-05], existing_date: existing_date}
    end

    test "does not update the record", config do
      %{date: date, existing_date: existing_date} = config

      ConfigurationManagementService.start_reporting_after(date)

      assert(
        %{
          tracking_enabled_at: nil,
          start_reporting_after: ^existing_date
        } = Repo.one!(DailyReportConfiguration)
      )
    end

    test "returns :error", %{date: date} do
      assert(
        ConfigurationManagementService.start_reporting_after(date) == :error
      )
    end
  end
end
