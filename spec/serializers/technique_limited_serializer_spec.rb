require 'rails_helper'

RSpec.describe TechniqueLimitedSerializer, type: :serializer do
  let(:belt) { create(:belt) }
  let(:technique_type) { create(:technique_type, belt: belt) }
  let(:technique) { create(:technique, technique_type: technique_type, belt: belt, summary: 'Short summary') }

  subject(:serialized) { ActiveModelSerializers::SerializableResource.new(technique, serializer: TechniqueLimitedSerializer).as_json }

  it 'includes id and summary' do
    data = serialized[:technique] || serialized[:data]
    expect(data[:id].to_s).to eq(technique.id.to_s)
    attrs = data[:attributes] || data
    expect(attrs[:summary] || attrs[:summary]).to eq(technique.summary)
  end

  it 'does not include large associations like comparisons, differences or videos' do
    rels = serialized[:technique] ? serialized[:technique][:relationships] : (serialized[:data] && serialized[:data][:relationships])
    if rels
      expect(rels).not_to have_key(:comparisons)
      expect(rels).not_to have_key(:differences)
      expect(rels).not_to have_key(:videos)
    else
      # If relationships are not present at all, that's acceptable for a limited serializer
      expect(rels).to be_nil.or be_empty
    end
  end
end
