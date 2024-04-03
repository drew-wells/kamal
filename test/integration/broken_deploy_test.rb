require_relative "integration_test"

class BrokenDeployTest < IntegrationTest
  test "deploying a bad image" do
    @app = "app_with_roles"

    kamal :envify

    first_version = latest_app_version

    kamal :deploy

    assert_app_is_up version: first_version
    assert_container_running host: :vm3, name: "app-workers-#{first_version}"

    second_version = break_app

    kamal :deploy, raise_on_error: false

    assert_app_is_up version: first_version
    assert_container_running host: :vm3, name: "app-workers-#{first_version}"
    assert_container_not_running host: :vm3, name: "app-workers-#{second_version}"
  end
end
