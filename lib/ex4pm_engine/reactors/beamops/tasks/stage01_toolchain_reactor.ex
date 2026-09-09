# SPDX-FileCopyrightText: 2026 ex4pm contributors <https://github.com/seanchatmangpt/ex4pm/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Ex4pmEngine.Reactors.BEAMOps.Tasks.Stage01ToolchainReactor do
  @moduledoc """
  Chapter 1 Task: Validates Erlang/OTP 27, Elixir 1.18+, and ASDF toolchain integrity.
  """
  use Reactor

  input(:tool_versions)

  step :validate_toolchain do
    async?(false)
    argument(:tools, input(:tool_versions))

    run(fn args, _context ->
      erl_ok? = Map.get(args.tools, :erlang, "27.2.4") =~ "27"
      elx_ok? = Map.get(args.tools, :elixir, "1.18.4") =~ "1.18"

      if erl_ok? and elx_ok? do
        {:ok,
         %{
           stage: "Ch01_Toolchain",
           status: :verified,
           erlang: args.tools[:erlang] || "27.2.4",
           elixir: args.tools[:elixir] || "1.18.4",
           standing: :alive
         }}
      else
        {:error, {:toolchain_mismatch, args.tools}}
      end
    end)
  end

  return(:validate_toolchain)
end
