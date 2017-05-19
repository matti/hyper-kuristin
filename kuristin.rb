require 'kommando'

@opts = {
  output: true,
  timeout: 10
}

@opts_silent = @opts.merge({
  output: false
})

def debug msg
  return unless ENV['KURISTIN_DEBUG']
  puts "DEBUG>> #{msg}"
end

def error msg
  puts msg
  exit 1
end

def cleanup
  func_names_k = Kommando.run "$ hyper func ls | tail +2 | cut -f1 -d' '", @opts_silent

  func_names_k.out.split("\n").each do |func_name|
    func_rm_k = Kommando.run "hyper func rm #{func_name}", @opts_silent
    unless func_rm_k.code == 0
      error func_rm_k.out.inspect
      exit 1
    else
      debug "cleaned #{func_name}"
    end
  end
end

pull_k = Kommando.run "hyper pull mattipaksula/hyper-func-kuristin"
error "Pull failed" unless pull_k.code == 0

kuristin_version = 0
while true do
  cleanup_started_at = Time.now
  cleanup
  cleanup_finished_at = Time.now

  started_at = Time.now

  #TODO entrypoint not enough
  k = Kommando.run "hyper func create --name kuristin --env KURISTIN_VERSION=#{kuristin_version} mattipaksula/hyper-func-kuristin ./docker-entrypoint.sh", @opts_silent
  func_created_at = Time.now

  matches = k.out.match /with the address of (https:\/\/.*)\r$/
  if matches
    url = "#{matches[1]}/sync"
    debug "func created #{url}"
  else
    error "func create failed: #{k.out}"
  end

  curl_k = Kommando.run "curl -v #{url}", @opts_silent
  call_completed_at = Time.now

  unless curl_k.code == 0
    puts "func call failed code: #{curl_k.code}, out: #{curl_k.out} - trying again in 3s to see what's up..."
    sleep 3
    curl_k = Kommando.run "curl -v #{url}", @opts
    if curl_k.code == 0
      puts "now it worked"
    else
      puts "nope, still doesn't work, let's see after 10s..."
      sleep 10
      curl_k = Kommando.run "curl -v #{url}", @opts
      if curl_k.code == 0
        puts "now it worked"
      else
        puts "nope, still doesn't work"
      end
    end

    error "func call failed, can't continue"
  end

  if curl_k.out.match "KURISTIN_VERSION: #{kuristin_version}"
    debug curl_k.out
  else
    error "output does not match expected: #{curl_k.out}"
  end

  puts "#{Time.now} - Total time: #{Time.now-started_at}, func create took: #{func_created_at - started_at}, Call took: #{call_completed_at-func_created_at} (cleanup: #{cleanup_finished_at-cleanup_started_at})"

  kuristin_version = kuristin_version + 1
end
