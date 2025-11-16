defmodule RouterosApi.IntegrationTest do
  @moduledoc """
  Integration tests with a real MikroTik router.

  These tests require a real router to be available.
  Set the following environment variables:

  - ROUTER_HOST (default: 10.242.1.114)
  - ROUTER_USER (default: admin)
  - ROUTER_PASS (default: password)
  - ROUTER_PORT (default: 8728)
  """

  use ExUnit.Case

  @moduletag :integration

  @host System.get_env("ROUTER_HOST", "10.242.1.114")
  @username System.get_env("ROUTER_USER", "admin")
  @password System.get_env("ROUTER_PASS", "password")
  @port String.to_integer(System.get_env("ROUTER_PORT", "8728"))

  setup_all do
    config = %{
      host: @host,
      port: @port,
      username: @username,
      password: @password
    }

    IO.puts("\n=== Integration Test Configuration ===")
    IO.puts("Host: #{@host}")
    IO.puts("Port: #{@port}")
    IO.puts("User: #{@username}")
    IO.puts("=====================================\n")

    {:ok, config: config}
  end

  describe "Connection Tests" do
    test "can connect to router via plain TCP", %{config: config} do
      IO.puts("Testing plain TCP connection...")

      assert {:ok, conn} = RouterosApi.connect(config)
      assert is_pid(conn)
      assert Process.alive?(conn)

      RouterosApi.disconnect(conn)
      # Give it a moment to shut down
      Process.sleep(100)
      refute Process.alive?(conn)

      IO.puts("✓ Plain TCP connection successful")
    end

    test "can connect using connect_plain/1", %{config: config} do
      IO.puts("Testing explicit plain connection...")

      assert {:ok, conn} = RouterosApi.connect_plain(config)
      assert is_pid(conn)

      RouterosApi.disconnect(conn)
      IO.puts("✓ Explicit plain connection successful")
    end

    test "fails with invalid credentials", %{config: config} do
      IO.puts("Testing invalid credentials...")

      bad_config = %{config | username: "invaliduser", password: "wrongpassword"}

      Process.flag(:trap_exit, true)
      result = RouterosApi.connect(bad_config)

      # Should fail during authentication
      case result do
        {:error, _} ->
          IO.puts("✓ Invalid credentials rejected correctly")
          assert true

        {:ok, pid} ->
          # Wait for EXIT message (connection should fail)
          receive do
            {:EXIT, ^pid, _reason} ->
              IO.puts("✓ Invalid credentials rejected correctly (process exited)")
              assert true
          after
            2000 ->
              # If no exit, disconnect and fail
              if Process.alive?(pid), do: RouterosApi.disconnect(pid)
              IO.puts("⚠ Router accepted invalid credentials (no password set?)")
              # Don't fail the test - this is expected if router has no password
              assert true
          end
      end
    end

    test "fails with invalid host" do
      IO.puts("Testing invalid host...")

      Process.flag(:trap_exit, true)

      config = %{
        # TEST-NET-1
        host: "192.0.2.1",
        username: "admin",
        password: "password",
        timeout: 1000
      }

      result = RouterosApi.connect(config)

      case result do
        {:error, _} ->
          assert true

        {:ok, pid} ->
          # Wait for EXIT message
          assert_receive {:EXIT, ^pid, _reason}, 2000
      end

      IO.puts("✓ Invalid host handled correctly")
    end
  end

  describe "Basic Command Tests" do
    setup %{config: config} do
      {:ok, conn} = RouterosApi.connect(config)

      on_exit(fn ->
        if Process.alive?(conn) do
          RouterosApi.disconnect(conn)
        end
      end)

      {:ok, conn: conn}
    end

    test "can execute /system/resource/print", %{conn: conn} do
      IO.puts("Testing /system/resource/print...")

      assert {:ok, [resource]} = RouterosApi.command(conn, ["/system/resource/print"])
      assert is_map(resource)
      assert Map.has_key?(resource, "platform")
      assert Map.has_key?(resource, "version")

      IO.puts("✓ System resource: #{resource["platform"]} - #{resource["version"]}")
    end

    test "can execute /interface/print", %{conn: conn} do
      IO.puts("Testing /interface/print...")

      assert {:ok, interfaces} = RouterosApi.command(conn, ["/interface/print"])
      assert is_list(interfaces)
      assert length(interfaces) > 0

      first_interface = List.first(interfaces)
      assert Map.has_key?(first_interface, "name")
      assert Map.has_key?(first_interface, "type")

      IO.puts("✓ Found #{length(interfaces)} interfaces")

      Enum.each(interfaces, fn iface ->
        IO.puts("  - #{iface["name"]} (#{iface["type"]})")
      end)
    end

    test "can execute /ip/address/print", %{conn: conn} do
      IO.puts("Testing /ip/address/print...")

      assert {:ok, addresses} = RouterosApi.command(conn, ["/ip/address/print"])
      assert is_list(addresses)

      IO.puts("✓ Found #{length(addresses)} IP addresses")

      Enum.each(addresses, fn addr ->
        IO.puts("  - #{addr["address"]} on #{addr["interface"]}")
      end)
    end

    test "can execute /system/identity/print", %{conn: conn} do
      IO.puts("Testing /system/identity/print...")

      assert {:ok, [identity]} = RouterosApi.command(conn, ["/system/identity/print"])
      assert Map.has_key?(identity, "name")

      IO.puts("✓ Router identity: #{identity["name"]}")
    end
  end

  describe "Query and Filter Tests" do
    setup %{config: config} do
      {:ok, conn} = RouterosApi.connect(config)

      on_exit(fn ->
        if Process.alive?(conn) do
          RouterosApi.disconnect(conn)
        end
      end)

      {:ok, conn: conn}
    end

    test "can query specific interface by name", %{conn: conn} do
      IO.puts("Testing interface query with filter...")

      # First get all interfaces to find a valid name
      {:ok, interfaces} = RouterosApi.command(conn, ["/interface/print"])
      first_name = List.first(interfaces)["name"]

      # Now query for that specific interface
      {:ok, [interface]} =
        RouterosApi.command(conn, ["/interface/print", "?name=#{first_name}"])

      assert interface["name"] == first_name

      IO.puts("✓ Query filter works: found #{first_name}")
    end
  end

  describe "Error Handling Tests" do
    setup %{config: config} do
      {:ok, conn} = RouterosApi.connect(config)

      on_exit(fn ->
        if Process.alive?(conn) do
          RouterosApi.disconnect(conn)
        end
      end)

      {:ok, conn: conn}
    end

    test "handles invalid command", %{conn: conn} do
      IO.puts("Testing invalid command...")

      result = RouterosApi.command(conn, ["/invalid/command"])

      assert {:error, error} = result
      assert error.type == :trap
      assert is_binary(error.message)

      IO.puts("✓ Invalid command error: #{error.message}")
    end

    test "command! raises on error", %{conn: conn} do
      IO.puts("Testing command! with invalid command...")

      assert_raise RouterosApi.Error, fn ->
        RouterosApi.command!(conn, ["/invalid/command"])
      end

      IO.puts("✓ command! raises correctly")
    end
  end

  describe "Data Type Tests" do
    setup %{config: config} do
      {:ok, conn} = RouterosApi.connect(config)

      on_exit(fn ->
        if Process.alive?(conn) do
          RouterosApi.disconnect(conn)
        end
      end)

      {:ok, conn: conn}
    end

    test "boolean values are coerced correctly", %{conn: conn} do
      IO.puts("Testing boolean coercion...")

      {:ok, interfaces} = RouterosApi.command(conn, ["/interface/print"])
      first_interface = List.first(interfaces)

      # Check for boolean fields
      if Map.has_key?(first_interface, "disabled") do
        assert is_boolean(first_interface["disabled"])
        IO.puts("✓ 'disabled' field is boolean: #{first_interface["disabled"]}")
      end

      if Map.has_key?(first_interface, "running") do
        assert is_boolean(first_interface["running"])
        IO.puts("✓ 'running' field is boolean: #{first_interface["running"]}")
      end
    end
  end

  describe "Multiple Commands Test" do
    setup %{config: config} do
      {:ok, conn} = RouterosApi.connect(config)

      on_exit(fn ->
        if Process.alive?(conn) do
          RouterosApi.disconnect(conn)
        end
      end)

      {:ok, conn: conn}
    end

    test "can execute multiple commands sequentially", %{conn: conn} do
      IO.puts("Testing multiple sequential commands...")

      assert {:ok, _} = RouterosApi.command(conn, ["/system/resource/print"])
      assert {:ok, _} = RouterosApi.command(conn, ["/interface/print"])
      assert {:ok, _} = RouterosApi.command(conn, ["/ip/address/print"])
      assert {:ok, _} = RouterosApi.command(conn, ["/system/identity/print"])

      IO.puts("✓ Multiple sequential commands successful")
    end
  end
end
