# -*- coding: utf-8 -*-
require 'json'

Plugin.create(:meshitero_uploader) do

  # 投稿する画像を取得
  def prepare
    # 投稿済みの一覧の管理
    begin
      meshitero_dir = File.join(__dir__, 'meshitero')
      @meshitero_images = Dir.glob("#{meshitero_dir}/*")
      # 3MB以上の画像は除外する
      @meshitero_images.delete_if { |image| File.stat(image).size > 3145728 }
    rescue => e
      error "Could not find dir: #{e}"
    end
  end


  # 投稿した画像のURLをyaml形式で書き出す
  def write_log(data)
    File.open(File.expand_path('./done.yml'), 'a+') { |f| f.puts(data) }
  end


  # 投稿する
  def post_image
    notice 'start'
    threads = []
    # 画像を4件ごとに処理
    @meshitero_images.each_slice(4) do |images|
      threads << Thread.new {
        # キーをファイル名, 値をIOとするハッシュを生成
        list = Hash.new
        images.each { |i| list[File.basename(i)] = File.open(i) }

        msg = "[画像アップロードテスト] #{File.basename(list.keys.first)}, etc…"
        Service.primary.post(message: msg,
                             mediaiolist: list.values).next { |res|
          # openしていたファイルをclose
          list.each_value { |i| i.close }
          # レスポンスから画像URLを取得してyaml形式で書き出し
          res.entity.to_a.each do |entity|
            puts "image uri: #{entity[:media_url_https]}"
            write_log("- #{entity[:media_url_https]}")
          end
        }.trap { |e| error e }
      }
    end

    threads.each { |t| t.run }
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
