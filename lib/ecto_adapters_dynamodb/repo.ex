defmodule Ecto.Adapters.DynamoDB.Repo do
  @moduledoc """                        
  Some wrapper functions for helping us create, update and delete in dynamo db.
  Not to be confused with Ecto.Repo

  """

  alias ExAws.Dynamo                    
  
  
  def insert(table, fields_map) do      
    Dynamo.put_item(table, fields_map) |> ExAws.request!
  end
end
