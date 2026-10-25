# encoding: UTF-8
module HP
  module AutoDim
    def self.reliable_line_source?(model, set)
      if set['scan_source_pid']
        source = entity_by_pid(model, set['scan_source_pid'])
        return source && source.valid? && source.respond_to?(:definition)
      end
      anchors = set['anchors'] || [set['a0'], set['a1']]
      anchors.compact.all? { |anchor| resolve_bound(model, anchor) }
    end

    def self.expected_dim_specs(model, set)
      mode = set['mode'] || 'std'
      if %w[cont chain cut].include?(mode)
        return nil unless reliable_line_source?(model, set)
        layout = compute_line(model, set)
        return nil unless layout
      else
        selection = resolve_sources(model, set).compact
        return [] if selection.empty? && set['allow_empty'] && known_empty_sources?(model, set)
        return nil if selection.empty? || selection.size != (set['sel'] || []).size
        context = ctx_entities(model, set['ctx'])
        layout = mode == 'obj' ? compute_obj(selection, obj_two_d?) : compute_layout(context, selection, set['leaf_scope'] == 'named')
        return nil unless layout
      end
      previous = @dim_specs
      @dim_specs = []
      begin
        case mode
        when 'cont', 'chain', 'cut'
          draw_line_set(model.entities, nil, set, layout)
        when 'obj'
          draw_obj_dims(nil, nil, layout, offset_mm * MM)
        else
          layout_dims(nil, nil, layout, offset_mm * MM)
        end
        @dim_specs.dup
      ensure
        @dim_specs = previous
      end
    end

    def self.verify_set(model, set)
      return :manual unless dim_set_state(model, set) == :ok
      specs = expected_dim_specs(model, set)
      return :unresolved unless specs
      mode = set['mode'] || 'std'
      entities = %w[cont chain cut].include?(mode) ? model.entities : ctx_entities(model, set['ctx'])
      items = dim_items(entities, set['id'])
      dimensions = items.flat_map do |item|
        item.is_a?(Sketchup::Group) ? item.entities.grep(Sketchup::DimensionLinear) : [item]
      end
      return :mismatch unless dimensions.size == specs.size
      tolerance = 0.05 * MM
      dimensions.each_with_index do |dimension, index|
        start, finish, offset = specs[index]
        actual_start = dimension.start[1]
        actual_finish = dimension.end[1]
        return :mismatch if actual_start.distance(start).to_f > tolerance || actual_finish.distance(finish).to_f > tolerance
        return :mismatch if (dimension.offset_vector - offset).length.to_f > tolerance
        text = dimension.text.to_s
        expected_text = strip_zeros(Sketchup.format_length(start.distance(finish).to_f))
        return :mismatch unless text.empty? || text == expected_text
      end
      :ok
    rescue StandardError => error
      log_once("HP kiểm tra DIM #{set['id']}: #{error.message}")
      :unresolved
    end

    def self.verify_dimensions
      model = Sketchup.active_model
      return if !model || @updating
      page = current_pgid(model)
      sets = load_sets(model).select { |set| set_in_scene?(set, page) }
      counts = Hash.new(0)
      details = []
      sets.each do |set|
        state = verify_set(model, set)
        counts[state] += 1
        details << "#{set['mode'] || 'std'} / #{set['id']}: #{state}" unless state == :ok
      end
      text = "Kiểm tra DIM ở scene đang mở\n\n" \
             "Khớp hình học, số đoạn, vị trí và chữ: #{counts[:ok]} bộ\n" \
             "Không khớp: #{counts[:mismatch]} bộ\n" \
             "Thiếu liên kết nguồn, chưa xác nhận được: #{counts[:unresolved]} bộ\n" \
             "Nhóm đã sửa tay hoặc mất: #{counts[:manual]} bộ\n\n" \
             "Sai số so sánh tọa độ: 0,05 mm. Số hiển thị vẫn theo độ chính xác Units của model."
      text += "\n\n" + details.join("\n") unless details.empty?
      UI.messagebox(text)
      counts
    rescue StandardError => error
      UI.messagebox("Chưa kiểm tra được DIM: #{error.message}")
      nil
    end
  end
end
