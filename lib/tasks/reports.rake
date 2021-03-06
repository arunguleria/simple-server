# frozen_string_literal: true

require "tasks/scripts/telemedicine_reports"

namespace :reports do
  desc "Generates the telemedicine report, takes the mixpanel report as input"
  task telemedicine: :environment do
    period_start = Date.today.prev_occurring(:monday).beginning_of_day
    period_end = period_start.next_occurring(:sunday).end_of_day

    report = TelemedicineReports.new(period_start, period_end)
    report.generate
  end
end
