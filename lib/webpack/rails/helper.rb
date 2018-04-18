require 'action_view'
require 'webpack/rails/manifest'

module Webpack
  module Rails
    # Asset path helpers for use with webpack
    module Helper
      # Return asset paths for a particular webpack entry point.
      #
      # Response may either be full URLs (eg http://localhost/...) if the dev server
      # is in use or a host-relative URl (eg /webpack/...) if assets are precompiled.
      #
      # Will raise an error if our manifest can't be found or the entry point does
      # not exist.
      def webpack_asset_paths(source, extension: nil)
        return "" unless source.present?

        paths = Webpack::Rails::Manifest.asset_paths(source)
        paths = paths.select { |p| p.ends_with? ".#{extension}" } if extension

        if ::Rails.configuration.webpack.dev_server.enabled
          paths.map! { |p| full_path(p) }
        end

        paths
      end

      # Returns the path of a specific chunk by name
      def webpack_chunk_path(name)
        full_path(Webpack::Rails::Manifest.chunk_path(name))
      end

      private

      def full_path(path)
        return path unless ::Rails.configuration.webpack.dev_server.enabled

        protocol = ::Rails.configuration.webpack.dev_server.https ? 'https' : 'http'
        host = ::Rails.configuration.webpack.dev_server.host
        host = instance_eval(&host) if host.respond_to?(:call)
        port = ::Rails.configuration.webpack.dev_server.port

        "#{protocol}://#{host}:#{port}#{path}"
      end
    end
  end
end
