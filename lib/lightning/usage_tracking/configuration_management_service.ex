defmodule Lightning.UsageTracking.ConfigurationManagementService do
  @moduledoc """
  Service that updates DailyReportConfiguration to align with the
  enabled/disabled state of usage tracking.

  """
  alias Ecto.Changeset
  alias Lightning.Repo
  alias Lightning.UsageTracking.DailyReportConfiguration

  def enable(enabled_at) do
    start_reporting_after = DateTime.to_date(enabled_at)

    case Repo.one(DailyReportConfiguration) do
      config = %{tracking_enabled_at: nil, start_reporting_after: nil} ->
        enable_config(config, enabled_at, start_reporting_after)

      nil ->
        create_enabled_config(enabled_at, start_reporting_after)

      config ->
        config
    end
  end

  def disable do
    if config = Repo.one(DailyReportConfiguration) do
      config
      |> Changeset.change(tracking_enabled_at: nil, start_reporting_after: nil)
      |> Repo.update!()
    end
  end

  def create_enabled_config(enabled_at, start_reporting_after) do
    %DailyReportConfiguration{
      tracking_enabled_at: enabled_at,
      start_reporting_after: start_reporting_after
    }
    |> Repo.insert!()
  end

  def enable_config(config, enabled_at, start_reporting_after) do
    config
    |> Changeset.change(
      tracking_enabled_at: enabled_at,
      start_reporting_after: start_reporting_after
    )
    |> Repo.update!()
  end

  def start_reporting_after(date) do
    case Repo.one(DailyReportConfiguration) do
      %{tracking_enabled_at: nil} ->
        :error

      nil ->
        :error

      config ->
        config
        |> Changeset.change(start_reporting_after: date)
        |> Repo.update!()

        :ok
    end
  end
end
