# encoding: UTF-8
module HP
  module AutoDim
    def self.anchor_member?(entity, container)
      return false unless entity && entity.valid?
      parent = entity.respond_to?(:parent) ? entity.parent : nil
      if !parent && entity.respond_to?(:edges)
        edge = entity.edges.first
        parent = edge.parent if edge
      end
      parent == container || (container.respond_to?(:entities) && parent == container.entities)
    end

    def self.anchor_frame(model, anchor)
      transform = IDENTITY_TR
      container = model
      (anchor['path'] || []).each do |pid|
        instance = entity_by_pid(model, pid)
        return nil unless anchor_member?(instance, container) && instance.respond_to?(:definition)
        transform = transform * instance.transformation
        container = instance.definition
      end
      [transform, container]
    end

    def self.resolve_bound(model, anchor)
      return nil unless anchor && (anchor['v'] || anchor['e'])
      frame = anchor_frame(model, anchor)
      return nil unless frame
      transform, container = frame
      point = nil
      if anchor['v']
        vertex = entity_by_pid(model, anchor['v'])
        point = vertex.position if anchor_member?(vertex, container) && vertex.respond_to?(:position)
      end
      if !point && anchor['e']
        edge = entity_by_pid(model, anchor['e'])
        if anchor_member?(edge, container) && edge.respond_to?(:start)
          point = edge.start.position + (edge.end.position - edge.start.position) * anchor['r'].to_f
        end
      end
      return nil unless point
      delta = anchor['projection_delta']
      point = point + Geom::Vector3d.new(*delta) if delta
      transform * point
    end

    def self.resolve_local_ratio(model, anchor)
      ratio = anchor['local_ratio']
      return nil unless ratio && !(anchor['path'] || []).empty?
      frame = anchor_frame(model, anchor)
      return nil unless frame
      transform, container = frame
      bounds = container.bounds
      return nil if bounds.empty?
      mn, mx = bounds.min, bounds.max
      transform * Geom::Point3d.new(mn.x + ratio[0] * (mx.x - mn.x),
                                    mn.y + ratio[1] * (mx.y - mn.y),
                                    mn.z + ratio[2] * (mx.z - mn.z))
    end

    def self.resolve_anchor_exact(model, anchor)
      return nil unless anchor
      point = resolve_bound(model, anchor)
      return point if point
      # A bound vertex/edge missing from the current definition is not a
      # fixed local point. Do not silently reuse its old position.
      return nil if anchor['v'] || anchor['e']
      frame = anchor_frame(model, anchor)
      return nil unless frame && anchor['p']
      frame[0] * Geom::Point3d.new(*anchor['p'])
    end

    def self.resolve_anchor(model, anchor)
      return nil unless anchor
      point = resolve_bound(model, anchor)
      point ||= resolve_local_ratio(model, anchor)
      point ||= resolve_by_trk(model, anchor)
      return point if point
      bound = anchor['v'] || anchor['e'] || anchor['trk'] || !(anchor['path'] || []).empty?
      return nil if bound && (anchor['v'] || anchor['e'] || anchor['trk'])
      resolve_anchor_exact(model, anchor)
    end

    def self.make_anchor(model, ip, pos, direct = false)
      return world_anchor(pos, direct ? nil : model) if ip.nil?
      instances = []
      if ip.respond_to?(:instance_path) && ip.instance_path
        instances = ip.instance_path.to_a.select { |e| e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance) }
      end
      transform = inst_product(instances)
      local = transform.inverse * pos
      picked = transform.inverse * ip.position
      anchor = {'path' => instances.map(&:persistent_id),
                'p' => [local.x.to_f, local.y.to_f, local.z.to_f],
                'w' => [pos.x.to_f, pos.y.to_f, pos.z.to_f]}
      if ip.vertex
        anchor['v'] = ip.vertex.persistent_id
      elsif ip.edge && ip.degrees_of_freedom == 1
        edge = ip.edge
        segment = edge.end.position - edge.start.position
        squared = segment.dot(segment).to_f
        if squared > 1e-12
          anchor['e'] = edge.persistent_id
          anchor['r'] = (picked - edge.start.position).dot(segment).to_f / squared
        end
      end
      if anchor['v'] || anchor['e']
        delta = local - picked
        anchor['projection_delta'] = [delta.x.to_f, delta.y.to_f, delta.z.to_f]
      end
      unless instances.empty?
        bounds = instances.last.definition.bounds
        unless bounds.empty?
          mn, mx = bounds.min, bounds.max
          anchor['local_ratio'] = [0, 1, 2].map do |i|
            width = mx[i].to_f - mn[i].to_f
            width.abs < 1e-9 ? 0.5 : (local[i].to_f - mn[i].to_f) / width
          end
        end
      end
      resolved = resolve_anchor_exact(model, anchor)
      return world_anchor(pos, direct ? nil : model) unless resolved && resolved.distance(pos).to_f <= MM
      tracking = trk_for(model, instances, pos) unless direct && instances.empty?
      anchor['trk'] = tracking if tracking
      anchor
    rescue StandardError => error
      log_once("HP điểm neo: #{error.message}")
      world_anchor(pos, direct ? nil : model)
    end
  end
end
