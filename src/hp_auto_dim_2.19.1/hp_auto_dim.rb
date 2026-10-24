# encoding: UTF-8
require 'sketchup.rb'
require 'extensions.rb'

module HP
  module AutoDim
    PLUGIN_ID      = 'HP_AutoDim'.freeze
    PLUGIN_NAME    = 'HP Auto Dim'.freeze
    PLUGIN_VERSION = '2.19.1'.freeze

    unless file_loaded?(__FILE__)
      if Sketchup.version.to_i < 23
        UI.messagebox('HP Auto Dim 2.19.1 yêu cầu SketchUp 2023 trở lên.')
      else
        ex = SketchupExtension.new(PLUGIN_NAME, 'hp_auto_dim/main')
        ex.version     = PLUGIN_VERSION
        ex.creator     = 'HP'
        ex.copyright   = '2026'
        ex.description = 'Dim liên tiếp, dim cắt, kích thước cánh/lỗ, đo nhanh. DIM theo scene và loại trong thư mục HP DIM và cập nhật theo đối tượng; mở file không tự quét/dựng DIM.'
        Sketchup.register_extension(ex, true)
      end
      file_loaded(__FILE__)
    end
  end
end
