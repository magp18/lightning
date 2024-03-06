defmodule Lightning.UsageTracking.ReportDateService do
  import Ecto.Query

  alias Lightning.Repo
  alias Lightning.UsageTracking.Report

  def reportable_dates(start_after, today, batch_size) do
    case Date.diff(today, start_after) do
      diff when diff > 2 ->
        start_date = start_after |> Date.add(1)
        end_date = today |> Date.add(-1) 

        candidate_dates = Date.range(start_date, end_date) |> Enum.to_list()

        candidate_dates
        |> remove_existing_dates()
        |> Enum.take(batch_size)
      _ -> []
    end
  end

  defp remove_existing_dates(candidate_date_list) do
    [start_date | _other_dates] = candidate_date_list
    [end_date | _other_dates] = candidate_date_list |> Enum.reverse()

    query = from r in Report,
      where: r.report_date >= ^start_date and r.report_date < ^end_date,
      select: r.report_date,
      order_by: [asc: r.report_date]

    existing_dates = Repo.all(query) |> MapSet.new()
    candidate_dates = candidate_date_list |> MapSet.new()
    MapSet.difference(candidate_dates, existing_dates) |> Enum.to_list()
  end
end
