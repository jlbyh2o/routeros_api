defmodule RouterosApi.ResponseTest do
  use ExUnit.Case, async: true
  alias RouterosApi.Response

  doctest RouterosApi.Response

  describe "parse/1" do
    test "parses successful response with data" do
      sentences = [
        ["=name=ether1", "=type=ether", "=disabled=false"],
        ["=name=ether2", "=type=ether", "=disabled=true"],
        ["!done"]
      ]

      assert {:ok, data} = Response.parse(sentences)
      assert length(data) == 2

      assert %{"name" => "ether1", "type" => "ether", "disabled" => false} in data
      assert %{"name" => "ether2", "type" => "ether", "disabled" => true} in data
    end

    test "parses empty successful response" do
      sentences = [["!done"]]

      assert {:ok, []} = Response.parse(sentences)
    end

    test "parses trap error response" do
      sentences = [
        ["!trap", "=message=no such item", "=category=2"]
      ]

      assert {:error, error} = Response.parse(sentences)
      assert error.type == :trap
      assert error.message == "no such item"
    end

    test "parses fatal error response" do
      sentences = [
        ["!fatal", "=message=connection lost"]
      ]

      assert {:error, error} = Response.parse(sentences)
      assert error.type == :fatal
      assert error.message == "connection lost"
    end

    test "handles response without explicit status" do
      sentences = [
        ["=name=value1"],
        ["=name=value2"]
      ]

      assert {:ok, data} = Response.parse(sentences)
      assert length(data) == 2
    end
  end

  describe "parse_sentence/1" do
    test "parses sentence with multiple attributes" do
      sentence = ["=name=ether1", "=type=ether", "=mtu=1500"]

      result = Response.parse_sentence(sentence)

      assert result == %{
               "name" => "ether1",
               "type" => "ether",
               "mtu" => "1500"
             }
    end

    test "filters out status words" do
      sentence = ["!done", "=name=value"]

      result = Response.parse_sentence(sentence)

      assert result == %{"name" => "value"}
    end

    test "handles empty sentence" do
      sentence = []

      result = Response.parse_sentence(sentence)

      assert result == %{}
    end

    test "handles sentence with only status words" do
      sentence = ["!done"]

      result = Response.parse_sentence(sentence)

      assert result == %{}
    end
  end

  describe "parse_attribute/1" do
    test "parses simple attribute" do
      assert {"name", "ether1"} = Response.parse_attribute("=name=ether1")
    end

    test "parses attribute with empty value" do
      assert {"key", ""} = Response.parse_attribute("=key=")
    end

    test "parses attribute with equals in value" do
      assert {"formula", "a=b"} = Response.parse_attribute("=formula=a=b")
    end

    test "returns nil for non-attribute strings" do
      assert nil == Response.parse_attribute("!done")
      assert nil == Response.parse_attribute("random")
    end
  end

  describe "coerce_value/1" do
    test "coerces boolean strings" do
      assert Response.coerce_value("true") == true
      assert Response.coerce_value("false") == false
      assert Response.coerce_value("yes") == true
      assert Response.coerce_value("no") == false
    end

    test "keeps other strings as-is" do
      assert Response.coerce_value("hello") == "hello"
      assert Response.coerce_value("123") == "123"
      assert Response.coerce_value("") == ""
    end
  end

  describe "is_status_word?/1" do
    test "identifies status words" do
      assert Response.is_status_word?("!done") == true
      assert Response.is_status_word?("!trap") == true
      assert Response.is_status_word?("!fatal") == true
      assert Response.is_status_word?("!re") == true
    end

    test "rejects non-status words" do
      assert Response.is_status_word?("=name=value") == false
      assert Response.is_status_word?("hello") == false
      assert Response.is_status_word?("") == false
    end
  end

  describe "complex scenarios" do
    test "parses interface print response" do
      sentences = [
        ["=.id=*1", "=name=ether1", "=type=ether", "=disabled=false", "=running=true"],
        ["=.id=*2", "=name=ether2", "=type=ether", "=disabled=false", "=running=true"],
        ["=.id=*3", "=name=bridge1", "=type=bridge", "=disabled=false", "=running=true"],
        ["!done"]
      ]

      assert {:ok, interfaces} = Response.parse(sentences)
      assert length(interfaces) == 3

      ether1 = Enum.find(interfaces, &(&1["name"] == "ether1"))
      assert ether1[".id"] == "*1"
      assert ether1["type"] == "ether"
      assert ether1["disabled"] == false
      assert ether1["running"] == true
    end

    test "parses error with category" do
      sentences = [
        ["!trap", "=category=2", "=message=failure: already have such address"]
      ]

      assert {:error, error} = Response.parse(sentences)
      assert error.type == :trap
      assert error.message == "failure: already have such address"
    end
  end
end
