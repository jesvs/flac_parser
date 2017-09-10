defmodule FlacParserTest do
  use ExUnit.Case
  doctest FlacParser

  setup_all do
    FlacParser.parse("test/data/test.flac")
  end

  test "metadata tags", state do
    assert "Track Test" == state.title
    assert "Artist Test" == state.artist
    assert "Album Test" == state.album
    assert "2017" == state.date
    assert "Genre Test" == state.genre
    assert "Composer Test" == state.composer
    assert "Performer Test" == state.performer
    assert "Album Artist Test" == state.albumartist
    assert "1" == state.tracknumber
    assert "2" == state.tracktotal
    assert "3" == state.discnumber
    assert "4" == state.disctotal
    assert "Comment Test" == state.comment
    assert "Lavf57.80.100" == state.encoder
    assert "0.440399" == state.replaygain_track_peak
  end

  test "pictures", state do
    assert Map.has_key? state, :pictures
    assert Map.has_key? state.pictures, :cover
    assert Map.has_key? state.pictures, :back
    assert Map.has_key? state.pictures, :media
    assert Map.has_key? state.pictures, :icon
  end

  test "test picture filenames", state do
    assert state.pictures.cover.filename == "cover.png"
    assert state.pictures.artist.filename == "artist.png"
    assert state.pictures.back.filename == "back.png"
    assert state.pictures.media.filename == "media.png"
  end

  test "cover has data", state do
    assert is_binary(state.pictures.cover.data)
  end

  test "has no picture key", state do
    refute Map.has_key? state, :picture
  end

  test "streaminfo", state do
    assert 24000 == state.streaminfo.sample_rate
    assert 3765 == state.streaminfo.total_samples
    assert 0 == state.streaminfo.duration
  end

  test "no unwanted keys", state do
    refute Map.has_key? state, :padding
    refute Map.has_key? state, :seektable
    refute Map.has_key? state, :application
    refute Map.has_key? state, :cuesheet
    refute Map.has_key? state, :reserved_or_invalid
  end
end
