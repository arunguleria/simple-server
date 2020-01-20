require 'rails_helper'

describe PatientSummary, type: :model do
  include QuarterHelper

  subject(:patient_summary) { PatientSummary.find(patient.id) }

  let(:old_date) { DateTime.new(2019, 1, 1) }
  let(:new_date) { DateTime.new(2019, 5, 1) }
  let(:old_quarter) { "2019 Q1" }
  let(:new_quarter) { "2019 Q2" }

  let!(:patient) { create(:patient, recorded_at: old_date) }

  let!(:old_phone) { create(:patient_phone_number, patient: patient, device_created_at: old_date) }
  let!(:new_phone) { create(:patient_phone_number, patient: patient, device_created_at: new_date) }

  let!(:old_bp) { create(:blood_pressure, patient: patient, recorded_at: old_date) }
  let!(:new_bp) { create(:blood_pressure, patient: patient, recorded_at: new_date, systolic: 110, diastolic: 70) }

  let!(:old_passport) { create(:patient_business_identifier, patient: patient, device_created_at: old_date) }

  let!(:next_appointment) { create(:appointment, patient: patient) }

  let(:med_history) { create(:medical_history, patient: patient) }

  describe "Patient details" do
    it "uses the same ID as patient" do
      expect(patient_summary.id).to eq(patient.id)
    end

    it "includes patient name" do
      expect(patient_summary.full_name).to eq(patient.full_name)
    end

    context "current_age" do
      it "uses DOB as current age if present" do
        date_of_birth = 40.years.ago
        patient.update(date_of_birth: date_of_birth)

        expect(patient_summary.current_age).to eq(40)
      end

      it "calculates current_age if DOB is not present" do
        patient.update(date_of_birth: nil, age: 50, age_updated_at: 13.months.ago)

        expect(patient_summary.current_age).to eq(51)
      end
    end

    it "includes patient gender" do
      expect(patient_summary.gender).to eq(patient.gender)
    end

    it "includes patient address", :aggregate_failures do
      expect(patient_summary.village_or_colony).to eq(patient.address.village_or_colony)
      expect(patient_summary.district).to eq(patient.address.district)
      expect(patient_summary.state).to eq(patient.address.state)
    end
  end

  describe "Registration details" do
    it "includes registration date" do
      expect(patient_summary.recorded_at).to eq(old_date)
    end

    it "calculates registration quarter" do
      expect(patient_summary.registration_quarter).to eq(old_quarter)
    end

    it "includes registration facility details", :aggregate_failures do
      expect(patient_summary.registration_facility_name).to eq(patient.registration_facility.name)
      expect(patient_summary.registration_facility_type).to eq(patient.registration_facility.facility_type)
      expect(patient_summary.registration_district).to eq(patient.registration_facility.district)
      expect(patient_summary.registration_state).to eq(patient.registration_facility.state)
    end
  end

  describe "Latest BP reading" do
    it "includes latest BP measurements", :aggregate_failures do
      expect(patient_summary.latest_bp_systolic).to eq(new_bp.systolic)
      expect(patient_summary.latest_bp_diastolic).to eq(new_bp.diastolic)
    end

    it "includes latest BP date" do
      expect(patient_summary.latest_bp_recorded_at).to eq(new_bp.recorded_at)
    end

    it "includes latest BP quarter" do
      expect(patient_summary.latest_bp_quarter).to eq(new_quarter)
    end

    it "includes latest BP facility details", :aggregate_failures do
      expect(patient_summary.latest_bp_facility_name).to eq(new_bp.facility.name)
      expect(patient_summary.latest_bp_facility_type).to eq(new_bp.facility.facility_type)
      expect(patient_summary.latest_bp_district).to eq(new_bp.facility.district)
      expect(patient_summary.latest_bp_state).to eq(new_bp.facility.state)
    end
  end

  describe "Next appointment details" do
    context "days_overdue" do
      it "set to zero if not overdue" do
        expect(patient_summary.days_overdue).to eq(0)
      end

      it "calculated if overdue" do
        next_appointment.update(scheduled_date: 60.days.ago)
        expect(patient_summary.reload.days_overdue).to eq(60)
      end
    end

    it "includes next appointment date" do
      expect(patient_summary.next_appointment_scheduled_date).to eq(next_appointment.scheduled_date)
    end

    it "includes latest BP facility details", :aggregate_failures do
      expect(patient_summary.next_appointment_facility_name).to eq(next_appointment.facility.name)
      expect(patient_summary.next_appointment_facility_type).to eq(next_appointment.facility.facility_type)
      expect(patient_summary.next_appointment_district).to eq(next_appointment.facility.district)
      expect(patient_summary.next_appointment_state).to eq(next_appointment.facility.state)
    end
  end

  describe "Risk level" do
    context "level 0" do
      it "calculated when systolic >= 180" do
        new_bp.update(systolic: 180)
        expect(patient_summary.reload.risk_level).to eq(0)
      end

      it "calculated when diastolic >= 180" do
        new_bp.update(diastolic: 110)
        expect(patient_summary.reload.risk_level).to eq(0)
      end
    end

    context "level 1" do
      it "calculated when prior heart attack" do
        med_history.update(prior_heart_attack: "yes")
        expect(patient_summary.reload.risk_level).to eq(1)
      end

      it "calculated when prior stroke" do
        med_history.update(prior_stroke: "yes")
        expect(patient_summary.reload.risk_level).to eq(1)
      end

      it "calculated when diabetic" do
        med_history.update(diabetes: "yes")
        expect(patient_summary.reload.risk_level).to eq(1)
      end

      it "calculated when chronic kidney disease" do
        med_history.update(chronic_kidney_disease: "yes")
        expect(patient_summary.reload.risk_level).to eq(1)
      end
    end

    context "level 2" do
      it "calculated when systolic between 160 and 179", :aggregate_failures do
        new_bp.update(systolic: 160)
        expect(patient_summary.reload.risk_level).to eq(2)

        new_bp.update(systolic: 179)
        expect(patient_summary.reload.risk_level).to eq(2)
      end

      it "calculated when diastolic between 100 and 109", :aggregate_failures do
        new_bp.update(diastolic: 100)
        expect(patient_summary.reload.risk_level).to eq(2)

        new_bp.update(diastolic: 109)
        expect(patient_summary.reload.risk_level).to eq(2)
      end
    end

    context "level 3" do
      it "calculated when systolic between 140 and 159", :aggregate_failures do
        new_bp.update(systolic: 140)
        expect(patient_summary.reload.risk_level).to eq(3)

        new_bp.update(systolic: 159)
        expect(patient_summary.reload.risk_level).to eq(3)
      end

      it "calculated when diastolic between 90 and 99", :aggregate_failures do
        new_bp.update(diastolic: 90)
        expect(patient_summary.reload.risk_level).to eq(3)

        new_bp.update(diastolic: 99)
        expect(patient_summary.reload.risk_level).to eq(3)
      end
    end

    context "level 4" do
      it "calculated when systolic <= 140 AND diastolic <= 90" do
        new_bp.update(systolic: 139, diastolic: 89)
        expect(patient_summary.reload.risk_level).to eq(4)
      end
    end

    context "level 5" do
      it "calculated when no BPs are present" do
        patient.blood_pressures.destroy_all
        expect(patient_summary.reload.risk_level).to eq(5)
      end
    end
  end

  describe "BP passport" do
    it "includes latest BP passport number" do
      expect(patient_summary.latest_bp_passport).to eq(patient.latest_bp_passport.identifier)
    end
  end
end
