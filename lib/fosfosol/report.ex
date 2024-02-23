defmodule Fosfosol.Report do
  def build_writer do
    case File.rm("./report") do
      :ok -> :ok
      {:error, _reason} -> :ok
    end

    file = File.open!("./report", [:append, :utf8])

    {fn contents ->
       options = [limit: :infinity, printable_limit: :infinity]
       IO.inspect(file, contents, options)
     end, file}
  end
end
