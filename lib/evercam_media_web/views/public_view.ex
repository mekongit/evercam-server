defmodule EvercamMediaWeb.PublicView do
  use EvercamMediaWeb, :view
  alias EvercamMedia.Util

  def render("index." <> <<version::binary-size(2)>>  <> ".json", %{cameras: cameras, total_pages: total_pages, count: count}) do
    %{
      cameras: Enum.map(cameras, fn(camera) ->
        %{
          id: camera.exid,
          name: camera.name,
          owner: Util.deep_get(camera, [:owner, :username], ""),
          vendor_id: Camera.get_vendor_attr(camera, :exid),
          vendor_name: Camera.get_vendor_attr(camera, :name),
          model_id: Camera.get_model_attr(camera, :exid),
          model_name: Camera.get_model_attr(camera, :name),
          created_at: Util.date_wrt_version(version, camera.created_at, camera),
          updated_at: Util.date_wrt_version(version, camera.updated_at, camera),
          last_polled_at: Util.date_wrt_version(version, camera.last_polled_at, camera),
          last_online_at: Util.date_wrt_version(version, camera.last_online_at, camera),
          is_online_email_owner_notification: camera.is_online_email_owner_notification,
          status: camera.status,
          is_public: camera.is_public,
          discoverable: camera.discoverable,
          timezone: Camera.get_timezone(camera),
          location: Camera.get_location(camera),
          proxy_url: %{
            hls: Util.get_hls_url(camera),
            rtmp: Util.get_rtmp_url(camera),
          },
          thumbnail_url: thumbnail_url(camera)
        }
      end),
      pages: total_pages,
      records: count
    }
  end

  def render("geojson.json", %{cameras: cameras}) do
    %{
      type: "FeatureCollection",
      features: [
        Enum.map(cameras, fn(camera) ->
          %{
            type: "Feature",
            properties: %{
              "marker-color": "#DC4C3F",
              "Current Thumbnail Tag": "<img width='140' src='#{thumbnail_url(camera)}' />",
              "Current Thumbnail URL": thumbnail_url(camera),
              "Camera Tag": "<a href='http://dash.evercam.io/v1/cameras/#{camera.exid}/live'>#{camera.name}</a>",
              "Camera Name": camera.name,
              "Camera ID": camera.exid,
              "Data Processor": "Camba.tv Ltd\n\n01-5383333",
              "Data Controller ID": Util.deep_get(camera, [:owner, :username], ""),
              "Status ?": camera.status,
              "Public ?": camera.is_public,
              "Vendor/Model": "#{Camera.get_vendor_attr(camera, :name)} / #{Camera.get_model_attr(camera, :name)}",
              "marker-symbol": "circle"
            },
            geometry: %{
              type: "Point",
              coordinates: Tuple.to_list(camera.location.coordinates)
            }
          }
        end)
      ]
    }
  end

  defp thumbnail_url(camera) do
    EvercamMediaWeb.Endpoint.static_url <> "/v1/cameras/" <> camera.exid <> "/thumbnail"
  end
end
