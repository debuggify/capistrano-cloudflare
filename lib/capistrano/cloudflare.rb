require 'capistrano'
require 'capistrano/cloudflare/version'
require 'json'
require 'net/http'

module Capistrano
  module CloudFlare
    def self.send_request(options = {})
      uri = URI('https://www.cloudflare.com/api_json.html')
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      request = Net::HTTP::Post.new(uri.request_uri)

      payload = {
        :a     => 'fpurge_ts',
        :z     => options[:domain],
        :tkn   => options[:api_key],
        :email => options[:email]
      }

      if options[:url].present?
        payload[:v] = 1
        payload[:a] = 'zone_file_purge'
      else
        payload[:url] = options[:url]
        payload[:a] = 'fpurge_ts'
      end

      request.set_form_data(payload)
      response = JSON.parse(http.request(request).body)
    end

    def self.load_into(configuration)
      configuration.set :capistrano_cloudflare, self
      configuration.load do
        namespace :cloudflare do
          namespace :file do

            def purge_file (filepath, protocol)
              response = capistrano_cloudflare.send_request( {url: "#{protocol}://#{filepath}"}.merge(cloudflare_options) )

              if response['result'] == 'success'
                logger.info(" #{protocol}: Yes")
              else
                logger.info(" #{protocol}: No    Reason: #{response['msg'] || 'unknown.'}")
              end
            end

            desc "Purge the CloudFlare single file"
            task :purge, :filename do |t, args|
              # raise unless fetch(:cloudflare_options).respond_to?(:[])
              domain = cloudflare_options[:domain];
              filename = args.filename
              filepath = "www.#{domain}/assets/#{filename}"

              logger.info("\n Purging #{filepath} \n")

              purge_file( filepath, 'http')
              purge_file(filepath, 'https')
            end
          end

          namespace :cache do
            desc "Purge the CloudFlare cache"
            task :purge do
              raise unless fetch(:cloudflare_options).respond_to?(:[])
              response = capistrano_cloudflare.send_request(cloudflare_options)
              if response['result'] == 'success'
                logger.info("Purged CloudFlare cache for #{cloudflare_options[:domain]}")
              else
                logger.info("CloudFlare cache purge failed. Reason: #{response['msg'] || 'unknown.'}")
              end
            end
          end

        end

      end
    end
  end
end

if Capistrano::Configuration.instance
  Capistrano::CloudFlare.load_into(Capistrano::Configuration.instance)
end
