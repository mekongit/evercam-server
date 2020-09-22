defmodule EvercamMedia.Snapshot.StorageTest do
  use ExUnit.Case, async: true
  alias EvercamMedia.Snapshot.Storage

  @root_dir Application.get_env(:evercam_media, :storage_dir)

  test "file paths are constructed correctly" do
    camera_exid = "austin"
    timestamp = 1454715880
    app_name = "recordings"

    directory_path = "#{@root_dir}/austin/snapshots/recordings/2016/02/05/23/"
    file_name = "44_40_000.jpg"

    assert Storage.construct_directory_path(camera_exid, timestamp, app_name) == directory_path
    assert Storage.construct_file_name(timestamp) == file_name
  end
end
