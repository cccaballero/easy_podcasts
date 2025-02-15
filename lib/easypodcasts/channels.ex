defmodule Easypodcasts.Channels do
  @moduledoc """
  The Channels context.
  """

  import Ecto.Query, warn: false
  import EasypodcastsWeb.Gettext
  alias Ecto.Changeset

  alias Easypodcasts.Repo
  alias Easypodcasts.Channels.{Channel, ChannelImage}
  alias Easypodcasts.Episodes
  alias Easypodcasts.Helpers.{Search, Feed}

  require Logger

  def list_channels, do: Repo.all(Channel)

  def list_channels(params) do
    {search, filters, tags} = Search.parse_search_string(params["search"], ~w(lang))

    page =
      if params["page"],
        do: String.to_integer(params["page"]),
        else: 0

    query =
      case Search.validate_search(search) do
        %{valid?: true, changes: %{search_phrase: search_phrase}} ->
          Search.search(Channel, search_phrase)

        _invalid ->
          # This should never happen when searching from the web
          Channel
      end

    query
    |> where(^filters)
    |> where([c], fragment("? @> ?", c.categories, ^tags))
    |> then(
      &from(c in &1,
        left_join: e in assoc(c, :episodes),
        group_by: c.id,
        select_merge: %{episodes: count(e.id)},
        order_by: [desc: c.updated_at]
      )
    )
    |> Repo.paginate(page: page)
  end

  def list_channels_titles(channels) do
    from(c in Channel, where: c.id in ^channels, select: c.title) |> Repo.all()
  end

  def get_channel!(id), do: Repo.get!(Channel, id)

  def get_channel_for_feed(id) do
    episodes = Episodes.query_done_episodes(id)

    Channel
    |> Repo.get!(id)
    |> Repo.preload(episodes: episodes)
    |> Map.from_struct()
  end

  def store_channel_image(channel) do
    if channel.image_url do
      case ChannelImage.store({channel.image_url, channel}) do
        {:ok, _} -> nil
        {:error, _} -> ChannelImage.store({"priv/static/images/placeholder-big.webp", channel})
      end
    end
  end

  def create_channel(attrs \\ %{}) do
    with {:ok, channel} <-
           %Channel{}
           |> Channel.changeset(attrs)
           |> Repo.insert(),
         {:ok, _episodes} <- process_channel(channel) do
      store_channel_image(channel)

      {:ok, channel}
    else
      {:error, %Changeset{} = changeset} ->
        # Some validation errors
        {:error, changeset}

      {:error, channel, msg} ->
        # The channel was created but the episodes weren't
        # or it didn't have any episodes
        delete_channel(channel)
        {:error, msg}
    end
  end

  def update_channel(%Channel{} = channel, attrs \\ %{}) do
    channel
    |> Changeset.change(attrs)
    |> Repo.update()
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking channel changes.

  ## Examples

      iex> change_channel(channel)
      %Ecto.Changeset{data: %Channel{}}

  """
  def change_channel(%Channel{} = channel, attrs \\ %{}) do
    Channel.changeset(channel, attrs)
  end

  @doc """
  Deletes a channel.

  ## Examples

      iex> delete_channel(channel)
      {:ok, %Channel{}}

      iex> delete_channel(channel)
      {:error, %Ecto.Changeset{}}

  """
  def delete_channel(%Channel{} = channel) do
    Repo.delete(channel)
  end

  def process_all_channels() do
    Logger.info("Processing all channels")

    Enum.each(list_channels(), &process_channel(&1, true))
  end

  def process_channel(channel, process_new_episodes \\ false) do
    Logger.info("Processing channel #{channel.title}")

    with {:ok, feed_data} <- Feed.get_feed_data(channel.link),
         {_, new_episodes = [_ | _]} <- Episodes.save_new_episodes(channel, feed_data) do
      Logger.info("Channel #{channel.title} has #{length(new_episodes)} new episodes")

      if process_new_episodes do
        Logger.info("Processing audio from new episodes of #{channel.title}")
        Enum.each(new_episodes, &Episodes.enqueue(&1.id))
      end

      datetime = DateTime.now!("UTC") |> DateTime.to_naive() |> NaiveDateTime.truncate(:second)

      update_channel(channel, %{updated_at: datetime})

      {:ok, new_episodes}
    else
      _error ->
        {:error, channel,
         gettext(
           "We can't process that podcast right now. Please create an issue with the feed url or visit our support group."
         )}
    end
  end

  alias Easypodcasts.Channels.Denylist

  def create_denylist(attrs \\ %{}) do
    %Denylist{}
    |> Denylist.changeset(attrs)
    |> Repo.insert()
  end

  def denied?(nil, nil) do
    false
  end

  def denied?(nil, link) do
    Repo.exists?(from d in Denylist, where: d.link == ^link)
  end

  def denied?(title, nil) do
    Repo.exists?(from d in Denylist, where: d.title == ^title)
  end

  def denied?(title, link) do
    Repo.exists?(from d in Denylist, where: d.title == ^title or d.link == ^link)
  end
end
