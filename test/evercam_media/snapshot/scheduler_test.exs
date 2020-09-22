defmodule EvercamMedia.Snapshot.SchedulerTest do
  use ExUnit.Case, async: true

  setup do
    schedule = %{
      "Monday" => ["00:00-23:59"], # all day
      "Tuesday" => ["00:00-23:59"],
      "Wednesday" => ["00:00-23:59"],
      "Thursday" => ["00:00-23:59"],
      "Friday" => ["00:00-23:59"],
      "Saturday" => ["00:00-23:59"],
      "Sunday" => ["00:00-23:59"],
    }
   {:ok, schedule: schedule}
 end

 test "scheduler return true at zero hours for all day recording - US Timezone", %{schedule: schedule} do
   timezone = "America/New_York"
   check_time = Calendar.DateTime.from_erl!({{2015, 10, 8}, {2, 35, 0}}, timezone)
   assert EvercamMedia.Schedule.scheduled?(schedule, check_time, timezone) == {:ok, true}
 end

 test "scheduler return true at 23 hours for all day recording - US Timezone", %{schedule: schedule} do
   timezone = "America/New_York"
   check_time = Calendar.DateTime.from_erl!({{2015, 10, 7}, {23, 59, 00}}, timezone)
   assert EvercamMedia.Schedule.scheduled?(schedule, check_time, timezone) == {:ok, true}
 end

 test "scheduler return true at zero hours for all day recording - UTC", %{schedule: schedule} do
   timezone = "UTC"
   check_time = Calendar.DateTime.from_erl!({{2015, 10, 8}, {2, 35, 0}}, timezone)
   assert EvercamMedia.Schedule.scheduled?(schedule, check_time, timezone) == {:ok, true}
 end

 test "scheduler return true at 23 hours for all day recording - UTC", %{schedule: schedule} do
   timezone = "UTC"
   check_time = Calendar.DateTime.from_erl!({{2015, 10, 7}, {23, 59, 00}}, timezone)
   assert EvercamMedia.Schedule.scheduled?(schedule, check_time, timezone) == {:ok, true}
 end

 test "scheduler return true at any time for all day recording - not timezone given", %{schedule: schedule} do
   check_time = Calendar.DateTime.now!("UTC")
   assert EvercamMedia.Schedule.scheduled?(schedule, check_time, nil) == {:ok, true}
 end

end
