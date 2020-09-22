defmodule EvercamMedia.UsersTask do
  require Logger
  alias Evercam.Repo

  def update_user_keys do
    User.all
    |> Enum.each(fn(user) ->
      Logger.info "#{user.email}: API_ID: #{user.api_id}, API_KEY: #{user.api_key}"

      api_id = UUID.uuid4(:hex) |> String.slice(0..7)
      api_key = UUID.uuid4(:hex)
      user_params = %{api_id: api_id, api_key: api_key}
      User.update_user(user, user_params)
    end)
  end

  def update_camera_share_rights do
    AccessRight.all
    |> Enum.each(fn(right) ->
      user_id = Util.deep_get(right, [:access_token, :user_id], 0)
      case user_id do
        id when id > 0 ->
          Logger.info("token-id: #{right.token_id}, user-id: #{id}, new-field-user-id: #{right.user_id}")
          right
          |> AccessRight.changeset(%{user_id: id})
          |> Repo.update
        _ -> Logger.info "User id empty for right-id: #{right.id}"
      end

    end)
  end
end
