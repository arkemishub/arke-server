defmodule ArkeServer.Support.Persistence do
  def create(_par1, _par2) do
    fn_message("called create fun")
    {:ok, nil}
  end

  def update(_par1, _par2) do
    fn_message("called update fun")
    {:ok, nil}
  end

  def delete(_par1, _par2) do
    fn_message("called delete fun")
    {:ok, nil}
  end

  def execute_query(_par1, _par2) do
    fn_message("called execute_query fun")
    {:ok, nil}
  end

  def get_parameters() do
    fn_message("called get_parameters fun")
    {:ok, nil}
  end

  def create_project(_par1) do
    fn_message("called create_project fun")
    {:ok, nil}
  end

  def delete_project(_par1) do
    fn_message("called delete_project fun")
    {:ok, nil}
  end

  defp fn_message(msg), do: IO.puts(IO.ANSI.format([:yellow, msg]))
end
