# encoding: UTF-8
module HP
  module AutoDim
    def self.translation_only?(transformation)
      values = transformation.to_a
      identity = IDENTITY_TR.to_a
      (0...12).all? { |i| (values[i] - identity[i]).abs <= 1e-9 } &&
        (values[15] - 1.0).abs <= 1e-9 && values.all? { |value| value.to_f.finite? }
    end

    def self.recovery_parts(root)
      result = []
      walk = lambda do |instances, entities, transform, ancestors|
        (entities.grep(Sketchup::Group) + entities.grep(Sketchup::ComponentInstance)).uniq.each do |part|
          next if hp_dim?(part) || !visible?(part)
          definition = part.definition
          next if ancestors.include?(definition.object_id)
          path = instances + [part]
          current = transform * part.transformation
          result << [part, path, current]
          walk.call(path, definition.entities, current, ancestors + [definition.object_id])
        end
      end
      walk.call([root], root.definition.entities, root.transformation, [root.definition.object_id])
      result
    end

    def self.recovery_anchor(path, transform, vertex)
      local = vertex.position
      world = transform * local
      bounds = path.last.definition.bounds
      ratio = 3.times.map do |index|
        span = bounds.max[index] - bounds.min[index]
        span.abs < 1e-9 ? 0.5 : (local[index] - bounds.min[index]) / span
      end
      {'path' => path.map(&:persistent_id), 'path_hints' => path.map { |part| {'identity' => part_identity(part)} },
       'p' => local.to_a, 'w' => world.to_a, 'v' => vertex.persistent_id, 'local_ratio' => ratio}
    end

    # This command explicitly recreates a full-cabinet cutting span. Once a
    # previous version removed a set, its exact original partial span is gone;
    # never pretend to recover that missing intent or infer an ambiguous source.
    def self.recovery_cut_set(model, group, source)
      id = group.get_attribute(PLUGIN_ID, 'set', nil)
      dimensions = group.entities.grep(Sketchup::DimensionLinear)
      raise 'Nhóm không chỉ gồm DIM cắt HP; giữ nguyên nhóm.' if !id || dimensions.empty? ||
        dimensions.size != group.entities.to_a.size || dimensions.any? { |dim| dim.get_attribute(PLUGIN_ID, 'set', nil) != id }
      raise 'Nhóm đã xoay/Scale; chưa thể khôi phục tự động.' unless translation_only?(group.transformation)
      raise 'Chỉ khôi phục DIM cắt; bộ khác cần dữ liệu nguồn gốc.' unless group.name.to_s.include?('Dim cắt')
      axis = (dimensions.first.end[1] - dimensions.first.start[1]).normalize
      raise 'Các DIM trong nhóm không cùng phương đo.' unless dimensions.all? do |dim|
        vector = dim.end[1] - dim.start[1]
        vector.length.to_f > MM && vector.normalize.dot(axis).abs > 0.9999
      end
      local_axis = source.transformation.inverse * axis
      axis_coordinate = local_axis.to_a.map(&:abs).each_with_index.max[1]
      raise 'Hướng đo không trùng trục tủ; cần chọn lại đường cắt.' if local_axis.normalize[axis_coordinate].abs < 0.9999
      aligned_axis = [0.0, 0.0, 0.0]
      aligned_axis[axis_coordinate] = local_axis[axis_coordinate] < 0 ? -1.0 : 1.0
      axis = (source.transformation * Geom::Vector3d.new(*aligned_axis)).normalize
      offset = dimensions.first.offset_vector
      raise 'Không xác định được phía đặt DIM.' if offset.length.to_f < MM
      offset = offset.normalize
      local_offset = source.transformation.inverse * offset
      coordinate = [local_offset.x, local_offset.y, local_offset.z].map(&:abs).each_with_index.max[1]
      raise 'Chưa hỗ trợ khôi phục theo hướng chéo.' if local_offset.normalize[coordinate].abs < 0.9999
      sides = {0 => ['ENDL', 'ENDR'], 2 => ['BOTTOM', 'TOP']}
      raise 'Chưa xác định được tấm biên của hướng đo này.' unless sides[coordinate]
      positive = local_offset[coordinate] > 0
      aligned_offset = [0.0, 0.0, 0.0]
      aligned_offset[coordinate] = positive ? 1.0 : -1.0
      offset = (source.transformation * Geom::Vector3d.new(*aligned_offset)).normalize
      type = sides[coordinate][positive ? 1 : 0]
      candidates = recovery_parts(source).select { |part, _path, _transform| part.get_attribute('fuji_dict', 'sheet_type', nil) == type }
      raise 'Không tìm được duy nhất tấm biên; không tự gán sang tấm khác.' unless candidates.size == 1
      part, path, transform = candidates.first
      vertices = part.definition.entities.grep(Sketchup::Edge).flat_map { |edge| [edge.start, edge.end] }.uniq
      raise 'Tấm biên thiếu hình học cạnh.' if vertices.empty?
      # Use the actual inner boundary of the current panel and its visible
      # depth edge, not a point scaled from the old cabinet bounding box.
      inner = vertices.map { |v| (transform * v.position - ORIGIN).dot(offset) }.min
      vertices.select! { |v| ((transform * v.position - ORIGIN).dot(offset) - inner).abs < 0.05 * MM }
      depth = axis.cross(offset).normalize
      camera = model.active_view.camera
      facing = camera.direction.dot(depth)
      raise 'Hãy nhìn chính diện mặt đang DIM để khôi phục.' if facing.abs < 0.2
      values = vertices.map { |v| (transform * v.position - ORIGIN).dot(depth) }
      extreme = facing < 0 ? values.max : values.min
      vertices.select! { |v| ((transform * v.position - ORIGIN).dot(depth) - extreme).abs < 0.05 * MM }
      raise 'Không tìm được hai đầu cạnh biên.' if vertices.size < 2
      first, last = vertices.minmax_by { |v| (transform * v.position - ORIGIN).dot(axis) }
      scene = group.get_attribute(PLUGIN_ID, 'scene_id', current_pgid(model))
      raise 'Hãy mở đúng scene của nhóm DIM trước khi khôi phục.' unless scene == 0 || scene == current_pgid(model)
      set = {'id' => id, 'mode' => 'cut', 'a0' => recovery_anchor(path, transform, first),
             'a1' => recovery_anchor(path, transform, last), 'axis' => axis.to_a,
             'od' => offset.to_a, 'perp' => depth.to_a, 'dm' => sc(offset, offset_mm * MM).to_a,
             'gap' => offset_mm, 'leg_policy' => 'settings', 'leg_len_mm' => nil,
             'skip_mm' => cut_skip? ? thick_mm : 0, 'cmode' => cut_mode,
             'cam' => cam_to_a(cam_from_view(model.active_view)), 'pgid' => scene,
             'ndim' => dimensions.size, 'tag_schema' => 219, 'recovered_span' => 'full_source'}
      configure_live_set(model, set, true)
      raise 'Không xác định được phạm vi toàn bộ tủ.' unless set['scan_full_span']
      set
    end

    def self.recover_selected_cut
      model = Sketchup.active_model
      selected = model.selection.to_a
      groups = selected.select { |entity| hp_dim?(entity) }
      raise 'Chọn nhóm DIM cắt HP cần khôi phục.' if groups.empty?
      sources = selected.select do |entity|
        !hp_dim?(entity) && entity.respond_to?(:definition) && entity.parent == model
      end
      if sources.empty?
        sources = (model.entities.grep(Sketchup::Group) + model.entities.grep(Sketchup::ComponentInstance)).uniq.select do |entity|
          entity.get_attribute('fuji_dict', 'comp_type', nil) == 'FujiFrame'
        end
      end
      sets = load_sets(model)
      plans = groups.map do |group|
        id = group.get_attribute(PLUGIN_ID, 'set', nil)
        raise 'Chọn nhóm DIM cắt ở ngoài cùng model.' unless group.is_a?(Sketchup::Group) && group.parent == model
        raise 'Có nhiều nhóm dùng chung mã DIM; giữ nguyên để tránh thay nhầm nhóm.' unless dim_items(model.entities, id) == [group]
        existing = sets.find { |set| set['id'] == id }
        if existing
          raise 'Lệnh này chỉ dùng cho DIM cắt.' unless existing['mode'] == 'cut'
          raise 'Nhóm có chỉnh sửa khác ngoài dịch chuyển; giữ nguyên dữ liệu.' unless dim_set_state(model, existing) == :ok
          set = JSON.parse(JSON.generate(existing))
        else
          raise 'Chọn thêm đúng tủ nguồn; không tự chọn giữa nhiều tủ.' unless sources.size == 1
          set = recovery_cut_set(model, group, sources.first)
        end
        line = compute_line(model, set)
        raise 'Không tính được giao cắt hiện tại; giữ nguyên DIM.' unless line
        [set, line]
      end
      leave_hp_groups(model)
      @updating = true
      model.start_operation('HP Khôi phục liên kết DIM cắt', true)
      started = true
      plans.each do |set, line|
        tag = tag_for(model, set)
        set['ndim'] = replace_dims(model.entities, set, tag) { draw_line_set(model.entities, tag, set, line) }
        set['sig'] = line[:sig]
        set['draw_fp'] = settings_fp
        sets.reject! { |previous| previous['id'] == set['id'] }
        sets << set
      end
      save_sets(model, sets)
      model.commit_operation
      started = false
      Sketchup.status_text = "HP Auto Dim: đã khôi phục #{plans.size} bộ DIM; nhóm mất nguồn được quét theo toàn bộ tủ."
      true
    rescue StandardError => error
      model.abort_operation if started
      UI.messagebox("Chưa khôi phục được: #{error.message}")
      false
    ensure
      @updating = false
      invalidate_tracking(model) if model
    end
  end
end
