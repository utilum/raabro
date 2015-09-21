
#
# specifying raabro
#
# Mon Sep 21 16:58:01 JST 2015
#

require 'spec_helper'

module Sample
  module Xel include Raabro

    def pa(i); str(nil, i, '('); end
    def pz(i); str(nil, i, ')'); end
    def com(i); str(nil, i, ','); end
    def num(i); rex(:num, i, /-?[0-9]+/); end

    def args(i); eseq(:args, i, :pa, :exp, :com, :pz); end

    def funame(i); rex(:funame, i, /[A-Z][A-Z0-9]*/); end
    def fun(i); seq(:fun, i, :funame, :args); end

    def exp(i); alt(:exp, i, :fun, :num); end
  end
end


describe Raabro do

  describe Sample::Xel do

    describe '.funame' do

      it 'hits' do

        i = Raabro::Input.new('NADA')

        t = Sample::Xel.funame(i)

        expect(t.to_a(:leaves => true)).to eq(
          [ :funame, 1, 0, 4, nil, :rex, 'NADA' ]
        )
      end
    end

    describe '.fun' do

      it 'parses a function call' do

        i = Raabro::Input.new('SUM(1,MUL(4,5))', :prune => true)

        t = Sample::Xel.fun(i)

        pp t.to_a(:leaves => true)

        expect(t.result).to eq(1)
      end
    end
  end
end

