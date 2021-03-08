defmodule FlacParser do
  @skip_types [:seektable, :padding, :application, :cuesheet, :reserved_or_invalid]

  @moduledoc """
  Parses metadata blocks from flac files.
  """

  @doc """
  Parse FLAC file.

  ### Examples

    iex> {:ok, metadata} = FlacParser.parse "test/data/test.flac"
    iex> metadata.artist
    "Artist Test"
  """
  def parse(filename) do
    case File.read(filename) do
      {:ok, binary} ->
        << signature :: binary-size(4), data :: binary >> = binary
  
        case signature do
          "fLaC" -> { :ok, parse_block(%{pictures: %{}}, data, 0) |> build_metadata_from_parsed_data |> Map.drop(@skip_types) }
          _ -> {:error, "Not a FLAC file."}
        end
      {:error, reason} -> {:error, reason}
    end
  end

  # parses, identifies and calls the proper function
  defp parse_block(parsed_metadata, binary, 0) when is_map(parsed_metadata) do
    <<
      last_metadata_block_flag :: size(1),
      block_type_int :: integer-size(7),
      metadata_length :: integer-size(24),
      binary_metadata :: binary-size(metadata_length),
      remaining_data :: binary
    >> = binary
    
    block_type = case block_type_int do
      0 -> :streaminfo
      1 -> :padding
      2 -> :application
      3 -> :seektable
      4 -> :vorbis_comment
      5 -> :cuesheet
      6 -> :picture
      _ -> :reserved_or_invalid
    end

    parsed_metadata
    |> Map.put(block_type, parse_block(block_type, binary_metadata))
    |> extract_picture(block_type)
    |> parse_block(remaining_data, last_metadata_block_flag)
  end

  defp parse_block(parsed_metadata, _binary, 1) when is_map(parsed_metadata), do: parsed_metadata

  # Parses streaminfo block.
  # Returns a map with streaminfo data.
  defp parse_block(:streaminfo, binary_metadata) do
    <<
      min_block_size  :: integer-size(16),
      max_block_size  :: integer-size(16),
      min_frame_size  :: integer-size(24),
      max_frame_size  :: integer-size(24),
      sample_rate     :: integer-size(20),
      channels        :: integer-size(3),
      bits_per_sample :: integer-size(5),
      total_samples   :: integer-size(36),
      md5_signature   :: integer-size(128)
    >> = binary_metadata

    %{
      min_block_size:  min_block_size,
      max_block_size:  max_block_size,
      min_frame_size:  min_frame_size,
      max_frame_size:  max_frame_size,
      sample_rate:     sample_rate,
      channels:        channels+1,
      bits_per_sample: bits_per_sample+1,
      total_samples:   total_samples,
      md5_signature:   Integer.to_charlist(md5_signature, 16),
      duration:        round(total_samples / sample_rate)
    }
  end

  # parse vorbix_comment block (tags)
  defp parse_block(:vorbis_comment, metadata) do
    <<
      vendor_length            :: little-integer-size(32),
      vendor_string            :: binary-size(vendor_length),
      user_comment_list_length :: little-integer-size(32),
      data                     :: binary
    >> = metadata

    %{
      user_comments: parse_user_comments(data, [], user_comment_list_length),
      vendor_string: vendor_string
    }
  end
  
  # parse picture block
  defp parse_block(:picture, metadata) do
    <<
      picture_type_int :: integer-size(32),
      mime_type_length :: integer-size(32),
      mime_type        :: binary-size(mime_type_length),
      description_size :: integer-size(32),
      _description     :: binary-size(description_size),
      width            :: integer-size(32),
      height           :: integer-size(32),
      depth            :: integer-size(32),
      colors           :: integer-size(32),
      picture_length   :: integer-size(32),
      picture_data     :: binary-size(picture_length)
    >> = metadata

    picture_type = case picture_type_int do
      2 -> :icon
      3 -> :cover
      4 -> :back
      6 -> :media
      8 -> :artist
      n -> :"type_#{n}"
    end

    extension = case mime_type do
      "image/jpeg" -> "jpg"
      "image/png"  -> "png"
      "image/gif"  -> "gif"
      _            -> "bin"
    end

    %{
      type: picture_type,
      mime_type: mime_type,
      width: width,
      height: height,
      depth: depth,
      color: colors,
      length: picture_length,
      filename: "#{picture_type}.#{extension}",
      data: picture_data  
    }
  end

  # skip block types
  defp parse_block(type, _metadata)
      when is_atom(type) and
      type in @skip_types do
    nil
  end

  # parses user comments (aka tags) into a list
  defp parse_user_comments(binary, comments, total_comments) do
    <<
      comment_length :: little-integer-size(32),
      user_comment   :: binary-size(comment_length),
      data           :: binary
    >> = binary

    [key, value] = String.split(user_comment, "=", parts: 2)
    comments = [[key, value] | comments]

    if length(comments) == total_comments do
      # last comment, return comments and remaining data
      Enum.reverse(comments)
    else
      # keep parsing comments
      parse_user_comments(data, comments, total_comments)
    end
  end
  # turns user comments (aka tags) into a map and merges into the main map
  defp build_metadata_from_parsed_data(parsed_metadata) do
    tags = Enum.reduce parsed_metadata.vorbis_comment.user_comments, %{}, fn [key, val] = _key_val, acc ->
      key_atom = key |> String.downcase |> String.to_atom

      # if map has the key, put value into a list
      if Map.has_key? acc, key_atom do
        acc_val = Map.get(acc, key_atom)
        val_list = [val | [acc_val]] |> List.flatten |> Enum.reverse
        Map.put(acc, key_atom, val_list)
      else
        Map.put(acc, key_atom, val)
      end
    end

    parsed_metadata
    |> Map.merge(tags)
    |> Map.delete(:vorbis_comment)
  end

  defp extract_picture(parsed_metadata, :picture) do
    pictures = Map.put(parsed_metadata.pictures, parsed_metadata.picture.type, parsed_metadata.picture)
    parsed_metadata
    |> Map.put(:pictures, pictures)
    |> Map.delete(:picture)
  end

  defp extract_picture(parsed_metadata, _), do: parsed_metadata

end
