defmodule EvercamMediaWeb.ProjectView do
  use EvercamMediaWeb, :view
  alias EvercamMedia.Util

  def render("index.json", %{projects: projects, version: version}) do
    %{projects: render_many(projects, __MODULE__, "project.#{version}.json")}
  end

  def render("show.json", %{project: project, version: version}) do
    %{projects: render_many([project], __MODULE__, "project.#{version}.json")}
  end

  def render("project." <> <<version::binary-size(2)>>  <> ".json", %{project: project}) do
    %{
      id: project.exid,
      name: project.name,
      camera_ids: Enum.map(project.cameras, fn(c) -> %{id: c.exid, location: get_camera_location(c, c.location_detailed)} end),
      owner: User.get_fullname(project.user),
      owner_email: project.user.email,
      overlays: get_overlays(project.overlays),
      created_at: Util.date_wrt_version(version, project.inserted_at, project),
      updated_at: Util.date_wrt_version(version, project.updated_at, project)
    }
  end

  defp get_overlays(nil), do: nil
  defp get_overlays(overlays) do
    Enum.map(overlays, fn(overlay) ->
      %{
        id: overlay.id,
        path: overlay.path,
        sw_bounds: Overlay.get_location(overlay.sw_bounds),
        ne_bounds: Overlay.get_location(overlay.ne_bounds)
      }
    end)
  end

  defp get_camera_location(camera, nil), do: Camera.get_location(camera) |> Map.merge(%{dir: 0, fov_h: 0})
  defp get_camera_location(_, location_detail), do: location_detail
end
