class AdjustChargebackReportsFeatures < ActiveRecord::Migration[5.2]
  class MiqProductFeature < ActiveRecord::Base; end
  class MiqRolesFeature < ActiveRecord::Base; end

  FEATURE_MAPPING = {
    'chargeback_download_csv'  => 'chargeback_reports_download_csv',
    'chargeback_download_pdf'  => 'chargeback_reports_download_pdf',
    'chargeback_download_text' => 'chargeback_reports_download_text',
    'chargeback_report_only'   => 'chargeback_reports_report_only'
  }.freeze

  def up
    return if MiqProductFeature.none?

    say_with_time 'Adjusting chargeback reports features for the non-explorer views' do
      new_feature = MiqProductFeature.find_or_create_by!(:identifier => 'chargeback_reports_view')
      MiqRolesFeature.where(:miq_product_feature_id => old_feature_ids).each do |feature|
        MiqRolesFeature.create!(:miq_product_feature_id => new_feature.id, :miq_user_role_id => feature.miq_user_role_id)
      end

      # Direct renaming of features
      FEATURE_MAPPING.each do |from, to|
        MiqProductFeature.find_by(:identifier => from)&.update!(:identifier => to)
      end
    end
  end

  def down
    return if MiqProductFeature.none?

    say_with_time 'Adjusting chargeback reports features to explorer views' do
      admin_feature = MiqProductFeature.find_or_create_by!(:identifier => 'chargeback_reports')

      return if MiqRolesFeature.none?
      MiqRolesFeature.where(:miq_product_feature_id => admin_feature.id).each do |feature|
        old_feature_ids.each do |id|
          MiqRolesFeature.create!(:miq_product_feature_id => id, :miq_user_role_id => feature.miq_user_role_id)
        end
      end

      FEATURE_MAPPING.each do |to, from|
        MiqProductFeature.find_by(:identifier => from)&.update!(:identifier => to)
      end
    end
  end

  private

  def old_feature_ids
    FEATURE_MAPPING.keys.map { |identifier| MiqProductFeature.find_or_create_by!(:identifier => identifier) }
  end
end
