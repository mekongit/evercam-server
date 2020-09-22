defmodule EvercamMediaWeb.ControllerHelpers do
  import Plug.Conn
  import Phoenix.Controller
  require Logger
  alias EvercamMediaWeb.ErrorView

  def render_error(conn, status, message) do
    user = conn.assigns[:current_user]
    Logger.error "[Handled Errors] [#{conn.method} #{conn.request_path}] [#{conn.query_string}] [#{get_user_email(user)}] [#{user_request_ip(conn)}] [#{status}] [#{inspect message}]"

    conn
    |> put_status(status)
    |> put_view(ErrorView)
    |> render("error.json", %{message: message})
  end

  def has_list_rights(true, _), do: :ok
  def has_list_rights(false, conn), do: render_error(conn, 403, "Unauthorized.")

  def has_edit_rights(true, _), do: :ok
  def has_edit_rights(false, conn), do: render_error(conn, 403, "Unauthorized.")

  def has_delete_rights(true, _), do: :ok
  def has_delete_rights(false, conn), do: render_error(conn, 403, "Unauthorized.")

  def authorized(conn, nil), do: render_error(conn, 401, "Unauthorized.")
  def authorized(_, _), do: :ok

  def user_request_ip(conn, requester_ip \\ "")
  def user_request_ip(conn, requester_ip) when requester_ip in [nil, ""] do
    x_real_ip = Plug.Conn.get_req_header(conn, "x-real-ip")
    x_real_ip |> List.first |> get_ip(conn)
  end
  def user_request_ip(_conn, requester_ip), do: requester_ip

  def get_requester_Country(ip, country_name, _country_code) when country_name in [nil, ""], do: get_country_from_geoip(ip)
  def get_requester_Country(ip, _country_name, country_code) when country_code in [nil, ""], do: get_country_from_geoip(ip)
  def get_requester_Country(ip, country_name, country_code), do: %{ip: ip, country: country_name, country_code: country_code}

  def get_user_agent(conn, agent \\ "")
  def get_user_agent(conn, agent) when agent in [nil, ""] do
    case get_req_header(conn, "user-agent") do
      [] -> ""
      [user_agent|_rest] -> parse_user_agent(user_agent)
    end
  end
  def get_user_agent(_conn, agent), do: agent

  defp get_country_from_geoip(ip) do
    case GeoIP.lookup(ip) do
      {:ok, info} -> %{ip: ip, country: Map.get(info, :country_name), country_code: Map.get(info, :country_code)}
      _ -> %{ip: ip, country: "", country_code: ""}
    end
  end

  defp get_ip(nil, conn), do: conn.remote_ip |> Tuple.to_list |> Enum.join(".")
  defp get_ip(user_ip, _conn), do: user_ip

  defp parse_user_agent(nil), do: ""
  defp parse_user_agent(user_agent), do: user_agent

  defp get_user_email(nil), do: "No User"
  defp get_user_email(user), do: user.email
end
