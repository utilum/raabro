
#--
# Copyright (c) 2015-2015, John Mettraux, jmettraux@gmail.com
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
#
# Made in Japan.
#++


module Raabro

  VERSION = '1.0.6'

  class Input

    attr_accessor :string, :offset
    attr_reader :options

    def initialize(string, offset=0, options={})

      @string = string
      @offset = offset.is_a?(Hash) ? 0 : offset
      @options = offset.is_a?(Hash) ? offset : options
    end

    def match(str_or_regex)

      if str_or_regex.is_a?(Regexp)
        m = @string[@offset..-1].match(str_or_regex)
        m && (m.offset(0).first == 0) ? m[0].length : false
      else # String or whatever responds to #to_s
        s = str_or_regex.to_s
        l = s.length
        @string[@offset, l] == s ? l : false
      end
    end

    def tring(l=-1)

      l < 0 ? @string[@offset..l] : @string[@offset, l]
    end
  end

  class Tree

    attr_accessor :name, :input
    attr_accessor :result # ((-1 error,)) 0 nomatch, 1 success
    attr_accessor :offset, :length
    attr_accessor :parter, :children

    def initialize(name, parter, input)

      @result = 0
      @name = name
      @parter = parter
      @input = input
      @offset = input.offset
      @length = 0
      @children = []
    end

    def empty?

      @result == 1 && @length == 0
    end

    def successful_children

      @children.select { |c| c.result == 1 }
    end

    def prune!

      @children = successful_children
    end

    def string

      @input.string[@offset, @length]
    end

    def lookup(name)

      name = name.to_s

      return self if @name.to_s == name
      @children.each { |c| if n = c.lookup(name); return n; end }
      nil
    end

    def gather(name, acc=[])

      name = name.to_s

      if @name.to_s == name
        acc << self
      else
        @children.each { |c| c.gather(name, acc) }
      end

      acc
    end

    def to_a(opts={})

      opts = Array(opts).inject({}) { |h, e| h[e] = true; h } \
        unless opts.is_a?(Hash)

      cn =
        if opts[:leaves] && (@result == 1) && @children.empty?
          string
        elsif opts[:children] != false
          @children.collect { |e| e.to_a(opts) }
        else
          @children.length
        end

      [ @name, @result, @offset, @length, @note, @parter, cn ]
    end

    def to_s(depth=0, io=StringIO.new)

      io.print "\n" if depth > 0
      io.print '  ' * depth
      io.print "#{@result} #{@name.inspect} #{@offset},#{@length}"
      io.print result == 1 && children.size == 0 ? ' ' + string.inspect : ''

      @children.each { |c| c.to_s(depth + 1, io) }

      depth == 0 ? io.string : nil
    end

    def odd_children

      cs = []; @children.each_with_index { |c, i| cs << c if i.odd? }; cs
    end

    def even_children

      cs = []; @children.each_with_index { |c, i| cs << c if i.even? }; cs
    end
  end

  module ModuleMethods

    def _match(name, input, parter, regex_or_string)

      r = Raabro::Tree.new(name, parter, input)

      if l = input.match(regex_or_string)
        r.result = 1
        r.length = l
        input.offset += l
      end

      r
    end

    def str(name, input, string)

      _match(name, input, :str, string)
    end

    def rex(name, input, regex_or_string)

      _match(name, input, :rex, Regexp.new(regex_or_string))
    end

    def _quantify(parser)

      return nil if parser.is_a?(Symbol) && respond_to?(parser)
        # so that :plus and co can be overriden

      case parser
        when '?', :q, :qmark then [ 0, 1 ]
        when '*', :s, :star then [ 0, 0 ]
        when '+', :p, :plus then [ 1, 0 ]
        else nil
      end
    end

    def _narrow(parser)

      fail ArgumentError.new("lone quantifier #{parser}") if _quantify(parser)

      method(parser.to_sym)
    end

    def _parse(parser, input)

      #p [ caller.length, parser, input.tring ]
      #r = _narrow(parser).call(input)
      #p [ caller.length, parser, input.tring, r.to_a(children: false) ]
      #r
      _narrow(parser).call(input)
    end

    def seq(name, input, *parsers)

      r = ::Raabro::Tree.new(name, :seq, input)

      start = input.offset
      c = nil

      loop do

        pa = parsers.shift
        break unless pa

        if q = _quantify(parsers.first)
          parsers.shift
          c = rep(nil, input, pa, *q)
          r.children.concat(c.children)
        else
          c = _parse(pa, input)
          r.children << c
        end

        break if c.result != 1
      end

      if c && c.result == 1
        r.result = 1
        r.length = input.offset - start
      else
        input.offset = start
      end

      r
    end

    def alt(name, input, *parsers)

      greedy =
        if parsers.last == true || parsers.last == false
          parsers.pop
        else
          false
        end

      r = ::Raabro::Tree.new(name, greedy ? :altg : :alt, input)

      start = input.offset
      c = nil

      parsers.each do |pa|

        cc = _parse(pa, input)
        r.children << cc

        input.offset = start

        if greedy
          if cc.result == 1 && cc.length >= (c ? c.length : -1)
            c.result = 0 if c
            c = cc
          else
            cc.result = 0
          end
        else
          c = cc
          break if c.result == 1
        end
      end

      if c && c.result == 1
        r.result = 1
        r.length = c.length
        input.offset = start + r.length
      end

      r.prune! if input.options[:prune]

      r
    end

    def altg(name, input, *parsers)

      alt(name, input, *parsers, true)
    end

    def rep(name, input, parser, min, max=0)

      min = 0 if min == nil || min < 0
      max = nil if max.nil? || max < 1

      r = ::Raabro::Tree.new(name, :rep, input)
      start = input.offset
      count = 0

      loop do
        c = _parse(parser, input)
        r.children << c
        break if c.result != 1
        count += 1
        break if c.length < 1
        break if max && count == max
      end

      if count >= min && (max == nil || count <= max)
        r.result = 1
        r.length = input.offset - start
      else
        input.offset = start
      end

      r.prune! if input.options[:prune]

      r
    end

    def ren(name, input, parser)

      r = _parse(parser, input)
      r.name = name

      r
    end
    alias rename ren

    def all(name, input, parser)

      start = input.offset
      length = input.string.length - input.offset

      r = ::Raabro::Tree.new(name, :all, input)
      c = _parse(parser, input)
      r.children << c

      if c.length < length
        input.offset = start
      else
        r.result = 1
        r.length = c.length
      end

      r
    end

    def eseq(name, input, startpa, eltpa, seppa=nil, endpa=nil)

      jseq = false

      if seppa.nil? && endpa.nil?
        jseq = true
        seppa = eltpa; eltpa = startpa; startpa = nil
      end

      start = input.offset
      r = ::Raabro::Tree.new(name, jseq ? :jseq : :eseq, input)
      r.result = 1
      c = nil

      if startpa
        c = _parse(startpa, input)
        r.children << c
        r.result = 0 if c.result != 1
      end

      if r.result == 1

        i = 0

        loop do

          add = true

          st = i > 0 ? _parse(seppa, input) : nil
          et = st == nil || st.result == 1 ? _parse(eltpa, input) : nil

          break if st && et && st.empty? && et.result == 0
          break if st && et && st.empty? && et.empty?

          r.children << st if st
          r.children << et if et

          break if et == nil
          break if et.result != 1

          i = i + 1
        end

        r.result = 0 if jseq && i == 0
      end

      if r.result == 1 && endpa
        c = _parse(endpa, input)
        r.children << c
        r.result = 0 if c.result != 1
      end

      if r.result == 1
        r.length = input.offset - start
      else
        input.offset = start
      end

      r.prune! if input.options[:prune]

      r
    end
    alias jseq eseq

    attr_accessor :last

    def method_added(name)

      m = method(name)
      return unless m.arity == 1
      return unless m.parameters[0][1] == :i || m.parameters[0][1] == :input

      @last = name.to_sym
    end

    def parse(input, opts={})

      d = opts[:debug].to_i
      opts[:rewrite] = false if d > 0
      opts[:all] = false if d > 1
      opts[:prune] = false if d > 2

      opts[:prune] = true unless opts.has_key?(:prune)

      root = self.respond_to?(:root) ? :root : @last

      t =
        if opts[:all] == false
          _parse(root, Raabro::Input.new(input, opts))
        else
          all(nil, Raabro::Input.new(input, opts), root)
        end

      return nil if opts[:prune] != false && t.result != 1

      t = t.children.first if t.parter == :all

      return rewrite(t) if opts[:rewrite] != false

      t
    end

    def rewrite_(tree)

      c = tree.children.find { |c| c.length > 0 || c.name }
      c ? rewrite(c) : nil
    end

    def rewrite(tree)

      return !! methods.find { |m| m.to_s.match(/^rewrite_/) } if tree == 0
        # return true when "rewrite_xxx" methods seem to have been provided

      send("rewrite_#{tree.name}", tree)
    end
  end
  extend ModuleMethods

  def self.included(target)

    target.instance_eval do
      extend ::Raabro::ModuleMethods
      extend self
    end
  end
end

