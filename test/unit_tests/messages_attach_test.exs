defmodule Cabbage.MessagesAttachTest do
  @moduledoc """
  Unit tests for the attach collector (`Cabbage.Messages.Attach`) and the `Attachment`
  envelopes the message-emitting runner emits during a step/hook.

  Two layers are pinned here:

    * the collector itself — a per-run process that step/hook bodies push attachments
      onto via the reserved `:__attach__` world key, and the runner drains in order. It
      must survive a raise in the step body (the body may attach *then* fail);
    * the end-to-end runner behaviour — an attaching step emits an `attachment` envelope
      *between* its `testStepStarted` and `testStepFinished`, with the right
      `contentEncoding`/`mediaType`/`body`.
  """
  use ExUnit.Case, async: true

  alias Cabbage.Messages
  alias Cabbage.Messages.{Attach, StepRegistry}

  describe "Attach collector" do
    test "collects text attachments as IDENTITY in order" do
      {:ok, pid} = Attach.start_link()
      world = %{__attach__: pid}

      Attach.attach(world, "hello", "text/plain")
      Attach.log(world, "a log line")
      Attach.link(world, "https://cucumber.io")

      assert Attach.drain(pid) == [
               %{body: "hello", content_encoding: :identity, media_type: "text/plain"},
               %{
                 body: "a log line",
                 content_encoding: :identity,
                 media_type: "text/x.cucumber.log+plain"
               },
               %{
                 body: "https://cucumber.io",
                 content_encoding: :identity,
                 media_type: "text/uri-list"
               }
             ]
    end

    test "base64-encodes binary bodies and keeps the raw bytes' encoding flag" do
      {:ok, pid} = Attach.start_link()
      world = %{__attach__: pid}

      bytes = :erlang.list_to_binary(Enum.to_list(0..9))
      Attach.attach(world, {:bytes, bytes}, "text/plain")

      assert [%{body: body, content_encoding: :base64, media_type: "text/plain"}] =
               Attach.drain(pid)

      assert body == "AAECAwQFBgcICQ=="
    end

    test "carries fileName when given" do
      {:ok, pid} = Attach.start_link()
      world = %{__attach__: pid}

      Attach.attach(world, {:bytes, <<1, 2, 3>>}, media_type: "application/pdf", file_name: "renamed.pdf")

      assert [%{file_name: "renamed.pdf", media_type: "application/pdf", content_encoding: :base64}] =
               Attach.drain(pid)
    end

    test "drain clears the collector" do
      {:ok, pid} = Attach.start_link()
      world = %{__attach__: pid}
      Attach.log(world, "x")
      assert [_] = Attach.drain(pid)
      assert Attach.drain(pid) == []
    end

    test "attach is a no-op (does not raise) when the world has no collector" do
      assert Attach.log(%{}, "no collector here") == :ok
      assert Attach.attach(%{}, "x", "text/plain") == :ok
    end
  end

  describe "runner emits attachment envelopes" do
    defp attachments(envelopes) do
      Enum.filter(envelopes, &Map.has_key?(&1, "attachment"))
    end

    defp types(envelopes), do: Enum.map(envelopes, fn e -> e |> Map.keys() |> hd() end)

    test "a logging step emits an attachment between started and finished" do
      registry =
        StepRegistry.new()
        |> StepRegistry.add("a step", fn _args, _arg, world -> Attach.log(world, "hi") end)

      feature = """
      Feature: F
        Scenario: S
          Given a step
      """

      envelopes = Messages.run(feature, registry)

      seq =
        envelopes
        |> Enum.filter(fn e ->
          k = e |> Map.keys() |> hd()
          k in ["testStepStarted", "attachment", "testStepFinished"]
        end)
        |> types()

      assert seq == ["testStepStarted", "attachment", "testStepFinished"]

      assert [att] = attachments(envelopes)

      assert att["attachment"]["body"] == "hi"
      assert att["attachment"]["contentEncoding"] == "IDENTITY"
      assert att["attachment"]["mediaType"] == "text/x.cucumber.log+plain"
      assert Map.has_key?(att["attachment"], "timestamp")
    end

    test "an attachment is emitted even when the step then fails" do
      registry =
        StepRegistry.new()
        |> StepRegistry.add("a step", fn _args, _arg, world ->
          Attach.attach(world, "before fail", "application/octet-stream")
          raise "whoops"
        end)

      feature = """
      Feature: F
        Scenario: S
          Given a step
      """

      envelopes = Messages.run(feature, registry)

      assert [att] = attachments(envelopes)
      assert att["attachment"]["body"] == "before fail"

      finished = Enum.find(envelopes, &Map.has_key?(&1, "testStepFinished"))
      assert get_in(finished, ["testStepFinished", "testStepResult", "status"]) == "FAILED"
    end

    test "a byte attachment is base64-encoded in the envelope" do
      registry =
        StepRegistry.new()
        |> StepRegistry.add("a step", fn _args, _arg, world ->
          Attach.attach(world, {:bytes, <<0, 1, 2>>}, "image/png")
        end)

      feature = """
      Feature: F
        Scenario: S
          Given a step
      """

      assert [att] = attachments(Messages.run(feature, registry))
      assert att["attachment"]["contentEncoding"] == "BASE64"
      assert att["attachment"]["body"] == Base.encode64(<<0, 1, 2>>)
    end
  end
end
