FactoryBot.define do
  factory :facility_group do
    transient do
      org { create(:organization) }
      state_name { Faker::Address.state }
    end

    id { SecureRandom.uuid }
    name { Seed::FakeNames.instance.district }
    description { Faker::Company.catch_phrase }
    organization { org }
    state { state_name }
    protocol

    transient do
      create_parent_region { Flipper.enabled?(:regions_prep) }
    end

    before(:create) do |facility_group, options|
      if options.create_parent_region
        facility_group.organization.region.state_regions.find_by(name: facility_group.state) ||
          create(:region, :state, name: facility_group.state, reparent_to: facility_group.organization.region)
      end
    end

    trait :without_parent_region do
      create_parent_region { false }
    end
  end
end
