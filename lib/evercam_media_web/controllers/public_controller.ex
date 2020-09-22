defmodule EvercamMediaWeb.PublicController do
  use EvercamMediaWeb, :controller
  use PhoenixSwagger

  @default_distance 1000
  @default_offset 0
  @default_limit 100
  @maximum_limit 1000

  def storage_stats(conn, _params) do
    spawn(fn ->
      EvercamMedia.StorageJson.start_link("refresh")
    end)
    json(conn, %{success: true})
  end

  swagger_path :index do
    get "/public/cameras"
    summary "Returns all public cameras list."
    parameters do
      is_near_to :query, :string, "Longitude,Latitude for example 31.4208475,73.0895894"
      within_distance :query, :string, "Within distance, for example 9.5"
      limit :query, :string, "Limit of records, for example 10"
      offset :query, :string, "Offset, for example 15"
    end
    tag "Cameras"
    response 200, "Success"
  end

  def index(conn, %{"geojson" => "true"} = params) do
    coordinates = parse_near_to(params["is_near_to"])
    within_distance = parse_distance(params["within_distance"])

    cameras =
      Camera.public_cameras_query(coordinates, within_distance)
      |> Camera.where_location_is_not_nil
      |> Camera.get_query_with_associations

    conn
    |> render("geojson.json", %{cameras: cameras})
  end
  def index(conn, params) do
    %{assigns: %{version: version}} = conn
    coordinates = parse_near_to(params["is_near_to"])
    within_distance = parse_distance(params["within_distance"])
    limit = parse_limit(params["limit"])
    offset = parse_offset(params["offset"])

    public_cameras_query = Camera.public_cameras_query(coordinates, within_distance)

    count = Camera.count(public_cameras_query)

    total_pages =
      count
      |> Kernel./(limit)
      |> Float.floor
      |> round
      |> if_zero

    cameras = Camera.get_query_with_associations(public_cameras_query, limit, offset)

    conn
    |> render("index.#{version}.json", %{cameras: cameras, total_pages: total_pages, count: count})
  end

  defp parse_near_to(nil), do: {0, 0}
  defp parse_near_to(near_to) do
    case String.contains?(near_to, ",") do
      true ->
        near_to
        |> String.trim
        |> String.split(",")
        |> Enum.map(fn(x) -> string_to_float(x) end)
        |> Enum.reverse
        |> List.to_tuple
      _ ->
        near_to
        |> fetch
    end
  end

  defp parse_distance(nil), do: @default_distance
  defp parse_distance(distance) do
    Float.parse(distance) |> elem(0)
  end

  defp parse_offset(nil), do: @default_offset
  defp parse_offset(offset) do
    case String.to_integer(offset) do
      offset when offset >= 0 -> offset
      _ -> @default_offset
    end
  end

  defp parse_limit(nil), do: @default_limit
  defp parse_limit(limit) do
    case String.to_integer(limit) do
      limit when limit > @maximum_limit -> @maximum_limit
      _ -> limit
    end
  end

  defp if_zero(total_pages) when total_pages <= 0, do: 1
  defp if_zero(total_pages), do: total_pages

  defp string_to_float(string), do: string |> Float.parse |> elem(0)

  defp fetch(address) do
    "http://maps.googleapis.com/maps/api/geocode/json?address=" <> URI.encode(address)
    |> HTTPoison.get
    |> elem(1)
    |> Map.get(:body)
    |> Jason.decode!
    |> get_in(["results", Access.at(0), "geometry", "location"])
    |> Enum.map(fn({_coordinate, value}) -> value end)
    |> List.to_tuple
  end


end
