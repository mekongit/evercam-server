defmodule EvercamMedia.Snapshot.CamClient do
  @moduledoc """
  Client to talk with the camera for various data. Currently this only fetches snapshots.
  In future, we could expand this module to check camera status, video stream etc.
  """

  alias EvercamMedia.HTTPClient
  alias EvercamMedia.Util
  alias EvercamMedia.Snapshot.Error
  require Logger

  @doc """
  Connect to the camera and get the snapshot
  """
  def fetch_snapshot(args) do
    [username, password] = extract_auth_credentials(args)
    try do
      {time, response} =
        :timer.tc(fn ->
          "#{args[:auth]}_auth"
          |> String.to_atom
          |> HTTPClient.get(args[:url], username, password)
        end)
      spawn(fn -> save_response_time(args[:camera_exid], args[:timestamp], args[:description], response, time/1_000_000) end)
      parse_snapshot_response(response)
    catch _type, error ->
      {:error, error}
    end
  end

  ## Private functions

  defp parse_snapshot_response({:ok, response}) do
    case Util.jpeg?(response.body) do
      true -> {:ok, response.body}
      _ -> {:error, %{reason: parse_reason(response.body), response: parse_response(response.body)}}
    end
  end

  defp parse_snapshot_response(response) do
    response
  end

  defp parse_reason(response_text) do
    cond do
      String.contains?(response_text, "Not Found") ->
        :not_found
      String.contains?(response_text, "Forbidden") ->
        :forbidden
      String.contains?(response_text, "Unauthorized") ->
        :unauthorized
      String.contains?(response_text, "Unsupported Authorization Type") ->
        :unauthorized
      String.contains?(response_text, "Device Busy") ->
        :device_busy
      String.contains?(response_text, "Device Error") ->
        :device_error
      String.contains?(response_text, "Invalid Operation") ->
        :invalid_operation
      String.contains?(response_text, "Moved Permanently") ->
        :moved
      String.contains?(response_text, "The document has moved") ->
        :moved
      true ->
        :not_a_jpeg
    end
  end

  defp parse_response(response_text) do
    case String.valid?(response_text) do
      true -> response_text
      false -> Base.encode64(response_text)
    end
  end

  defp extract_auth_credentials(%{vendor_exid: _vendor_exid, url: _url, username: username, password: password}) do
    [username, password]
  end

  defp extract_auth_credentials(%{vendor_exid: _vendor_exid, url: _url, auth: auth}) do
    String.split(auth, ":")
  end

  defp extract_auth_credentials(args) do
    String.split(args[:auth], ":")
  end

  defp save_response_time(nil, _timestamp, _description, _response, _time), do: :noop
  defp save_response_time(_camera_exid, nil, _description, _response, _time), do: :noop
  defp save_response_time(camera_exid, timestamp, description, response, time) do
    date_time = Calendar.DateTime.Parse.unix!(timestamp)
    snapshot_response_time = Float.round(time, 3)

    response_times =
      ConCache.dirty_get_or_store(:camera_response_times, camera_exid, fn() -> [date_time] end)
      |> reset_response_time_list(date_time)
      |> List.insert_at(-1, timestamp)

    response_times =
      case parse_snapshot_response(response) do
        {:ok, _} ->
          Util.broadcast_camera_response(camera_exid, timestamp, snapshot_response_time, description, :ok)
          List.insert_at(response_times, -1, "[Snapshot] [#{snapshot_response_time}] [#{description}]")
        {:error, error} ->
          error_reason = error |> Error.parse
          Util.broadcast_camera_response(camera_exid, timestamp, snapshot_response_time, description, error_reason)
          List.insert_at(response_times, -1, "[Error] [#{snapshot_response_time}] [#{error_reason}]")
      end
    ConCache.dirty_put(:camera_response_times, camera_exid, response_times)
  end

  defp reset_response_time_list(response_times, curr_date_time) do
    last_date_time = List.first(response_times)

    case Calendar.DateTime.diff(curr_date_time, last_date_time) do
      {:ok, seconds, _, :after} when seconds > 1800 ->
        response_times
        |> List.replace_at(0, Calendar.DateTime.advance!(last_date_time, 1))
        |> List.delete_at(1)
        |> List.delete_at(1)
      _ -> response_times
    end
  end
end
