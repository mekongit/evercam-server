defmodule EvercamMediaWeb.ArchiveView do
  use EvercamMediaWeb, :view
  alias EvercamMedia.Util

  def render("index." <> <<version::binary-size(2)>>  <> ".json", %{archives: archives, compares: compares, timelapses: timelapses}) do
    archives_list = render_many(archives, __MODULE__, "archive." <> version <> ".json")
    compares_list = Enum.map(compares, fn(compare) -> render_compare_archive(version, compare) end)
    timelapse_list = Enum.map(timelapses, fn(timelapses) -> render_timelapse_archive(version, timelapses) end)
    %{archives: archives_list ++ compares_list ++ timelapse_list}
  end

  def render("compare." <> <<version::binary-size(2)>>  <> ".json", %{compare: compare}) do
    %{archives: [render_compare_archive(version, compare)]}
  end

  def render("show." <> <<_version::binary-size(2)>>  <> ".json", %{archive: nil}), do: %{archives: []}
  def render("show." <> <<version::binary-size(2)>>  <> ".json", %{archive: archive}) do
    %{archives: render_many([archive], __MODULE__, "archive." <> version <> ".json")}
  end

  def render("timelapse." <> <<version::binary-size(2)>>  <> ".json", %{timelapse: timelapse}) do
    %{archives: [render_timelapse_archive(version, timelapse)]}
  end

  def render("archive." <> <<version::binary-size(2)>>  <> ".json", %{archive: archive}) do
    %{
      id: archive.exid,
      camera_id: archive.camera.exid,
      title: archive.title,
      from_date: Util.date_wrt_version(version, archive.from_date, archive.camera),
      to_date: Util.date_wrt_version(version, archive.to_date, archive.camera),
      created_at: Util.date_wrt_version(version, archive.created_at, archive.camera),
      status: status(archive.status),
      requested_by: Util.deep_get(archive, [:user, :username], ""),
      requester_name: User.get_fullname(archive.user),
      requester_email: Util.deep_get(archive, [:user, :email], ""),
      embed_time: archive.embed_time,
      frames: archive.frames,
      public: archive.public,
      embed_code: "",
      file_name: archive.file_name,
      type: get_archive_type(archive.type),
      media_url: archive.url,
      thumbnail_url: get_url_thumbnail(archive.type, archive)
    }
  end

  def render_compare_archive(version, compare) do
    %{
      id: compare.exid,
      camera_id: compare.camera.exid,
      title: compare.name,
      from_date: Util.date_wrt_version(version, compare.before_date, compare.camera),
      to_date: Util.date_wrt_version(version, compare.after_date, compare.camera),
      created_at: Util.date_wrt_version(version, compare.inserted_at, compare.camera),
      status: compare_status(compare.status),
      requested_by: Util.deep_get(compare, [:user, :username], ""),
      requester_name: User.get_fullname(compare.user),
      requester_email: Util.deep_get(compare, [:user, :email], ""),
      embed_time: false,
      frames: 2,
      public: true,
      file_name: "",
      media_url: "",
      embed_code: compare.embed_code,
      type: "compare",
      thumbnail_url: "#{EvercamMediaWeb.Endpoint.static_url}/v1/cameras/#{compare.camera.exid}/archives/#{compare.exid}/thumbnail?type=compare"
    }
  end

  def render_timelapse_archive(version, timelapse) do
    %{
      id: timelapse.exid,
      camera_id: timelapse.camera.exid,
      title: timelapse.title,
      from_date: Util.date_wrt_version(version, timelapse.from_datetime, timelapse.camera),
      to_date: Util.date_wrt_version(version, timelapse.to_datetime, timelapse.camera),
      created_at: Util.date_wrt_version(version, timelapse.inserted_at, timelapse.camera),
      status: timelapse_status(timelapse.status),
      requested_by: Util.deep_get(timelapse, [:user, :username], ""),
      requester_name: User.get_fullname(timelapse.user),
      requester_email: Util.deep_get(timelapse, [:user, :email], ""),
      embed_time: false,
      frames: 2,
      public: true,
      file_name: "",
      media_url: "",
      embed_code: timelapse.exid,
      type: "timelapse",
      thumbnail_url: "#{EvercamMediaWeb.Endpoint.static_url}/v1/cameras/#{timelapse.camera.exid}/archives/#{timelapse.exid}/thumbnail?type=timelapse"
    }
  end

  defp get_archive_type("local_clip"), do: "clip"
  defp get_archive_type(type), do: type

  defp status(0), do: "Pending"
  defp status(1), do: "Processing"
  defp status(2), do: "Completed"
  defp status(3), do: "Failed"

  defp timelapse_status(11), do: "Pending"
  defp timelapse_status(6), do: "Processing"
  defp timelapse_status(5), do: "Completed"
  defp timelapse_status(7), do: "Failed"
  defp timelapse_status(8), do: "Creating"
  defp timelapse_status(9), do: "Extracting"
  defp timelapse_status(10), do: "Uploading"
  defp timelapse_status(_), do: "No Data"

  defp compare_status(0), do: "Processing"
  defp compare_status(1), do: "Completed"
  defp compare_status(2), do: "Failed"

  defp get_url_thumbnail("url", archive) do
    default_thumbnail = "#{EvercamMediaWeb.Endpoint.static_url}/v1/cameras/#{archive.camera.exid}/archives/#{archive.exid}/thumbnail?type=clip"
    cond do
      String.match?(archive.url, ~r/youtube.com/) == true ->
        video_id = archive.url
        |> String.split("watch?v=")
        |> List.last
        "http://img.youtube.com/vi/#{video_id}/hqdefault.jpg"
      String.match?(archive.url, ~r/vimeo.com/) ->
        case EvercamMedia.HTTPClient.get("https://vimeo.com/api/oembed.json?url=#{archive.url}?width=640&height=480") do
          {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
            case convert_to_json(body) do
              nil -> default_thumbnail
              res -> Map.get(res, "thumbnail_url") |> get_default(default_thumbnail)
            end
          _ -> default_thumbnail
        end
      true ->
        default_thumbnail
    end
  end
  defp get_url_thumbnail(_, archive) do
    "#{EvercamMediaWeb.Endpoint.static_url}/v1/cameras/#{archive.camera.exid}/archives/#{archive.exid}/thumbnail?type=clip"
  end

  defp convert_to_json(body) when body in ["", nil], do: nil
  defp convert_to_json(body), do: body |> Jason.decode!

  defp get_default(nil, default_image), do: default_image
  defp get_default(vimeo_image, _), do: vimeo_image
end
