defmodule EvercamMediaWeb.SnapshotExtractorView do
  use EvercamMediaWeb, :view
  alias EvercamMedia.Util

  def render("index.json", %{snapshot_extractor: snapshot_extractors, version: version}) do
    %{SnapshotExtractor: render_many(snapshot_extractors, __MODULE__, "snapshot_extractor.#{version}.json")}
  end

  def render("show.json", %{snapshot_extractor: snapshot_extractor, version: version}) do
    %{SnapshotExtractor: render_many([snapshot_extractor], __MODULE__, "snapshot_extractor.#{version}.json")}
  end

  def render("snapshot_extractor." <> <<version::binary-size(2)>>  <> ".json", %{snapshot_extractor: snapshot_extractor}) do
    %{
      id: snapshot_extractor.id,
      camera: snapshot_extractor.camera.name,
      from_date: Util.date_wrt_version(version, snapshot_extractor.from_date, snapshot_extractor.camera),
      to_date: Util.date_wrt_version(version, snapshot_extractor.to_date, snapshot_extractor.camera),
      interval: snapshot_extractor.interval,
      schedule: snapshot_extractor.schedule,
      status: snapshot_extractor.status,
      requestor: snapshot_extractor.requestor,
      created_at: Util.date_wrt_version(version, snapshot_extractor.created_at, snapshot_extractor.camera),
      updated_at: Util.date_wrt_version(version, snapshot_extractor.updated_at, snapshot_extractor.camera)
    }
  end
end
