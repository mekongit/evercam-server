defmodule EvercamMediaWeb.UserView do
  use EvercamMediaWeb, :view
  alias EvercamMedia.Util

  def render("show.v1.json", %{user: user}) do
    %{
      users: [
        %{
          id: user.username,
          firstname: user.firstname,
          lastname: user.lastname,
          username: user.username,
          telegram_username: user.telegram_username,
          email: user.email,
          country: User.get_country_attr(user, :iso3166_a2),
          stripe_customer_id: user.stripe_customer_id,
          created_at: Util.ecto_datetime_to_unix(user.created_at),
          updated_at: Util.ecto_datetime_to_unix(user.updated_at),
          confirmed_at: Util.ecto_datetime_to_unix(user.confirmed_at),
          last_login_at: Util.ecto_datetime_to_unix(user.last_login_at),
          intercom_hmac_ios: Util.create_HMAC(user.username, System.get_env["INTERCOM_IOS_KEY"]),
          intercom_hmac_android: Util.create_HMAC(user.username, System.get_env["INTERCOM_ANDROID_KEY"])
        }
      ]
    }
  end

  def render("show.v2.json", %{token: token, user: user}) do
    %{token: token} |> Map.merge(get_user(user))
  end
  def render("show.v2.json", %{user: user}) do
    %{users: [get_user(user)]}
  end

  def render("remote_login.json", %{token: token, user: user}) do
    %{token: token} |> Map.merge(get_user(user))
  end

  def render("credentials.json", %{user: user}) do
    %{
      api_id: user.api_id,
      api_key: user.api_key
    }
  end

  defp get_user(user) do
    %{
      id: user.username,
      firstname: user.firstname,
      lastname: user.lastname,
      username: user.username,
      telegram_username: user.telegram_username,
      email: user.email,
      country: User.get_country_attr(user, :iso3166_a2),
      stripe_customer_id: user.stripe_customer_id,
      created_at: Util.datetime_to_iso8601(user.created_at),
      updated_at: Util.datetime_to_iso8601(user.updated_at),
      confirmed_at: Util.datetime_to_iso8601(user.confirmed_at),
      last_login_at: Util.datetime_to_iso8601(user.last_login_at),
      intercom_hmac_ios: Util.create_HMAC(user.username, System.get_env["INTERCOM_IOS_KEY"]),
      intercom_hmac_android: Util.create_HMAC(user.username, System.get_env["INTERCOM_ANDROID_KEY"])
    }
  end
end
