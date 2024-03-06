defmodule Lightning.UsageTracking.DailyReportConfiguration do
  @moduledoc """
  Configuration for the creation of daily reports

  """
  use Ecto.Schema

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "usage_tracking_daily_report_configurations" do
    field :instance_id, Ecto.UUID, autogenerate: true
    field :tracking_enabled_at, :utc_datetime_usec
    field :start_reporting_after, :date

    timestamps()
  end
end