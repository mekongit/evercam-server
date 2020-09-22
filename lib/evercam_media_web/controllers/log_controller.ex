defmodule EvercamMediaWeb.LogController do
  use EvercamMediaWeb, :controller
  use PhoenixSwagger
  import EvercamMedia.Validation.Log
  import Ecto.Query
  import String, only: [to_integer: 1]
  alias EvercamMedia.Util

  @default_limit 50

  swagger_path :show do
    get "/cameras/{id}/logs"
    summary "Returns the logs."
    parameters do
      id :path, :string, "The ID of the camera being requested.", required: true
      api_id :query, :string, "The Evercam API id for the requester."
      api_key :query, :string, "The Evercam API key for the requester."
    end
    tag "Cameras"
    response 200, "Success"
    response 401, "Invalid API keys"
    response 403, "Forbidden camera access"
    response 404, "Camera didn't found"
  end

  def show(conn, %{"id" => exid} = params) do
    current_user = conn.assigns[:current_user]
    camera = Camera.by_exid_with_associations(exid)

    with :ok <- ensure_camera_exists(camera, exid, conn),
         :ok <- ensure_can_edit(current_user, camera, conn),
         :ok <- validate_params(params) |> ensure_params(conn)
    do
      show_logs(params, camera, conn)
    end
  end

  def create(conn,  params) do
    current_user = conn.assigns[:current_user]

    with :ok <- authorized(conn, current_user),
         {:ok, camera} <- camera_exists(params["camera_exid"])
    do
      extra = %{
        agent: params["agent"],
        custom_message: params["custom_message"]
      }
      |> Map.merge(get_requester_Country(user_request_ip(conn, params["requester_ip"]), params["u_country"], params["u_country_code"]))
      Util.log_activity(current_user, camera, params["action"], extra)
      conn |> json(%{})
    end
  end

  def response_time(conn, %{"id" => exid}) do
    current_user = conn.assigns[:current_user]
    camera = Camera.get_full(exid)

    with :ok <- ensure_camera_exists(camera, exid, conn),
         :ok <- ensure_can_edit(current_user, camera, conn)
    do
      camera_response = ConCache.get(:camera_response_times, camera.exid)
      conn |> json(camera_response)
    end
  end

  defp ensure_camera_exists(nil, exid, conn) do
    render_error(conn, 404, "Camera '#{exid}' not found!")
  end
  defp ensure_camera_exists(_camera, _id, _conn), do: :ok

  defp ensure_can_edit(current_user, camera, conn) do
    case Permission.Camera.can_edit?(current_user, camera) do
      true -> :ok
      _ -> render_error(conn, 401, "Unauthorized.")
    end
  end

  defp show_logs(params, camera, conn) do
    %{assigns: %{version: version}} = conn
    from = parse_from(version, params["from"])
    to = parse_to(version, params["to"])
    limit = parse_limit(params["limit"])
    page = parse_page(params["page"])
    types = parse_types(params["types"])

    all_logs =
      CameraActivity
      |> where(camera_id: ^camera.id)
      |> where([c], c.done_at >= ^from and c.done_at <= ^to)
      |> CameraActivity.with_types_if_specified(types)
      |> CameraActivity.get_all

    logs_count = Enum.count(all_logs)
    total_pages = Float.floor(logs_count / limit)
    logs = Enum.slice(all_logs, page * limit, limit)

    render(conn, "show.#{version}.json", %{total_pages: total_pages, camera: camera, logs: logs})
  end

  defp camera_exists(camera_exid) when camera_exid in [nil, ""] do
    {:ok, %{ id: 0, exid: "" }}
  end
  defp camera_exists(camera_exid) do
    case Camera.by_exid_with_associations(camera_exid) do
      nil -> {:ok, %{ id: 0, exid: "" }}
      %Camera{} = camera -> {:ok, camera}
    end
  end

  defp parse_to(_, to) when to in [nil, ""], do: Calendar.DateTime.now_utc
  defp parse_to(:v1, to), do: to |> Calendar.DateTime.Parse.unix!
  defp parse_to(:v2, to), do: to |> Util.datetime_from_iso

  defp parse_from(_, from) when from in [nil, ""], do: Util.datetime_from_iso("2014-01-01T14:00:00Z")
  defp parse_from(:v1, from), do: from |> Calendar.DateTime.Parse.unix!
  defp parse_from(:v2, from), do: from |> Util.datetime_from_iso

  defp parse_limit(limit) when limit in [nil, ""], do: @default_limit
  defp parse_limit(limit) do
    case to_integer(limit) do
      num when num < 1 -> @default_limit
      num -> num
    end
  end

  defp parse_page(page) when page in [nil, ""], do: 0
  defp parse_page(page) do
    case to_integer(page) do
      num when num < 0 -> 0
      num -> num
    end
  end

  defp parse_types(types) when types in [nil, ""], do: nil
  defp parse_types(types), do: types |> String.split(",", trim: true) |> Enum.map(&String.trim/1)

  defp ensure_params(:ok, _conn), do: :ok
  defp ensure_params({:invalid, message}, conn), do: render_error(conn, 400, message)
end
