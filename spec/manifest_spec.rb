require 'spec_helper'
require 'json'

describe "Webpack::Rails::Manifest" do
  let(:manifest) do
    <<-EOF
      {
        "errors": [],
        "assetsByChunkName": {
          "entry1": "entry1.js",
          "entry1-a": "entry1-a.js",
          "entry2": "entry2.js"
        },
        "entrypoints": {
          "entry1": {
            "assets": [
              "entry1.js",
              "entry1-a.js"
            ]
          },
          "entry2": {
            "assets": [
              "entry2.js"
            ]
          }
        }
      }
    EOF
  end

  shared_examples_for "a valid manifest" do
    it "should return single entry asset paths from the manifest" do
      expect(Webpack::Rails::Manifest.asset_paths("entry2")).to eq(["/public_path/entry2.js"])
    end

    it "should return multiple entry asset paths from the manifest" do
      expect(Webpack::Rails::Manifest.asset_paths("entry1")).to eq(["/public_path/entry1.js", "/public_path/entry1-a.js"])
    end

    it "should error on a missing entry point" do
      expect { Webpack::Rails::Manifest.asset_paths("herp") }.to raise_error(Webpack::Rails::Manifest::EntryPointMissingError)
    end
  end

  before do
    # Test that config variables work while we're here
    ::Rails.configuration.webpack.dev_server.host = 'client-host'
    ::Rails.configuration.webpack.dev_server.port = 2000
    ::Rails.configuration.webpack.dev_server.manifest_host = 'server-host'
    ::Rails.configuration.webpack.dev_server.manifest_port = 4000
    ::Rails.configuration.webpack.manifest_filename = "my_manifest.json"
    ::Rails.configuration.webpack.public_path = "public_path"
    ::Rails.configuration.webpack.output_dir = "manifest_output"
  end

  context "with dev server enabled" do
    before do
      ::Rails.configuration.webpack.dev_server.enabled = true

      stub_request(:get, "http://server-host:4000/public_path/my_manifest.json").to_return(body: manifest, status: 200)
    end

    describe :asset_paths do
      it_should_behave_like "a valid manifest"

      it "should error if we can't find the manifest" do
        ::Rails.configuration.webpack.manifest_filename = "broken.json"
        stub_request(:get, "http://server-host:4000/public_path/broken.json").to_raise(SocketError)

        expect { Webpack::Rails::Manifest.asset_paths("entry1") }.to raise_error(Webpack::Rails::Manifest::ManifestLoadError)
      end

      describe "webpack errors" do
        context "when webpack has 'Module build failed' errors in its manifest" do
          it "should error" do
            error_manifest = JSON.parse(manifest).merge("errors" => [
              "somethingModule build failed something",
              "I am an error"
            ]).to_json
            stub_request(:get, "http://server-host:4000/public_path/my_manifest.json").to_return(body: error_manifest, status: 200)

            expect { Webpack::Rails::Manifest.asset_paths("entry1") }.to raise_error(Webpack::Rails::Manifest::WebpackError)
          end
        end

        context "when webpack does not have 'Module build failed' errors in its manifest" do
          it "should not error" do
            error_manifest = JSON.parse(manifest).merge("errors" => ["something went wrong"]).to_json
            stub_request(:get, "http://server-host:4000/public_path/my_manifest.json").to_return(body: error_manifest, status: 200)

            expect { Webpack::Rails::Manifest.asset_paths("entry1") }.to_not raise_error
          end
        end

        it "should not error if errors is present but empty" do
          error_manifest = JSON.parse(manifest).merge("errors" => []).to_json
          stub_request(:get, "http://server-host:4000/public_path/my_manifest.json").to_return(body: error_manifest, status: 200)
          expect { Webpack::Rails::Manifest.asset_paths("entry1") }.to_not raise_error
        end
      end
    end

    describe :chunk_path do
      context "when the chunk is in the manifest" do
        it "returns the path to the chunk" do
          expect(Webpack::Rails::Manifest.chunk_path('entry1-a')).to eq("/public_path/entry1-a.js")
        end
      end

      context "when the chunk is not in the manifest" do
        it "returns the path to the chunk" do
          expect { Webpack::Rails::Manifest.chunk_path('not_a_chunk') }.to raise_error(Webpack::Rails::Manifest::EntryPointMissingError)
        end
      end
    end
  end

  context "with dev server disabled" do
    before do
      ::Rails.configuration.webpack.dev_server.enabled = false
      allow(File).to receive(:read).with(::Rails.root.join("manifest_output/my_manifest.json")).and_return(manifest)
    end

    describe :asset_paths do
      it_should_behave_like "a valid manifest"

      it "should error if we can't find the manifest" do
        ::Rails.configuration.webpack.manifest_filename = "broken.json"
        allow(File).to receive(:read).with(::Rails.root.join("manifest_output/broken.json")).and_raise(Errno::ENOENT)
        expect { Webpack::Rails::Manifest.asset_paths("entry1") }.to raise_error(Webpack::Rails::Manifest::ManifestLoadError)
      end
    end
  end
end
