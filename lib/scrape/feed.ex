defmodule Scrape.Feed do

  alias Scrape.Exquery
  use Timex

  def parse(xml, url) do
    items = xml
    |> Floki.find("item, entry")
    |> transform_items
    items || []
  end

  defp transform_items(items) when is_list (items) do
    Parallel.map items, &transform_item/1
  end

  defp transform_item(item) do
    %{
      title: find_title(item),
      description: find_description(item),
      url: find_url(item),
      image: find_image(item),
      pubdate: find_pubdate(item)
    }
  end

  defp find_title(item) do
    item |> Exquery.find("title") |> clean_text
  end

  defp find_description(item) do
    description = item |> Exquery.find("description")
    summary = description || item |> Exquery.find("summary")
    content = summary || item |> Exquery.find("content")
    clean_text content
  end

  defp find_url(item) do
    href = item |> Exquery.attr("link", "href", :first)
    url = href || item |> Exquery.find("link", :first)
    clean_text url
  end

  defp find_image(item) do
    enclosure = item |> Exquery.attr("enclosure", "url")
    media = enclosure || item |> Exquery.attr("media, content", :first)
    if media do
      clean_text media
    else
      image_str = item |> Floki.text
      rx = ~r/\ssrc=["']*(([^'"\s]+)\.(jpe?g)|(png))["'\s]/i
      results = Regex.run(rx, image_str || "", capture: :all_but_first)
      if results, do: clean_text(List.first(results)), else: nil
    end
  end

  defp find_pubdate(item) do
    str = item |> Exquery.find("updated,pubDate,pubdate", :first)  |> clean_text
    {status, date_rfc} = str |> DateFormat.parse("{RFC1123}")
    if status == :ok do
      date_rfc
    else
      {status, date_iso} = str |> DateFormat.parse("{ISO}")
      if status == :ok do
        date_iso
      else
        Date.now
      end
    end
  end

  @datetime_patterns [
    "{ISO}", "{ISOz}", "{RFC822}", "{RFC822z}", "{RFC1123}", "{RFC1123z}",
    "{RFC3339}", "{RFC3339z}", "{ANSIC}", "{UNIX}"
  ]

  defp try_date(str, patterns \\ @datetime_patterns)
  defp try_date(str, []), do: Date.now
  defp try_date(str, [format | others]) do
    case DateFormat.parse(str, format) do
      {:ok, result} -> result
      _ -> try_date(str, others)
    end
  end

  defp clean_text(nil), do: nil
  defp clean_text(str) do
    str
    |> String.strip
  end

  # def parse(xml) do
  #   case FeederEx.parse(xml) do
  #     {:ok, feed, _} -> feed.entries
  #     _ -> []
  #   end
  # end

end
