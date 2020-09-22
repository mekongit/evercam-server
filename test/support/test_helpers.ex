defmodule EvercamMedia.TestHelpers do
  def invalidate_caches do
    Supervisor.terminate_child(EvercamMedia.Supervisor, :camera)
    Supervisor.terminate_child(EvercamMedia.Supervisor, :cameras)
    Supervisor.terminate_child(EvercamMedia.Supervisor, :camera_full)
    Supervisor.terminate_child(EvercamMedia.Supervisor, :users)
    Supervisor.restart_child(EvercamMedia.Supervisor, :camera)
    Supervisor.restart_child(EvercamMedia.Supervisor, :cameras)
    Supervisor.restart_child(EvercamMedia.Supervisor, :camera_full)
    Supervisor.restart_child(EvercamMedia.Supervisor, :users)
  end
end
