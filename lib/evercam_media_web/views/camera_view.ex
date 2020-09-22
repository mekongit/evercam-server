defmodule EvercamMediaWeb.CameraView do
  use EvercamMediaWeb, :view
  alias EvercamMedia.Util

  def render("index." <> <<version::binary-size(2)>>  <> ".json", %{cameras: cameras, user: user}) do
    %{cameras: render_many(cameras, __MODULE__, "camera." <> version <>".json", user: user)}
  end

  def render("show." <> <<version::binary-size(2)>>  <> ".json", %{camera: camera, user: user}) do
    %{cameras: render_many([camera], __MODULE__, "camera." <> version <> ".json", user: user)}
  end

  def render("camera." <> <<version::binary-size(2)>>  <> ".json", %{camera: camera, user: user}) do
    case Permission.Camera.can_view?(user, camera) do
      true -> base_camera_attributes(version, camera, user) |> Map.merge(privileged_camera_attributes(camera))
      _ -> base_camera_attributes(version, camera, user)
    end
  end

  defp base_camera_attributes(version, camera, user) do
    %{
      id: camera.exid,
      name: camera.name,
      owned: Camera.is_owner?(user, camera),
      owner: camera.owner.username,
      vendor_id: Camera.get_vendor_attr(camera, :exid),
      vendor_name: Camera.get_vendor_attr(camera, :name),
      model_id: Camera.get_model_attr(camera, :exid),
      model_name: Camera.get_model_attr(camera, :name),
      created_at: Util.date_wrt_version(version, camera.created_at, camera),
      updated_at: Util.date_wrt_version(version, camera.updated_at, camera),
      last_polled_at: Util.date_wrt_version(version, camera.last_polled_at, camera),
      last_online_at: Util.date_wrt_version(version, camera.last_online_at, camera),
      is_online_email_owner_notification: is_send_notification?(camera.alert_emails, user),
      status: camera.status,
      is_online: (if camera.status == "online", do: true, else: false),
      is_public: camera.is_public,
      offline_reason: Util.get_offline_reason(camera.offline_reason),
      discoverable: camera.discoverable,
      timezone: Camera.get_timezone(camera),
      location: Camera.get_location(camera),
      location_detailed: camera.location_detailed,
      rights: Camera.get_rights(camera, user),
      proxy_url: %{
        hls: Util.get_hls_url(camera, User.get_fullname(user)),
        rtmp: Util.get_rtmp_url(camera, User.get_fullname(user)),
      },
      thumbnail_url: thumbnail_url(camera),
      project: project(camera.projects)
    }
  end

  defp privileged_camera_attributes(camera) do
    %{
      cam_username: Camera.username(camera),
      cam_password: Camera.password(camera),
      external: %{
        host: Camera.host(camera, "external"),
        http: %{
          port: Camera.port(camera, "external", "http"),
          nvr_port: Camera.port(camera, "nvr", "http"),
          camera: Camera.external_url(camera, "http"),
          jpg: Camera.snapshot_url(camera, "jpg"),
          mjpg: Camera.snapshot_url(camera, "mjpg"),
        },
        rtsp: %{
          port: Camera.port(camera, "external", "rtsp"),
          mpeg: Camera.rtsp_url(camera, "external", "mpeg", false),
          audio: Camera.rtsp_url(camera, "external", "audio", false),
          h264: Camera.rtsp_url(camera, "external", "h264", false),
        },
      },
      internal: %{
        host: Camera.host(camera, "internal"),
        http: %{
          port: Camera.port(camera, "internal", "http"),
          camera: Camera.internal_url(camera, "http"),
          jpg: Camera.internal_snapshot_url(camera, "jpg"),
          mjpg: Camera.internal_snapshot_url(camera, "mjpg"),
        },
        rtsp: %{
          port: Camera.port(camera, "internal", "rtsp"),
          mpeg: Camera.rtsp_url(camera, "internal", "mpeg", false),
          audio: Camera.rtsp_url(camera, "internal", "audio", false),
          h264: Camera.rtsp_url(camera, "internal", "h264", false),
        },
      },
      cloud_recordings: cloud_recording(camera.cloud_recordings)
    }
  end

  defp thumbnail_url(camera) do
    EvercamMediaWeb.Endpoint.static_url <> "/v1/cameras/" <> camera.exid <> "/thumbnail"
  end

  defp is_send_notification?(_emails, nil), do: false
  defp is_send_notification?(emails, _caller) when emails in [nil, ""], do: false
  defp is_send_notification?(emails, caller) do
    String.contains?(emails, caller.email)
  end

  defp cloud_recording(nil), do: nil
  defp cloud_recording(cloud_recording) do
    %{
      frequency: cloud_recording.frequency,
      storage_duration: cloud_recording.storage_duration,
      status: cloud_recording.status,
      schedule: cloud_recording.schedule
    }
  end

  defp project(nil), do: nil
  defp project(project) do
    %{
      name: project.name,
      id: project.exid
    }
  end

  defp get_camera_location(camera, nil), do: Camera.get_location(camera) |> Map.merge(%{dir: 0, fov_h: 0})
  defp get_camera_location(_, location_detail), do: location_detail
end
