defmodule Permission.CameraTest do
  use EvercamMedia.ModelCase

  test "owner can do anything with the camera" do
    country = Repo.insert!(%Country{name: "Something", iso3166_a2: "SMT"})
    user = Repo.insert!(%User{firstname: "John", lastname: "Doe", username: "johndoe", email: "john@doe.com", password: "password123", country_id: country.id})
    token = Repo.insert!(%AccessToken{user_id: user.id, is_revoked: false, request: "whatever"})
    camera = Repo.insert!(%Camera{owner_id: user.id, name: "camera 1", exid: "123", is_public: false, config: ""})
    _access_right = Repo.insert!(%AccessRight{user_id: user.id, right: "edit", camera_id: camera.id, status: 1, scope: "cameras"})
    camera = Repo.preload(camera, [:access_rights, [access_rights: :access_token]])

    assert Permission.Camera.can_edit?(user, camera)
    assert Permission.Camera.can_view?(user, camera)
    assert Permission.Camera.can_snapshot?(user, camera)
    assert Permission.Camera.can_delete?(user, camera)
    assert Permission.Camera.can_list?(user, camera)
    assert Permission.Camera.can_grant?(user, camera)
  end

  test ".can_edit(user, camera) - returns false if the USER cannot EDIT the CAMERA" do
    country = Repo.insert!(%Country{name: "Something", iso3166_a2: "SMT"})
    user = Repo.insert!(%User{firstname: "John", lastname: "Doe", username: "johndoe", email: "john@doe.com", password: "password123", country_id: country.id})
    owner = Repo.insert!(%User{firstname: "Jane", lastname: "Doe", username: "janedoe", email: "jane@doe.net", password: "password123", country_id: country.id})
    token = Repo.insert!(%AccessToken{user_id: user.id, is_revoked: false, request: "whatever"})
    camera = Repo.insert!(%Camera{owner_id: owner.id, name: "camera 1", exid: "123", is_public: false, config: ""})
    _access_right = Repo.insert!(%AccessRight{user_id: user.id, right: "view", camera_id: camera.id, status: 1, scope: "cameras"})
    camera = Repo.preload(camera, [:access_rights, [access_rights: :access_token]])

    assert Permission.Camera.can_view?(user, camera)
    refute Permission.Camera.can_edit?(user, camera)
  end

  test ".can_edit(user, camera) - returns true if the USER can EDIT the CAMERA" do
    country = Repo.insert!(%Country{name: "Something", iso3166_a2: "SMT"})
    user = Repo.insert!(%User{firstname: "John", lastname: "Doe", username: "johndoe", email: "john@doe.com", password: "password123", country_id: country.id})
    owner = Repo.insert!(%User{firstname: "Jane", lastname: "Doe", username: "janedoe", email: "jane@doe.net", password: "password123", country_id: country.id})
    token = Repo.insert!(%AccessToken{user_id: user.id, is_revoked: false, request: "whatever"})
    camera = Repo.insert!(%Camera{owner_id: owner.id, name: "camera 1", exid: "123", is_public: false, config: ""})
    _access_right = Repo.insert!(%AccessRight{user_id: user.id, right: "edit", camera_id: camera.id, status: 1, scope: "cameras"})
    camera = Repo.preload(camera, [:access_rights, [access_rights: :access_token]])

    assert Permission.Camera.can_edit?(user, camera)
  end

  test ".can_edit(user, camera) - returns false if USER has other access rights but not EDIT" do
    country = Repo.insert!(%Country{name: "Something", iso3166_a2: "SMT"})
    user = Repo.insert!(%User{firstname: "John", lastname: "Doe", username: "johndoe", email: "john@doe.com", password: "password123", country_id: country.id})
    owner = Repo.insert!(%User{firstname: "Jane", lastname: "Doe", username: "janedoe", email: "jane@doe.net", password: "password123", country_id: country.id})
    token = Repo.insert!(%AccessToken{user_id: user.id, is_revoked: false, request: "whatever"})
    camera = Repo.insert!(%Camera{owner_id: owner.id, name: "camera 1", exid: "123", is_public: false, config: ""})
    _grant_right = Repo.insert!(%AccessRight{user_id: user.id, right: "grant", camera_id: camera.id, status: 1, scope: "cameras"})
    _view_right = Repo.insert!(%AccessRight{user_id: user.id, right: "list", camera_id: camera.id, status: 1, scope: "cameras"})
    camera = Repo.preload(camera, [:access_rights, [access_rights: :access_token]])

    assert Permission.Camera.can_list?(user, camera)
    assert Permission.Camera.can_grant?(user, camera)
    refute Permission.Camera.can_edit?(user, camera)
  end
end
