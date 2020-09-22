defmodule EvercamMediaWeb.LogView do
  use EvercamMediaWeb, :view
  alias EvercamMedia.Util

  def render("show." <> <<version::binary-size(2)>>  <> ".json", %{total_pages: total_pages, camera: camera, logs: logs}) do
    %{
      logs: Enum.map(logs, fn(log) ->
        %{
          who: name(log.name),
          action: log.action,
          done_at: Util.date_wrt_version(version, log.done_at, camera),
          extra: log.extra
        }
      end),
      pages: total_pages,
      camera_name: camera.name,
      camera_exid: camera.exid
    }
  end

  def render("user_logs." <> <<version::binary-size(2)>>  <> ".json", %{user_logs: user_logs}) do
    %{
      user_logs: Enum.map(user_logs, fn(log) ->
        %{
          who: name(log.name),
          action: log.action,
          camera_exid: log.camera_exid,
          done_at: Util.date_wrt_version(version, log.done_at, log),
          extra: log.extra
        }
      end)
    }
  end

  defp name(name) when name in [nil, ""], do: "Anonymous"
  defp name(name), do: name
end
