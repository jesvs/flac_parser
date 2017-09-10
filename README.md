# Flac

Parses a FLAC file metadata.

### Examples

  ```elixir
  iex> {:ok, metadata} = FlacParser.parse "test/data/test.flac"
  iex> Map.keys metadata
  [:album, :albumartist, :artist, :comment, :composer, :date,
 :discnumber, :disctotal, :encoder, :genre, :performer,
 :pictures, :replaygain_album_peak, :replaygain_track_peak,
 :streaminfo, :title, :tracknumber, :tracktotal]
  iex> metadata.album
  "Album Test"
  ```

## Installation

The package can be installed by adding `flac_parser` to your list of
dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:flac_parser, "~> 0.1.0"}
  ]
end
```
