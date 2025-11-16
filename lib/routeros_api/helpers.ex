defmodule RouterosApi.Helpers do
  @moduledoc """
  Helper functions for common RouterOS operations.

  Provides convenient wrappers around common RouterOS commands.
  """

  alias RouterosApi

  @doc """
  Lists all interfaces on the router.

  ## Examples

      {:ok, interfaces} = RouterosApi.Helpers.list_interfaces(conn)
      # => [%{"name" => "ether1", "type" => "ether", ...}, ...]
  """
  @spec list_interfaces(RouterosApi.connection()) :: {:ok, [map()]} | {:error, term()}
  def list_interfaces(conn) do
    RouterosApi.command(conn, ["/interface/print"])
  end

  @doc """
  Gets a specific interface by name.

  ## Examples

      {:ok, interface} = RouterosApi.Helpers.get_interface(conn, "ether1")
      # => %{"name" => "ether1", "type" => "ether", ...}
  """
  @spec get_interface(RouterosApi.connection(), String.t()) ::
          {:ok, map()} | {:error, term()}
  def get_interface(conn, name) do
    case RouterosApi.command(conn, ["/interface/print", "?name=#{name}"]) do
      {:ok, [interface]} -> {:ok, interface}
      {:ok, []} -> {:error, :not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Lists all IP addresses on the router.

  ## Examples

      {:ok, addresses} = RouterosApi.Helpers.list_ip_addresses(conn)
      # => [%{"address" => "192.168.88.1/24", "interface" => "bridge", ...}, ...]
  """
  @spec list_ip_addresses(RouterosApi.connection()) :: {:ok, [map()]} | {:error, term()}
  def list_ip_addresses(conn) do
    RouterosApi.command(conn, ["/ip/address/print"])
  end

  @doc """
  Adds an IP address to an interface.

  ## Examples

      {:ok, _} = RouterosApi.Helpers.add_ip_address(conn, "192.168.1.1/24", "ether1")
  """
  @spec add_ip_address(RouterosApi.connection(), String.t(), String.t()) ::
          {:ok, [map()]} | {:error, term()}
  def add_ip_address(conn, address, interface) do
    RouterosApi.command(conn, [
      "/ip/address/add",
      "=address=#{address}",
      "=interface=#{interface}"
    ])
  end

  @doc """
  Removes an IP address by ID.

  ## Examples

      {:ok, _} = RouterosApi.Helpers.remove_ip_address(conn, "*1")
  """
  @spec remove_ip_address(RouterosApi.connection(), String.t()) ::
          {:ok, [map()]} | {:error, term()}
  def remove_ip_address(conn, id) do
    RouterosApi.command(conn, ["/ip/address/remove", "=.id=#{id}"])
  end

  @doc """
  Gets system resource information.

  ## Examples

      {:ok, resource} = RouterosApi.Helpers.get_system_resource(conn)
      # => %{"version" => "7.12.1", "uptime" => "1d2h3m4s", ...}
  """
  @spec get_system_resource(RouterosApi.connection()) :: {:ok, map()} | {:error, term()}
  def get_system_resource(conn) do
    case RouterosApi.command(conn, ["/system/resource/print"]) do
      {:ok, [resource]} -> {:ok, resource}
      {:ok, []} -> {:error, :not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Gets the router identity.

  ## Examples

      {:ok, identity} = RouterosApi.Helpers.get_identity(conn)
      # => %{"name" => "MikroTik"}
  """
  @spec get_identity(RouterosApi.connection()) :: {:ok, map()} | {:error, term()}
  def get_identity(conn) do
    case RouterosApi.command(conn, ["/system/identity/print"]) do
      {:ok, [identity]} -> {:ok, identity}
      {:ok, []} -> {:error, :not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Sets the router identity.

  ## Examples

      {:ok, _} = RouterosApi.Helpers.set_identity(conn, "MyRouter")
  """
  @spec set_identity(RouterosApi.connection(), String.t()) :: {:ok, [map()]} | {:error, term()}
  def set_identity(conn, name) do
    RouterosApi.command(conn, ["/system/identity/set", "=name=#{name}"])
  end

  @doc """
  Lists all firewall filter rules.

  ## Examples

      {:ok, rules} = RouterosApi.Helpers.list_firewall_rules(conn)
  """
  @spec list_firewall_rules(RouterosApi.connection()) :: {:ok, [map()]} | {:error, term()}
  def list_firewall_rules(conn) do
    RouterosApi.command(conn, ["/ip/firewall/filter/print"])
  end

  @doc """
  Lists all DHCP leases.

  ## Examples

      {:ok, leases} = RouterosApi.Helpers.list_dhcp_leases(conn)
  """
  @spec list_dhcp_leases(RouterosApi.connection()) :: {:ok, [map()]} | {:error, term()}
  def list_dhcp_leases(conn) do
    RouterosApi.command(conn, ["/ip/dhcp-server/lease/print"])
  end

  @doc """
  Reboots the router.

  ## Examples

      {:ok, _} = RouterosApi.Helpers.reboot(conn)
  """
  @spec reboot(RouterosApi.connection()) :: {:ok, [map()]} | {:error, term()}
  def reboot(conn) do
    RouterosApi.command(conn, ["/system/reboot"])
  end
end

