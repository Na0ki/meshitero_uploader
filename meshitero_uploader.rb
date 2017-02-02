# -*- coding: utf-8 -*-
require 'yaml'

Plugin.create(:meshitero_uploader) do

  # 投稿する画像を取得
  def prepare
    # 投稿済みの一覧の管理
    begin
      meshitero_dir = File.join(__dir__, 'meshitero')
      Dir.mkdir(meshitero_dir) unless File.exist?(meshitero_dir)

      @meshitero_images = Dir.glob("#{meshitero_dir}/*.*")
      # 3MB以上の画像は除外する
      @meshitero_images.delete_if { |image| File.stat(image).size > 3145728 }
      notice 'number of images: %{num}' % {num: @meshitero_images.length}
    rescue => e
      error e
    end
  end


  # 投稿する
  def post_image
    prepare

    if @meshitero_images.empty?
      notice '飯テロ画像なんもねぇ…'
      return
    end

    notice "start: #{Time.now.to_s}"

    # 画像を4件ごとに処理
    @meshitero_images.each_slice(4).inject(Delayer::Deferred.new) do |promise, images|
      promise.next do
        # 画像ファイルIOの配列
        list = images.map { |img| File.open(img) }

        # FIXME: 初回以降の投稿が実行されない（特にエラーは表示されない）
        # TODO: Deferred.when() の動作確認をする
        # メモ: service.post() の返す Deferred オブジェクトを確認する
        notice 'going to post images: %{list}' %{list: list}

        Service.primary.post(message: '[飯テロ画像] %{filename}, etc…' % {filename: File.basename(images.first)},
                             mediaiolist: list).next { |message|
          notice 'post message: %{message}' % {message: message}

          # レスポンスから画像URLを取得して配列に格納
          url_list = []
          message.entity.to_a.each do |entity|
            url_list << entity[:media_url_https]
          end

          # 配列のURLを書き出し
          begin
            File.open(File.join(__dir__, 'done.yml'), 'a+') { |f| YAML.dump(url_list, f) }
          rescue => e
            Delayer::Deferred.fail(e)
          end

          notice "post done: #{url_list}"
        }
      end
    end
  end


  # イベント起動
  on_post_meshitero do
    post_image.trap { |e| error e }
  end


  # 手動で確認するとき用
  command(:post_meshitero,
          name: '飯テロ画像投稿',
          condition: lambda { |_| true },
          visible: true,
          role: :postbox
  ) do |_|
    post_image.trap { |e|
      error e
    }.next {
      puts 'upload has been done!'
    }
  end

end
