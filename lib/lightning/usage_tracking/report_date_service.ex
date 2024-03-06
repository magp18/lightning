defmodule Lightning.UsageTracking.ReportDateService do
  @moduledoc """
  Service that generates a collection of dates that need to be reported on.

  """
  import Ecto.Query

  alias Lightning.Repo
  alias Lightning.UsageTracking.Report

  def reportable_dates(start_after, today, batch_size) do
    case Date.diff(today, start_after) do
      diff when diff > 2 ->
        build_reportable_dates(start_after, today, batch_size)

      _too_small_a_diff ->
        []
    end
  end

  defp build_reportable_dates(start_after, today, batch_size) do
    start_after
    |> candidate_dates(today)
    |> remove_existing_dates()
    |> Enum.take(batch_size)
  end

  defp candidate_dates(start_after, today) do
    start_date = start_after |> Date.add(1)
    end_date = today |> Date.add(-1)

    Date.range(start_date, end_date)
  end

  defp remove_existing_dates(candidate_dates) do
    candidate_dates
    |> MapSet.new()
    |> MapSet.difference(report_dates(candidate_dates))
  end

  defp report_dates(candidate_dates) do
    [start_date, end_date] = find_boundaries(candidate_dates)

    query =
      from r in Report,
        where: r.report_date >= ^start_date and r.report_date < ^end_date,
        select: r.report_date,
        order_by: [asc: r.report_date]

    Repo.all(query) |> MapSet.new()
  end

  defp find_boundaries(date_range) do
    date_range
    |> Enum.to_list()
    |> then(fn [start | other_dates] -> [start, other_dates] end)
    |> then(fn [start, dates] -> [start, hd(Enum.reverse(dates))] end)
  end
end
