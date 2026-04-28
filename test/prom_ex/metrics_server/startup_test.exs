defmodule PromEx.MetricsServer.StartupTest do
  use ExUnit.Case, async: true

  @moduletag :capture_log

  defmodule TestPromEx do
    use PromEx, otp_app: :prom_ex

    @impl true
    def plugins, do: []

    @impl true
    def dashboards, do: []
  end

  defp build_config(extra \\ %{}) do
    Map.merge(
      %{
        port: 9999,
        path: "/metrics",
        protocol: :http,
        auth_strategy: :none,
        bandit_opts: []
      },
      extra
    )
  end

  defp bandit_opts_from_spec(spec) do
    {Bandit, :start_link, [opts]} = spec.start
    opts
  end

  describe "metrics_server_child_spec/4" do
    test "produces a Bandit child spec with the configured port and scheme" do
      [spec | []] = PromEx.metrics_server_child_spec([], build_config(), TestPromEx, :test_server)

      opts = bandit_opts_from_spec(spec)
      assert opts[:port] == 9999
      assert opts[:scheme] == :http
      assert {PromEx.MetricsServer.Plug, _plug_opts} = opts[:plug]
    end

    test "splices bandit_opts into the child spec" do
      bandit_opts = [
        thousand_island_options: [
          transport_options: [reuseport: true, reuseaddr: true]
        ]
      ]

      [spec | []] =
        PromEx.metrics_server_child_spec(
          [],
          build_config(%{bandit_opts: bandit_opts}),
          TestPromEx,
          :test_server
        )

      opts = bandit_opts_from_spec(spec)
      assert opts[:thousand_island_options] == [transport_options: [reuseport: true, reuseaddr: true]]
    end

    test "ignores attempts to override scheme/plug/port via bandit_opts" do
      [spec | []] =
        PromEx.metrics_server_child_spec(
          [],
          build_config(%{bandit_opts: [port: 1, scheme: :https, plug: :evil]}),
          TestPromEx,
          :test_server
        )

      opts = bandit_opts_from_spec(spec)
      assert opts[:port] == 9999
      assert opts[:scheme] == :http
      assert {PromEx.MetricsServer.Plug, _} = opts[:plug]
    end

    test "skips child spec when config is :disabled" do
      assert PromEx.metrics_server_child_spec([], :disabled, TestPromEx, :test_server) == []
    end
  end
end
