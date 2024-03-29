class Kamal::Cli::App::Boot
  attr_reader :host, :role, :version, :sshkit
  delegate :execute, :capture_with_info, :info, to: :sshkit
  delegate :assets?, :running_proxy?, to: :role

  def initialize(host, role, version, sshkit)
    @host = host
    @role = role
    @version = version
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
    def app
      @app ||= KAMAL.app(role: role)
    end

    def auditor
      @auditor = KAMAL.auditor(role: role)
    end

    def audit(message)
      execute *auditor.record(message), verbosity: :debug
    end

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
      execute *app.run(hostname: "#{host}-#{SecureRandom.hex(6)}")
      if running_proxy?
        execute *KAMAL.proxy.deploy("#{app.container_name(version)}:#{role.port}")
      end
    end

    def stop_old_version(version)
      execute *app.stop(version: version), raise_on_non_zero_exit: false
      execute *app.clean_up_assets if assets?
    end
end
