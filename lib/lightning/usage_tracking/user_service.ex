defmodule Lightning.UsageTracking.UserService do
  alias Lightning.Repo
  alias Lightning.UsageTracking.UserQueries

  def no_of_users(date) do
    UserQueries.enabled_users(date) |> Repo.aggregate(:count)
  end

  def no_of_active_users(date) do
    UserQueries.active_users(date) |> Repo.aggregate(:count)
  end
end
