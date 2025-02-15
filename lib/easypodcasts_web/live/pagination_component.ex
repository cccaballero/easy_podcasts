defmodule EasypodcastsWeb.PaginationComponent do
  @moduledoc """
  Component to generate the pagination element
  """
  use Phoenix.Component
  import EasypodcastsWeb.Gettext

  def pagination(
        %{
          socket: socket,
          page_number: page_number,
          total_pages: total_pages,
          page_range: page_range,
          route: route,
          action: action,
          object_id: object_id,
          search: search
        } = assigns
      ) do
    # TODO figure out how to use live_patch here but scrolling to the top
    # after changing page
    ~H"""
    <nav class="flex justify-center mt-5 mb-5 w-full text-lg">
      <%= if page_number != 1 do %>
        <%= live_redirect to: get_route(socket, route, action, object_id, search, page_number - 1),
                      class: "block ml-0 rounded-l-lg mr-1 leading-tight py-2 px-3 hover:bg-primary hover:text-text-light" do %>
          <span class="sr-only">
            <%= gettext("Previous") %>
          </span>
          <svg class="w-6 h-6 text-primary-dark" fill="currentColor" viewBox="0 0 20 20" xmlns="http://www.w3.org/2000/svg">
            <path
              fill-rule="evenodd"
              d="M12.707 5.293a1 1 0 010 1.414L9.414 10l3.293 3.293a1 1 0 01-1.414 1.414l-4-4a1 1 0 010-1.414l4-4a1 1 0 011.414 0z"
              clip-rule="evenodd"
            >
            </path>
          </svg>
        <% end %>
      <% end %>

      <%= for idx <- Enum.to_list(page_range) do %>
        <%= if page_number == idx do %>
          <%= live_redirect(idx,
            to: get_route(socket, route, action, object_id, search, idx),
            class: "leading-tight rounded mr-1 py-2 px-3 pointer-events-none bg-primary text-text-light text-xl"
          ) %>
        <% else %>
          <%= live_redirect(idx,
            to: get_route(socket, route, action, object_id, search, idx),
            class: "leading-tight rounded mr-1 py-2 px-3 hover:bg-primary text-primary-dark hover:text-text-light text-xl"
          ) %>
        <% end %>
      <% end %>

      <%= if page_number != total_pages do %>
        <%= live_redirect to: get_route(socket, route, action, object_id, search, page_number + 1),
                      class: "block rounded-r-lg leading-tight py-2 px-3 hover:bg-primary hover:text-text-light" do %>
          <span class="sr-only">
            <%= gettext("Next") %>
          </span>
          <svg class="w-6 h-6 text-primary-dark" fill="currentColor" viewBox="0 0 20 20" xmlns="http://www.w3.org/2000/svg">
            <path
              fill-rule="evenodd"
              d="M7.293 14.707a1 1 0 010-1.414L10.586 10 7.293 6.707a1 1 0 011.414-1.414l4 4a1 1 0 010 1.414l-4 4a1 1 0 01-1.414 0z"
              clip-rule="evenodd"
            >
            </path>
          </svg>
        <% end %>
      <% end %>
    </nav>
    """
  end

  defp get_route(socket, route_func, action, object_id, search, page_number) do
    params =
      case search do
        nil -> [page: page_number]
        _other -> [page: page_number, search: search]
      end

    case object_id do
      nil -> route_func.(socket, action, params)
      _other -> route_func.(socket, action, object_id, params)
    end
  end
end
