require "test_helper"

class CommandsHealthcheckTest < ActiveSupport::TestCase
  setup do
    @config = {
      service: "app", image: "dhh/app", registry: { "username" => "dhh", "password" => "secret" }, servers: [ "1.1.1.1" ]
    }
  end

  test "run" do
    assert_equal \
      "docker run --detach --name healthcheck-app-123 --publish 3999:3000 --label service=healthcheck-app -e KAMAL_CONTAINER_NAME=\"healthcheck-app\" --env-file .kamal/env/roles/app-web.env --health-cmd \"curl -f http://localhost:3000/up || exit 1\" --health-interval \"1s\" dhh/app:123",
      new_command.run.join(" ")
  end

  test "run with custom port" do
    @config[:healthcheck] = { "port" => 3001 }

    assert_equal \
      "docker run --detach --name healthcheck-app-123 --publish 3999:3001 --label service=healthcheck-app -e KAMAL_CONTAINER_NAME=\"healthcheck-app\" --env-file .kamal/env/roles/app-web.env --health-cmd \"curl -f http://localhost:3001/up || exit 1\" --health-interval \"1s\" dhh/app:123",
      new_command.run.join(" ")
  end

  test "run with destination" do
    @destination = "staging"

    assert_equal \
      "docker run --detach --name healthcheck-app-staging-123 --publish 3999:3000 --label service=healthcheck-app-staging -e KAMAL_CONTAINER_NAME=\"healthcheck-app-staging\" --env-file .kamal/env/roles/app-web-staging.env --health-cmd \"curl -f http://localhost:3000/up || exit 1\" --health-interval \"1s\" dhh/app:123",
      new_command.run.join(" ")
  end

  test "run with custom healthcheck" do
    @config[:healthcheck] = { "cmd" => "/bin/up" }

    assert_equal \
      "docker run --detach --name healthcheck-app-123 --publish 3999:3000 --label service=healthcheck-app -e KAMAL_CONTAINER_NAME=\"healthcheck-app\" --env-file .kamal/env/roles/app-web.env --health-cmd \"/bin/up\" --health-interval \"1s\" dhh/app:123",
      new_command.run.join(" ")
  end

  test "run with custom options" do
    @config[:servers] = { "web" => { "hosts" => [ "1.1.1.1" ], "options" => { "mount" => "somewhere" } } }
    @config[:healthcheck] = { "exposed_port" => 4999 }
    assert_equal \
      "docker run --detach --name healthcheck-app-123 --publish 4999:3000 --label service=healthcheck-app -e KAMAL_CONTAINER_NAME=\"healthcheck-app\" --env-file .kamal/env/roles/app-web.env --health-cmd \"curl -f http://localhost:3000/up || exit 1\" --health-interval \"1s\" --mount \"somewhere\" dhh/app:123",
      new_command.run.join(" ")
  end

  test "status" do
    assert_equal \
      "docker container ls --all --filter name=^healthcheck-app-123$ --quiet | xargs docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}'",
      new_command.status.join(" ")
  end

  test "container_health_log" do
    assert_equal \
      "docker container ls --all --filter name=^healthcheck-app-123$ --quiet | xargs docker inspect --format '{{json .State.Health}}'",
      new_command.container_health_log.join(" ")
  end

  test "stop" do
    assert_equal \
      "docker container ls --all --filter name=^healthcheck-app-123$ --quiet | xargs docker stop",
      new_command.stop.join(" ")
  end

  test "stop with destination" do
    @destination = "staging"

    assert_equal \
      "docker container ls --all --filter name=^healthcheck-app-staging-123$ --quiet | xargs docker stop",
      new_command.stop.join(" ")
  end

  test "remove" do
    assert_equal \
      "docker container ls --all --filter name=^healthcheck-app-123$ --quiet | xargs docker container rm",
      new_command.remove.join(" ")
  end

  test "remove with destination" do
    @destination = "staging"

    assert_equal \
      "docker container ls --all --filter name=^healthcheck-app-staging-123$ --quiet | xargs docker container rm",
      new_command.remove.join(" ")
  end

  test "logs" do
    assert_equal \
      "docker container ls --all --filter name=^healthcheck-app-123$ --quiet | xargs docker logs --tail 50 2>&1",
      new_command.logs.join(" ")
  end

  test "logs with custom lines number" do
    @config[:healthcheck] = { "log_lines" => 150 }
    assert_equal \
      "docker container ls --all --filter name=^healthcheck-app-123$ --quiet | xargs docker logs --tail 150 2>&1",
      new_command.logs.join(" ")
  end

  test "logs with destination" do
    @destination = "staging"

    assert_equal \
      "docker container ls --all --filter name=^healthcheck-app-staging-123$ --quiet | xargs docker logs --tail 50 2>&1",
      new_command.logs.join(" ")
  end

  private
    def new_command
      Kamal::Commands::Healthcheck.new(Kamal::Configuration.new(@config, destination: @destination, version: "123"))
    end
end
