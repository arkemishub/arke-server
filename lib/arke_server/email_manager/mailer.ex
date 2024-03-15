defmodule ArkeServer.Mailer do

  defmacro __using__(_)do
    quote do
      use Swoosh.Mailer, otp_app: :arke_server
      import Swoosh.Email

      def signin(conn,member,opts), do: {:ok,opts}
      def signup(conn,params,opts), do: {:ok,opts}
      def reset_password(conn,member,opts), do: {:ok,opts}

      def send_email(opts) when is_list(opts) do
        case Keyword.keyword?(opts) do
          true -> send_email(Enum.into(opts, %{}))
          false -> {:error, "email options must be a valid keyword list or map"}
        end
      end

      def send_email(opts) when is_map(opts) do
        email = get_email_struct(opts)
        deliver(email)
      end

      def send_email(opts), do: {:error, "email options must be a valid keyword list or map"}

      defp get_email_struct(opts) do
        sender = get_sender(opts)
        receiver = Map.fetch!(opts, :to)
        subject = Map.get(opts, :subject, "")
        text = Map.get(opts, :text, "")
        new()
        |> from(sender)
        |> to(receiver)
        |> subject(subject)
        |> text_body(text)
        |> parse_option(Map.to_list(opts))
      end

      defp get_sender(opts) do
        case Map.get(opts, :from, nil) do
          nil ->
            case Application.get_env(:arke_server,__MODULE__)[:default_sender] do
              nil -> raise "missing `from:` value and `default_sender` is not set"
              default_sender -> default_sender
            end

          receiver ->
            receiver
        end
      end

      defp parse_option(email, [{k, v} | t])
           when  not is_nil(v) do
        parse_option(put_provider_option(email, k, v), t)
      end

      # See https://hexdocs.pm/swoosh/Swoosh.Attachment.html
      defp parse_option(email, [{:attachments, v} | t]) when not is_nil(v) do
        attachment = Swoosh.Attachment.new(v)
        parse_option(attachment(email, attachment), t)
      end

      defp parse_option(email, [h | t]), do: parse_option(email, t)

      defp parse_option(email, nil), do: email
      defp parse_option(email, []), do: email

      defoverridable signin: 3,signup: 3, reset_password: 3,send_email: 1
    end

  end
end
