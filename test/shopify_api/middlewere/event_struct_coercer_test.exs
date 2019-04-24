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

  test "converts a map into an event" do
    pipe =
      %{destination: "somewhere", action: "anything", token: %{}}
      |> build_pipeline
      |> EventStructCoercer.before_work()

    assert ^pipe =
             build_pipeline(%Event{destination: "somewhere", action: "anything", token: %{}})
  end

  test "converts a list of maps into events" do
    pipe =
      [
        %{destination: "somewhere", action: "anything", token: %{}},
        %{destination: "nowhere", action: "nothing", token: %{}}
      ]
      |> build_pipeline
      |> EventStructCoercer.before_work()

    assert ^pipe =
             build_pipeline([
               %Event{destination: "somewhere", action: "anything", token: %{}},
               %Event{destination: "nowhere", action: "nothing", token: %{}}
             ])
  end

  test "non events skip coercion" do
    pipe =
      [
        {:not_an_event},
        %{type: "not and event"},
        %{destination: "is_event", action: "action", token: %{}}
      ]
      |> build_pipeline
      |> EventStructCoercer.before_work()

    assert ^pipe =
             build_pipeline([
               {:not_an_event},
               %{type: "not and event"},
               %Event{destination: "is_event", action: "action", token: %{}}
             ])
  end
end
