defmodule EvercamMediaWeb.NVRController do
  use EvercamMediaWeb, :controller
  use PhoenixSwagger
  alias EvercamMediaWeb.SnapshotExtractorView
  alias EvercamMediaWeb.ErrorView
  alias EvercamMedia.HikvisionNVR
  alias Evercam.Repo

  @root_dir Application.get_env(:evercam_media, :storage_dir)

  swagger_path :get_info do
    get "/cameras/{id}/nvr/stream/info"
    summary "Returns all information about NVR."
    parameters do
      id :path, :string, "Unique identifier for camera.", required: true
      api_id :query, :string, "The Evercam API id for the requester."
      api_key :query, :string, "The Evercam API key for the requester."
    end
    tag "Nvr"
    response 200, "Success"
    response 401, "Invalid API keys"
    response 403, "Unauthorized"
  end

  def get_info(conn, %{"id" => exid}) do
    current_user = conn.assigns[:current_user]
    camera = Camera.by_exid_with_associations(exid)

    with :ok <- ensure_camera_exists(camera, exid, conn),
         :ok <- ensure_can_edit(current_user, camera, conn)
    do
      ip = Camera.host(camera, "external")
      port = Camera.get_nvr_port(camera)
      cam_username = Camera.username(camera)
      cam_password = Camera.password(camera)
      channel = VendorModel.get_channel(camera, camera.vendor_model.channel)

      stream_info = HikvisionNVR.get_stream_info(ip, port, cam_username, cam_password, channel)
      device_info = HikvisionNVR.get_device_info(ip, port, cam_username, cam_password)
      hdd_info = HikvisionNVR.get_hdd_info(ip, port, cam_username, cam_password)
      time_info = HikvisionNVR.get_time_info(ip, port, cam_username, cam_password)
      ntp_server_info = HikvisionNVR.get_ntp_server_info(ip, port, cam_username, cam_password)
      json(conn, %{stream_info: stream_info, device_info: device_info, hdd_info: hdd_info, time_info: time_info, ntp_server_info: ntp_server_info})
    end
  end

  swagger_path :get_vh_info do
    get "/cameras/{id}/nvr/stream/vhinfo"
    summary "Returns all VH information of NVR."
    parameters do
      id :path, :string, "Unique identifier for camera.", required: true
      api_id :query, :string, "The Evercam API id for the requester."
      api_key :query, :string, "The Evercam API key for the requester."
    end
    tag "Nvr"
    response 200, "Success"
    response 401, "Invalid API keys"
    response 403, "Unauthorized"
  end

  def get_vh_info(conn, %{"id" => exid}) do
    current_user = conn.assigns[:current_user]
    camera = Camera.by_exid_with_associations(exid)

    with :ok <- ensure_camera_exists(camera, exid, conn),
         :ok <- ensure_can_edit(current_user, camera, conn)
    do
      ip = Camera.host(camera, "external")
      port = Camera.get_nvr_port(camera)
      cam_username = Camera.username(camera)
      cam_password = Camera.password(camera)
      channel = VendorModel.get_channel(camera, camera.vendor_model.channel)

      vh_info = HikvisionNVR.get_vh_info(ip, port, cam_username, cam_password, channel)

      response =
        case Map.get(vh_info, :vh_port) do
          nil -> %{vh_info: vh_info, vh_stream_info: %{}, vh_device_info: %{}}
          "" -> %{vh_info: vh_info, vh_stream_info: %{}, vh_device_info: %{}}
          vh_port ->
            vh_stream_info = HikvisionNVR.get_stream_info(ip, vh_port, cam_username, cam_password, channel)
            vh_device_info = HikvisionNVR.get_device_info(ip, vh_port, cam_username, cam_password)
            vh_time_info = HikvisionNVR.get_time_info(ip, vh_port, cam_username, cam_password)
            vh_ntp_server_info = HikvisionNVR.get_ntp_server_info(ip, vh_port, cam_username, cam_password)
            %{vh_info: vh_info, vh_stream_info: vh_stream_info, vh_device_info: vh_device_info, vh_time_info: vh_time_info, vh_ntp_server_info: vh_ntp_server_info}
        end

      json(conn, response)
    end
  end

  def extract_snapshots(conn, %{"id" => exid, "start_date" => start_date, "end_date" => end_date, "interval" => interval} = params) do
    %{assigns: %{version: version}} = conn
    current_user = conn.assigns[:current_user]
    camera = Camera.by_exid_with_associations(exid)

    with :ok <- ensure_camera_exists(camera, exid, conn),
         :ok <- ensure_can_edit(current_user, camera, conn),
         :ok <- ensure_process_exists(camera, conn)
    do
      host = Camera.host(camera, "external")
      port = Camera.port(camera, "external", "rtsp")
      cam_username = Camera.username(camera)
      cam_password = Camera.password(camera)
      timezone = Camera.get_timezone(camera)
      channel = VendorModel.get_channel(camera, camera.vendor_model.channel)
      config =
        %{
          exid: camera.exid,
          timezone: timezone,
          host: host,
          port: port,
          username: cam_username,
          password: cam_password,
          channel: channel,
          start_date: convert_timestamp(version, start_date),
          end_date: convert_timestamp(version, end_date),
          interval: String.to_integer(interval),
          schedule: get_schedule(params["schedule"]),
          requester: params["requester"],
          create_mp4: params["create_mp4"],
          jpegs_to_dropbox: params["jpegs_to_dropbox"],
          inject_to_cr: params["inject_to_cr"]
        }

      config
      |> snapshot_extractor_changeset(camera.id, params["requester"], current_user)
      |> Repo.insert
      |> case do
        {:ok, snapshot_extractor} ->
          full_snapshot_extractor = Repo.preload(snapshot_extractor, :camera, force: true)
          spawn(fn ->
            EvercamMedia.UserMailer.snapshot_extraction_started(full_snapshot_extractor, "Local")
            start_snapshot_extractor(config, full_snapshot_extractor.id)
          end)
          conn
          |> put_status(:created)
          |> put_view(SnapshotExtractorView)
          |> render("show.json", %{snapshot_extractor: full_snapshot_extractor})
        {:error, changeset} ->
          render_error(conn, 400, Util.parse_changeset(changeset))
      end
    end
  end

  defp snapshot_extractor_changeset(config, id, requester, user) do
    params =
      %{
        camera_id: id,
        from_date: config.start_date,
        to_date: config.end_date,
        interval: config.interval,
        schedule: config.schedule,
        status: 11,
        create_mp4: config.create_mp4,
        jpegs_to_dropbox: config.jpegs_to_dropbox,
        inject_to_cr: config.inject_to_cr,
        requestor: get_requester(requester, user)
      }
    SnapshotExtractor.changeset(%SnapshotExtractor{}, params)
  end

  defp start_snapshot_extractor(config, id) do
    config = Map.put(config, :id, id)
    name = :"snapshot_extractor_#{id}"
    case Process.whereis(name) do
      nil ->
        {:ok, pid} = GenStage.start_link(EvercamMedia.SnapshotExtractor.Extractor, {}, name: name)
        pid
      pid -> pid
    end
    |> GenStage.cast({:snapshot_extractor, config})
  end

  defp get_requester(value, user) when value in [nil, ""], do: user.email
  defp get_requester(value, _user), do: value

  defp ensure_camera_exists(nil, exid, conn) do
    conn
    |> put_status(404)
    |> render(ErrorView, "error.json", %{message: "Camera '#{exid}' not found!"})
  end
  defp ensure_camera_exists(_camera, _id, _conn), do: :ok

  defp ensure_can_edit(current_user, camera, conn) do
    case Permission.Camera.can_edit?(current_user, camera) do
      true -> :ok
      _ ->
        conn
        |> put_status(403)
        |> render(ErrorView, "error.json", %{message: "You don't have sufficient rights for this."})
    end
  end

  defp convert_timestamp(:v1, timestamp) do
    timestamp
    |> String.to_integer
    |> Calendar.DateTime.Parse.unix!
  end
  defp convert_timestamp(:v2, timestamp) do
    {:ok, datetime} = Calendar.DateTime.Parse.rfc3339_utc(timestamp)
    datetime
  end

  defp ensure_process_exists(camera, conn) do
    case Porcelain.shell("ps -ef | grep ffmpeg | grep '#{@root_dir}/#{camera.exid}/extract/' | grep -v grep | awk '{print $2}'").out do
      "" -> :ok
      _ ->
        conn
        |> put_status(400)
        |> render(ErrorView, "error.json", %{message: "Snapshot extractor already processing for this camera '#{camera.name}'."})
    end
  end

  defp get_schedule(schedule) when schedule in [nil, ""] do
    Jason.decode!("{\"Wednesday\":[\"08:00-18:00\"],\"Tuesday\":[\"00:00-18:00\"],\"Thursday\":[\"00:00-18:00\"],\"Sunday\":[\"00:00-18:00\"],\"Saturday\":[\"00:00-18:00\"],\"Monday\":[\"00:00-18:00\"],\"Friday\":[\"00:00-08:00\"]}")
  end
  defp get_schedule(schedule), do: Jason.decode!(schedule)
end
