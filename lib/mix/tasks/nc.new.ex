defmodule Mix.Tasks.Nc.New do
  use Mix.Task

  @version Mix.Project.config()[:version]
  @shortdoc "Creates a new Nerves v#{@version} application"

  @global_switches [
    phoenix: :boolean,
    nerves_cloud: :boolean
  ]

  @nerves_switches [
    app: :string,
    module: :string,
    target: :string,
    cookie: :string
  ]

  @phx_switches [
    dev: :boolean,
    assets: :boolean,
    esbuild: :boolean,
    tailwind: :boolean,
    ecto: :boolean,
    app: :string,
    module: :string,
    web_module: :string,
    database: :string,
    binary_id: :boolean,
    html: :boolean,
    gettext: :boolean,
    verbose: :boolean,
    live: :boolean,
    dashboard: :boolean,
    install: :boolean,
    prefix: :string,
    mailer: :boolean,
    adapter: :string
  ]

  @firmware_files [
    {:eex, "new/config/host.exs.eex", "config/host.exs"}
  ]

  root = Path.expand("../../../templates", __DIR__)

  for {format, source, _} <- @firmware_files do
    unless format == :keep do
      @external_resource Path.join(root, source)
      defp render(unquote(source)), do: unquote(File.read!(Path.join(root, source)))
    end
  end

  @impl true
  def run([version]) when version in ~w(-v --version) do
    Mix.shell().info("NervesCloud v#{@version}")
    Mix.shell().info("Phoenix installer v#{@version}")
  end

  def run(argv) do
    switches = Enum.uniq(@global_switches ++ @nerves_switches ++ @phx_switches)

    case OptionParser.parse!(argv, strict: switches) do
      {_opts, []} ->
        Mix.Tasks.Help.run(["nc.new"])

      {opts, [base_path | _]} ->
        generate(base_path, opts)
    end
  end

  defp to_args(opts, switches) do
    Enum.reduce(opts, [], fn {key, value}, acc ->
      case {switches[key], value} do
        {:string, value} -> ["--#{key}" | [value | acc]]
        {:boolean, true} -> ["--#{key}" | acc]
        {:boolean, false} -> ["--no-#{key}" | acc]
        _ -> acc
      end
    end)
  end

  defp generate(project_path, opts) do
    project_path = Path.expand(project_path)
    app = opts[:app] || Path.basename(project_path)
    File.mkdir_p(project_path)

    app_mod = Module.concat([opts[:module] || Macro.camelize(app)])
    File.cd!(project_path)

    # In case the module or app was overridden
    nerves_opts = Keyword.merge(opts, module: "#{app_mod}Firmware", app: "#{app}_firmware")
    nerves_args = to_args(nerves_opts, @nerves_switches)

    firmware_path = Path.join(project_path, "#{app}_firmware")
    Mix.Task.run("nerves.new", ["#{app}_firmware" | nerves_args])

    if opts[:phoenix] != false do
      # Ensure big UI in module name to avoid murder by mob
      phx_opts = Keyword.merge(opts, module: "#{app_mod}UI", app: "#{app}_ui")
      phx_args = to_args(phx_opts, @phx_switches)
      Mix.Task.run("phx.new", ["#{app}_ui" | phx_args])
    end

    Mix.shell().info("Writing special NervesCloud hosts.exs config files...")

    binding =
      [
        app_name: app,
        app_module: app_mod
      ]

    for {format, source, target} <- @firmware_files do
      target = Path.join(firmware_path, target)

      case format do
        :eex ->
          File.write!(
            target,
            EEx.eval_string(render(source), binding)
          )

        _ ->
          :ok
      end
    end
  end
end
