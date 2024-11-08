# frozen_string_literal: true

require "spec_helper"

RSpec.describe SiteMaps::NamedRoute do
  it "includes Rails.application.routes.url_helpers" do
    expect(described_class.ancestors).to include(Rails.application.routes.url_helpers)
  end

  it "is a singleton" do
    expect(described_class.instance).to be(SiteMaps::NamedRoute.instance) # rubocop:disable RSpec/DescribedClass
  end

  it 'delegates url helpers to to Rails.application.routes.url_helpers' do
    expect(described_class.instance).to respond_to(:root_path)
    expect(described_class.instance).to respond_to(:post_path)
  end

  it 'forwards class methods to instance' do
    expect(described_class).to respond_to(:root_path)
    expect(described_class).to respond_to(:post_path)
    expect(described_class.posts_path).to eq('/posts')
  end
end
