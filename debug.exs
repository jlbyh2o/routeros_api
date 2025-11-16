# Debug script - test raw protocol

alias RouterosApi.Protocol

config = %{
  host: "10.242.1.114",
  port: 8728,
  username: "admin",
  password: "password"
}

IO.puts("Testing hash calculation...")
test_salt = "abc123"
test_pass = "password"
hash = RouterosApi.Auth.calculate_hash(test_pass, test_salt)
IO.puts("Hash of '#{test_pass}' with salt '#{test_salt}': #{hash}")

# Manual calculation to verify
salt_bin = Base.decode16!(String.upcase(test_salt))
data = <<0>> <> test_pass <> salt_bin
manual_hash = :crypto.hash(:md5, data) |> Base.encode16(case: :lower)
IO.puts("Manual hash: #{manual_hash}")
IO.puts("Match: #{hash == manual_hash}\n")

IO.puts("Connecting via raw TCP...")
{:ok, socket} = :gen_tcp.connect(
  String.to_charlist(config.host),
  config.port,
  [:binary, active: false],
  5000
)

IO.puts("Connected! Socket: #{inspect(socket)}")

# Login - step by step
IO.puts("\n=== Step 1: Send /login ===")
:ok = Protocol.write_sentence(socket, ["/login"])
{:ok, sentences} = Protocol.read_block(socket)
IO.puts("Response to /login:")
IO.inspect(sentences, pretty: true)

salt = RouterosApi.Auth.extract_salt(sentences)
IO.puts("Extracted salt: #{inspect(salt)}")

{:ok, salt_value} = salt
hash = RouterosApi.Auth.calculate_hash(config.password, salt_value)
IO.puts("Calculated hash: #{hash}")

IO.puts("\n=== Step 2: Send /login with credentials ===")
login_sentence = [
  "/login",
  "=name=#{config.username}",
  "=response=00#{hash}"
]
IO.puts("Sending login sentence:")
IO.inspect(login_sentence, pretty: true)

:ok = Protocol.write_sentence(socket, login_sentence)
{:ok, login_response} = Protocol.read_block(socket)
IO.puts("Login response:")
IO.inspect(login_response, pretty: true)

# Test command
IO.puts("\n=== Sending /system/identity/print ===")
:ok = Protocol.write_sentence(socket, ["/system/identity/print"])
IO.puts("Command sent, reading response...")

{:ok, sentences} = Protocol.read_block(socket)
IO.puts("Raw sentences received:")
IO.inspect(sentences, pretty: true, limit: :infinity)

IO.puts("\n=== Parsing response ===")
result = RouterosApi.Response.parse(sentences)
IO.inspect(result, pretty: true)

# Test another command
IO.puts("\n=== Sending /interface/print ===")
:ok = Protocol.write_sentence(socket, ["/interface/print"])
IO.puts("Command sent, reading response...")

{:ok, sentences2} = Protocol.read_block(socket)
IO.puts("Raw sentences received:")
IO.inspect(sentences2, pretty: true, limit: :infinity)

IO.puts("\n=== Parsing response ===")
result2 = RouterosApi.Response.parse(sentences2)
IO.inspect(result2, pretty: true)

IO.puts("\nClosing socket...")
:gen_tcp.close(socket)
IO.puts("Done!")

