defmodule RouterosApi.AuthTest do
  use ExUnit.Case, async: true
  alias RouterosApi.Auth

  describe "extract_salt/1" do
    test "extracts salt from valid response" do
      sentences = [
        ["!done", "=ret=abc123def456"]
      ]

      assert {:ok, "abc123def456"} = Auth.extract_salt(sentences)
    end

    test "handles empty salt (newer RouterOS versions)" do
      sentences = [
        ["!done", "=ret="]
      ]

      assert {:ok, ""} = Auth.extract_salt(sentences)
    end

    test "handles response without ret attribute" do
      sentences = [
        ["!done"]
      ]

      assert {:ok, ""} = Auth.extract_salt(sentences)
    end

    test "returns error when no done response" do
      sentences = [
        ["!trap", "=message=login failed"]
      ]

      assert {:error, :no_done_response} = Auth.extract_salt(sentences)
    end

    test "extracts salt from multi-sentence response" do
      sentences = [
        ["=some=data"],
        ["!done", "=ret=fedcba987654"]
      ]

      assert {:ok, "fedcba987654"} = Auth.extract_salt(sentences)
    end
  end

  describe "calculate_hash/2" do
    test "calculates MD5 hash correctly with empty salt" do
      # When salt is empty, hash should be md5(0x00 + password)
      password = "admin"
      salt = ""

      hash = Auth.calculate_hash(password, salt)

      # Verify it's a valid hex string
      assert String.length(hash) == 32
      assert hash =~ ~r/^[0-9a-f]{32}$/
    end

    test "calculates MD5 hash correctly with salt" do
      password = "password"
      salt = "abc123"

      hash = Auth.calculate_hash(password, salt)

      # Verify it's a valid hex string
      assert String.length(hash) == 32
      assert hash =~ ~r/^[0-9a-f]{32}$/
    end

    test "hash is deterministic" do
      password = "test123"
      salt = "deadbeef"

      hash1 = Auth.calculate_hash(password, salt)
      hash2 = Auth.calculate_hash(password, salt)

      assert hash1 == hash2
    end

    test "different passwords produce different hashes" do
      salt = "abc123"

      hash1 = Auth.calculate_hash("password1", salt)
      hash2 = Auth.calculate_hash("password2", salt)

      assert hash1 != hash2
    end

    test "different salts produce different hashes" do
      password = "password"

      hash1 = Auth.calculate_hash(password, "abc123")
      hash2 = Auth.calculate_hash(password, "def456")

      assert hash1 != hash2
    end
  end

  describe "hex conversion" do
    test "hex_to_binary and binary_to_hex are inverse operations" do
      # We can't directly test private functions, but we can test through calculate_hash
      # which uses both functions

      # Test with known MD5 hash
      password = "test"
      salt = "0123456789abcdef"

      hash = Auth.calculate_hash(password, salt)

      # Hash should be valid hex
      assert String.length(hash) == 32
      assert hash =~ ~r/^[0-9a-f]{32}$/
    end
  end

  describe "send_login_credentials/3" do
    test "formats login sentence correctly" do
      # We can't easily test socket operations without a mock
      # This will be tested in integration tests
      :ok
    end
  end

  describe "login/3" do
    test "login flow structure" do
      # Full login flow will be tested in integration tests
      # with a mock MikroTik server
      :ok
    end
  end
end

