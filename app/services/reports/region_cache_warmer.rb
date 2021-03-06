module Reports
  class RegionCacheWarmer
    def self.call
      new.call
    end

    BATCH_SIZE = 100

    def initialize(period: RegionService.default_period)
      @period = period
      @original_force_cache = RequestStore.store[:force_cache]
      RequestStore.store[:force_cache] = true
      notify "start"
    end

    attr_reader :original_force_cache
    attr_reader :period
    attr_reader :notifier

    def call
      duration = Benchmark.ms {
        if Flipper.enabled?(:disable_region_cache_warmer)
          notify "disabled via flipper - exiting"
          return
        end

        notify "starting facility_group caching"
        Statsd.instance.time("region_cache_warmer.facility_groups") do
          cache_facility_groups
        end

        notify "starting facility caching"
        Statsd.instance.time("region_cache_warmer.facilities") do
          cache_facilities
        end
      }
      notify "finished", duration: duration
    ensure
      RequestStore.store[:force_cache] = original_force_cache
    end

    private

    def notify(msg, extra = {})
      data = {
        logger: {
          name: self.class.name
        },
        class: self.class.name
      }.merge(extra).merge(msg: msg)
      Rails.logger.info data
    end

    def cache_facility_groups
      FacilityGroup.find_each(batch_size: BATCH_SIZE).each do |region|
        RegionService.new(region: region, period: period).call
        Statsd.instance.increment("region_cache_warmer.facility_groups.cache")
      end
    end

    def cache_facilities
      Facility.find_each(batch_size: BATCH_SIZE).each do |region|
        RegionService.new(region: region, period: period).call
        Statsd.instance.increment("region_cache_warmer.facilities.cache")
      end
    end
  end
end
