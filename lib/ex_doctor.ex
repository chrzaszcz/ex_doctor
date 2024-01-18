defmodule ExDoctor do
  require Record

  @moduledoc """
  This module defines records from the `:tr` module, allowing to use them in `iex`.
  """

  for {name, fields} <- Record.extract_all(from_lib: "erlang_doctor/include/tr.hrl") do
    Record.defrecord(name, fields)
  end
end
