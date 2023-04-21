require "./spec_helper"

describe PubGrub::StaticPackageSource do
  it "resolves given packages" do
    source = PubGrub::StaticPackageSource.new do |source|
      source.root "foo", ">= 1.0.0"
  
      source.add "foo", "2.0.0", { "bar" => "1.0.0" }
      source.add "foo", "1.0.0"
      source.add "bar", "1.0.0", { "foo" => "1.0.0" }
    end
  
    source.root.should eq({"foo" => ">= 1.0.0"})
  
    source.packages.should eq({
      "foo" => {"2.0.0" => {"bar" => "1.0.0"}},
      "bar" => {"1.0.0" => {"foo" => "1.0.0"}}
    })
  end
end
