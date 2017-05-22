ExUnit.start()

files = File.ls!("./test/support") |> Enum.filter(&(String.ends_with?(&1, [".ex", ".exs"])))

Enum.each files, fn(file) ->
  Code.require_file "support/#{file}", __DIR__
end
