defmodule Cabbage.Messages.Attach do
  @moduledoc """
  A per-run *attachment collector* for the message-emitting runner (`Cabbage.Messages`).

  Cucumber lets a step or hook body attach arbitrary data while it runs (`this.attach`,
  `this.log`, `this.link` in cucumber-js). The runner needs to turn those into `attachment`
  envelopes emitted **between** the attaching step's `testStepStarted` and
  `testStepFinished` (or, for a global hook, between its `testRunHookStarted` and
  `testRunHookFinished`).

  Because cabbage step/hook bodies are plain functions receiving a `world` and returning an
  outcome, we cannot collect attachments through the return value alone: a body may attach
  data *and then raise* (the CCK `attachments` "before a failure" scenario and the
  `markdown` "fail" scenario both do this), and the return value is lost on a raise.

  So the collector is a tiny `Agent` owned by the single run process. `Cabbage.Messages`
  starts one per run, threads its pid into the `world` under the reserved key
  `:__attach__`, and `drain/1`s it after each step/hook to read (and clear) whatever that
  body attached — surviving a raise, since the state lives outside the body's return value.

  ## Body shapes and content encoding

    * a binary string is attached verbatim with `content_encoding: :identity`;
    * `{:bytes, binary}` (and any non-string body) is Base64-encoded with
      `content_encoding: :base64`, mirroring cucumber's rule that byte payloads are always
      base64 regardless of media type.

  Each drained attachment is a plain map (`:body`, `:content_encoding`, `:media_type`, and
  optionally `:file_name`); the runner shapes it into the cucumber-messages `attachment`
  envelope (uppercasing the encoding, adding the test-step/test-case ids and a timestamp).
  """

  use Agent

  import Cabbage.Messages.MapHelpers, only: [put_unless_nil: 3]

  @type content_encoding :: :identity | :base64

  @type t :: %{
          required(:body) => String.t(),
          required(:content_encoding) => content_encoding(),
          required(:media_type) => String.t(),
          optional(:file_name) => String.t()
        }

  @log_media_type "text/x.cucumber.log+plain"
  @link_media_type "text/uri-list"

  @doc "Start a fresh collector. Returns `{:ok, pid}`."
  @spec start_link() :: {:ok, pid()}
  def start_link, do: Agent.start_link(fn -> [] end)

  @doc "Stop a collector."
  @spec stop(pid()) :: :ok
  def stop(pid), do: Agent.stop(pid)

  @doc """
  Attach `body` with a media type from a step/hook body.

  `body` is either a binary string (attached as-is, `IDENTITY`) or `{:bytes, binary}`
  (Base64-encoded, `BASE64`). `opts` is either a media-type string or a keyword list with
  `:media_type` (required) and optional `:file_name`.

  Reads the collector pid from `world[:__attach__]`; when the world carries no collector
  (e.g. a body run outside the runner) this is a no-op so step code is portable. Returns
  `:ok` so a step body can `... |> Attach.attach(...)` as its passing return value.
  """
  @spec attach(map(), String.t() | {:bytes, binary()}, String.t() | keyword()) :: :ok
  def attach(world, body, opts) do
    {media_type, file_name} = normalize_opts(opts)
    {encoded, encoding} = encode(body)

    record =
      %{body: encoded, content_encoding: encoding, media_type: media_type}
      |> put_unless_nil(:file_name, file_name)

    push(world, record)
  end

  @doc "Attach `text` as a log line (`text/x.cucumber.log+plain`, IDENTITY)."
  @spec log(map(), String.t()) :: :ok
  def log(world, text), do: attach(world, text, @log_media_type)

  @doc "Attach `uri` as a link (`text/uri-list`, IDENTITY)."
  @spec link(map(), String.t()) :: :ok
  def link(world, uri), do: attach(world, uri, @link_media_type)

  @doc "Return the attachments pushed so far (in push order) and clear the collector."
  @spec drain(pid()) :: [t()]
  def drain(pid) do
    Agent.get_and_update(pid, fn acc -> {Enum.reverse(acc), []} end)
  end

  # ---- internals -------------------------------------------------------------

  defp push(world, record) do
    case Map.get(world, :__attach__) do
      pid when is_pid(pid) -> Agent.update(pid, fn acc -> [record | acc] end)
      _ -> :ok
    end

    :ok
  end

  defp normalize_opts(media_type) when is_binary(media_type), do: {media_type, nil}

  defp normalize_opts(opts) when is_list(opts) do
    {Keyword.fetch!(opts, :media_type), Keyword.get(opts, :file_name)}
  end

  # A binary string is attached verbatim (IDENTITY); anything else is treated as raw bytes
  # and Base64-encoded (BASE64), matching cucumber's "byte payloads are always base64" rule.
  defp encode(body) when is_binary(body), do: {body, :identity}
  defp encode({:bytes, bytes}) when is_binary(bytes), do: {Base.encode64(bytes), :base64}
end
