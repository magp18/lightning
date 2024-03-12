defmodule Lightning.UsageTracking.WorkflowMetricsServiceTest do
  use Lightning.DataCase

  alias Lightning.UsageTracking.WorkflowMetricsService

  @date ~D[2024-02-05]
  @finished_at ~U[2024-02-05 12:11:10Z]
  @hashed_id "EECF8CFDD120E8DF8D9A12CA92AC3E815908223F95CFB11F19261A3C0EB34AEC"
  @workflow_id "3cfb674b-e878-470d-b7c0-cfa8f7e003ae"

  setup do
    no_of_jobs = 2
    no_of_work_orders = 3
    no_of_runs_per_work_order = 2
    no_of_steps_per_run = 3

    workflow = build_workflow(
      @workflow_id,
      no_of_jobs: no_of_jobs,
      no_of_work_orders: no_of_work_orders,
      no_of_runs_per_work_order: no_of_runs_per_work_order,
      no_of_steps_per_run: no_of_steps_per_run
    )
    _other_workflow = build_workflow(
      Ecto.UUID.generate(),
      no_of_jobs: no_of_jobs + 1,
      no_of_work_orders: no_of_work_orders + 1,
      no_of_runs_per_work_order: no_of_runs_per_work_order + 1,
      no_of_steps_per_run: no_of_steps_per_run + 1
    )

    no_of_runs = no_of_work_orders * no_of_runs_per_work_order
    no_of_steps = no_of_runs * no_of_steps_per_run

    %{
      workflow: workflow,
      no_of_jobs: no_of_jobs,
      no_of_runs: no_of_runs,
      no_of_steps: no_of_steps
    }
  end
  
  describe "generate_metrics/3 - cleartext disabled" do
    setup context do
      context |> Map.merge(%{enabled: false})
    end

    test "includes the hashed workflow uuid", config do
      %{workflow: workflow, enabled: enabled} = config

      hashed_uuid = @hashed_id

      assert(
        %{
          hashed_uuid: ^hashed_uuid
        } = WorkflowMetricsService.generate_metrics(workflow, enabled, @date)
      )
    end

    test "does not include the cleartext uuid", config do
      %{workflow: workflow, enabled: enabled} = config

      assert(
        %{
          cleartext_uuid: nil
        } = WorkflowMetricsService.generate_metrics(workflow, enabled, @date)
      )
    end

    test "includes the number of jobs", config do
      %{
        workflow: workflow,
        enabled: enabled,
        no_of_jobs: no_of_jobs
      } = config

      assert(
        %{
          no_of_jobs: ^no_of_jobs
        } = WorkflowMetricsService.generate_metrics(workflow, enabled, @date)
      )
    end

    test "includes the number of finished runs", config do
      %{
        workflow: workflow,
        enabled: enabled,
        no_of_runs: no_of_runs
      } = config

      assert(
        %{
          no_of_runs: ^no_of_runs
        } = WorkflowMetricsService.generate_metrics(workflow, enabled, @date)
      )
    end

    test "includes the number of steps for the finished runs", config do
      %{
        workflow: workflow,
        enabled: enabled,
        no_of_steps: no_of_steps
      } = config

      assert(
        %{
          no_of_steps: ^no_of_steps
        } = WorkflowMetricsService.generate_metrics(workflow, enabled, @date)
      )
    end
  end

  describe "generate_metrics/3 - cleartext enabled" do
    setup context do
      context |> Map.merge(%{enabled: true})
    end

    test "includes the hashed workflow uuid", config do
      %{workflow: workflow, enabled: enabled} = config

      hashed_uuid = @hashed_id

      assert(
        %{
          hashed_uuid: ^hashed_uuid
        } = WorkflowMetricsService.generate_metrics(workflow, enabled, @date)
      )
    end

    test "includes the cleartext uuid", config do
      %{workflow: workflow, enabled: enabled} = config

      cleartext_uuid = @workflow_id

      assert(
        %{
          cleartext_uuid: ^cleartext_uuid
        } = WorkflowMetricsService.generate_metrics(workflow, enabled, @date)
      )
    end

    test "includes the number of jobs", config do
      %{
        workflow: workflow,
        enabled: enabled,
        no_of_jobs: no_of_jobs
      } = config

      assert(
        %{
          no_of_jobs: ^no_of_jobs
        } = WorkflowMetricsService.generate_metrics(workflow, enabled, @date)
      )
    end

    test "includes the number of finished runs", config do
      %{
        workflow: workflow,
        enabled: enabled,
        no_of_runs: no_of_runs
      } = config

      assert(
        %{
          no_of_runs: ^no_of_runs
        } = WorkflowMetricsService.generate_metrics(workflow, enabled, @date)
      )
    end

    test "includes the number of steps for the finished runs", config do
      %{
        workflow: workflow,
        enabled: enabled,
        no_of_steps: no_of_steps
      } = config

      assert(
        %{
          no_of_steps: ^no_of_steps
        } = WorkflowMetricsService.generate_metrics(workflow, enabled, @date)
      )
    end
  end

  defp build_workflow(workflow_id, opts) do
    no_of_jobs = opts |> Keyword.get(:no_of_jobs)
    no_of_work_orders = opts |> Keyword.get(:no_of_work_orders)
    no_of_runs_per_work_order = opts |> Keyword.get(:no_of_runs_per_work_order)
    no_of_steps_per_run = opts |> Keyword.get(:no_of_steps_per_run)

    workflow = insert(:workflow, id: workflow_id)

    [job | _] = insert_list(no_of_jobs, :job, workflow: workflow)

    work_orders = insert_list(no_of_work_orders, :workorder, workflow: workflow)

    for work_order <- work_orders do
      insert_runs_with_steps(
        no_of_runs_per_work_order: no_of_runs_per_work_order,
        no_of_steps_per_run: no_of_steps_per_run,
        work_order: work_order,
        job: job
      )
    end

    workflow |> Repo.preload([:jobs, runs: [:steps]])
  end

  defp insert_runs_with_steps(opts) do
    no_of_runs_per_work_order = opts |> Keyword.get(:no_of_runs_per_work_order)
    no_of_steps_per_run = opts |> Keyword.get(:no_of_steps_per_run)
    work_order = opts |> Keyword.get(:work_order)
    job = opts |> Keyword.get(:job)

    dataclip_builder = fn -> build(:dataclip) end

    insert_list(
      no_of_runs_per_work_order,
      :run,
      work_order: work_order,
      dataclip: dataclip_builder,
      finished_at: @finished_at,
      state: :success,
      starting_job: job,
      steps: fn ->
        build_list(
          no_of_steps_per_run,
          :step,
          input_dataclip: dataclip_builder,
          output_dataclip: dataclip_builder,
          job: job,
          finished_at: @finished_at
        )
      end
    )
  end
end
