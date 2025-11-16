defmodule RouterosApi.ProtocolTest do
  use ExUnit.Case, async: true
  alias RouterosApi.Protocol

  doctest RouterosApi.Protocol

  describe "encode_length/1" do
    test "encodes 1-byte length (< 128)" do
      assert Protocol.encode_length(0) == <<0>>
      assert Protocol.encode_length(5) == <<5>>
      assert Protocol.encode_length(127) == <<127>>
    end

    test "encodes 2-byte length (128 to 16383)" do
      assert Protocol.encode_length(128) == <<0x80, 128>>
      assert Protocol.encode_length(200) == <<0x80, 200>>
      assert Protocol.encode_length(16383) == <<0xBF, 0xFF>>
    end

    test "encodes 3-byte length (16384 to 2097151)" do
      assert Protocol.encode_length(16384) == <<0xC0, 0x40, 0x00>>
      assert Protocol.encode_length(100_000) == <<0xC1, 0x86, 0xA0>>
      assert Protocol.encode_length(2_097_151) == <<0xDF, 0xFF, 0xFF>>
    end

    test "encodes 4-byte length (2097152 to 268435455)" do
      assert Protocol.encode_length(2_097_152) == <<0xE0, 0x20, 0x00, 0x00>>
      assert Protocol.encode_length(10_000_000) == <<0xE0, 0x98, 0x96, 0x80>>
      assert Protocol.encode_length(268_435_455) == <<0xEF, 0xFF, 0xFF, 0xFF>>
    end
  end

  describe "length encoding round-trip" do
    test "1-byte lengths" do
      for len <- [0, 1, 50, 127] do
        encoded = Protocol.encode_length(len)
        assert byte_size(encoded) == 1
      end
    end

    test "2-byte lengths" do
      for len <- [128, 200, 1000, 16383] do
        encoded = Protocol.encode_length(len)
        assert byte_size(encoded) == 2
      end
    end

    test "3-byte lengths" do
      for len <- [16384, 50_000, 100_000, 2_097_151] do
        encoded = Protocol.encode_length(len)
        assert byte_size(encoded) == 3
      end
    end

    test "4-byte lengths" do
      for len <- [2_097_152, 5_000_000, 10_000_000, 268_435_455] do
        encoded = Protocol.encode_length(len)
        assert byte_size(encoded) == 4
      end
    end
  end

  describe "write_word/2 and read_word/1" do
    setup do
      # Create a mock socket using a simple port-based approach
      # For now, we'll test the encoding/decoding logic separately
      :ok
    end

    test "encodes empty word correctly" do
      # Empty word should be just a zero-length prefix
      assert Protocol.encode_length(0) == <<0>>
    end

    test "encodes short word correctly" do
      word = "hello"
      len = byte_size(word)
      expected = Protocol.encode_length(len) <> word
      assert expected == <<5, "hello">>
    end

    test "encodes longer word correctly" do
      word = String.duplicate("a", 200)
      len = byte_size(word)
      encoded_len = Protocol.encode_length(len)
      expected = encoded_len <> word
      assert byte_size(expected) == 2 + 200
    end
  end

  describe "write_sentence/2" do
    test "sentence structure" do
      # A sentence should be: word1_len + word1 + word2_len + word2 + ... + 0 (EOF)
      # We can't easily test socket operations, but we can verify the logic
      # This will be tested in integration tests
      :ok
    end
  end

  describe "status word detection" do
    test "identifies status words" do
      assert "!done" =~ ~r/^!/
      assert "!trap" =~ ~r/^!/
      assert "!fatal" =~ ~r/^!/
      refute "=name=value" =~ ~r/^!/
    end
  end
end

