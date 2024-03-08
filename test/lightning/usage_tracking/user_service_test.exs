defmodule Lightning.UsageTracking.UserServiceTest do
  use Lightning.DataCase

  alias Lightning.UsageTracking.UserService

  @date ~D[2024-02-05]
  describe "no_of_users/1" do
    test "count includes enabled users created on/before date" do
      _eligible_user_1 = insert(
        :user,
        disabled: false,
        inserted_at: ~U[2024-02-05 23:59:59Z]
      )
      _eligible_user_2 = insert(
        :user,
        disabled: false,
        inserted_at: ~U[2024-02-04 01:00:00Z]
      )
      _eligible_user_3 = insert(
        :user,
        disabled: false,
        inserted_at: ~U[2024-02-04 01:00:00Z]
      )
      _ineligible_user_disabled = insert(
        :user,
        disabled: true,
        inserted_at: ~U[2024-02-04 01:00:00Z],
        updated_at: ~U[2024-02-04 01:00:00Z]
      )
      _ineligible_user_after_date = insert(
        :user,
        disabled: false,
        inserted_at: ~U[2024-02-06 00:00:01Z]
      )

      assert UserService.no_of_users(@date) == 3
    end

    test "count includes disabled users that may have been active" do
      _eligible_user_enabled = insert(
        :user,
        disabled: false,
        inserted_at: ~U[2024-02-05 23:59:59Z]
      )
      _eligible_user_inserted_before_disabled_after_date_1 = insert(
        :user,
        disabled: true,
        inserted_at: ~U[2024-02-04 01:00:00Z],
        updated_at: ~U[2024-02-06 00:00:00Z]
      )
      _eligible_user_inserted_before_disabled_after_date_2 = insert(
        :user,
        disabled: true,
        inserted_at: ~U[2024-02-05 01:00:00Z],
        updated_at: ~U[2024-02-06 00:00:01Z]
      )
      _eligible_user_inserted_before_disabled_after_date_3 = insert(
        :user,
        disabled: true,
        inserted_at: ~U[2024-02-05 12:00:00Z],
        updated_at: ~U[2024-02-06 00:00:02Z]
      )
      _eligible_user_inserted_before_disabled_after_date_4 = insert(
        :user,
        disabled: true,
        inserted_at: ~U[2024-02-05 23:59:59Z],
        updated_at: ~U[2024-02-07 00:00:00Z]
      )
      _ineligible_user_disabled_inserted_before_disabled_before = insert(
        :user,
        disabled: true,
        inserted_at: ~U[2024-02-04 01:00:00Z],
        updated_at: ~U[2024-02-04 01:00:00Z]
      )
      _ineligible_user_disabled_inserted_after_disabled_after_1 = insert(
        :user,
        disabled: true,
        inserted_at: ~U[2024-02-06 00:00:00Z],
        updated_at: ~U[2024-02-06 01:00:00Z]
      )
      _ineligible_user_disabled_inserted_after_disabled_after_2 = insert(
        :user,
        disabled: true,
        inserted_at: ~U[2024-02-06 00:00:01Z],
        updated_at: ~U[2024-02-06 01:00:00Z]
      )

      assert UserService.no_of_users(@date) == 5
    end
  end
end
