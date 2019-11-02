defmodule Ecto.Adapters.DynamoDB.Protocol do
  @moduledoc false

  # called by DBConnection.Connection.connect
  def connect(_opts) do
    # For the time-being, this gets the job done.
    # To what extent do we need to replicate the behavior outlined at
    # http://blog.plataformatec.com.br/2018/12/building-a-new-mysql-adapter-for-ecto-part-iii-dbconnection-integration/
    {:ok, []}
  end

  # called by DBConnection.Connection.handle_cast
  def checkout(state) do
    {:ok, state}
  end

  # called by DBConnection.Connection.connect
  def ping(state) do
    {:ok, state}
  end

end
