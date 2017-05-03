defmodule Ecto.Adapters.DynamoDB.Repo do
  @moduledoc """                        
  Some wrapper functions for helping us create, update and delete in dynamo db.
  Not to be confused with Ecto.Repo

  """

  alias ExAws.Dynamo                    
  

  def insert(table, fields_map) do
    case Dynamo.put_item(table, fields_map) |> ExAws.request! do
      %{}   -> {:ok, %{}}               
      error -> {:error, error}          
    end
  end  
end
