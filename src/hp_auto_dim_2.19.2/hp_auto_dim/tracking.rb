# encoding: UTF-8
require 'digest'

module HP
  module AutoDim
    # Runtime data belongs to a live model, not its saved GUID. Two documents
    # can share a GUID; timers and fingerprints must still remain independent.
    def self.runtime(model)
      @runtimes ||= {}
      @runtimes[model.object_id] ||= {
        model: model, fp_cache: {}, geometry_cache: {}, revisions: {},
        watchers: {}, geometry_epoch: 0, cache_epoch: 0,
        pending: false, timer: nil, perf: {},
        pid_cache: {}, regions: {}, root_index: nil, tx: 0,
        generation: 0, job: nil, slow_sets: {}, transaction_open: false,
        saving: false, attach_timer: nil
      }
    end

    # Ruby Console output is slow while the console is open; repeated errors
    # from draw/observer callbacks must not flood it every frame.
    def self.log_once(msg)
      @logged ||= {}
      return if @logged[msg]
      @logged.clear if @logged.size > 200
      @logged[msg] = true
      puts msg
    end

    def self.geometry_changed(model, entities, entity = nil)
      return if @updating
      return if entity && (entity.is_a?(Sketchup::Dimension) || hp_dim?(entity))
      state = runtime(model)
      key = entities.object_id
      state[:revisions][key] = state[:revisions].fetch(key, 0) + 1
      state[:geometry_epoch] += 1
    rescue StandardError => error
      log_once("HP geometry observer: #{error.message}")
    end

    def self.note_transaction(model)
      return if @updating
      state = runtime(model)
      state[:tx] += 1
      state[:generation] += 1
      state[:job] = nil
      state[:root_index] = nil
    end

    def self.record_time(model, key, seconds)
      stat = (runtime(model)[:perf][key] ||= {count: 0, last: 0.0, max: 0.0})
      stat[:count] += 1
      stat[:last] = seconds
      stat[:max] = seconds if seconds > stat[:max]
    end

    # ---- Không làm gì khi người dùng đang xoay / pan / zoom ----
    # Ruby chạy chung luồng với giao diện SketchUp: bất kỳ việc gì chạy lúc
    # camera đang chuyển động đều làm màn hình khựng lại.
    def self.camera_key(model)
      cam = model.active_view.camera
      e = cam.eye
      t = cam.target
      u = cam.up
      size = cam.perspective? ? cam.fov.to_f : cam.height.to_f
      [e.x.to_f, e.y.to_f, e.z.to_f, t.x.to_f, t.y.to_f, t.z.to_f, u.x.to_f, u.y.to_f, u.z.to_f, size]
    rescue StandardError
      nil
    end

    # true nếu camera đã đổi kể từ lần kiểm tra trước
    def self.camera_moving?(model)
      state = runtime(model)
      key = camera_key(model)
      moving = !state[:cam_key].nil? && key != state[:cam_key]
      state[:cam_key] = key
      moving
    end

    # ---- Tìm entity theo persistent id ----
    # Model#find_entity_by_persistent_id duyệt cả model ở mỗi lần gọi; với
    # model lớn, gọi lặp cho từng pid mỗi 3 giây làm SketchUp giật. Tra cứu
    # được gom thành một lượt và nhớ lại tới khi entity bị xóa.
    def self.batch_find(model, pids)
      if pids.size > 128
        return pids.each_slice(128).flat_map do |chunk|
          check_auto_budget!
          batch_find(model, chunk)
        end
      end
      if pids.size > 1
        begin
          found = model.find_entity_by_persistent_id(pids)
          return found if found.is_a?(Array) && found.size == pids.size
        rescue StandardError
          nil
        end
      end
      pids.map { |pid| model.find_entity_by_persistent_id(pid) }
    end

    def self.entities_by_pid(model, pids)
      state = runtime(model)
      cache = state[:pid_cache]
      out = {}
      miss = []
      pids.uniq.each do |pid|
        next if pid.nil? || out.key?(pid)
        hit = cache[pid]
        if hit
          e = hit[0]
          if e
            if e.valid?
              out[pid] = e
              next
            end
          elsif hit[1] == state[:tx]
            # Not found during this transaction: no need to search again.
            out[pid] = nil
            next
          end
        end
        miss << pid
      end
      unless miss.empty?
        found = batch_find(model, miss)
        miss.each_with_index do |pid, i|
          e = found[i]
          e = nil unless e && e.valid?
          cache[pid] = [e, state[:tx]]
          out[pid] = e
        end
      end
      out
    end

    def self.entity_by_pid(model, pid)
      return nil if pid.nil?
      entities_by_pid(model, [pid])[pid]
    end

    def self.remember_entities(model, entities)
      state = runtime(model)
      entities.each do |entity|
        state[:pid_cache][entity.persistent_id] = [entity, state[:tx]] if entity && entity.valid?
      end
    end

    def self.watch_entities(model, entities)
      state = runtime(model)
      key = entities.object_id
      return true if state[:watchers][key]
      observer = HPGeometryObserver.new(model)
      return false unless entities.add_observer(observer)
      state[:watchers][key] = [entities, observer]
      state[:revisions][key] ||= 0
      true
    end

    def self.layer_visible?(layer)
      return true unless layer
      return false unless layer.visible?
      folder = layer.respond_to?(:folder) ? layer.folder : nil
      while folder
        return false unless folder.visible?
        folder = folder.folder
      end
      true
    end

    def self.point_fp(point)
      [point.x, point.y, point.z].map { |value| (value.to_f / (0.01 * MM)).round }
    end

    def self.entity_geometry_fp(entity, model, stack = {})
      check_auto_budget!
      return ['invalid'] unless entity && entity.valid?
      parts = [entity.persistent_id, entity.class.name]
      parts << entity.name if entity.respond_to?(:name)
      parts << (entity.hidden? ? 1 : 0) if entity.respond_to?(:hidden?)
      parts << (layer_visible?(entity.layer) ? 1 : 0) if entity.respond_to?(:layer)
      case entity
      when Sketchup::Group, Sketchup::ComponentInstance
        parts.concat(entity.transformation.to_a.map { |value| value.to_f.round(9) })
        parts << entity.definition.name
        bounds = entity.definition.bounds
        parts.concat(point_fp(bounds.min)) unless bounds.empty?
        parts.concat(point_fp(bounds.max)) unless bounds.empty?
        digest, = definition_geometry_fp(entity.definition, model, stack)
        parts << digest
      when Sketchup::Edge
        parts.concat(point_fp(entity.start.position))
        parts.concat(point_fp(entity.end.position))
        curve = entity.curve
        if curve && curve.respond_to?(:radius)
          parts << curve.radius.to_f.round(9)
          parts.concat(point_fp(curve.center))
        end
      when Sketchup::Face
        entity.vertices.each { |vertex| parts.concat(point_fp(vertex.position)) }
      when Sketchup::SectionPlane
        parts.concat(entity.get_plane.map { |value| value.to_f.round(9) })
        parts << (entity.active? ? 1 : 0)
      else
        parts.concat(point_fp(entity.position)) if entity.respond_to?(:position)
      end
      parts
    end

    # A definition is scanned once after a change, even if many instances/sets
    # use it. Cache validity includes every nested collection's revision.
    # When the collection is observed, every edit inside it bumps its revision,
    # so the digest is built from revisions; only nested instances are visited
    # instead of reading every vertex of every face again.
    def self.definition_geometry_fp(definition, model, stack = {})
      state = runtime(model)
      entities = definition.entities
      key = entities.object_id
      cacheable = watch_entities(model, entities)
      entry = state[:geometry_cache][key]
      if cacheable && entry && entry[:epoch] == state[:cache_epoch] && entry[:tx] == state[:tx] &&
         entry[:dependencies].all? { |id, revision| state[:watchers][id] && state[:revisions].fetch(id, 0) == revision }
        return [entry[:digest], entry[:dependencies]]
      end
      return ['recursive-definition', {}] if stack[key]
      stack = stack.merge(key => true)
      dependencies = {key => state[:revisions].fetch(key, 0)}
      parts = [definition.name]
      parts << "e#{state[:cache_epoch]}" << "r#{dependencies[key]}" if cacheable
      entities.each do |entity|
        check_auto_budget!
        if entity.is_a?(Sketchup::Group) || entity.is_a?(Sketchup::ComponentInstance)
          next if hp_dim?(entity)
          if cacheable
            nested_digest, nested = definition_geometry_fp(entity.definition, model, stack)
            parts.concat(entity.transformation.to_a.map { |value| value.to_f.round(9) })
            parts << entity.persistent_id << (entity.hidden? ? 1 : 0)
            parts << (layer_visible?(entity.layer) ? 1 : 0)
            parts << nested_digest
          else
            parts.concat(entity_geometry_fp(entity, model, stack))
            _, nested = definition_geometry_fp(entity.definition, model, stack)
          end
          dependencies.merge!(nested)
        else
          next if cacheable || entity.is_a?(Sketchup::Dimension)
          parts.concat(entity_geometry_fp(entity, model, stack))
        end
      end
      digest = Digest::SHA256.hexdigest(parts.join('|'))
      if cacheable && dependencies.keys.all? { |id| state[:watchers][id] }
        state[:geometry_cache][key] = {digest: digest, dependencies: dependencies, epoch: state[:cache_epoch], tx: state[:tx]}
      end
      [digest, dependencies]
    end

    # ---- Vùng ảnh hưởng của Dim cắt / Dim liên tiếp ----
    # Trước đây mọi chỉnh sửa ở bất kỳ đâu trong model đều làm tính lại TẤT CẢ
    # bộ dim cắt của scene (mỗi bộ quét giao cắt cả model). Giờ chỉ những đối
    # tượng ngoài cùng có hộp bao chạm đường đo (cộng dung sai) mới được đưa
    # vào dấu vân tay của bộ dim đó.
    def self.root_index(model)
      state = runtime(model)
      observed = watch_entities(model, model.entities)
      idx = state[:root_index]
      if observed && idx && idx[:epoch] == state[:geometry_epoch] && idx[:cache_epoch] == state[:cache_epoch] && idx[:tx] == state[:tx]
        return idx[:items]
      end
      items = []
      model.entities.each do |entity|
        check_auto_budget!
        next unless entity.is_a?(Sketchup::Face) || entity.is_a?(Sketchup::Group) || entity.is_a?(Sketchup::ComponentInstance)
        next if hp_dim?(entity)
        bb = entity.bounds
        next if bb.empty?
        items << [entity, [bb.min.x.to_f, bb.min.y.to_f, bb.min.z.to_f], [bb.max.x.to_f, bb.max.y.to_f, bb.max.z.to_f]]
      end
      state[:root_index] = {epoch: state[:geometry_epoch], cache_epoch: state[:cache_epoch], tx: state[:tx], items: items}
      items
    end

    def self.remember_region(model, s, line)
      return unless line && line[:ref] && line[:axis]
      tol = 25.0 * MM
      pad = lat_mm * MM + tol
      span = line[:span]
      lo = span ? span[0] - tol : nil
      hi = span ? span[1] + tol : nil
      runtime(model)[:regions][s['id']] = [line[:ref], line[:axis], lo, hi, pad]
    end

    def self.region_fp(model, s, parts)
      region = runtime(model)[:regions][s['id']]
      unless region
        anchors = s['anchors'] || [s['a0'], s['a1']]
        points = anchors.compact.map { |anchor| resolve_anchor(model, anchor) }
        if points.size >= 2 && points.none?(&:nil?) && points.first.distance(points.last).to_f > MM
          axis = s['axis'] ? Geom::Vector3d.new(*s['axis']) : (points.last - points.first).normalize
          span = points.map { |point| (point - points.first).dot(axis).to_f }.minmax
          remember_region(model, s, ref: points.first, axis: axis, span: span)
          region = runtime(model)[:regions][s['id']]
        end
      end
      return false unless region
      ref, axis, lo, hi, pad = region
      root_index(model).each do |entity, mn, mx|
        check_auto_budget!
        iv = line_aabb_interval(ref, axis, mn, mx, pad)
        next unless iv
        next if lo && (iv[1] < lo || iv[0] > hi)
        parts.concat(entity_geometry_fp(entity, model))
      end
      true
    end

    def self.prune_watchers(model)
      state = runtime(model)
      state[:watchers].keys.each do |key|
        entities, observer = state[:watchers][key]
        begin
          owner = entities.parent
          unused = !owner.is_a?(Sketchup::Model) && (!owner.valid? || (owner.respond_to?(:instances) && owner.instances.none?(&:valid?)))
        rescue StandardError
          unused = true
        end
        next unless unused
        begin
          entities.remove_observer(observer)
        rescue StandardError
          # An invalid native collection may no longer accept API calls.
        end
        state[:watchers].delete(key)
        state[:revisions].delete(key)
        state[:geometry_cache].delete(key)
      end
    end

    def self.invalidate_tracking(model)
      return if @updating
      state = runtime(model)
      state[:geometry_cache].clear
      state[:fp_cache].clear
      state[:pid_cache].clear
      state[:root_index] = nil
      state[:cache_epoch] += 1
      state[:geometry_epoch] += 1
    end

    def self.forget_model(model)
      state = @runtimes.delete(model.object_id) if @runtimes
      UI.stop_timer(state[:timer]) if state && state[:timer]
      UI.stop_timer(state[:attach_timer]) if state && state[:attach_timer]
      @attached.delete(model.object_id) if @attached
      @overlays.delete(model.object_id) if @overlays
    end

    def self.watch_anchor_geometry(model, set)
      seen = {}
      set['anchors'].each do |anchor|
        (anchor['path'] || []).each do |pid|
          next if seen[pid]
          seen[pid] = true
          instance = entity_by_pid(model, pid)
          watch_entities(model, instance.definition.entities) if instance && instance.valid? && instance.respond_to?(:definition)
        end
      end
    end

    class HPGeometryObserver < Sketchup::EntitiesObserver
      def initialize(model); @model = model; end
      def onElementAdded(entities, entity); HP::AutoDim.geometry_changed(@model, entities, entity); end
      def onElementModified(entities, entity); HP::AutoDim.geometry_changed(@model, entities, entity); end
      def onElementRemoved(entities, _id); HP::AutoDim.geometry_changed(@model, entities); end
      def onEraseEntities(entities); HP::AutoDim.geometry_changed(@model, entities); end
      def onActiveSectionPlaneChanged(entities); HP::AutoDim.geometry_changed(@model, entities); end
    end

    class HPDefinitionListObserver < Sketchup::DefinitionsObserver
      def initialize(model); @model = model; end
      def onComponentPropertiesChanged(_definitions, _definition); HP::AutoDim.invalidate_tracking(@model); end
      def onComponentAdded(_definitions, _definition); HP::AutoDim.invalidate_tracking(@model); end
      def onComponentRemoved(_definitions, _definition); HP::AutoDim.invalidate_tracking(@model); end
    end

    class HPTagObserver < Sketchup::LayersObserver
      def initialize(model); @model = model; end
      def onLayerChanged(_layers, layer)
        return if HP::AutoDim.tag_owned?(layer)
        # Legacy DIM tags have not yet received the ownership marker.
        return if HP::AutoDim.poll_sets(@model).any? { |set| set['tag_pid'] == layer.persistent_id || set['tag'] == layer.name }
        HP::AutoDim.invalidate_tracking(@model)
      end
      def onLayerRemoved(_layers, _layer); HP::AutoDim.invalidate_tracking(@model); end
      def onLayerFolderChanged(_layers, _folder); HP::AutoDim.invalidate_tracking(@model); end
      def onParentFolderChanged(layers, layer); onLayerChanged(layers, layer); end
    end
  end
end
