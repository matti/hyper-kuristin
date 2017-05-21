require 'kommando'

@opts = {
  output: true,
  timeout: 60
}

@opts_silent = @opts.merge({
  output: false
})

Kommando.when :timeout do |k|
    puts "TIMED OUT!"
    puts k.out
    exit 1
end


@debug_output = File.open "debug.txt", "a"
def debug msg
  @debug_output.puts "#{msg}"
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
  calls_failed = 0
  output_good = true

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


  while true do
    curl_k = Kommando.run "curl -v #{url}", @opts_silent
    call_completed_at = Time.now

    unless curl_k.code == 0
      debug "func call failed code: #{curl_k.code}, out: #{curl_k.out} - trying again in 1s to see what's up..."
      calls_failed = calls_failed + 1
      sleep 1
    else
      break
    end
  end

  if curl_k.out.match "KURISTIN_VERSION: #{kuristin_version}"
    debug curl_k.out
  else
    debug "output does not match expected: #{curl_k.out}"
    output_good = false
  end

  puts "#{Time.now} - Total time: #{Time.now-started_at}, func create took: #{func_created_at - started_at}, Call took: #{call_completed_at-func_created_at} - Number of calls needed: #{calls_failed} - Got output: #{output_good} (cleanup: #{cleanup_finished_at-cleanup_started_at})"

  kuristin_version = kuristin_version + 1
end
