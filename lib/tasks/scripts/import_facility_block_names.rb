class ImportFacilityBlockNames
  def self.import(file)
    facilities_updated = 0
    facilities_not_found = 0

    CSV.foreach(file, headers: true) do |row|
      district = row["district"]
      facility_name = row["facility"]
      block = row["block"]

      facility = Facility.where(name: facility_name, district: district)
      if facility.present?
        facilities_updated += 1 if facility.update_all(zone: block)
      else
        facilities_not_found += 1
        Rails.logger.info "Facility #{facility_name} in district #{district} not found"
      end
    end

    Rails.logger.info "Updated #{facilities_updated} facilities, #{facilities_not_found} facilities not found"
  end
end
