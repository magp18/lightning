defmodule Lightning.UsageTracking.UserQueries do
  import Ecto.Query

  alias Lightning.Accounts.User
  alias Lightning.Accounts.UserToken

  def enabled_users(date) do
    report_time = report_date_as_time(date)

    from u in User,
      where: u.disabled == false and u.inserted_at <= ^report_time,
      or_where:
        u.disabled == true and
          u.inserted_at <= ^report_time and
          u.updated_at > ^report_time
  end

  def active_users(date) do
    report_time = report_date_as_time(date)

    {:ok, threshold_time, _offset} =
      date
      |> Date.add(-30)
      |> then(& "#{&1}T23:59:59Z")
      |> DateTime.from_iso8601()

    from eu in enabled_users(date),
      distinct: eu.id,
      join: ut in UserToken, on: ut.user_id == eu.id,
      where: ut.context == "session",
      where: ut.inserted_at > ^threshold_time and ut.inserted_at <= ^report_time
  end

  defp report_date_as_time(date) do
    {:ok, datetime, _offset} = "#{date}T23:59:59Z" |> DateTime.from_iso8601()

    datetime
  end
end
