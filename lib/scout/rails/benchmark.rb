module Benchmark
  if Rails.version < '2.3.0'
    def ms
      1000 * realtime { yield }
    end
  end
end
