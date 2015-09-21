
#
# specifying raabro
#
# Mon Sep 21 10:15:35 JST 2015
#

require 'spec_helper'


describe Raabro do

  describe '.eseq' do

    it 'parses successfully' do

      i = Raabro::Input.new('<a,b>')

      t = Raabro.eseq(:list, i, :lt, :cha, :com, :gt)

      expect(t.to_a(:leaves => true)).to eq(
        [ :list, 1, 0, 5, nil, :eseq, [
          [ nil, 1, 0, 1, nil, :str, '<' ],
          [ nil, 1, 1, 1, nil, :rex, 'a' ],
          [ nil, 1, 2, 1, nil, :str, ',' ],
          [ nil, 1, 3, 1, nil, :rex, 'b' ],
          [ nil, 0, 4, 0, nil, :str, [] ],
          [ nil, 1, 4, 1, nil, :str, '>' ]
        ] ]
      )
      expect(i.offset).to eq(5)
    end

    context 'no start parser' do

      it 'parses successfully' do

        i = Raabro::Input.new('a,b>')

        t = Raabro.eseq(:list, i, nil, :cha, :com, :gt)

        expect(t.to_a(:leaves => true)).to eq(
          [ :list, 1, 0, 4, nil, :eseq, [
            [ nil, 1, 0, 1, nil, :rex, 'a' ],
            [ nil, 1, 1, 1, nil, :str, ',' ],
            [ nil, 1, 2, 1, nil, :rex, 'b' ],
            [ nil, 0, 3, 0, nil, :str, [] ],
            [ nil, 1, 3, 1, nil, :str, '>' ]
          ] ]
        )
        expect(i.offset).to eq(4)
      end
    end

    context 'no end parser' do

      it 'parses successfully' do

        i = Raabro::Input.new('<a,b')

        t = Raabro.eseq(:list, i, :lt, :cha, :com, nil)

        expect(t.to_a(:leaves => true)).to eq(
          [ :list, 1, 0, 4, nil, :eseq, [
            [ nil, 1, 0, 1, nil, :str, '<' ],
            [ nil, 1, 1, 1, nil, :rex, 'a' ],
            [ nil, 1, 2, 1, nil, :str, ',' ],
            [ nil, 1, 3, 1, nil, :rex, 'b' ],
            [ nil, 0, 4, 0, nil, :str, [] ],
          ] ]
        )
        expect(i.offset).to eq(4)
      end
    end
  end
end

