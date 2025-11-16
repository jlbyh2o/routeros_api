defmodule RouterosApi.PoolTest do
  use ExUnit.Case, async: false

  @moduletag :integration

  @host System.get_env("ROUTER_HOST", "10.242.1.114")
  @username System.get_env("ROUTER_USER", "admin")
  @password System.get_env("ROUTER_PASS", "password")
  @port String.to_integer(System.get_env("ROUTER_PORT", "8728"))

  describe "Connection Pool" do
    test "can start a pool and execute commands" do
      pool_opts = [
        name: :test_pool,
        host: @host,
        port: @port,
        username: @username,
        password: @password,
        pool_size: 3
      ]

      # Start the pool
      {:ok, pool_pid} = RouterosApi.Pool.start_link(pool_opts)
      assert is_pid(pool_pid)

      # Execute a command using the pool
      {:ok, result} = RouterosApi.command(:test_pool, ["/system/identity/print"])
      assert is_list(result)

      # Stop the pool
      GenServer.stop(pool_pid)
    end

    test "pool handles multiple concurrent requests" do
      pool_opts = [
        name: :concurrent_pool,
        host: @host,
        port: @port,
        username: @username,
        password: @password,
        pool_size: 5
      ]

      {:ok, pool_pid} = RouterosApi.Pool.start_link(pool_opts)

      # Execute multiple commands concurrently
      tasks =
        for i <- 1..10 do
          Task.async(fn ->
            {:ok, result} = RouterosApi.command(:concurrent_pool, ["/system/identity/print"])
            {i, result}
          end)
        end

      # Wait for all tasks
      results = Task.await_many(tasks, 10_000)

      # All should succeed
      assert length(results) == 10
      Enum.each(results, fn {_i, result} ->
        assert is_list(result)
      end)

      GenServer.stop(pool_pid)
    end

    test "pool can execute different commands" do
      pool_opts = [
        name: :multi_command_pool,
        host: @host,
        port: @port,
        username: @username,
        password: @password,
        pool_size: 2
      ]

      {:ok, pool_pid} = RouterosApi.Pool.start_link(pool_opts)

      # Execute different commands
      {:ok, identity} = RouterosApi.command(:multi_command_pool, ["/system/identity/print"])
      assert is_list(identity)

      {:ok, interfaces} = RouterosApi.command(:multi_command_pool, ["/interface/print"])
      assert is_list(interfaces)

      {:ok, resource} = RouterosApi.command(:multi_command_pool, ["/system/resource/print"])
      assert is_list(resource)

      GenServer.stop(pool_pid)
    end

    test "pool handles errors gracefully" do
      pool_opts = [
        name: :error_pool,
        host: @host,
        port: @port,
        username: @username,
        password: @password,
        pool_size: 2
      ]

      {:ok, pool_pid} = RouterosApi.Pool.start_link(pool_opts)

      # Execute invalid command
      {:error, error} = RouterosApi.command(:error_pool, ["/invalid/command"])
      assert error.type == :trap

      # Pool should still work after error
      {:ok, result} = RouterosApi.command(:error_pool, ["/system/identity/print"])
      assert is_list(result)

      GenServer.stop(pool_pid)
    end
  end

  describe "Pool in supervision tree" do
    test "pool can be supervised" do
      children = [
        {RouterosApi.Pool,
         [
           name: :supervised_pool,
           host: @host,
           port: @port,
           username: @username,
           password: @password,
           pool_size: 2
         ]}
      ]

      {:ok, supervisor} = Supervisor.start_link(children, strategy: :one_for_one)

      # Use the pool
      {:ok, result} = RouterosApi.command(:supervised_pool, ["/system/identity/print"])
      assert is_list(result)

      # Stop supervisor
      Supervisor.stop(supervisor)
    end
  end
end

