require 'fileutils'
require 'zip'
require 'json'

namespace :remote_assets do
  task :upload, [:s3_bucket] do |t, args|
    file_path = File.dirname(__FILE__)
    config_raw = File.open(file_path + "/config.json", "rb").read
    config_json = JSON.parse(config_raw)

    path_to_dir = Dir.pwd + config_json["path_to_remote_assets"]
    app_version = `rake current_app_version`.gsub(".", "_").gsub("\n", "")
    s3_bucket = args[:s3_bucket] != nil ? args[:s3_bucket] : config_json["default_s3_bucket"]
    
    manifest = {}

    assets_dir = 's3_assets'
    manifest_name = "manifest_#{app_version}.json"
    manifest_path = assets_dir + '/' + manifest_name

    if config_json["requires_confirmation"]
      puts "are your sure you want to upload #{manifest_name} to s3://#{s3_bucket} (y/n)?"
      input = STDIN.gets.chomp.downcase
      if !(input == 'y' or input == 'yes')
        return
      end
    end

    path_to_dir.sub!('~', ENV['HOME'])
    Dir.chdir(path_to_dir)

    FileUtils.rm_rf(assets_dir)
    FileUtils.mkdir(assets_dir)

    for file_name in Dir.entries('.') do
      next if file_name.start_with?('.')
      next if file_name == assets_dir
      extension = File.extname(file_name)
      file_path = path_to_dir + '/' + file_name
      file = File.new(file_path, 'r')
      file_contents = file.read
      md5 = Digest::MD5.new
      md5 << file_contents
      url = "https://#{s3_bucket}.s3.amazonaws.com/#{md5}#{extension}"
      key = file_name
      manifest_entry = {
        :checksum => md5.to_s,
        :url => url
      }
      manifest[key] = manifest_entry

      src_path = file_path
      target_path = assets_dir + '/' + md5.to_s + extension
      FileUtils.copy(src_path, target_path)
    end

    for asset_name in Dir.entries(assets_dir) do
      next if asset_name.start_with?('.')
      asset_path = path_to_dir + '/' + assets_dir + '/' + asset_name
      puts `s3cmd put #{asset_path} s3://#{s3_bucket}`
    end

    File.open(manifest_path, 'w+') do |file|
      pretty_json = JSON.pretty_generate(manifest)
      puts "uploading #{manifest_path} :\n#{pretty_json}"
      file.write(pretty_json)
    end

    # always upload manifest last so that all of the assets are present before clobbering the manifest
    puts `s3cmd put #{manifest_path} s3://#{s3_bucket}`

    FileUtils.rm_rf(assets_dir)
  end
end

task :current_app_version do
  version_output = `agvtool what-marketing-version -terse`
  output = /Clinkle-Info.plist"=(.*)\n/.match(version_output)[1]
  puts output.chomp
end