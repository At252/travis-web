# Make sure we set that before everything
ENV['RACK_ENV'] ||= ENV['RAILS_ENV'] || ENV['ENV']
ENV['RAILS_ENV']  = ENV['RACK_ENV']

$: << 'lib'
require 'travis/web'

class RedirectSubdomain < Struct.new(:app, :from)
  def call(env)
    request = Rack::Request.new(env)
    if request.host == from
      [301, { 'Location' => "https://travis-ci.org#{request.fullpath}", 'Content-Type' => 'text/html' }, []]
    else
      app.call(env)
    end
  end
end

class RedirectPages < Struct.new(:app, :from, :to, :page)
  def call(env)
    request = Rack::Request.new(env)
    if  request.host == from && request.fullpath == page
      [301, { 'Location' => "https://#{to}#{request.fullpath}", 'Content-Type' => 'text/html' }, []]
    else
      app.call(env)
    end
  end
end

if ENV['TRAVIS_PRO']
  ENV['API_ENDPOINT'] ||= "https://api.travis-ci.com"
  ENV['PAGES_ENDPOINT'] ||= "https://travis-ci.com/account/plan"
  ENV['BILLING_ENDPOINT'] ||= "https://travis-ci.com/account/plan"

  ENV['SSH_KEY_ENABLED'] = 'true' unless ENV.has_key?('SSH_KEY_ENABLED')
  ENV['CACHES_ENABLED'] = 'true' unless ENV.has_key?('CACHES_ENABLED')

  ENV['PUSHER_KEY'] ||= "59236bc0716a551eab40"
  ENV['GA_CODE'] ||= "UA-24868285-5"

  ENV['REDIRECT_FROM'] ||= "travis-ci.org"
  ENV['REDIRECT_TO'] ||= "app.travis-ci.com"
  ENV['TRAVIS_WP_SITE'] ||= "www.travis-ci.com"
end

unless ENV['TRAVIS_PRO']
  if ENV['REDIRECT']
    use RedirectSubdomain, 'secure.travis-ci.org'
    use RedirectPages, ENV['REDIRECT_FROM'], ENV['REDIRECT_TO'], '/signin'
    use RedirectPages, ENV['REDIRECT_FROM'], ENV['REDIRECT_TO'], '/signup'
    use RedirectPages, ENV['REDIRECT_FROM'], ENV['TRAVIS_WP_SITE'],  '/help'
    use RedirectPages, ENV['REDIRECT_FROM'], ENV['TRAVIS_WP_SITE'],  '/'
  end
end

use RedirectPages, ENV['REDIRECT_TO'], ENV['TRAVIS_WP_SITE'],  '/help' if ENV['TRAVIS_PRO'] && ENV['REDIRECT']

use Rack::MobileDetect, :redirect_to => ENV['MOBILE_ENDPOINT'] if ENV['MOBILE_ENDPOINT']

use Travis::Web::SentryDeployHook

use Travis::Web::SetToken
use Travis::Web::Allow

use Travis::Web::ApiRedirect do |app|
  app.settings.api_endpoint = ENV['API_ENDPOINT'] if ENV['API_ENDPOINT']
end

if ENV['TRAVIS_ENTERPRISE']
  ENV['SSH_KEY_ENABLED'] = 'true' unless ENV.has_key?('SSH_KEY_ENABLED')
  ENV['CACHES_ENABLED'] = 'true' unless ENV.has_key?('CACHES_ENABLED')
end

run Travis::Web::App.build(
  userlike:        ENV['USERLIKE'],
  environment:     ENV['RACK_ENV'] || 'development',
  api_endpoint:    ENV['API_ENDPOINT'],
  github_apps_endpoint: 'https://github.com/apps',
  pages_endpoint:   ENV['PAGES_ENDPOINT'],
  billing_endpoint: ENV['BILLING_ENDPOINT'],
  source_endpoint: ENV['SOURCE_ENDPOINT'] || 'https://github.com',
  pusher_key:      ENV['PUSHER_KEY'],
  pusher_host:     ENV['PUSHER_HOST'] || 'ws.pusherapp.com',
  pusher_path:     ENV['PUSHER_PATH'],
  pusher_channel_prefix: ENV['PUSHER_CHANNEL_PREFIX'],
  ga_code:         ENV['GA_CODE'],
  root:            File.expand_path('../../dist', __FILE__),
  server_start:    Time.now,
  caches_enabled:  ENV['CACHES_ENABLED'],
  ssh_key_enabled: ENV['SSH_KEY_ENABLED'],
  pusher_log_fallback:  ENV['PUSHER_LOG_FALLBACK'],
  customer_io_site_id: ENV['CUSTOMER_IO_SITE_ID'],
  pro: ENV['TRAVIS_PRO'],
  enterprise: ENV['TRAVIS_ENTERPRISE'],
  public_mode: ENV['PUBLIC_MODE'],
  assets_host: ENV['ASSETS_HOST'],
  ajax_polling: ENV['AJAX_POLLING'],
  github_orgs_oauth_access_settings_url: ENV['GITHUB_ORGS_OAUTH_ACCESS_SETTINGS_URL'],
  github_apps_app_name: ENV['GITHUB_APPS_APP_NAME'],
  enable_feature_flags: ENV['ENABLE_FEATURE_FLAGS'],
  stripe_publishable_key: ENV['STRIPE_PUBLISHABLE_KEY'],
  default_provider: ENV['DEFAULT_PROVIDER']
)
