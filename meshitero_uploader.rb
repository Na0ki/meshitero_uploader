# -*- coding: utf-8 -*-
require 'base64'
require 'json'

Plugin.create(:meshitero_uploader) do

  # 投稿する画像を取得
  def prepare
    # 投稿済みの一覧の管理
    begin
      meshitero_dir = File.join(__dir__, 'meshitero')
      @meshitero_images = Dir.glob("#{meshitero_dir}/*")
    rescue => e
      error "Could not find dir: #{e}"
    end
  end


  # 投稿した画像のURLをyaml形式で書き出す
  def write_log(data)
    File.open('done.yml', 'a') do |f|
      f.puts('---') unless f.readlines[0].equal?('---')
      f.puts(data)
    end
  end


  # 投稿する
  def post_image
    puts 'start'
    threads = []
    @meshitero_images.each_slice(4) do |images|
      threads << Thread.new {
        list = Hash.new
        images.each { |i| list[File.basename(i)] = File.open(i) }
        Service.primary.post(message: "[テスト] 飯テロ画像: #{File.basename(list.keys.first)}, etc…",
                             mediaiolist: list.values).next { |res|
          list.each_value { |i| i.close }
          res.entity.to_a.each do |entity|
            puts "image uri: #{entity[:media_url_https]}"
            write_log("- #{entity[:media_url_https]}")
          end
        }.trap { |e| error e }
      }
    end

    threads.each { |t| t.join }
  end


  command(:post_meshitero,
          name: '飯テロ画像投稿',
          condition: lambda { |_| true },
          visible: true,
          role: :postbox
  ) do |_|
    prepare
    post_image
  end

end
