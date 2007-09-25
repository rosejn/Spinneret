require 'zlib'

def get_input_stream(filename)
  case filename
  when /.+\.gz/
    Zlib::GzipReader::open(filename)
  else
    File::open(filename, "r")
  end
end

def get_output_stream(filename)
  case filename
  when /.+\.gz/
    Zlib::GzipWriter::open(filename)
  else
    File::open(filename, "w+")
  end
end
