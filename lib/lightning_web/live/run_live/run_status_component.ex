defmodule Lightning.RunLive.RunStatusComponent do
  @moduledoc """
  Run Status MultiSelect.
  """
  use LightningWeb, :live_component

  @impl true
  attr(:label, :string)

  def render(assigns) do
    ~H"""
    <div id={"#{@id}-status_options-container"}>
      <div class="font-semibold mt-4">
        Filter by workorder status
        <Common.tooltip
          id="trigger-tooltip"
          title="Filter workorders based on their status. (I.e., the status of
            the last run in any attempt for that workorder.)"
          class="inline-block"
        />
      </div>
      <%= inputs_for @form, :status_options, fn opt -> %>
        <div class="form-check">
          <div class="selectable-option">
            <%= checkbox(opt, :selected,
              value: opt.data.selected,
              phx_change: "checked",
              class:
                "mb-1 mr-1/2 h-4 w-4 rounded border-gray-300 text-indigo-600 focus:ring-indigo-500",
              phx_target: @myself
            ) %>
            <%= label(opt, :label, opt.data.label) %>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  @impl true
  def update(assigns, socket) do
    %{status_options: status_options, form: form, id: id, selected: selected} =
      assigns

    socket =
      socket
      |> assign(:id, id)
      |> assign(:form, form)
      |> assign(:selected, selected)
      |> assign(:status_options, status_options)

    {:ok, socket}
  end

  @impl true
  def handle_event(
        "checked",
        %{"run_search_form" => %{"status_options" => values}},
        socket
      ) do
    [{index, %{"selected" => selected?}}] = Map.to_list(values)
    index = String.to_integer(index)
    current_option = Enum.at(socket.assigns.status_options, index)

    selected_statuses =
      List.replace_at(
        socket.assigns.status_options,
        index,
        %{current_option | selected: selected?}
      )

    socket.assigns.selected.(selected_statuses)

    {:noreply, socket}
  end
end