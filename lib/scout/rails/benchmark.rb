class << Benchmark
  if RAILS_GEM_VERSION < '2.3.0'
    def ms
      1000 * realtime { yield }
    end
  end
end
