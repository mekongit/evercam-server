defmodule ExternalPTZTest do
  use ExUnit.Case
  alias EvercamMedia.ONVIFPTZ

  @camera_url System.get_env["ONVIF_CAM_URL"]
  @auth System.get_env["ONVIF_AUTH"]

  @moduletag :external
  @access_info %{"url" => @camera_url, "auth" => @auth}

  test "goto_preset method on hikvision camera" do
    {:ok, response} = ONVIFPTZ.goto_preset(@access_info, "Profile_1", "6")
    assert response == :ok
  end

  test "set_preset and remove_preset method on hikvision camera" do
    {:ok, response} = ONVIFPTZ.set_preset(@access_info, "Profile_1")
    preset_token = response |> Map.get("PresetToken")
    {:ok, response} = ONVIFPTZ.remove_preset(@access_info, "Profile_1", preset_token)
    assert response == :ok
  end

  test "set_home_position method on hikvision camera" do
    {:ok, response} = ONVIFPTZ.set_home_position(@access_info, "Profile_1")
    assert response == :ok
  end

  test "goto_home_position method on hikvision camera" do
    {:ok, response} = ONVIFPTZ.goto_home_position(@access_info, "Profile_1")
    assert response == :ok
  end

  test "relative_move method on hikvision camera" do
    {:ok, response} = ONVIFPTZ.relative_move(@access_info, "Profile_1", [x: 0.0, y: 0.0, zoom: 0.0])
    assert response == :ok
  end

  test "stop method on hikvision camera" do
    {:ok, response} = ONVIFPTZ.continuous_move(@access_info, "Profile_1", [x: 0.1, y: 0.0])
    assert response == :ok
    {:ok, response} = ONVIFPTZ.stop(@access_info, "Profile_1")
    assert response == :ok
  end
end
