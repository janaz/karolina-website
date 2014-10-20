namespace :jekyll do
  desc "compile and run the site"
  task :start do
    pids = [
        spawn("jekyll serve -w --drafts --trace"), # put `auto: true` in your _config.yml
        spawn("scss --watch assets"),
#    spawn("coffee -b -w -o javascripts -c assets/*.coffee")
    ]
    spawn("sleep 3 && open http://localhost:4000/")

    trap "INT" do
      Process.kill "INT", *pids
      exit 1
    end

    loop do
      sleep 1
    end
  end
end

task :default => %w(jekyll:start)
