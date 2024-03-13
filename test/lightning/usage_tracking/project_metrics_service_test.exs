defmodule Lightning.UsageTracking.ProjectMetricsServiceTest do
  use Lightning.DataCase

  alias Lightning.UsageTracking.ProjectMetricsService
  alias Lightning.UsageTracking.WorkflowMetricsService

  @active_user_threshold_time ~U[2024-01-07 00:00:00Z]
  @date ~D[2024-02-05]
  @hashed_id "EECF8CFDD120E8DF8D9A12CA92AC3E815908223F95CFB11F19261A3C0EB34AEC"
  @project_id "3cfb674b-e878-470d-b7c0-cfa8f7e003ae"
  @report_time ~U[2024-02-05 23:59:59Z]

  setup do
    active_user_count = 2
    project = build_project(active_user_count, @project_id)
    _other_project = build_project(3, Ecto.UUID.generate())

    %{project: project, active_user_count: active_user_count}
  end

  describe ".generate_metrics/3 - cleartext disabled" do
    setup context do
      context |> Map.merge(%{enabled: false})
    end

    test "includes the hashed project id", config do
      %{project: project, enabled: enabled} = config

      hashed_uuid = @hashed_id

      assert(
        %{
          hashed_uuid: ^hashed_uuid
        } = ProjectMetricsService.generate_metrics(project, enabled, @date)
      )
    end

    test "excludes the cleartext uuid", config do
      %{project: project, enabled: enabled} = config

      assert(
        %{
          cleartext_uuid: nil
        } = ProjectMetricsService.generate_metrics(project, enabled, @date)
      )
    end

    test "includes the number of enabled users", config do
      %{
        project: project,
        enabled: enabled,
        active_user_count: active_user_count
      } = config

      enabled_user_count = active_user_count + 1

      assert(
        %{
          no_of_users: ^enabled_user_count
        } = ProjectMetricsService.generate_metrics(project, enabled, @date)
      )
    end

    test "includes the number of active users", config do
      %{
        project: project,
        enabled: enabled,
        active_user_count: active_user_count
      } = config

      assert(
        %{
          no_of_active_users: ^active_user_count
        } = ProjectMetricsService.generate_metrics(project, enabled, @date)
      )
    end

    test "includes data for associated workflows", config do
      %{project: project, enabled: enabled} = config

      [workflow_1, workflow_2] = project.workflows

      %{workflows: workflows} = ProjectMetricsService.generate_metrics(project, enabled, @date)

      workflows
      |> assert_workflow_metrics(
        workflow: workflow_1,
        cleartext_enabled: enabled,
        date: @date
      )
      workflows
      |> assert_workflow_metrics(
        workflow: workflow_2,
        cleartext_enabled: enabled,
        date: @date
      )
    end
  end

  describe ".generate_metrics/3 - cleartext enabled" do
    setup context do
      context |> Map.merge(%{enabled: true})
    end

    test "includes the hashed project id", config do
      %{project: project, enabled: enabled} = config

      hashed_uuid = @hashed_id

      assert(
        %{
          hashed_uuid: ^hashed_uuid
        } = ProjectMetricsService.generate_metrics(project, enabled, @date)
      )
    end

    test "includes the cleartext uuid", config do
      %{project: project, enabled: enabled} = config

      project_id = @project_id

      assert(
        %{
          cleartext_uuid: ^project_id
        } = ProjectMetricsService.generate_metrics(project, enabled, @date)
      )
    end

    test "includes the number of enabled users", config do
      %{
        project: project,
        enabled: enabled,
        active_user_count: active_user_count
      } = config

      enabled_user_count = active_user_count + 1

      assert(
        %{
          no_of_users: ^enabled_user_count
        } = ProjectMetricsService.generate_metrics(project, enabled, @date)
      )
    end

    test "includes the number of active users", config do
      %{
        project: project,
        enabled: enabled,
        active_user_count: active_user_count
      } = config

      assert(
        %{
          no_of_active_users: ^active_user_count
        } = ProjectMetricsService.generate_metrics(project, enabled, @date)
      )
    end

    test "includes data for associated workflows", config do
      %{project: project, enabled: enabled} = config

      [workflow_1, workflow_2] = project.workflows

      %{workflows: workflows} = ProjectMetricsService.generate_metrics(project, enabled, @date)

      workflows
      |> assert_workflow_metrics(
        workflow: workflow_1,
        cleartext_enabled: enabled,
        date: @date
      )
      workflows
      |> assert_workflow_metrics(
        workflow: workflow_2,
        cleartext_enabled: enabled,
        date: @date
      )
    end
  end

  defp build_project(count, project_id) do
    project = insert(:project, id: project_id, project_users: build_project_users(count))

    insert_list(count, :workflow, project: project)

    project |> Repo.preload([:users, workflows: [:jobs, :runs]])
  end

  defp build_project_users(count) do
    active_users = build_list(count, :project_user, user: &insert_active_user/0)
    enabled_user = build(:project_user, user: &insert_enabled_user/0)
    disabled_user = build(:project_user, user: &insert_disabled_user/0)

    [disabled_user | [enabled_user | active_users]]
  end

  defp insert_active_user do
    user =  insert_enabled_user()

    insert(
      :user_token,
      context: "session",
      user: user,
      inserted_at: @active_user_threshold_time
    )

    user
  end

  defp insert_enabled_user do
    user = insert(:user, disabled: false, inserted_at: @report_time)

    precedes_active_threshold =
      @active_user_threshold_time
      |> DateTime.add(-1, :second)

    insert(
      :user_token,
      context: "session",
      user: user,
      inserted_at: precedes_active_threshold
    )

    user
  end

  defp insert_disabled_user do
    activated_after_report = @report_time |> DateTime.add(1, :second)

    insert(:user, disabled: false, inserted_at: activated_after_report)
  end

  defp assert_workflow_metrics(workflows_metrics, opts) do
    workflow = opts |> Keyword.get(:workflow)
    cleartext_enabled = opts |> Keyword.get(:cleartext_enabled)
    date = opts |> Keyword.get(:date)

    workflow_metrics = workflows_metrics |> find_instrumentation(workflow.id)
    expected_metrics =
      WorkflowMetricsService.generate_metrics(workflow, cleartext_enabled, date)

    assert workflow_metrics == expected_metrics
  end

  defp find_instrumentation(instrumented_collection, identity) do
    hashed_uuid = build_hash(identity)

    instrumented_collection
    |> Enum.find(fn record -> record.hashed_uuid == hashed_uuid end)
  end

  defp build_hash(uuid), do: Base.encode16(:crypto.hash(:sha256, uuid))
end
