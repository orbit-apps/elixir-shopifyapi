defmodule ShopifyAPI.Middleware.EventStructCoercerTest do
  use ExUnit.Case

  alias Exq.Middleware.Pipeline
  alias ShopifyAPI.EventPipe.Event
  alias ShopifyAPI.Middleware.EventStructCoercer

  defp build_pipeline(args) when is_list(args) do
    %Pipeline{
      assigns: %{
        job: %{
          args: args
        }
      }
    }
  end

  defp build_pipeline(arg), do: build_pipeline([arg])

  defp get_pipeline_args(%Pipeline{assigns: %{job: %{args: args}}}), do: args

  test "converts a map into an event" do
    pipe =
      %{destination: "somewhere", action: "anything", token: %{}}
      |> build_pipeline
      |> EventStructCoercer.before_work()

    assert [%Event{destination: "somewhere", action: "anything", token: %{}}] =
             get_pipeline_args(pipe)
  end

  test "does not convert a map with extra keys into an event" do
    pipe =
      %{
        destination: "somewhere",
        action: "anything",
        token: %{},
        not_in_struct: "not a key in the struct"
      }
      |> build_pipeline
      |> EventStructCoercer.before_work()

    assert [
             %{
               destination: "somewhere",
               action: "anything",
               token: %{},
               not_in_struct: "not a key in the struct"
             }
           ] = get_pipeline_args(pipe)
  end

  test "converts a list of maps into events" do
    pipe =
      [
        %{destination: "somewhere", action: "anything", token: %{}},
        %{destination: "nowhere", action: "nothing", token: %{}}
      ]
      |> build_pipeline
      |> EventStructCoercer.before_work()

    assert [
             %Event{destination: "somewhere", action: "anything", token: %{}},
             %Event{destination: "nowhere", action: "nothing", token: %{}}
           ] = get_pipeline_args(pipe)
  end

  test "non events skip coercion" do
    pipe =
      [
        {:not_an_event},
        %{type: "not an event"},
        %{destination: "is_event", action: "action", token: %{}}
      ]
      |> build_pipeline
      |> EventStructCoercer.before_work()

    assert [
             {:not_an_event},
             %{type: "not an event"},
             %Event{destination: "is_event", action: "action", token: %{}}
           ] = get_pipeline_args(pipe)
  end
end
