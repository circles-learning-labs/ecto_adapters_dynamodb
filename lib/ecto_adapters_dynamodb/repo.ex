defmodule Ecto.Adapters.DynamoDB.Repo do
  @moduledoc """                        
  Some wrapper functions for helping us create, update and delete in dynamo db.
  Not to be confused with Ecto.Repo

  """

  alias ExAws.Dynamo                    


  def insert(table, fields_map) do
    case Dynamo.put_item(table, fields_map) |> ExAws.request! do
      %{}   -> {:ok, []}
      error -> {:error, error}         
    end
  end
 

  def delete(table, filters) do
    case Dynamo.delete_item(table, filters) |> ExAws.request! do
      %{}   -> {:ok, []}
      error -> {:error, error}
    end
  end


  def update(table, filters, fields) do
    key_val_string = Enum.map(fields, fn {key, _} -> "#{Atom.to_string(key)}=:#{Atom.to_string(key)}" end)
    update_expression = "SET " <> Enum.join(key_val_string, ", ")
    
    case Dynamo.update_item(table, filters, expression_attribute_values: fields, update_expression: update_expression) |> ExAws.request! do
      %{}   -> {:ok, []}                
      error -> {:error, error}
    end
  end
end
