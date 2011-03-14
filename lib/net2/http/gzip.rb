require "zlib"

module Net2
  # This class is similar to GzipReader, but can accept chunks at a
  # time (like Zlib::Inflater), rather than needing to read off of a stream
  class GzipInflater
    FLAGS = {
      :extra => 0x4,
      :original_name => 0x8,
      :comment => 0x10
    }

    BLANK = ""
    BLANK.force_encoding("BINARY") if BLANK.respond_to?(:force_encoding)

    def initialize
      @inflater = Zlib::Inflate.new -Zlib::MAX_WBITS
      @state    = :header
      @buffer   = BLANK.dup
    end

    def close
      @inflater.close unless @inflater.closed?
    end

    def inflate(chunk)
      @buffer << chunk
      send(@state) || BLANK.dup
    end

    def header
      if @buffer.size >= 10
        header = @buffer.slice!(0,10)
        @flags = header.unpack('CCCCVCC')[3]

        to_state :check_extra
      end
    end

    def check_extra
      choose_state :flag => :extra, :true => :get_extra, :false => :check_original_name do
        if @buffer.size >= 2
          @extra_length = @buffer.slice!(0,2).unpack('v')
          true
        end
      end
    end

    def get_extra
      if @buffer.size >= @extra_length + 2
        @buffer.slice!(0, @extra_length + 2)
        to_state :check_original_name
      end
    end

    def check_original_name
      @next_state = :check_comment
      choose_state :flag => :original_name, :true => :consume_to_null, :false => @next_state
    end

    def check_comment
      @next_state = :inflate_chunk
      choose_state :flag => :comment, :true => :consume_to_null, :false => @next_state
    end

    def consume_to_null
      @buffer.gsub!(/^[^\0]*(\0)?/n, "")

      return nil unless $1
      to_state @next_state
    end

    def inflate_chunk
      result = @inflater.inflate(@buffer)
      @buffer.replace BLANK.dup
      result
    end

  private
    def choose_state(options)
      if flag? options[:flag]
        conditional = block_given? ? yield : true
        to_state options[:true] if conditional
      else
        to_state options[:false]
      end
    end

    def to_state(state)
      @state = state
      send state
    end

    def flag?(flag)
      @flags & FLAGS[flag] == FLAGS[flag]
    end
  end
end

