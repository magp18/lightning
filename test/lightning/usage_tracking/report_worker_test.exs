defmodule Lightning.UsageTracking.ReportWorkerTest do
  use Lightning.DataCase

  import Mock
  import Lightning.ApplicationHelpers, only: [put_temporary_env: 3]

  alias Lightning.UsageTracking.Client
  alias Lightning.UsageTracking.ConfigurationManagementService 
  alias Lightning.UsageTracking.Report
  alias Lightning.UsageTracking.ReportData 
  alias Lightning.UsageTracking.ReportWorker

  @date ~D[2024-02-25]
  @host "https://foo.bar"

  describe "tracking is enabled" do
    setup do
      cleartext_uuids_enabled = false
      report_config =
        ConfigurationManagementService.enable(DateTime.utc_now())

      put_temporary_env(:lightning, :usage_tracking,
        cleartext_uuids_enabled: cleartext_uuids_enabled,
        enabled: true,
        host: @host
      )

      expected_report_data =
        ReportData.generate(report_config, cleartext_uuids_enabled, @date)

      %{expected_report_data: expected_report_data}
    end

    test "submits the metrics to the ImpactTracker", config do
      %{expected_report_data: expected_report_data} = config

      with_mock Client,
        submit_metrics: &mock_submit_metrics_ok/2 do
        perform_job(ReportWorker, %{date: @date})

        assert_called(Client.submit_metrics(expected_report_data, @host))
      end
    end

    test "persists a report indicating successful submission", config do
      %{expected_report_data: expected_report_data} = config

      persisted_report_data = expected_report_data |> stringify_keys()

      report_date = @date

      with_mock Client,
        submit_metrics: &mock_submit_metrics_ok/2 do
        perform_job(ReportWorker, %{date: @date})
      end

      report = Report |> Repo.one()

      assert(
        %Report{
          submitted: true,
          report_date: ^report_date,
          data: ^persisted_report_data 
        } = report
      )
      assert DateTime.diff(DateTime.utc_now(), report.submitted_at, :second) < 2
    end

    test "persists a report indicating unsuccessful submission", config do
      %{expected_report_data: expected_report_data} = config

      persisted_report_data = expected_report_data |> stringify_keys()

      report_date = @date

      with_mock Client,
        submit_metrics: &mock_submit_metrics_error/2 do
        perform_job(ReportWorker, %{date: @date})
      end

      report = Report |> Repo.one()

      assert(
        %Report{
          submitted: false,
          report_date: ^report_date,
          data: ^persisted_report_data,
          submitted_at: nil,
        } = report
      )
    end

    test "on successful submission crashes if a report already exists" do
      existing_report = 
        %Report{
          data: %{"old" => "data"},
          report_date: @date,
          submitted: false
        } |> Repo.insert!()

      assert_raise Ecto.ConstraintError, fn ->
        with_mock Client,
          submit_metrics: &mock_submit_metrics_ok/2 do
          perform_job(ReportWorker, %{date: @date})
        end
      end

      assert existing_report == Report |> Repo.one()
    end

    test "on unsuccessful submission crashes if a report already exists" do
      existing_report = 
        %Report{
          data: %{"old" => "data"},
          report_date: @date,
          submitted: false
        } |> Repo.insert!()

      assert_raise Ecto.ConstraintError, fn ->
        with_mock Client,
          submit_metrics: &mock_submit_metrics_error/2 do
          perform_job(ReportWorker, %{date: @date})
        end
      end

      assert existing_report == Report |> Repo.one()
    end

    test "indicates that the job executed successfully" do
      with_mock Client,
        submit_metrics: &mock_submit_metrics_ok/2 do
        assert perform_job(ReportWorker, %{date: @date}) == :ok
      end
    end

    test "correctly indicates if cleartext uuids are enabled"
  end

  describe "tracking is disabled" do

  end

  defp mock_submit_metrics_ok(_metrics, _host), do: :ok
  defp mock_submit_metrics_error(_metrics, _host), do: :error

  defp stringify_keys(map) do
    map
    |> Map.keys()
    |> Enum.reduce(%{}, fn key, acc ->
      acc |> Map.merge(%{to_string(key) => map[key]})
    end)
  end
end
