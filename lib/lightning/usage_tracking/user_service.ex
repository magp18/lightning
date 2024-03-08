defmodule Lightning.UsageTracking.UserService do
  import Ecto.Query

  alias Lightning.Repo
  alias Lightning.Accounts.User

  def no_of_users(date) do
    {:ok, datetime, _offset} = "#{date}T23:59:59Z" |> DateTime.from_iso8601()

    query =
      from u in User,
        where: u.disabled == false and u.inserted_at <= ^datetime,
        or_where:
          u.disabled == true and
            u.inserted_at <= ^datetime and
            u.updated_at > ^datetime

    Repo.aggregate(query, :count)
  end
end
