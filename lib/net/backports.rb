class StringIO
  def read_nonblock(*args)
    val = read(*args)
    raise EOFError if val.nil?
    val
  end
end

class File
  def to_path
    path
  end
end

class IO
  def self.copy_stream(a, b)
    FileUtils.copy_stream(a, b)
  end
end

module SecureRandom
  def self.urlsafe_base64(n=nil, padding=false)
    s = [random_bytes(n)].pack("m*")
    s.delete!("\n")
    s.tr!("+/", "-_")
    s.delete!("=") if !padding
    s
  end
end

module OpenSSL
  module Buffering

    def read_nonblock(maxlen, buf=nil)
      if maxlen == 0
        if buf
          buf.clear
          return buf
        else
          return ""
        end
      end
      if @rbuffer.empty?
        return sysread(maxlen, buf)
      end
      ret = consume_rbuff(maxlen)
      if buf
        buf.replace(ret)
        ret = buf
      end
      raise EOFError if ret.empty?
      ret
    end

  end

  module SSL
    class SSLSocket
      include Buffering
    end
  end
end

module URI
  TBLENCWWWCOMP_ = {} # :nodoc:
  TBLDECWWWCOMP_ = {} # :nodoc:

  # Encode given +str+ to URL-encoded form data.
  #
  # This method doesn't convert *, -, ., 0-9, A-Z, _, a-z, but does convert SP
  # (ASCII space) to + and converts others to %XX.
  #
  # This is an implementation of
  # http://www.w3.org/TR/html5/forms.html#url-encoded-form-data
  #
  # See URI.decode_www_form_component, URI.encode_www_form
  def self.encode_www_form_component(str)
    if TBLENCWWWCOMP_.empty?
      256.times do |i|
        TBLENCWWWCOMP_[i.chr] = '%%%02X' % i
      end
      TBLENCWWWCOMP_[' '] = '+'
      TBLENCWWWCOMP_.freeze
    end
    str = str.to_s.dup
    str.gsub!(/[^*\-.0-9A-Z_a-z]/) { |m| TBLENCWWWCOMP_[m] }
    str
  end

  # Decode given +str+ of URL-encoded form data.
  #
  # This decods + to SP.
  #
  # See URI.encode_www_form_component, URI.decode_www_form
  def self.decode_www_form_component(str)
    if TBLDECWWWCOMP_.empty?
      256.times do |i|
        h, l = i>>4, i&15
        TBLDECWWWCOMP_['%%%X%X' % [h, l]] = i.chr
        TBLDECWWWCOMP_['%%%x%X' % [h, l]] = i.chr
        TBLDECWWWCOMP_['%%%X%x' % [h, l]] = i.chr
        TBLDECWWWCOMP_['%%%x%x' % [h, l]] = i.chr
      end
      TBLDECWWWCOMP_['+'] = ' '
      TBLDECWWWCOMP_.freeze
    end
    raise ArgumentError, "invalid %-encoding (#{str})" unless /\A(?:%\h\h|[^%]+)*\z/ =~ str
    str.gsub(/\+|%\h\h/, TBLDECWWWCOMP_)
  end

  # Generate URL-encoded form data from given +enum+.
  #
  # This generates application/x-www-form-urlencoded data defined in HTML5
  # from given an Enumerable object.
  #
  # This internally uses URI.encode_www_form_component(str).
  #
  # This method doesn't convert the encoding of given items, so convert them
  # before call this method if you want to send data as other than original
  # encoding or mixed encoding data. (Strings which are encoded in an HTML5
  # ASCII incompatible encoding are converted to UTF-8.)
  #
  # This method doesn't handle files.  When you send a file, use
  # multipart/form-data.
  #
  # This is an implementation of
  # http://www.w3.org/TR/html5/forms.html#url-encoded-form-data
  #
  #    URI.encode_www_form([["q", "ruby"], ["lang", "en"]])
  #    #=> "q=ruby&lang=en"
  #    URI.encode_www_form("q" => "ruby", "lang" => "en")
  #    #=> "q=ruby&lang=en"
  #    URI.encode_www_form("q" => ["ruby", "perl"], "lang" => "en")
  #    #=> "q=ruby&q=perl&lang=en"
  #    URI.encode_www_form([["q", "ruby"], ["q", "perl"], ["lang", "en"]])
  #    #=> "q=ruby&q=perl&lang=en"
  #
  # See URI.encode_www_form_component, URI.decode_www_form
  def self.encode_www_form(enum)
    enum.map do |k,v|
      if v.nil?
        encode_www_form_component(k)
      elsif v.respond_to?(:to_ary)
        v.to_ary.map do |w|
          str = encode_www_form_component(k)
          unless w.nil?
            str << '='
            str << encode_www_form_component(w)
          end
        end.join('&')
      else
        str = encode_www_form_component(k)
        str << '='
        str << encode_www_form_component(v)
      end
    end.join('&')
  end
end
