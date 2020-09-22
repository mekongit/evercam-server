defmodule EvercamMediaWeb.SnapmailView do
  use EvercamMediaWeb, :view
  alias EvercamMedia.Util

  def render("index.json", %{snapmails: snapmails, version: version}) do
    %{snapmails: render_many(snapmails, __MODULE__, "snapmail.#{version}.json")}
  end

  def render("show.json", %{snapmail: nil, version: _}), do: %{snapmails: []}
  def render("show.json", %{snapmail: snapmail, version: version}) do
    %{snapmails: render_many([snapmail], __MODULE__, "snapmail.#{version}.json")}
  end

  def render("snapmail." <> <<version::binary-size(2)>>  <> ".json", %{snapmail: snapmail}) do
    %{
      id: snapmail.exid,
      camera_ids: Snapmail.get_camera_ids(snapmail.snapmail_cameras),
      camera_names: Snapmail.get_camera_names(snapmail.snapmail_cameras),
      title: snapmail.subject,
      recipients: snapmail.recipients,
      message: snapmail.message,
      notify_days: snapmail.notify_days,
      notify_time: snapmail.notify_time,
      requested_by: Util.deep_get(snapmail, [:user, :username], ""),
      requester_name: User.get_fullname(snapmail.user),
      requester_email: Util.deep_get(snapmail, [:user, :email], ""),
      is_public: snapmail.is_public,
      is_paused: snapmail.is_paused,
      timezone: Snapmail.get_timezone(snapmail),
      created_at: Util.date_wrt_version(version, snapmail.inserted_at, snapmail)
    }
  end
end
