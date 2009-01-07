if RAILS_GEM_VERSION < '2.3.0'
  class << Benchmark
    def ms
      1000 * realtime { yield }
    end
  end
end
