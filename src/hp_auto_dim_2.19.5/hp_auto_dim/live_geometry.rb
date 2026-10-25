# encoding: UTF-8
module HP
  module AutoDim
    def self.named_leaf?(entity)
      return false unless entity.respond_to?(:definition)
      return true if name_match?(entity, leaf_kw)
      instance_type = entity.get_attribute('fuji_dict', 'comp_type', nil)
      return false if %w[FujiFrame FujiSubFrame].include?(instance_type)
      type = instance_type || entity.definition.get_attribute('fuji_dict', 'comp_type', nil)
      sheet = entity.get_attribute('fuji_dict', 'sheet_type', nil) || entity.definition.get_attribute('fuji_dict', 'sheet_type', nil)
      type == 'door' || sheet == 'smart_door'
    end

    def self.transformed_normal(transform, normal)
      inverse = transform.inverse
      result = Geom::Vector3d.new(inverse.xaxis.dot(normal), inverse.yaxis.dot(normal), inverse.zaxis.dot(normal))
      result.length.to_f > 1e-12 ? result.normalize : result
    end

    # Native definition.bounds includes annotations. Measuring a cabinet which
    # already contains DIM groups must not count its own witness/text extents.
    def self.physical_definition_bounds(model, definition, stack = {})
      check_auto_budget!
      key = definition.entities.object_id
      return Geom::BoundingBox.new if stack[key]
      digest, = definition_geometry_fp(definition, model)
      cache = (runtime(model)[:shape_bounds_cache] ||= {})
      entry = cache[key]
      return entry[1] if entry && entry[0] == digest
      bounds = Geom::BoundingBox.new
      next_stack = stack.merge(key => true)
      definition.entities.each do |entity|
        check_auto_budget!
        case entity
        when Sketchup::Group, Sketchup::ComponentInstance
          next if hp_dim?(entity)
          child = physical_definition_bounds(model, entity.definition, next_stack)
          bounds.add((0..7).map { |i| entity.transformation * child.corner(i) }) unless child.empty?
        when Sketchup::Face, Sketchup::Edge
          child = entity.bounds
          bounds.add(child.min, child.max) unless child.empty?
        end
      end
      cache[key] = [digest, bounds]
      bounds
    end

    def self.physical_bounds(entity, model = Sketchup.active_model)
      return entity.bounds unless entity.respond_to?(:definition)
      local = physical_definition_bounds(model, entity.definition)
      bounds = Geom::BoundingBox.new
      bounds.add((0..7).map { |i| entity.transformation * local.corner(i) }) unless local.empty?
      bounds
    end

    def self.erase_owned_items(entities, items, set_id = nil)
      items.each do |item|
        next unless item.valid?
        id = item.get_attribute(PLUGIN_ID, 'set', nil)
        next unless id && (!set_id || id == set_id)
        if item.is_a?(Sketchup::Group)
          owned = item.entities.grep(Sketchup::Dimension).select { |dimension| dimension.get_attribute(PLUGIN_ID, 'set', nil) == id }
          if item.entities.to_a.size != owned.size
            # Preserve manually added dimensions/geometry even inside an HP group.
            item.entities.erase_entities(owned) unless owned.empty?
            item.delete_attribute(PLUGIN_ID, 'set')
            item.delete_attribute(PLUGIN_ID, 'scene_id')
            next
          end
        end
        entities.erase_entities([item])
      end
    end

    # Resolve sources BEFORE fingerprinting. Otherwise a recreated source with
    # unchanged initial size can leave the fingerprint permanently at missing-PID.
    def self.resolve_sources(model, set)
      context = ctx_entities(model, set['ctx'])
      return [] unless context
      container = context.parent
      (set['sel'] || []).each_with_index.map do |pid, index|
        entity = entity_by_pid(model, pid)
        entity = nil unless anchor_member?(entity, container)
        info = (set['sel_info'] || [])[index]
        if !entity && info && !info['nm'].to_s.empty?
          hint = info.dup
          hint.delete('pid') # old PID may still exist in a different definition
          entity = find_semantic_part(context, hint['identity'])
          entity ||= find_instance_in(context, hint) unless hint['identity']
        end
        entity
      end
    end

    def self.known_empty_sources?(model, set)
      context = ctx_entities(model, set['ctx'])
      return false unless context && !(set['sel'] || []).empty?
      info = set['sel_info'] || []
      (set['sel'] || []).each_with_index.all? do |pid, index|
        hint = info[index]
        entity = entity_by_pid(model, pid)
        (!entity || !entity.valid?) && hint && hint['identity'] && semantic_parts(context, hint['identity']).empty?
      end
    end

    def self.root_for_anchor(model, anchor)
      return nil unless anchor
      pid = (anchor['path'] || []).first || (anchor['trk'] || {})['pid']
      entity = entity_by_pid(model, pid) if pid
      entity if entity && entity.valid? && entity.respond_to?(:definition) && entity.parent == model
    end

    def self.configure_live_set(model, set, explicit = false)
      return unless %w[cont cut chain].include?(set['mode'])
      return if !explicit && pref('live_partitions', 1).to_i != 1
      anchors = set['anchors'] || [set['a0'], set['a1']]
      endpoints = [anchors.first, anchors.last]
      roots = endpoints.map { |anchor| root_for_anchor(model, anchor) }.compact.uniq
      return unless roots.size == 1
      if set['mode'] == 'cont'
        return if anchors.any? { |anchor| root_for_anchor(model, anchor) != roots.first }
        points = anchors.map { |anchor| resolve_anchor(model, anchor) }
        return if points.any?(&:nil?)
        axis = Geom::Vector3d.new(*set['axis']).normalize
        projected = points.map { |point| (point - points.first).dot(axis).to_f }
        deltas = projected.each_cons(2).map { |a, b| b - a }.reject { |delta| delta.abs < 0.01 * MM }
        unless deltas.empty? || deltas.all? { |delta| delta > 0 } || deltas.all? { |delta| delta < 0 }
          set['follow_surfaces'] = false
          set['scan_full_span'] = false
          return
        end
      end
      root = roots.first
      points = endpoints.map { |anchor| resolve_anchor(model, anchor) }
      return if points.any?(&:nil?)
      axis = Geom::Vector3d.new(*set['axis']).normalize
      origin = points.first
      bounds = physical_bounds(root, model)
      interval = (0..7).map { |i| (bounds.corner(i) - origin).dot(axis).to_f }.minmax
      picked = points.map { |point| (point - origin).dot(axis).to_f }.minmax
      tolerance = [thick_mm, 25.0].max * MM
      local = root.transformation.inverse * origin
      set['scan_reference'] = [local.x.to_f, local.y.to_f, local.z.to_f]
      set['scan_directions'] = {}
      %w[axis od perp].each do |key|
        next unless set[key]
        vector = root.transformation.inverse * Geom::Vector3d.new(*set[key])
        set['scan_directions'][key] = [vector.x.to_f, vector.y.to_f, vector.z.to_f]
      end
      set['scan_source_pid'] = root.persistent_id
      set['scan_full_span'] = picked[0] <= interval[0] + tolerance && picked[1] >= interval[1] - tolerance
      set['follow_surfaces'] = true if set['mode'] == 'cont'
      set['scan_recessed'] = true if (set['cmode'] || cut_mode) == 'base'
    end

    def self.measuring_direction(model, set, key)
      local = (set['scan_directions'] || {})[key]
      source = entity_by_pid(model, set['scan_source_pid']) if local && set['scan_source_pid']
      if source && source.valid? && source.respond_to?(:transformation)
        vector = source.transformation * Geom::Vector3d.new(*local)
      elsif set[key]
        vector = Geom::Vector3d.new(*set[key])
      end
      vector && vector.length.to_f > 1e-9 ? vector.normalize : nil
    end

    def self.scan_depth_direction(model, set, axis)
      return nil unless set['scan_recessed'] && set['scan_source_pid']
      offset = measuring_direction(model, set, 'od')
      normal = offset && axis.cross(offset)
      normal && normal.length.to_f > 1e-9 ? normal.normalize : nil
    end

    def self.scan_reference_point(model, set)
      return nil unless set['scan_full_span'] && set['scan_reference'] && set['scan_source_pid']
      source = entity_by_pid(model, set['scan_source_pid'])
      return nil unless source && source.valid? && source.respond_to?(:transformation)
      source.transformation * Geom::Point3d.new(*set['scan_reference'])
    end

    def self.scan_span(model, set, first, last, axis)
      return [first, last] unless set['scan_full_span'] && set['scan_source_pid']
      source = entity_by_pid(model, set['scan_source_pid'])
      return nil unless source && source.valid? && source.respond_to?(:bounds)
      bounds = physical_bounds(source, model)
      return nil if bounds.empty?
      low, high = (0..7).map { |i| (bounds.corner(i) - first).dot(axis).to_f }.minmax
      [first + sc(axis, low), first + sc(axis, high)]
    end

    def self.live_cont_points(model, set, axis)
      anchors = set['anchors'] || []
      return nil if anchors.size < 2
      first = resolve_anchor(model, anchors.first) || scan_reference_point(model, set)
      last = resolve_anchor(model, anchors.last)
      last ||= first + axis if first && set['scan_full_span']
      return nil unless first && last
      span = scan_span(model, set, first, last, axis)
      return nil unless span
      first, last = span
      distance = (last - first).dot(axis).to_f
      return nil if distance.abs < MM
      # Scan only the chosen span, not a neighbouring cabinet or the whole model.
      direction = distance < 0 ? sc(axis, -1) : axis
      length = distance.abs
      padding = 0.5 * MM
      hits = cut_hits(model, first - sc(direction, padding),
                     first + sc(direction, length + padding), cam_from_a(set['cam']),
                     set['cmode'] || 'base', set['scan_recessed'] == true, set['scan_source_pid'], scan_depth_direction(model, set, axis))
      positions = [0.0, length]
      hits.each do |hit|
        position = hit - padding
        next if position < -0.01 * MM || position > length + 0.01 * MM
        positions << [[position, 0.0].max, length].min
      end
      positions.sort!
      unique = []
      positions.each { |v| unique << v if unique.empty? || v - unique.last > 0.2 * MM }
      unique.map { |v| first + sc(direction, v) }
    end

    # Explicit conversion of selected HP sets, with a native undo operation.
    # No mass migration on opening a document; no changes to manual dimensions.
    def self.follow_partitions
      model = Sketchup.active_model
      ids = model.selection.map { |entity| entity.get_attribute(PLUGIN_ID, 'set', nil) }.compact.uniq
      sets = load_sets(model)
      selected = sets.select { |set| ids.include?(set['id']) && %w[cont chain cut].include?(set['mode']) }
      if selected.empty?
        UI.messagebox('Chọn nhóm DIM liên tiếp hoặc DIM cắt HP cần theo dõi thêm/bớt đợt, hồi.')
        return false
      end
      leave_hp_groups(model)
      @updating = true
      model.start_operation('HP DIM theo dõi đợt, hồi', true)
      started = true
      selected.each do |set|
        raise 'Nhóm DIM đã sửa tay hoặc bị mất; giữ nguyên dữ liệu.' unless dim_set_state(model, set) == :ok
        configure_live_set(model, set, true)
        raise 'Không xác định được group nguồn; không tự đoán lại điểm đo.' unless set['scan_source_pid']
        set['follow_surfaces'] = true if set['mode'] == 'cont'
        set['scan_recessed'] = true
        line = compute_line(model, set)
        raise 'Không xác định được hai đầu đường đo; giữ nguyên DIM.' unless line
        tag = tag_for(model, set)
        count = replace_dims(model.entities, set, tag) { draw_line_set(model.entities, tag, set, line) }
        set['ndim'] = count
        set['sig'] = line[:sig]
        set['draw_fp'] = settings_fp
      end
      save_sets(model, sets)
      model.commit_operation
      started = false
      Sketchup.status_text = "HP Auto Dim: #{selected.size} bộ DIM theo dõi giao cắt đợt/hồi; dung sai ngang #{lat_mm} mm."
      true
    rescue StandardError => error
      model.abort_operation if started
      UI.messagebox("Chưa bật theo dõi đợt/hồi: #{error.message}")
      false
    ensure
      @updating = false
      invalidate_tracking(model) if model
    end
  end
end
