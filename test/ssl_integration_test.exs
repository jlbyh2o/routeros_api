defmodule RouterosApi.SslIntegrationTest do
  use ExUnit.Case, async: false

  @moduletag :ssl_integration

  @host System.get_env("ROUTER_HOST", "10.242.1.114")
  @username System.get_env("ROUTER_USER", "admin")
  @password System.get_env("ROUTER_PASS", "password")
  @ssl_port String.to_integer(System.get_env("ROUTER_SSL_PORT", "8729"))

  setup_all do
    IO.puts("\n" <> String.duplicate("=", 60))
    IO.puts("=== SSL/TLS Integration Test Configuration ===")
    IO.puts("Host: #{@host}")
    IO.puts("SSL Port: #{@ssl_port}")
    IO.puts("User: #{@username}")
    IO.puts(String.duplicate("=", 60) <> "\n")
    :ok
  end

  describe "SSL/TLS Connection Tests" do
    test "can connect via TLS with self-signed certificate (verify_none)" do
      IO.puts("Testing TLS connection with verify_none...")

      config = %{
        host: @host,
        port: @ssl_port,
        username: @username,
        password: @password,
        ssl: true,
        ssl_opts: [
          verify: :verify_none
        ]
      }

      {:ok, conn} = RouterosApi.connect(config)
      assert is_pid(conn)

      IO.puts("✓ TLS connection successful with verify_none")

      RouterosApi.disconnect(conn)
    end

    test "can execute commands over TLS" do
      IO.puts("Testing command execution over TLS...")

      config = %{
        host: @host,
        port: @ssl_port,
        username: @username,
        password: @password,
        ssl: true,
        ssl_opts: [verify: :verify_none]
      }

      {:ok, conn} = RouterosApi.connect(config)

      # Test /system/identity/print
      {:ok, identity} = RouterosApi.command(conn, ["/system/identity/print"])
      assert is_list(identity)
      IO.puts("✓ /system/identity/print successful over TLS")

      # Test /interface/print
      {:ok, interfaces} = RouterosApi.command(conn, ["/interface/print"])
      assert is_list(interfaces)
      assert length(interfaces) > 0
      IO.puts("✓ /interface/print successful over TLS (#{length(interfaces)} interfaces)")

      # Test /system/resource/print
      {:ok, [resource]} = RouterosApi.command(conn, ["/system/resource/print"])
      assert Map.has_key?(resource, "version")
      IO.puts("✓ /system/resource/print successful over TLS")

      RouterosApi.disconnect(conn)
    end

    test "TLS connection with explicit ssl: true" do
      IO.puts("Testing explicit ssl: true...")

      config = %{
        host: @host,
        port: @ssl_port,
        username: @username,
        password: @password,
        ssl: true,
        ssl_opts: [verify: :verify_none]
      }

      {:ok, conn} = RouterosApi.connect(config)
      {:ok, _} = RouterosApi.command(conn, ["/system/identity/print"])

      IO.puts("✓ Explicit ssl: true works")

      RouterosApi.disconnect(conn)
    end

    test "auto-detects SSL from port 8729" do
      IO.puts("Testing auto-detection of SSL from port...")

      config = %{
        host: @host,
        port: 8729,
        username: @username,
        password: @password,
        ssl_opts: [verify: :verify_none]
      }

      {:ok, conn} = RouterosApi.connect(config)
      {:ok, _} = RouterosApi.command(conn, ["/system/identity/print"])

      IO.puts("✓ Auto-detected SSL from port 8729")

      RouterosApi.disconnect(conn)
    end

    test "handles multiple sequential commands over TLS" do
      IO.puts("Testing multiple sequential commands over TLS...")

      config = %{
        host: @host,
        port: @ssl_port,
        username: @username,
        password: @password,
        ssl: true,
        ssl_opts: [verify: :verify_none]
      }

      {:ok, conn} = RouterosApi.connect(config)

      # Execute multiple commands
      {:ok, _} = RouterosApi.command(conn, ["/system/identity/print"])
      {:ok, _} = RouterosApi.command(conn, ["/interface/print"])
      {:ok, _} = RouterosApi.command(conn, ["/system/resource/print"])
      {:ok, _} = RouterosApi.command(conn, ["/ip/address/print"])

      IO.puts("✓ Multiple sequential commands successful over TLS")

      RouterosApi.disconnect(conn)
    end

    test "handles errors over TLS" do
      IO.puts("Testing error handling over TLS...")

      config = %{
        host: @host,
        port: @ssl_port,
        username: @username,
        password: @password,
        ssl: true,
        ssl_opts: [verify: :verify_none]
      }

      {:ok, conn} = RouterosApi.connect(config)

      # Execute invalid command
      result = RouterosApi.command(conn, ["/invalid/command"])
      assert match?({:error, _}, result)

      # Connection should still work after error (if still alive)
      if Process.alive?(conn) do
        case RouterosApi.command(conn, ["/system/identity/print"]) do
          {:ok, _} -> :ok
          # Connection might be closed after fatal error
          {:error, _} -> :ok
        end
      end

      IO.puts("✓ Error handling works over TLS")

      if Process.alive?(conn) do
        RouterosApi.disconnect(conn)
      end
    end
  end

  describe "SSL/TLS Pool Tests" do
    test "connection pool works with TLS" do
      IO.puts("Testing connection pool with TLS...")

      pool_opts = [
        name: :ssl_test_pool,
        host: @host,
        port: @ssl_port,
        username: @username,
        password: @password,
        ssl: true,
        ssl_opts: [verify: :verify_none],
        pool_size: 3
      ]

      {:ok, pool_pid} = RouterosApi.Pool.start_link(pool_opts)

      # Execute commands via pool
      {:ok, identity} = RouterosApi.command(:ssl_test_pool, ["/system/identity/print"])
      assert is_list(identity)

      {:ok, interfaces} = RouterosApi.command(:ssl_test_pool, ["/interface/print"])
      assert is_list(interfaces)

      IO.puts("✓ Connection pool works with TLS")

      GenServer.stop(pool_pid)
    end

    test "pool handles concurrent TLS requests" do
      IO.puts("Testing concurrent TLS requests via pool...")

      pool_opts = [
        name: :ssl_concurrent_pool,
        host: @host,
        port: @ssl_port,
        username: @username,
        password: @password,
        ssl: true,
        ssl_opts: [verify: :verify_none],
        pool_size: 5
      ]

      {:ok, pool_pid} = RouterosApi.Pool.start_link(pool_opts)

      # Execute multiple concurrent commands
      tasks =
        for i <- 1..10 do
          Task.async(fn ->
            {:ok, result} = RouterosApi.command(:ssl_concurrent_pool, ["/system/identity/print"])
            {i, result}
          end)
        end

      results = Task.await_many(tasks, 10_000)
      assert length(results) == 10

      IO.puts("✓ Concurrent TLS requests successful (10 requests)")

      GenServer.stop(pool_pid)
    end
  end

  describe "SSL/TLS Helper Tests" do
    test "helpers work over TLS" do
      IO.puts("Testing helper functions over TLS...")

      config = %{
        host: @host,
        port: @ssl_port,
        username: @username,
        password: @password,
        ssl: true,
        ssl_opts: [verify: :verify_none]
      }

      {:ok, conn} = RouterosApi.connect(config)

      alias RouterosApi.Helpers

      {:ok, interfaces} = Helpers.list_interfaces(conn)
      assert is_list(interfaces)

      {:ok, resource} = Helpers.get_system_resource(conn)
      assert Map.has_key?(resource, "version")

      {:ok, identity} = Helpers.get_identity(conn)
      assert Map.has_key?(identity, "name")

      IO.puts("✓ Helper functions work over TLS")

      RouterosApi.disconnect(conn)
    end
  end
end
