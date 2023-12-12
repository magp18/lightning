# This module will be re-introduced in https://github.com/OpenFn/Lightning/issues/1143
defmodule LightningWeb.EndToEndTest do
  use LightningWeb.ConnCase, async: false

  import Lightning.JobsFixtures
  import Lightning.Factories

  alias Lightning.Attempt
  alias Lightning.Attempts
  alias Lightning.Attempts.Events
  alias Lightning.Invocation
  alias Lightning.Repo
  alias Lightning.WorkOrders
  alias Lightning.Runtime.RuntimeManager

  require Attempt

  setup_all context do
    start_runtime_manager(context)
  end

  describe "webhook triggered attempts" do
    setup :register_and_log_in_superuser

    @tag timeout: 120_000
    test "complete an attempt on a complex workflow with parallel jobs", %{
      conn: conn
    } do
      project = insert(:project)

      %{triggers: [%{id: webhook_trigger_id}]} =
        insert(:complex_workflow, project: project)

      # Post to webhook
      webhook_body = %{"x" => 1}
      conn = post(conn, "/i/#{webhook_trigger_id}", webhook_body)

      assert %{"work_order_id" => wo_id} = json_response(conn, 200)

      assert %{attempts: [%{id: attempt_id}]} =
               WorkOrders.get(wo_id, include: [:attempts])

      assert %{runs: []} = Attempts.get(attempt_id, include: [:runs])

      assert %{attempts: [attempt]} =
               WorkOrders.get(wo_id, include: [:attempts])

      # wait to complete
      Events.subscribe(attempt)

      attempt_id = attempt.id

      assert_receive %Events.AttemptUpdated{
                       attempt: %{id: ^attempt_id, state: :success}
                     },
                     115_000

      assert %{state: :success} = WorkOrders.get(wo_id)

      %{entries: runs} = Invocation.list_runs_for_project(project)

      # runs with unique outputs and all succeed
      assert Enum.count(runs) == 7
      assert Enum.count(runs, & &1.output_dataclip_id) == 7
      assert Enum.all?(runs, fn run -> run.exit_reason == "success" end)

      # first run has the webhook body as input
      [first_run | runs] = Enum.reverse(runs)
      assert webhook_body == select_dataclip_body(first_run.input_dataclip_id)

      # the other 6 runs produce the same input and output on x twice
      # (2 branches that doubles x value three times)
      assert runs
             |> Enum.map(&select_dataclip_body(&1.input_dataclip_id)["x"])
             |> Enum.frequencies()
             |> Enum.all?(fn {_x, count} -> count == 2 end)

      assert runs
             |> Enum.map(&select_dataclip_body(&1.output_dataclip_id)["x"])
             |> Enum.frequencies()
             |> Enum.all?(fn {_x, count} -> count == 2 end)

      assert %{state: :success} = WorkOrders.get(wo_id)
    end

    @tag timeout: 120_000
    test "the whole thing", %{conn: conn} do
      project = insert(:project)

      project_credential =
        insert(:project_credential,
          credential: %{
            name: "test credential",
            body: %{"username" => "quux", "password" => "immasecret"}
          },
          project: project
        )

      %{
        job: first_job = %{workflow: workflow},
        trigger: webhook_trigger,
        edge: _edge
      } =
        workflow_job_fixture(
          project: project,
          name: "1st-job",
          adaptor: "@openfn/language-http@latest",
          body: webhook_body(),
          project_credential: project_credential
        )

      flow_job =
        insert(:job,
          name: "2nd-job",
          adaptor: "@openfn/language-http@latest",
          body: on_success_body(),
          workflow: workflow,
          project_credential: project_credential
        )

      insert(:edge, %{
        workflow: workflow,
        source_job_id: first_job.id,
        target_job_id: flow_job.id,
        condition: :on_job_success
      })

      catch_job =
        insert(:job,
          name: "3rd-job",
          adaptor: "@openfn/language-http@latest",
          body: on_failure_body(),
          workflow: workflow,
          project_credential: project_credential
        )

      insert(:edge, %{
        source_job_id: flow_job.id,
        workflow: workflow,
        target_job_id: catch_job.id,
        condition: :on_job_failure
      })

      expression1_job =
        insert(:job,
          name: "4th-job",
          adaptor: "@openfn/language-http@latest",
          body: on_js_condition_body(),
          workflow: workflow,
          project_credential: project_credential
        )

      insert(:edge, %{
        source_job_id: catch_job.id,
        workflow: workflow,
        target_job_id: expression1_job.id,
        condition: :js_expression,
        js_expression_label: "less_than_1000",
        js_expression_body: "state.x < 1000"
      })
      |> IO.inspect()

      # expression2_job =
      #   insert(:job,
      #     name: "5th-job",
      #     adaptor: "@openfn/language-http@latest",
      #     body: on_js_condition_body(),
      #     workflow: workflow,
      #     project_credential: project_credential
      #   )

      # insert(:edge, %{
      #   source_job_id: expression1_job.id,
      #   workflow: workflow,
      #   target_job_id: expression2_job.id,
      #   condition: :js_expression,
      #   js_expression_label: "greater_than_10000",
      #   js_expression_body: "state.x > 10000"
      # })
      # |> IO.inspect()

      webhook_body = %{"fieldOne" => 123, "fieldTwo" => "some string"}

      conn = post(conn, "/i/#{webhook_trigger.id}", webhook_body)

      assert %{"work_order_id" => wo_id} = json_response(conn, 200)

      assert %{attempts: [%{id: attempt_id} = attempt]} =
               WorkOrders.get(wo_id, include: [:attempts])

      assert %{runs: []} = Attempts.get(attempt.id, include: [:runs])

      # wait to complete
      Events.subscribe(attempt)

      Enum.any?(1..1000, fn _i ->
        receive do
          %Events.AttemptUpdated{
            attempt: %{id: ^attempt_id, state: :success}
          } ->
            true

          %{} = event ->
            Map.get(event, :state) == :crashed && IO.inspect(event)
            false

          _message ->
            false
        end
      end)

      assert %{state: :success} = WorkOrders.get(wo_id)

      # All runs are associated with the same project and attempt and proper job
      %{runs: runs} = Attempts.get(attempt.id, include: [:runs])

      %{entries: [run_3, run_2, run_1]} =
        Invocation.list_runs_for_project(project)

      assert MapSet.new(runs, & &1.id) ==
               MapSet.new([run_1, run_2, run_3], & &1.id)

      # Alls runs have consistent finish_at, exit_reason and dataclips
      %{claimed_at: claimed_at, finished_at: finished_at} =
        Attempts.get(attempt.id)

      # Run 1 succeeds with webhook_body as input
      assert NaiveDateTime.diff(run_1.finished_at, claimed_at, :microsecond) > 0
      assert NaiveDateTime.diff(run_1.finished_at, finished_at, :microsecond) < 0
      assert run_1.exit_reason == "success"

      expected_job_x_value = 123 * 2

      lines = Invocation.logs_for_run(run_1)

      assert Enum.any?(
               lines,
               &(&1.source == "R/T" and &1.message =~ "Operation 1 complete in")
             )

      version_logs =
        lines
        |> Enum.find(fn l -> l.source == "VER" end)
        |> Map.get(:message)

      assert version_logs =~ "▸ node.js                  18.17"
      assert version_logs =~ "▸ worker                   0.3"
      assert version_logs =~ "▸ engine                   0.2"
      assert version_logs =~ "▸ @openfn/language-http    3.1.12"

      expected_lines =
        MapSet.new([
          {"R/T", "Starting operation 1"},
          {"JOB", "#{expected_job_x_value}"},
          {"JOB", "{\"name\":\"ศผ่องรี มมซึฆเ\"}"},
          {"R/T", "Expression complete!"}
        ])

      assert expected_lines ==
               MapSet.intersection(
                 expected_lines,
                 MapSet.new(lines, &{&1.source, &1.message})
               )

      # input: has only the webhook body
      assert webhook_body == select_dataclip_body(run_1.input_dataclip_id)

      # output: data unchanged by the job and x is updated
      assert %{"data" => ^webhook_body, "x" => ^expected_job_x_value} =
               select_dataclip_body(run_1.output_dataclip_id)

      # #  Run 2 should fail but not expose a secret
      assert NaiveDateTime.diff(run_2.finished_at, claimed_at, :microsecond) > 0
      assert NaiveDateTime.diff(run_2.finished_at, finished_at, :microsecond) < 0
      assert run_2.exit_reason == "fail"

      log = Invocation.assemble_logs_for_run(run_2)

      assert log =~ ~S[{"password":"***","username":"quux"}]
      assert log =~ ~S"Check state.errors"

      assert select_dataclip_body(run_1.output_dataclip_id) ==
               select_dataclip_body(run_2.input_dataclip_id)

      #  Run 3 should succeed and log "6"
      assert NaiveDateTime.diff(run_3.finished_at, claimed_at, :microsecond) > 0
      assert NaiveDateTime.diff(run_3.finished_at, finished_at, :microsecond) < 0
      assert run_3.exit_reason == "success"

      lines = Invocation.logs_for_run(run_3)

      assert Enum.any?(
               lines,
               &(&1.source == "R/T" and &1.message =~ "Operation 1 complete in")
             )

      expected_job_x_value = 123 * 6

      expected_lines =
        MapSet.new([
          {"R/T", "Starting operation 1"},
          {"JOB", "#{expected_job_x_value}"},
          # Check to ensure that an inadvertantly exposed secret from job 2 is
          # still scrubbed properly in job 3.
          {"JOB", "quux is on the safelist"},
          {"JOB", "but *** should be scrubbed"},
          {"JOB", "along with its encoded form ***"},
          {"JOB", "and its basic auth form ***"},
          {"R/T", "Expression complete!"}
        ])

      assert expected_lines ==
               MapSet.intersection(
                 expected_lines,
                 MapSet.new(lines, &{&1.source, &1.message})
               )

      assert select_dataclip_body(run_2.output_dataclip_id) ==
               select_dataclip_body(run_3.input_dataclip_id)

      assert %{"data" => ^webhook_body, "x" => ^expected_job_x_value} =
               select_dataclip_body(run_3.output_dataclip_id)
    end
  end

  defp webhook_body do
    "fn(state => {
      state.x = state.data.fieldOne * 2;
      console.log(state.x);
      console.log({name: 'ศผ่องรี มมซึฆเ'})
      return state;
    });"
  end

  defp on_success_body do
    "fn(state => {
      console.log(state.configuration);
      throw 'fail!'
    });"
  end

  defp on_failure_body do
    "fn(state => {
      state.x = state.x * 3;
      console.log(state.x);
      console.log('quux is on the safelist')
      console.log('but immasecret should be scrubbed');
      console.log('along with its encoded form #{Base.encode64("immasecret")}');
      console.log('and its basic auth form #{Base.encode64("quux:immasecret")}');
      return state;
    });"
  end

  defp on_js_condition_body do
    "fn(state => {
      state.x = state.x * 5;
      console.log(state.x);
      return state;
    });"
  end

  defp start_runtime_manager(_context) do
    opts =
      Application.get_env(:lightning, RuntimeManager)
      |> Keyword.merge(
        name: E2ETestRuntimeManager,
        start: true,
        worker_secret: Lightning.Config.worker_secret(),
        port: Enum.random(2223..3333)
      )

    {:ok, rtm_server} = RuntimeManager.start_link(opts)

    running =
      Enum.any?(1..20, fn _i ->
        Process.sleep(50)
        %{runtime_port: port} = :sys.get_state(rtm_server)
        port != nil
      end)

    if running, do: :ok, else: :error
  end

  defp select_dataclip_body(uuid) do
    {:ok, %{rows: [[body]]}} =
      Ecto.Adapters.SQL.query(
        Repo,
        "SELECT BODY FROM DATACLIPS WHERE ID=$1",
        [
          Ecto.UUID.dump!(uuid)
        ]
      )

    body
  end
end
