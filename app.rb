require 'sinatra'
require 'json'
require 'open3'
require 'yaml'
require 'digest/hmac'


config = YAML.load_file("config.yml")


config.each_pair do |path, info|
  post path do
    request.body.rewind
    body = request.body.read

    to_run = info["run"]

    if info["github"]
      if info["secret"]
        digest = Digest::HMAC.hexdigest(body, config["secret"], Digest::SHA1)

        error 403 if(env["HTTP_X_HUB_SIGNATURE"] != "sha1="+digest)
      end

      data = JSON.parse body
      url = data["repository"]["url"] rescue nil
      ref = data["ref"] rescue nil
      short_ref = ref.split('/').last rescue nil
      short_url = data["repository"]["name"] rescue nil

      unless [url, short_url].include? info["github"]["repo"]
        error(403, {error: "Wrong repo for this webhook"})
      end
      unless [ref, short_ref].include? info["github"]["track"]
        return {info: "Not tracking this branch, no action taken"}
      end
    end

    begin
      stdout, stderr, status = Open3.capture3 to_run
    rescue Exception => e
      error(400, {error: "Exceptun running hook script: " + e.to_s})
    end

    {status: status.exitstatus, stdout: stdout, stderr: stderr}
  end
end
