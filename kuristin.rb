require 'kommando'

@opts = {
  output: true,
  timeout: 10
}


@opts_silent = @opts.merge({
  output: false
})

def cleanup
  func_names_k = Kommando.run "$ hyper func ls | tail +2 | cut -f1 -d' '", @opts_silent

  func_names_k.out.split("\n").each do |func_name|
    func_rm_k = Kommando.run "hyper func rm #{func_name}", @opts_silent
    unless func_rm_k.code == 0
      puts func_rm_k.out.inspect
      exit 1
    end
  end
end

while true do
  cleanup_started_at = Time.now
  cleanup
  cleanup_finished_at = Time.now

  started_at = Time.now

  k = Kommando.run "hyper func create --name kuristin mattipaksula/hyper-func-echo", @opts_silent
  func_created_at = Time.now

  matches = k.out.match /with the address of (https:\/\/.*)\r$/
  if matches
    url = "#{matches[1]}/sync"
  else
    puts "failed!"
    puts k.out
    exit 1
  end

  curl_k = Kommando.run "curl -v #{url}", @opts_silent
  call_completed_at = Time.now

  errored = curl_k.code == 0
  print Time.now
  puts " - Total time: #{Time.now-started_at}, func create took: #{func_created_at - started_at}, Call took: #{call_completed_at-func_created_at} (cleanup: #{cleanup_finished_at-cleanup_started_at})"

end
