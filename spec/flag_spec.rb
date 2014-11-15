require "spec_helper"
require "janko/flag"

RSpec.describe Janko::Flag do
    def flag(value)
        Janko::Flag.new(value)
    end

    it { expect(flag(2 ** 0)).to_not eq(2 ** 0) }

    it { expect(flag(2 ** 0)).to eq(flag(2 ** 0)) }

    it { expect(flag(2 ** 0)).to eq(flag(2 ** 0) | flag(2 ** 1)) }

    it { expect(flag(2 ** 0)).to_not eq(flag(2 ** 2) | flag(2 ** 1)) }
end
