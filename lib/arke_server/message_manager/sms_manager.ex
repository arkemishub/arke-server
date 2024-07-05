defmodule ArkeServer.SMSManager do
#  use ArkeServer.Mailer

  require Logger
  alias ExTwilio.Message

  def signin(_conn,member,opts) do
    mode = Keyword.get(opts,:mode)
    handle_signin(member, mode, opts)
  end

  defp handle_signin(member, "otp_sms", opts) do
    code = Keyword.get(opts,:code)
    send_sms(member.data.phone, member.data.email, "signin", code) # todo: implementare il recupero del messaggio da db
  end
  defp handle_signin(member, _mode, opts) do
    code = Keyword.get(opts,:code)
    full_name = "#{member.data.first_name} #{member.data.last_name}"
    email = member.data.email
    send_email(
      to: {full_name, email},
      template_uuid: "cd331f05-6fb7-460d-9639-d6f14d4ce02f",
      template_variables: %{name: full_name, otp: code, expire: "5 minuti"}
    )
  end

  def signup(_conn,%{
    "otp" => otp,
    "arke_system_user" => %{"username" => username},
    "email" => email,
    "first_name" => first_name,
    "last_name" => last_name,
  } = params,opts) do
    mode = Keyword.get(opts,:mode)
    handle_signup(params, mode, opts)
  end
  def signup(_conn,_params,_opts), do: {:ok,nil}

  defp handle_signup(%{"phone" => phone, "email" => email}, "otp_sms", opts) do
    code = Keyword.get(opts, :code)
    send_sms(phone, email, "signup", code) # todo: implementare il recupero del messaggio da db
  end
  defp handle_signup(%{
    "email" => email,
    "first_name" => first_name,
    "last_name" => last_name
  }, _mode, opts) do
    code = Keyword.get(opts, :code)
    full_name = "#{first_name} #{last_name}"
    send_email(
      to: {full_name, email},
      template_uuid: "2bac0781-93a9-42f7-8c28-536af16e2e71",
      template_variables: %{name: full_name, otp: code, expire: "5 minuti"}
    )
  end

  def reset_password(_conn,member,opts)do
    mode = Keyword.get(opts,:mode)
    handle_reset_password(member, mode, opts)
  end

  defp handle_reset_password(member, "otp_sms", opts) do
    code = Keyword.get(opts, :code)
    send_sms(member.data.phone, member.data.email, "reset", code) # todo: implementare il recupero del messaggio da db
  end
  defp handle_reset_password(member, _mode, opts) do
    full_name = "#{member.data.first_name} #{member.data.last_name}"
    code = Keyword.get(opts,:code)
    send_email(
      to: {full_name, member.data.email},
      template_uuid: "f8b2c3e4-7b3e-4ab3-b626-8ddd11cb8a6c",
      template_variables: %{
        name: full_name,
        otp: code,
        expire: "5 minuti",
        user_email: member.data.email
      }
    )
  end

  defp send_sms(phone_number, email, template, code) do
    sender = System.get_env("SMS_SENDER_NAME", "default")
    response = Message.create(
      to: phone_number,
      from: sender,
      body: get_template(template, code)
    )
    case response do
      {:ok, _} -> response
      {:error, %{"message" => message, "code" => code}, _http_code} ->
        Logger.warn("Error sending message to {phone: #{phone_number}, email: #{email}}\n Twilio error: #{code} - #{message}")
        response
    end
  end

  defp get_template("signin", code) do
    """
    Ecco il tuo codice OTP per accedere a Daikin ti premia: #{code}
    Il codice è valido per 5 minuti.
    """
  end
  defp get_template("signup", code) do
    """
    Grazie per esserti registrato/a su Daikin ti premia!
    Per completare la registrazione, inserisci il seguente codice OTP: #{code}
    Il codice è valido per 5 minuti.
    """
  end
  defp get_template("reset", code) do
    """
    Abbiamo ricevuto una richiesta di recupero password per il tuo account su Daikin ti premia.
    Il tuo codice OTP è: #{code}
    Il codice è valido per 5 minuti. Se non hai richiesto il recupero della password, ignora questo messaggio.
    """
  end
end
