defmodule Lightning.UsageTracking.ProjectMetricsService do
  alias Lightning.Projects.Project
  alias Lightning.UsageTracking.UserService

  def generate_metrics(project, cleartext_enabled, date) do
    %Project{id: id, users: users} = project

    %{
      no_of_active_users: UserService.no_of_active_users(date, users),
      no_of_users: UserService.no_of_users(date, users)
    }
    |> Map.merge(instrument_identity(id, cleartext_enabled))
  end

  defp instrument_identity(identity, false = _cleartext_enabled) do
    %{
      cleartext_uuid: nil,
      hashed_uuid: identity |> build_hash()
    }
  end

  defp instrument_identity(identity, true = _cleartext_enabled) do
    identity
    |> instrument_identity(false)
    |> Map.merge(%{cleartext_uuid: identity})
  end

  defp build_hash(uuid), do: Base.encode16(:crypto.hash(:sha256, uuid))
end
