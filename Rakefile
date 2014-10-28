require 'time'
require 'yaml'

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

desc 'Generate index.md files'
task :generate_index_files do
  hash = File.open('prod-data.txt').each.map{|l| l.split(/\t/)}.inject({}){|h,d| h[d[0]]={title:d[1],desc:d[2],date:Time.parse(d[3].to_s.strip)};h}
  FileList['_galleries/karola/*'].select{|f| File.directory?(f)}.each do |dir|
    if hash[File.basename(dir)]
      info = hash[File.basename(dir)]
      File.open(File.join(dir, 'index.md'), 'w') do |f|
        f.write <<-EOF.gsub(/^\s+/,'')
          ---
          layout: gallery-index
          title: #{info.fetch(:title)}
          desc: #{info.fetch(:desc)}
          date: #{info.fetch(:date)}
          ---
        EOF
      end
      puts "Wrote to #{dir}"
    end
  end
end

desc 'remove all reized images'
task :remove_resized_images do
  FileList['_galleries/**/resized'].select{|f| File.directory?(f)}.each do |dir|
    rm_rf dir
  end
end

def build
  rm_rf "_site"
  sh "jekyll build -t"
end

desc 'build'
task :build do
  build
end

desc 'release'
task :release do
  tmp_config = "tmp-aws-creds-#{Time.now.to_f}"
  content = <<-CONF.gsub(/^\s+/,'')
    access_key = #{ENV.fetch('AWS_ACCESS_KEY_ID')}
    secret_key = #{ENV.fetch('AWS_SECRET_ACCESS_KEY')}
    access_token = #{ENV['AWS_SECURITY_TOKEN']}
  CONF
  bucket = ENV.fetch('BUCKET_NAME')
  s3cmd = ENV.fetch('S3CMD', 's3cmd')
  sh("#{s3cmd} --version")
  begin
    File.open(tmp_config, "w") {|f| f.write(content)}
    t = Thread.new do
      max_age = 3600
      sh(
        s3cmd,
        '-c', tmp_config,
        'sync', 
        '--verbose',
        '--acl-public', 
        '--delete-removed', 
        "--add-header=Cache-Control:max-age=#{max_age}, must-revalidate",
        '_site/', 
        "s3://#{bucket}"
      )
    end
    sleep 1
    rm_f tmp_config
    t.join
  ensure
    rm_f tmp_config
  end
end
