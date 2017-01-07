# -*- coding: utf-8 -*-

Plugin.create(:meshitero_uploader) do

  # 投稿する画像を取得
  def prepare
    # 投稿済みの一覧の管理
    begin
      meshitero_dir = File.join(__dir__, 'meshitero')
      @meshitero_images = Dir.glob("#{meshitero_dir}/*.*")
      # 3MB以上の画像は除外する
      @meshitero_images.delete_if { |image| File.stat(image).size > 3145728 }
    rescue => e
      error "Could not find dir: #{e}"
    end
  end


  # 投稿した画像のURLをyaml形式で書き出す
  # @param [String] 書き出すデータ
  def write_log(data)
    File.open(File.join(__dir__, 'done.yml'), 'a+') { |f| f.puts(data) }
  end


  # 投稿する
  def post_image
    prepare

    return if @meshitero_images.empty?
    notice "start: #{Time.now.to_s}"

    # 画像を4件ごとに処理
    @meshitero_images.each_slice(4).inject(Delayer::Deferred.new) do |promise, images|
      promise.next do
        # キーをファイル名, 値をIOとするハッシュを生成
        list = images.map { |img| File.open(img) }

        msg = "[飯テロ画像] #{File.basename(File.basename(images.first))}, etc…"
        Service.primary.update(message: msg,
                               mediaiolist: list).next { |message|
          # レスポンスから画像URLを取得してyaml形式で書き出し
          message.entity.to_a.each do |entity|
            notice "image uri: #{entity[:media_url_https]}"
            write_log("- #{entity[:media_url_https]}")
          end
        }.next { |message|
          Thread.new { sleep(60) }
          message
        }
      end
    end
  end


  # 勝手に開始させる
  # post_image.trap { |err| error err }


  # 手動で確認するとき用
  command(:post_meshitero,
          name: '飯テロ画像投稿',
          condition: lambda { |_| true },
          visible: true,
          role: :postbox
  ) do |_|
    post_image.trap { |err| error err }
  end

end
