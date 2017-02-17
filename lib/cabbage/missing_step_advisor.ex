defmodule Cabbage.MissingStepAdvisor do

  def raise(step_text, step_type) do
    raise """
    Please add a matching step for:
    "#{step_type} #{step_text}"

      def#{step_type |> String.downcase} ~r/^#{step_text}$/, vars, state do
        # Your implementation here
      end
    """
  end

end
