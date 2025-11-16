defmodule RouterosApiTest do
  use ExUnit.Case, async: true
  doctest RouterosApi

  describe "API structure" do
    test "exports connect/1" do
      assert function_exported?(RouterosApi, :connect, 1)
    end

    test "exports connect_plain/1" do
      assert function_exported?(RouterosApi, :connect_plain, 1)
    end

    test "exports connect_tls/1" do
      assert function_exported?(RouterosApi, :connect_tls, 1)
    end

    test "exports disconnect/1" do
      assert function_exported?(RouterosApi, :disconnect, 1)
    end

    test "exports command/2" do
      assert function_exported?(RouterosApi, :command, 2)
    end

    test "exports command!/2" do
      assert function_exported?(RouterosApi, :command!, 2)
    end
  end

  describe "configuration validation" do
    test "connect handles connection failures" do
      # Trap exits so we can catch the GenServer crash
      Process.flag(:trap_exit, true)

      config = %{
        host: "192.0.2.1",  # TEST-NET-1, should timeout
        username: "test",
        password: "test",
        timeout: 100  # Short timeout for test
      }

      # GenServer will exit during init
      result = RouterosApi.connect(config)

      # Should get either {:error, reason} or receive an EXIT message
      case result do
        {:error, _reason} ->
          assert true

        {:ok, pid} ->
          # Wait for EXIT message
          assert_receive {:EXIT, ^pid, _reason}, 200
      end
    end
  end
end
