defmodule Lightning.UsageTracking.ReportDateServiceTest do
  use Lightning.DataCase

  alias Lightning.UsageTracking.ReportDateService

  describe "reportable_dates/1" do
    test "returns a range of reportable dates between the two boundary dates" do
      start_after = ~D[2024-02-12]
      today = ~D[2024-02-20]
      expected_dates = [
        ~D[2024-02-13],
        ~D[2024-02-14],
        ~D[2024-02-15],
        ~D[2024-02-16],
        ~D[2024-02-17],
        ~D[2024-02-18],
        ~D[2024-02-19],
      ]

      dates = ReportDateService.reportable_dates(start_after, today)

      assert dates == expected_dates
    end

    test "returns empty list if no reportable dates" do
      start_after = ~D[2024-02-19]
      today = ~D[2024-02-20]

      assert ReportDateService.reportable_dates(start_after, today) == []
    end

    test "returns empty list if start_after is today" do
      start_after = ~D[2024-02-20]
      today = ~D[2024-02-20]

      assert ReportDateService.reportable_dates(start_after, today) == []
    end

    test "returns empty list if start_after is after today" do
      start_after = ~D[2024-02-21]
      today = ~D[2024-02-20]

      assert ReportDateService.reportable_dates(start_after, today) == []
    end

    test "excludes any reportable days for which reports exist" do
      start_after = ~D[2024-02-12]
      today = ~D[2024-02-20]

      _before_start = insert(:usage_tracking_report, report_date: ~D[2024-02-11])
      _exclude_date_1 = insert(:usage_tracking_report, report_date: ~D[2024-02-17])
      _exclude_date_2 = insert(:usage_tracking_report, report_date: ~D[2024-02-14])
      _nil_date = insert(:usage_tracking_report, report_date: nil)

      expected_dates = [
        ~D[2024-02-13],
        ~D[2024-02-15],
        ~D[2024-02-16],
        ~D[2024-02-18],
        ~D[2024-02-19],
      ]

      dates = ReportDateService.reportable_dates(start_after, today)

      assert dates == expected_dates
    end

    # test "number of reportable days is constrained by batch size" do
    #
    # end
  end
end
