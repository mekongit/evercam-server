defmodule EvercamMedia.SnapshotExtractor.ExtractorSupervisor do

  use Supervisor
  require Logger
  import Commons

  @root_dir Application.get_env(:evercam_media, :storage_dir)

  def start_link() do
    DynamicSupervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(:ok) do
    Task.start_link(&initiate_workers/0)
    DynamicSupervisor.init(strategy: :one_for_one, max_restarts: 1_000_000)
  end

  def initiate_workers do
    Logger.info "Initiate workers for extractor."
    #..Starting Local extractions.
    SnapshotExtractor.by_status(11)
    |> Enum.each(fn(extractor) ->
      spawn(fn ->
        extractor
        |> start_extraction(:local)
      end)
    end)

    #..Starting Cloud extractions.
    SnapshotExtractor.by_status(1)
    |> Enum.each(fn(extractor) ->
      spawn(fn ->
        extractor
        |> start_extraction(:cloud)
      end)
    end)

    #..Starting Timelapse extractions.
    SnapshotExtractor.by_status(21)
    |> Enum.each(fn(extractor) ->
      spawn(fn ->
        extractor
        |> start_extraction(:timelapse)
      end)
    end)
  end

  def start_extraction(nil, :local), do: :noop
  def start_extraction(nil, :cloud), do: :noop
  def start_extraction(nil, :timelapse), do: :noop
  def start_extraction(extractor, :local) do
    Logger.debug "Ressuming extraction for #{extractor.camera.exid}"
    Process.whereis(:"snapshot_extractor_#{extractor.id}")
    |> get_process_pid(EvercamMedia.SnapshotExtractor.Extractor, extractor.id)
    |> GenStage.cast({:snapshot_extractor, get_config(extractor, :local)})
  end
  def start_extraction(extractor, :cloud) do
    Logger.debug "Ressuming extraction for #{extractor.camera.exid}"
    Process.whereis(:"snapshot_extractor_#{extractor.id}")
    |> get_process_pid(EvercamMedia.SnapshotExtractor.CloudExtractor, extractor.id)
    |> GenStage.cast({:snapshot_extractor, get_config(extractor, :cloud)})
  end
  def start_extraction(extractor, :timelapse) do
    # checkjson file
    File.exists?("#{@root_dir}/#{extractor.camera.exid}/#{extractor.id}.json")
    |> case do
      true ->
        details = File.read!("#{@root_dir}/#{extractor.camera.exid}/#{extractor.id}.json") |> Jason.decode! |> Map.new(fn {key, value} -> {String.to_atom(key), value} end)
        File.exists?("#{@root_dir}/#{details.camera_exid}/#{details.exid}/CURRENT")
        |> case do
          true ->
            unix_datetime = File.read!("#{@root_dir}/#{details.camera_exid}/#{details.exid}/CURRENT")
            config = %{
              id: details.id,
              from_datetime: Calendar.DateTime.Parse.unix!(unix_datetime),
              to_datetime: details.to_datetime |> Calendar.DateTime.Parse.rfc3339_utc() |> elem(1),
              duration: details.duration,
              schedule: details.schedule,
              camera_exid: details.camera_exid,
              timezone: details.timezone,
              camera_name: details.camera_name,
              requestor: details.requestor,
              create_mp4: details.create_mp4,
              jpegs_to_dropbox: details.jpegs_to_dropbox,
              expected_count: 0,
              watermark: details.watermark,
              watermark_logo: details.watermark_logo,
              title: details.title,
              rm_date: details.rm_date,
              format: details.format,
              headers: details.headers,
              exid: details.exid,
            }
            Logger.debug "Ressuming extraction for #{extractor.camera.exid}"
            Process.whereis(:"snapshot_extractor_#{extractor.id}")
            |> get_process_pid(EvercamMedia.SnapshotExtractor.TimelapseCreator, extractor.id)
            |> GenStage.cast({:snapshot_extractor, config})
          false -> :noop
        end
      false -> :noop
    end
  end

  defp get_process_pid(nil, module, id) do
    case GenStage.start_link(module, {}, name: :"snapshot_extractor_#{id}") do
      {:ok, pid} -> pid
      {:error, {:already_started, pid}} -> pid
    end
  end
  defp get_process_pid(pid, _module, _id), do: pid

  def get_config(extractor, :cloud) do
  %{
    id: extractor.id,
    from_date: get_starting_date(extractor),
    to_date: extractor.to_date,
    interval: extractor.interval,
    schedule: extractor.schedule,
    camera_exid: extractor.camera.exid,
    timezone: extractor.camera.timezone,
    camera_name: extractor.camera.name,
    requestor: extractor.requestor,
    create_mp4: extractor.create_mp4,
    jpegs_to_dropbox: extractor.jpegs_to_dropbox,
    expected_count: get_count("#{@root_dir}/#{extractor.camera.exid}/extract/#{extractor.id}/") - 2
  }
  end
  def get_config(extractor, :local) do
    camera = Camera.by_exid_with_associations(extractor.camera.exid)
    host = Camera.host(camera, "external")
    port = Camera.port(camera, "external", "rtsp")
    cam_username = Camera.username(camera)
    cam_password = Camera.password(camera)
    url = camera.vendor_model.h264_url
    channel = url |> String.split("/channels/") |> List.last |> String.split("/") |> List.first
    %{
      exid: camera.exid,
      id: extractor.id,
      timezone: Camera.get_timezone(camera),
      host: host,
      port: port,
      username: cam_username,
      password: cam_password,
      channel: channel,
      start_date: get_starting_date(extractor),
      end_date: extractor.to_date,
      interval: extractor.interval,
      schedule: extractor.schedule,
      requester: extractor.requestor,
      create_mp4: serve_nil_value(extractor.create_mp4),
      jpegs_to_dropbox: serve_nil_value(extractor.jpegs_to_dropbox),
      inject_to_cr: serve_nil_value(extractor.inject_to_cr)
    }
  end
  def get_config(extractor, :timelapse) do
  %{
    id: extractor.id,
    from_date: get_starting_date(extractor),
    to_date: extractor.to_date,
    interval: extractor.interval,
    schedule: extractor.schedule,
    camera_exid: extractor.camera.exid,
    timezone: extractor.camera.timezone,
    camera_name: extractor.camera.name,
    requestor: extractor.requestor,
    create_mp4: extractor.create_mp4,
    jpegs_to_dropbox: extractor.jpegs_to_dropbox,
    expected_count: get_count("#{@root_dir}/#{extractor.camera.exid}/extract/#{extractor.id}/") - 2
  }
  end

  defp serve_nil_value(nil), do: false
  defp serve_nil_value(val), do: val

  defp get_starting_date(extractor) do
    {:ok, extraction_date} =
      File.read!("#{@root_dir}/#{extractor.camera.exid}/extract/#{extractor.id}/CURRENT")
      |> Calendar.DateTime.Parse.rfc3339_utc
    extraction_date
  end
end
