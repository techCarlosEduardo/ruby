# frozen_string_literal: true
require_relative "package/tar_test_case"
require "rubygems/package"

class TestGemPackageTarReaderEntry < Gem::Package::TarTestCase
  def setup
    super

    @contents = ("a".."z").to_a.join * 100

    @tar = String.new
    @tar << tar_file_header("lib/foo", "", 0, @contents.size, Time.now)
    @tar << @contents
    @tar << "\0" * (512 - (@tar.size % 512))

    @entry = util_entry @tar
  end

  def teardown
    close_util_entry(@entry)
    super
  end

  def close_util_entry(entry)
    entry.instance_variable_get(:@io).close!
  end

  def test_bytes_read
    assert_equal 0, @entry.bytes_read

    @entry.getc

    assert_equal 1, @entry.bytes_read
  end

  def test_size
    assert_equal @contents.size, @entry.size
  end

  def test_close
    @entry.close

    assert @entry.bytes_read

    e = assert_raise(IOError) { @entry.eof? }
    assert_equal "closed Gem::Package::TarReader::Entry", e.message

    e = assert_raise(IOError) { @entry.getc }
    assert_equal "closed Gem::Package::TarReader::Entry", e.message

    e = assert_raise(IOError) { @entry.pos }
    assert_equal "closed Gem::Package::TarReader::Entry", e.message

    e = assert_raise(IOError) { @entry.read }
    assert_equal "closed Gem::Package::TarReader::Entry", e.message

    e = assert_raise(IOError) { @entry.rewind }
    assert_equal "closed Gem::Package::TarReader::Entry", e.message
  end

  def test_closed_eh
    @entry.close

    assert @entry.closed?
  end

  def test_eof_eh
    @entry.read

    assert @entry.eof?
  end

  def test_full_name
    assert_equal "lib/foo", @entry.full_name
  end

  def test_full_name_null
    pend "jruby strips the null byte and does not think it's corrupt" if Gem.java_platform?
    @entry.header.prefix << "\000"

    e = assert_raise Gem::Package::TarInvalidError do
      @entry.full_name
    end

    assert_equal "tar is corrupt, name contains null byte", e.message
  end

  def test_getc
    assert_equal ?a, @entry.getc
  end

  def test_directory_eh
    assert_equal false, @entry.directory?
    dir_ent = util_dir_entry
    assert_equal true, dir_ent.directory?
  ensure
    close_util_entry(dir_ent) if dir_ent
  end

  def test_symlink_eh
    assert_equal false, @entry.symlink?
    symlink_ent = util_symlink_entry
    assert_equal true, symlink_ent.symlink?
  ensure
    close_util_entry(symlink_ent) if symlink_ent
  end

  def test_file_eh
    assert_equal true, @entry.file?
    dir_ent = util_dir_entry
    assert_equal false, dir_ent.file?
  ensure
    close_util_entry(dir_ent) if dir_ent
  end

  def test_pos
    assert_equal 0, @entry.pos

    @entry.getc

    assert_equal 1, @entry.pos
  end

  def test_read
    assert_equal @contents, @entry.read
  end

  def test_consecutive_read
    expected = StringIO.new(@contents)
    assert_equal expected.read, @entry.read
    assert_equal expected.read, @entry.read
  end

  def test_consecutive_read_bytes_past_eof
    expected = StringIO.new(@contents)
    assert_equal expected.read, @entry.read
    assert_equal expected.read(1), @entry.read(1)
  end

  def test_read_big
    assert_equal @contents, @entry.read(@contents.size * 2)
  end

  def test_read_small
    assert_equal @contents[0...100], @entry.read(100)
  end

  def test_read_remaining
    @entry.read(100)
    assert_equal @contents[100..-1], @entry.read
  end

  def test_read_partial
    assert_equal @contents[0...100], @entry.readpartial(100)
  end

  def test_read_partial_buffer
    buffer = "".b
    @entry.readpartial(100, buffer)
    assert_equal @contents[0...100], buffer
  end

  def test_readpartial_past_eof
    @entry.readpartial(@contents.size)
    assert_raise(EOFError) do
      @entry.readpartial(1)
    end
  end

  def test_rewind
    char = @entry.getc

    @entry.rewind

    assert_equal 0, @entry.pos

    assert_equal char, @entry.getc
  end

  def test_read_zero
    expected = StringIO.new("")
    assert_equal expected.read(0), @entry.read(0)
  end

  def test_readpartial_zero
    expected = StringIO.new("")
    assert_equal expected.readpartial(0), @entry.readpartial(0)
  end

  def util_zero_byte_entry
    tar = String.new
    tar << tar_file_header("lib/empty", "", 0, 0, Time.now)
    tar << "\0" * (512 - (tar.size % 512))
    util_entry tar
  end

  def test_zero_byte_file_read
    zero_entry = util_zero_byte_entry
    expected = StringIO.new("")

    assert_equal expected.read, zero_entry.read
  end

  def test_zero_byte_file_readpartial
    zero_entry = util_zero_byte_entry
    expected = StringIO.new("")

    assert_equal expected.readpartial(0), zero_entry.readpartial(0)
  end
end
