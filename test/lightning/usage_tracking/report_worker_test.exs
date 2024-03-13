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

      %{instance: expected_instance_data} = expected_report_data

      with_mock Client,
        submit_metrics: &mock_submit_metrics_ok/2 do
        perform_job(ReportWorker, %{date: @date})

        assert_called Client.submit_metrics(
          %{instance: expected_instance_data},
          @host
        )
      end
    end

    test "persists a report indicating successful submission", config do
      %{expected_report_data: expected_report_data} = config

      %{"instance" => expected_instance_data} =
        expected_report_data |> stringify_keys()

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
          data: %{"instance" => ^expected_instance_data} 
        } = report
      )
      assert DateTime.diff(DateTime.utc_now(), report.submitted_at, :second) < 2
    end

    test "persists a report indicating unsuccessful submission", config do
      %{expected_report_data: expected_report_data} = config

      %{"instance" => expected_instance_data} =
        expected_report_data |> stringify_keys()

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
          data: %{"instance" => ^expected_instance_data},
          submitted_at: nil,
        } = report
      )
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
      acc |> stringify_key(key, map[key])
    end)
  end

  defp stringify_key(acc, key, val) when is_map(val) and not is_struct(val) do
    acc
    |> Map.merge(%{to_string(key) => stringify_keys(val)})
  end

  defp stringify_key(acc, key, val) do
    acc
    |> Map.merge(%{to_string(key) => val})
  end
end
