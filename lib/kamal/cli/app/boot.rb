class Kamal::Cli::App::Boot
  attr_reader :host, :role, :version, :barrier, :sshkit
  delegate :execute, :capture_with_info, :info, to: :sshkit
  delegate :uses_cord?, :assets?, :running_traefik?, to: :role

  def initialize(host, role, sshkit, version, barrier)
    @host = host
    @role = role
    @version = version
    @barrier = barrier
    @sshkit = sshkit
  end

  def run
    old_version = old_version_renamed_if_clashing

    start_new_version

    if old_version
      stop_old_version(old_version)
    end
  end

  private
    def old_version_renamed_if_clashing
      if capture_with_info(*app.container_id_for_version(version), raise_on_non_zero_exit: false).present?
        renamed_version = "#{version}_replaced_#{SecureRandom.hex(8)}"
        info "Renaming container #{version} to #{renamed_version} as already deployed on #{host}"
        audit("Renaming container #{version} to #{renamed_version}")
        execute *app.rename_container(version: version, new_version: renamed_version)
      end

      capture_with_info(*app.current_running_version, raise_on_non_zero_exit: false).strip.presence
    end

    def start_new_version
      audit "Booted app version #{version}"

      execute *app.tie_cord(role.cord_host_file) if uses_cord?
      execute *app.run(hostname: "#{host}-#{SecureRandom.hex(6)}")

      Kamal::Cli::Healthcheck::Poller.wait_for_healthy(pause_after_ready: true) { capture_with_info(*app.status(version: version)) }

      reach_barrier
    rescue => e
      close_barrier if barrier_role?
      execute *app.stop(version: version), raise_on_non_zero_exit: false

      raise
    end

    def stop_old_version(version)
      if uses_cord?
        cord = capture_with_info(*app.cord(version: version), raise_on_non_zero_exit: false).strip
        if cord.present?
          execute *app.cut_cord(cord)
          Kamal::Cli::Healthcheck::Poller.wait_for_unhealthy(pause_after_ready: true) { capture_with_info(*app.status(version: version)) }
        end
      end

      execute *app.stop(version: version), raise_on_non_zero_exit: false

      execute *app.clean_up_assets if assets?
    end

    def reach_barrier
      if barrier
        if barrier_role?
          if barrier.open
            info "Opened barrier (#{host})"
          end
        else
          wait_for_barrier
        end
      end
    end

    def wait_for_barrier
      info "Waiting at web barrier (#{host})..."
      barrier.wait
      info "Barrier opened (#{host})"
    rescue Kamal::Cli::Healthcheck::Error
      info "Barrier closed, shutting down new container... (#{host})"
      raise
    end

    def close_barrier
      barrier&.close
    end

    def barrier_role?
      role == KAMAL.primary_role
    end

    def app
      @app ||= KAMAL.app(role: role)
    end

    def auditor
      @auditor = KAMAL.auditor(role: role)
    end

    def audit(message)
      execute *auditor.record(message), verbosity: :debug
    end
end
