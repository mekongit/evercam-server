defmodule EvercamMedia.Snapshot.StreamerSupervisor do
  @moduledoc """
  TODO
  """

  use DynamicSupervisor
  require Logger

  def start_link() do
    DynamicSupervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(:ok) do
    DynamicSupervisor.init(strategy: :one_for_one, max_restarts: 1_000_000)
  end

  @doc """
  Start streamer process
  """
  def start_streamer(camera_exid) do
    case find_streamer(camera_exid) do
      nil ->
        Logger.debug "[#{camera_exid}] Starting streamer"
        spec = %{id: EvercamMedia.Snapshot.Streamer, start: {EvercamMedia.Snapshot.Streamer, :start_link, [camera_exid]}}
        DynamicSupervisor.start_child(__MODULE__, spec)
      _is_pid ->
        Logger.debug "[#{camera_exid}] Skipping streamer ..."
    end
  end

  @doc """
  Stop streamer process
  """
  def stop_streamer(camera_exid) do
    String.to_atom("#{camera_exid}_streamer")
    |> Process.whereis()
    |> case do
      nil -> Logger.debug "[#{camera_exid}] Skipping streamer ..."
      pid -> DynamicSupervisor.terminate_child(__MODULE__, pid)
    end
  end

  @doc """
  Restart streamer process
  """
  def restart_streamer(camera_exid) do
    stop_streamer(camera_exid)
    start_streamer(camera_exid)
  end

  @doc """
  Find streamer process
  """
  def find_streamer(camera_exid) do
    "#{camera_exid}_streamer"
    |> String.to_atom
    |> Process.whereis
  end
end
