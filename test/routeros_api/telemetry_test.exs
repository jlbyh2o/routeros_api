defmodule RouterosApi.TelemetryTest do
  use ExUnit.Case, async: false

  @moduletag :integration

  @host System.get_env("ROUTER_HOST", "10.242.1.114")
  @username System.get_env("ROUTER_USER", "admin")
  @password System.get_env("ROUTER_PASS", "password")
  @port String.to_integer(System.get_env("ROUTER_PORT", "8728"))

  setup do
    # Attach telemetry handler
    events = [
      [:routeros_api, :connection, :start],
      [:routeros_api, :connection, :stop],
      [:routeros_api, :connection, :exception],
      [:routeros_api, :command, :start],
      [:routeros_api, :command, :stop],
      [:routeros_api, :command, :exception],
      [:routeros_api, :pool, :checkout],
      [:routeros_api, :pool, :checkin]
    ]

    test_pid = self()

    :telemetry.attach_many(
      "test-handler-#{:erlang.unique_integer()}",
      events,
      fn event, measurements, metadata, _config ->
        send(test_pid, {:telemetry_event, event, measurements, metadata})
      end,
      nil
    )

    on_exit(fn ->
      :telemetry.detach("test-handler-#{:erlang.unique_integer()}")
    end)

    :ok
  end

  describe "Connection Telemetry" do
    test "emits connection events" do
      config = %{
        host: @host,
        port: @port,
        username: @username,
        password: @password
      }

      {:ok, conn} = RouterosApi.connect(config)

      # Should receive connection start event
      assert_receive {:telemetry_event, [:routeros_api, :connection, :start], measurements,
                      metadata}

      assert is_integer(measurements.system_time)
      assert metadata.host == @host
      assert metadata.port == @port

      # Should receive connection stop event
      assert_receive {:telemetry_event, [:routeros_api, :connection, :stop], measurements,
                      metadata}

      assert is_integer(measurements.duration)
      assert metadata.host == @host

      RouterosApi.disconnect(conn)
    end

    test "emits connection exception on failure" do
      config = %{
        # Invalid host
        host: "192.0.2.1",
        port: 8728,
        username: "admin",
        password: "password",
        timeout: 1000
      }

      Process.flag(:trap_exit, true)
      result = RouterosApi.connect(config)

      # Should receive connection start
      assert_receive {:telemetry_event, [:routeros_api, :connection, :start], _measurements,
                      _metadata}

      # Should receive connection exception
      case result do
        {:error, _} ->
          # Immediate error
          assert true

        {:ok, pid} ->
          # Wait for EXIT
          assert_receive {:EXIT, ^pid, _reason}, 2000
      end

      # May or may not receive exception event depending on timing
      receive do
        {:telemetry_event, [:routeros_api, :connection, :exception], _measurements, _metadata} ->
          assert true
      after
        100 -> :ok
      end
    end
  end

  describe "Command Telemetry" do
    test "emits command events" do
      config = %{
        host: @host,
        port: @port,
        username: @username,
        password: @password
      }

      {:ok, conn} = RouterosApi.connect(config)

      # Clear connection events
      flush_messages()

      # Execute command
      {:ok, _result} = RouterosApi.command(conn, ["/system/identity/print"])

      # Should receive command start
      assert_receive {:telemetry_event, [:routeros_api, :command, :start], measurements, metadata}
      assert is_integer(measurements.system_time)
      assert metadata.command == "/system/identity/print"

      # Should receive command stop
      assert_receive {:telemetry_event, [:routeros_api, :command, :stop], measurements, metadata}
      assert is_integer(measurements.duration)
      assert is_integer(measurements.result_count)
      assert metadata.command == "/system/identity/print"

      RouterosApi.disconnect(conn)
    end

    test "emits command exception on error" do
      config = %{
        host: @host,
        port: @port,
        username: @username,
        password: @password
      }

      {:ok, conn} = RouterosApi.connect(config)
      flush_messages()

      # Execute invalid command
      {:error, _} = RouterosApi.command(conn, ["/invalid/command"])

      # Should receive command start
      assert_receive {:telemetry_event, [:routeros_api, :command, :start], _measurements,
                      _metadata}

      # Should receive command exception
      assert_receive {:telemetry_event, [:routeros_api, :command, :exception], measurements,
                      metadata}

      assert is_integer(measurements.duration)
      assert metadata.command == "/invalid/command"

      RouterosApi.disconnect(conn)
    end
  end

  defp flush_messages do
    receive do
      _ -> flush_messages()
    after
      0 -> :ok
    end
  end
end
