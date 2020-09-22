defmodule EvercamMedia.Zoho do
  require Logger

  @zoho_url System.get_env["ZOHO_URL"]
  @zoho_refresh_token System.get_env["ZOHO_REFRESH_TOKEN"]
  @zoho_client_id System.get_env["ZOHO_CLIENT_ID"]
  @zoho_client_secret System.get_env["ZOHO_CLIENT_SECRET"]

  def refresh_token(recall_fn) do
    headers = []
    qs = "refresh_token=#{@zoho_refresh_token}&client_id=#{@zoho_client_id}&client_secret=#{@zoho_client_secret}&grant_type=refresh_token"
    case HTTPoison.post("https://accounts.zoho.com/oauth/v2/token?#{qs}", headers) do
      {:ok, %HTTPoison.Response{body: body, status_code: 200}} ->
        case Jason.decode!(body) do
          %{"access_token" => access_token} ->
            ConCache.put(:zoho_auth_token, :oauth_token, access_token)
            recall_fn.()
          %{"error" => error} ->
            Logger.info "[Refresh zoho token] [#{inspect error}]"
            :noop
        end
      error ->
        Logger.info "[Refresh zoho token] [#{inspect error}]"
        :noop
    end
  end

  def get_camera(camera_exid) do
    url = "#{@zoho_url}Cameras/search?criteria=(Evercam_ID:equals:#{camera_exid})"
    headers = ["Authorization": "Bearer #{ConCache.get(:zoho_auth_token, :oauth_token)}"]

    case HTTPoison.get(url, headers) do
      {:ok, %HTTPoison.Response{body: body, status_code: 200}} ->
        json_response = Jason.decode!(body)
        camera = Map.get(json_response, "data") |> List.first
        {:ok, camera}
      {:ok, %HTTPoison.Response{status_code: 204}} -> {:nodata, "Camera does't exits."}
      {:ok, %HTTPoison.Response{status_code: 401}} ->
        recall_function = fn -> get_camera(camera_exid) end
        Logger.debug "Invalid Token"
        refresh_token(recall_function)
      error -> {:error, error}
    end
  end

  def insert_camera([]), do: :noop
  def insert_camera(cameras) do
    url = "#{@zoho_url}Cameras"
    headers = ["Authorization": "Bearer #{ConCache.get(:zoho_auth_token, :oauth_token)}", "Content-Type": "application/x-www-form-urlencoded"]


    camera_object = create_camera_request(cameras, [])
    request = %{"data" => camera_object}

    case HTTPoison.post(url, Jason.encode!(request), headers) do
      {:ok, %HTTPoison.Response{body: body, status_code: 201}} -> {:ok, body}
      {:ok, %HTTPoison.Response{status_code: 401}} ->
        recall_function = fn -> insert_camera(cameras) end
        Logger.debug "Invalid Token"
        refresh_token(recall_function)
      response -> {:error, response}
    end
  end

  def update_camera(cameras, id) do
    url = "#{@zoho_url}Cameras/#{id}"
    headers = ["Authorization": "Bearer #{ConCache.get(:zoho_auth_token, :oauth_token)}", "Content-Type": "application/x-www-form-urlencoded"]

    camera_object = create_camera_request(cameras, [])
    request = %{"data" => camera_object}

    case HTTPoison.put(url, Jason.encode!(request), headers) do
      {:ok, %HTTPoison.Response{body: body, status_code: 200}} ->
        json_response = Jason.decode!(body)
        response = Map.get(json_response, "data") |> List.first
        {:ok, response}
      {:ok, %HTTPoison.Response{status_code: 401}} ->
        recall_function = fn -> update_camera(cameras, id) end
        Logger.debug "Invalid Token"
        refresh_token(recall_function)
      error -> {:error, error}
    end
  end

  def get_account(domain) do
    search_criteria = "(Email_Domain:starts_with:#{domain})or(Website:starts_with:http://#{domain})or(Website:starts_with:http://www.#{domain})or(Website:starts_with:https://#{domain})or(Website:starts_with:https://www.#{domain})or(Website:starts_with:www.#{domain})or(Website:starts_with:#{domain})"
    url = "#{@zoho_url}Accounts/search?criteria=(#{search_criteria})"
    headers = ["Authorization": "Bearer #{ConCache.get(:zoho_auth_token, :oauth_token)}"]

    case HTTPoison.get(url, headers) do
      {:ok, %HTTPoison.Response{body: body, status_code: 200}} ->
        json_response = Jason.decode!(body)
        account = Map.get(json_response, "data") |> List.first
        {:ok, account}
      {:ok, %HTTPoison.Response{status_code: 204}} -> {:nodata, "Account does't exits."}
      {:ok, %HTTPoison.Response{status_code: 401}} ->
        recall_function = fn -> get_account(domain) end
        Logger.debug "Invalid Token"
        refresh_token(recall_function)
      error -> {:error, error}
    end
  end

  def search_account(domain) do
    url = "https://www.zohoapis.com/crm/v2/coql"
    headers = ["Authorization": "Bearer #{ConCache.get(:zoho_auth_token, :oauth_token)}", "Content-Type": "application/x-www-form-urlencoded"]
    query = "select Account_Name from Accounts where Email_Domain like '%#{domain}%'"

    case HTTPoison.post(url, Jason.encode!(%{select_query: query}), headers) do
      {:ok, %HTTPoison.Response{body: body, status_code: 200}} ->
        json_response = Jason.decode!(body)
        account = Map.get(json_response, "data") |> List.first
        {:ok, account}
      {:ok, %HTTPoison.Response{status_code: 401}} ->
        recall_function = fn -> search_account(domain) end
        Logger.debug "Invalid Token"
        refresh_token(recall_function)
      {:ok, %HTTPoison.Response{status_code: 204}} ->
        domain
        |> String.split(".")
        |> List.first
        |> get_account
      error -> {:error, error}
    end
  end

  def get_contact(email) do
    url = "#{@zoho_url}Contacts/search?criteria=(Email:equals:#{email})"
    headers = ["Authorization": "Bearer #{ConCache.get(:zoho_auth_token, :oauth_token)}"]

    case HTTPoison.get(url, headers) do
      {:ok, %HTTPoison.Response{body: body, status_code: 200}} ->
        json_response = Jason.decode!(body)
        contact = Map.get(json_response, "data") |> List.first
        {:ok, contact}
      {:ok, %HTTPoison.Response{status_code: 204}} -> {:nodata, "Contact does't exits."}
      {:ok, %HTTPoison.Response{status_code: 401}} ->
        recall_function = fn -> get_contact(email) end
        Logger.debug "Invalid Token"
        refresh_token(recall_function)
      error -> {:error, error}
    end
  end

  def insert_contact(user, owner_email \\ nil, retry \\ 1) do
    Logger.debug("Try #{retry} to insert zoho contact")
    url = "#{@zoho_url}Contacts"

    headers = ["Authorization": "Bearer #{ConCache.get(:zoho_auth_token, :oauth_token)}", "Content-Type": "application/x-www-form-urlencoded"]
    domain = user.email |> String.split("@") |> List.last
    account_name =
      case search_account(domain) do
        {:ok, account} -> account["Account_Name"]
        _ -> get_account_by_owner_email(owner_email)
      end

    contact_xml =
      %{"data" =>
        [%{
          "Contact_lead_source" => "Evercam User",
          "Account_Name" => account_name,
          "First_Name" => "#{user.firstname}",
          "Last_Name" => "#{user.lastname}",
          "Email" => "#{user.email}",
          "Evercam_Signup_Date" => Calendar.Strftime.strftime!(user.created_at, "%Y-%m-%dT%H:%M:%S+00:00")
        }]
      }

    case HTTPoison.post(url, Jason.encode!(contact_xml), headers) do
      {:ok, %HTTPoison.Response{body: body, status_code: 201}} ->
        json_response = Jason.decode!(body)
        contact = Map.get(json_response, "data") |> List.first
        {:ok, contact["details"]}
      {:ok, %HTTPoison.Response{status_code: 401}} ->
        recall_function = fn -> insert_contact(user, owner_email, retry) end
        Logger.debug "Invalid Token"
        refresh_token(recall_function)
      error ->
        if retry < 2 do
          insert_contact(user, owner_email, retry + 1)
        else
          {:error, error}
        end
    end
  end

  def update_contact(id, request_params) do
    url = "#{@zoho_url}Contacts/#{id}"
    headers = ["Authorization": "Bearer #{ConCache.get(:zoho_auth_token, :oauth_token)}", "Content-Type": "application/x-www-form-urlencoded"]

    contact_xml = %{ "data" => request_params }
    case HTTPoison.put(url, Jason.encode!(contact_xml), headers) do
      {:ok, %HTTPoison.Response{body: body, status_code: 200}} -> {:ok, body}
      {:ok, %HTTPoison.Response{status_code: 401}} ->
        recall_function = fn -> update_contact(id, request_params) end
        Logger.debug "Invalid Token"
        refresh_token(recall_function)
      error -> {:error, error}
    end
  end

  def delete_contact(id) do
    url = "#{@zoho_url}Contacts/#{id}"
    headers = ["Authorization": "Bearer #{ConCache.get(:zoho_auth_token, :oauth_token)}", "Content-Type": "application/x-www-form-urlencoded"]

    case HTTPoison.delete(url, headers) do
      {:ok, %HTTPoison.Response{status_code: 200}} -> {:ok}
      {:ok, %HTTPoison.Response{status_code: 401}} ->
        recall_function = fn -> delete_contact(id) end
        Logger.debug "Invalid Token"
        refresh_token(recall_function)
      error -> {:error, error}
    end
  end

  defp get_account_by_owner_email(nil), do: "No Account"
  defp get_account_by_owner_email(owner_email) do
    domain = owner_email |> String.split("@") |> List.last |> String.split(".") |> List.first
    case get_account(domain) do
      {:ok, account} -> account["Account_Name"]
      _ -> "No Account"
    end
  end

  def get_share(camera_exid, contact_fulname) do
    url = "#{@zoho_url}Cameras_X_Contacts/search?criteria=(Share_ID:equals:#{create_share_id(camera_exid, contact_fulname)})"
    headers = ["Authorization": "Bearer #{ConCache.get(:zoho_auth_token, :oauth_token)}"]

    case HTTPoison.get(url, headers) do
      {:ok, %HTTPoison.Response{body: body, status_code: 200}} ->
        json_response = Jason.decode!(body)
        share = Map.get(json_response, "data") |> List.first
        {:ok, share}
      {:ok, %HTTPoison.Response{status_code: 204}} -> {:nodata, "Share does't exits."}
      {:ok, %HTTPoison.Response{status_code: 401}} ->
        recall_function = fn -> get_share(camera_exid, contact_fulname) end
        Logger.debug "Invalid Token"
        refresh_token(recall_function)
      _ -> {:error}
    end
  end

  def delete_share(share_id) do
    url = "#{@zoho_url}Cameras_X_Contacts?ids=#{share_id}"
    headers = ["Authorization": "Bearer #{ConCache.get(:zoho_auth_token, :oauth_token)}"]

    case HTTPoison.delete(url, headers) do
      {:ok, %HTTPoison.Response{status_code: 200}} -> {:ok, "Share deleted successfully."}
      {:ok, %HTTPoison.Response{status_code: 204}} -> {:nodata, "Share does't exits."}
      {:ok, %HTTPoison.Response{status_code: 401}} ->
        recall_function = fn -> delete_share(share_id) end
        Logger.debug "Invalid Token"
        refresh_token(recall_function)
      _ -> {:error}
    end
  end

  def associate_camera_contact(contact, camera) do
    url = "#{@zoho_url}Cameras_X_Contacts"
    headers = ["Authorization": "Bearer #{ConCache.get(:zoho_auth_token, :oauth_token)}", "Content-Type": "application/x-www-form-urlencoded"]

    contact_xml =
      %{ "data" => [%{
          "Share_ID" => create_share_id(camera["Evercam_ID"], contact["Full_Name"]),
          "Description" => "#{camera["Name"]} shared with #{contact["Full_Name"]}",
          "Related_Camera_Sharees" => %{
            name: camera["Name"],
            id: camera["id"]
          },
          "Camera_Sharees" => %{
            name: contact["Full_Name"],
            id: contact["id"]
          }
        }]
      }

    case HTTPoison.post(url, Jason.encode!(contact_xml), headers) do
      {:ok, %HTTPoison.Response{body: body, status_code: 201}} ->
        {:ok, body}
      {:ok, %HTTPoison.Response{status_code: 401}} ->
        recall_function = fn -> associate_camera_contact(contact, camera) end
        Logger.debug "Invalid Token"
        refresh_token(recall_function)
      error -> {:error, error}
    end
  end

  def associate_multiple_contact(request_params) do
    url = "#{@zoho_url}Cameras_X_Contacts"
    headers = ["Authorization": "Bearer #{ConCache.get(:zoho_auth_token, :oauth_token)}", "Content-Type": "application/x-www-form-urlencoded"]

    contact_xml = %{ "data" => request_params }
    case HTTPoison.post(url, Jason.encode!(contact_xml), headers) do
      {:ok, %HTTPoison.Response{body: body, status_code: 201}} -> {:ok, body}
      {:ok, %HTTPoison.Response{status_code: 401}} ->
        recall_function = fn -> associate_multiple_contact(request_params) end
        Logger.debug "Invalid Token"
        refresh_token(recall_function)
      error -> {:error, error}
    end
  end

  def create_camera_request([camera | rest], camera_json) do
    url_to_nvr = "http://#{Camera.host(camera, "external")}:#{Camera.get_nvr_port(camera)}"
    evercam_type =
      case camera.owner.email do
        "smartcities@evercam.io" -> "Smart Cities"
        _ -> "Construction"
      end
    camera_obj =
      %{
        "Evercam_ID" => "#{camera.exid}",
        "Evercam_Type" => "#{evercam_type}",
        "Name" => "#{camera.name}",
        "Passwords" => "#{Camera.password(camera)}",
        "URL_to_NVR" => "#{url_to_nvr}"
      }

    create_camera_request(rest, List.insert_at(camera_json, -1, camera_obj))
  end
  def create_camera_request([], camera_json), do: camera_json

  def create_share_id(camera_exid, username) do
    clean_name = username |> EvercamMedia.Util.slugify |> String.replace(" ", "") |> String.replace("-", "") |> String.downcase
    "#{camera_exid}-#{clean_name}"
  end

  def get_share_request(email) do
    url = "#{@zoho_url}Share_Requests/search?criteria=(Email:equals:#{email})"
    headers = ["Authorization": "Bearer #{ConCache.get(:zoho_auth_token, :oauth_token)}"]

    case HTTPoison.get(url, headers) do
      {:ok, %HTTPoison.Response{body: body, status_code: 200}} ->
        json_response = Jason.decode!(body)
        share_requests = Map.get(json_response, "data")
        {:ok, share_requests}
      {:ok, %HTTPoison.Response{status_code: 204}} -> {:nodata, "Share request does't exits."}
      {:ok, %HTTPoison.Response{status_code: 401}} ->
        recall_function = fn -> get_share_request(email) end
        Logger.debug "Invalid Token"
        refresh_token(recall_function)
      _ -> {:error}
    end
  end

  def insert_requestee(share_request, camera, _owner_email \\ nil) do
    url = "#{@zoho_url}Share_Requests"
    headers = ["Authorization": "Bearer #{ConCache.get(:zoho_auth_token, :oauth_token)}", "Content-Type": "application/x-www-form-urlencoded"]
    domain = share_request.email |> String.split("@") |> List.last |> String.split(".") |> List.first
    account_name =
      case get_account(domain) do
        {:ok, account} -> %{"id" => account["id"], "name" => account["Account_Name"]}
        _ -> %{"id" => "432169000008646140", "name" => "No Account"}
      end

    contact =
      case get_contact(share_request.user.email) do
        {:ok, contact} -> %{"id" => contact["id"]}
        {:nodata, _message} ->
          {:ok, contact} = insert_contact(share_request.user)
          %{"id" => contact["id"]}
        {:error} -> %{}
      end

    contact_xml =
      %{"data" =>
        [%{
          "Camera_Shared" => %{
            "id" => camera["id"],
            "name" => camera["Name"]
          },
          "Contact" => contact,
          "Account" => account_name,
          "Email" => "#{share_request.email}",
          "Share_Text" => share_request.message,
          "Share_Request_Rights" => get_share_rights(share_request.rights),
          "Status" => "Shared-Non-Registered"
        }]
      }

    case HTTPoison.post(url, Jason.encode!(contact_xml), headers) do
      {:ok, %HTTPoison.Response{body: body, status_code: 201}} ->
        json_response = Jason.decode!(body)
        contact = Map.get(json_response, "data") |> List.first
        {:ok, contact["details"]}
      {:ok, %HTTPoison.Response{status_code: 401}} ->
        recall_function = fn -> insert_requestee(share_request, camera) end
        Logger.debug "Invalid Token"
        refresh_token(recall_function)
      error -> {:error, error}
    end
  end

  def update_share_requests(share_requests) do
    url = "#{@zoho_url}Share_Requests"
    headers = ["Authorization": "Bearer #{ConCache.get(:zoho_auth_token, :oauth_token)}", "Content-Type": "application/x-www-form-urlencoded"]

    xml_data =
      Enum.map(share_requests, fn(req) ->
        %{
          "id" => req["id"],
          "Status" => "Share-Accepted"
        }
      end)
    contact_xml = %{ "data" => xml_data }
    case HTTPoison.put(url, Jason.encode!(contact_xml), headers) do
      {:ok, %HTTPoison.Response{body: body, status_code: 200}} -> {:ok, body}
      {:ok, %HTTPoison.Response{status_code: 401}} ->
        recall_function = fn -> update_share_requests(share_requests) end
        Logger.debug "Invalid Token"
        refresh_token(recall_function)
      error -> {:error, error}
    end
  end

  defp get_share_rights("list,snapshot"), do: "Read Only"
  defp get_share_rights("list,snapshot,share"), do: "Read Only + Share"
  defp get_share_rights(_), do: "Full Rights"
end
