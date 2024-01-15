defmodule ExDoctor do
  require Record

  for {name, fields} <- Record.extract_all(from_lib: "erlang_doctor/include/tr.hrl") do
    Record.defrecord(name, fields)
  end
end
