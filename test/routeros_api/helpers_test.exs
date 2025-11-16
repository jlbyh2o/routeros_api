defmodule RouterosApi.HelpersTest do
  use ExUnit.Case, async: false

  @moduletag :integration

  alias RouterosApi.Helpers

  @host System.get_env("ROUTER_HOST", "10.242.1.114")
  @username System.get_env("ROUTER_USER", "admin")
  @password System.get_env("ROUTER_PASS", "password")
  @port String.to_integer(System.get_env("ROUTER_PORT", "8728"))

  setup do
    config = %{
      host: @host,
      port: @port,
      username: @username,
      password: @password
    }

    {:ok, conn} = RouterosApi.connect(config)

    on_exit(fn ->
      if Process.alive?(conn) do
        RouterosApi.disconnect(conn)
      end
    end)

    {:ok, conn: conn}
  end

  describe "Interface Helpers" do
    test "list_interfaces/1 returns all interfaces", %{conn: conn} do
      {:ok, interfaces} = Helpers.list_interfaces(conn)
      assert is_list(interfaces)
      assert length(interfaces) > 0

      # Check structure
      first = List.first(interfaces)
      assert Map.has_key?(first, "name")
      assert Map.has_key?(first, "type")
    end

    test "get_interface/2 returns specific interface", %{conn: conn} do
      {:ok, interface} = Helpers.get_interface(conn, "ether1")
      assert interface["name"] == "ether1"
      assert interface["type"] == "ether"
    end

    test "get_interface/2 returns error for non-existent interface", %{conn: conn} do
      {:error, :not_found} = Helpers.get_interface(conn, "nonexistent")
    end
  end

  describe "IP Address Helpers" do
    test "list_ip_addresses/1 returns all IP addresses", %{conn: conn} do
      {:ok, addresses} = Helpers.list_ip_addresses(conn)
      assert is_list(addresses)
    end
  end

  describe "System Helpers" do
    test "get_system_resource/1 returns system info", %{conn: conn} do
      {:ok, resource} = Helpers.get_system_resource(conn)
      assert Map.has_key?(resource, "version")
      assert Map.has_key?(resource, "board-name")
    end

    test "get_identity/1 returns router identity", %{conn: conn} do
      {:ok, identity} = Helpers.get_identity(conn)
      assert Map.has_key?(identity, "name")
    end

    test "set_identity/2 changes router identity", %{conn: conn} do
      # Get current identity
      {:ok, original} = Helpers.get_identity(conn)
      original_name = original["name"]

      # Set new identity
      new_name = "TestRouter-#{:rand.uniform(1000)}"
      {:ok, _} = Helpers.set_identity(conn, new_name)

      # Verify it changed
      {:ok, updated} = Helpers.get_identity(conn)
      assert updated["name"] == new_name

      # Restore original
      {:ok, _} = Helpers.set_identity(conn, original_name)
    end
  end

  describe "Firewall Helpers" do
    test "list_firewall_rules/1 returns firewall rules", %{conn: conn} do
      {:ok, rules} = Helpers.list_firewall_rules(conn)
      assert is_list(rules)
    end
  end

  describe "DHCP Helpers" do
    test "list_dhcp_leases/1 returns DHCP leases", %{conn: conn} do
      {:ok, leases} = Helpers.list_dhcp_leases(conn)
      assert is_list(leases)
    end
  end

  describe "Pool Support" do
    test "helpers work with connection pools" do
      pool_opts = [
        name: :helper_test_pool,
        host: @host,
        port: @port,
        username: @username,
        password: @password,
        pool_size: 2
      ]

      {:ok, pool_pid} = RouterosApi.Pool.start_link(pool_opts)

      # Test helpers with pool
      {:ok, interfaces} = Helpers.list_interfaces(:helper_test_pool)
      assert is_list(interfaces)
      assert length(interfaces) > 0

      {:ok, identity} = Helpers.get_identity(:helper_test_pool)
      assert Map.has_key?(identity, "name")

      {:ok, resource} = Helpers.get_system_resource(:helper_test_pool)
      assert Map.has_key?(resource, "version")

      GenServer.stop(pool_pid)
    end
  end
end

