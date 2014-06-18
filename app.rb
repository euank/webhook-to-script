require 'sinatra'
require 'json'
require 'yaml'
require 'digest/hmac'


config = YAML.load_file("config.yml")


post "/webhook" do
  request.body.rewind

  body = request.body.read

  if(config && config["secret"])
    digest = Digest::HMAC.hexdigest(body, config["secret"], Digest::SHA1)
    if(env["HTTP_X_HUB_SIGNATURE"] != "sha1="+digest)
      error 403
    end
  end

  data = JSON.parse body

  puts data.to_json

  url = data["repository"]["url"]
  ref = data["ref"]
  short_ref = ref.split('/').last
  short_url = data["repository"]["name"]

  config["repositories"].each{|repo|
    name = repo.keys.first
    if([url, short_url].include?(name) &&
       [ref, short_ref].include?(repo[name]["track"]))

      `#{repo[name]["run"]}`
    end
  }

  {ok: 1}
end
