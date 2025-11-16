# Very simple test - just try to connect and see what happens

IO.puts("Testing connection to 10.242.1.114:8728...")

case :gen_tcp.connect('10.242.1.114', 8728, [:binary, active: false], 5000) do
  {:ok, socket} ->
    IO.puts("✓ TCP connection successful!")
    IO.puts("Socket: #{inspect(socket)}")
    
    # Try to read the first byte to see if anything comes back
    IO.puts("\nWaiting for any data from router (2 seconds)...")
    case :gen_tcp.recv(socket, 0, 2000) do
      {:ok, data} ->
        IO.puts("Received data: #{inspect(data)}")
      {:error, :timeout} ->
        IO.puts("No data received (timeout) - this is expected for API protocol")
      {:error, reason} ->
        IO.puts("Error receiving: #{inspect(reason)}")
    end
    
    :gen_tcp.close(socket)
    IO.puts("Connection closed")
    
  {:error, reason} ->
    IO.puts("✗ Connection failed: #{inspect(reason)}")
end

IO.puts("\n" <> String.duplicate("=", 60))
IO.puts("Now testing with our library...")
IO.puts(String.duplicate("=", 60) <> "\n")

# Test with empty password (factory default)
IO.puts("Attempt 1: Empty password")
config1 = %{host: "10.242.1.114", port: 8728, username: "admin", password: ""}
case RouterosApi.connect(config1) do
  {:ok, conn} ->
    IO.puts("✓ Connected with empty password!")
    RouterosApi.disconnect(conn)
  {:error, reason} ->
    IO.puts("✗ Failed with empty password: #{inspect(reason)}")
end

# Test with "password"
IO.puts("\nAttempt 2: Password = 'password'")
config2 = %{host: "10.242.1.114", port: 8728, username: "admin", password: "password"}
case RouterosApi.connect(config2) do
  {:ok, conn} ->
    IO.puts("✓ Connected with password 'password'!")
    
    # Try a command
    IO.puts("\nTrying /system/identity/print...")
    case RouterosApi.command(conn, ["/system/identity/print"]) do
      {:ok, result} ->
        IO.puts("✓ Command successful!")
        IO.inspect(result, label: "Result")
      {:error, reason} ->
        IO.puts("✗ Command failed: #{inspect(reason)}")
    end
    
    RouterosApi.disconnect(conn)
  {:error, reason} ->
    IO.puts("✗ Failed with password 'password': #{inspect(reason)}")
end

