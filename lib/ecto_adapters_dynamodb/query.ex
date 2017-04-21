defmodule Ecto.Adapters.DynamoDB.Query do
  @moduledoc """
  Some query wrapper functions for helping us query dynamo db. Selects indexes to use, etc.
  Not to be confused with Ecto.Query (Should wec rename this module?)

  """

	import Ecto.Adapters.DynamoDB.Info

  def get_item(table, search) do
	
    index = get_best_index!(table, search)
    query = construct_search(index, search)



  	results = ExAws.Dynamo.get_item("circle", %{id: "circle-test"}) |> ExAws.request!

    filter(results, search)  # index may have had more fields than the index did, thus results need to be trimmed.
  end


  def construct_search(index, search), do: %{}

  def filter(results, search), do: %{}

end