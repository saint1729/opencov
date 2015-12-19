defmodule Opencov.User do
  use Opencov.Web, :model

  use SecurePassword

  schema "users" do
    field :email, :string
    field :admin, :boolean, default: false
    field :name, :string
    field :password_need_reset, :boolean, default: false
    field :confirmation_token, :string
    field :confirmed_at, Timex.Ecto.DateTime

    field :current_password, :string, virtual: true
    has_secure_password

    has_many :projects, Opencov.Project

    timestamps
  end

  @required_fields ~w(email)
  @optional_fields ~w(admin name password)

  def changeset(model, params \\ :empty, opts \\ []) do
    model
    |> cast(params, @required_fields, @optional_fields)
    |> unique_constraint(:email)
    |> validate_email
    |> with_generated_password(opts)
    |> with_confirmation_token(opts)
    |> with_secure_password
  end

  def confirmation_changeset(model, params \\ :empty) do
    model |> cast(params, ~w(confirmed_at), [])
  end

  def password_update_changeset(model, params \\ :empty) do
    model
    |> cast(params, ~w(password password_confirmation), ~w(current_password))
    |> validate_password_update
    |> put_change(:password_need_reset, false)
    |> with_secure_password
  end

  defp validate_password_update(changeset) do
    user = changeset.model
    if user.password_need_reset or Opencov.User.authenticate(user, get_change(changeset, :current_password)) do
      delete_change(changeset, :current_password)
    else
      add_error(changeset, :current_password, "is invalid")
    end
  end

  defp with_generated_password(changeset, opts) do
    if opts[:generate_password] do
      change(changeset, password: SecureRandom.urlsafe_base64(12), password_need_reset: true)
    else
      changeset
    end
  end

  defp with_confirmation_token(changeset, opts) do
    if opts[:generate_token] do
      put_change(changeset, :confirmation_token, SecureRandom.urlsafe_base64(30))
    else
      changeset
    end
  end

  defp validate_email(%Ecto.Changeset{} = changeset) do
    if (email = get_change(changeset, :email)) && (error = validate_email(email)) do
      add_error(changeset, :email, error)
    else
      changeset
    end
  end

  defp validate_email(email) do
    if not Regex.match?(~r/@/, email) do
      "the email is not valid"
    else
      validate_domain(email)
    end
  end

  defp validate_domain(email) do
    allowed_domains = Opencov.Settings.restricted_signup_domains
    domain = email |> String.split("@") |> List.last
    if allowed_domains && not domain in allowed_domains do
      "only the following domains are allowed: #{Enum.join(allowed_domains, ",")}"
    else
      nil
    end
  end
end
