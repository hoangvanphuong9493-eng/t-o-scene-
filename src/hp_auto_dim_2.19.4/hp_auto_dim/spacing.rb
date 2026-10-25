# encoding: UTF-8
module HP
  module AutoDim
    # Capture once per placement, never from idle/open observers or per mouse move.
    # Use rendered endpoints so manually moved HP rows and short staggered rows
    # are respected. Manual/non-HP dimensions are not touched or adopted.
    def self.spacing_rows(model)
      rows = []
      scene = current_pgid(model)
      walk = lambda do |entities, transform, ancestors|
        candidates = entities.grep(Sketchup::Group) + entities.grep(Sketchup::ComponentInstance) + entities.grep(Sketchup::DimensionLinear)
        candidates.each do |entity|
          next if entity.hidden?
          layer = entity.layer
          next if layer && !layer.visible?
          folder = layer && layer.folder
          hidden_folder = false
          while folder
            hidden_folder ||= !folder.visible?
            folder = folder.respond_to?(:folder) ? folder.folder : nil
          end
          next if hidden_folder
          owner = entity.get_attribute(PLUGIN_ID, 'scene_id', nil)
          next if owner && owner != 0 && owner != scene
          if entity.is_a?(Sketchup::DimensionLinear)
            next unless entity.get_attribute(PLUGIN_ID, 'set', nil)
            a = entity.start[1]
            b = entity.end[1]
            offset = entity.offset_vector
            rows << [(a + offset).transform(transform), (b + offset).transform(transform)]
          else
            definition = entity.definition
            next if ancestors.include?(definition.object_id)
            walk.call(definition.entities, transform * entity.transformation, ancestors + [definition.object_id])
          end
        end
      end
      walk.call(model.entities, Geom::Transformation.new, [])
      rows
    end

    # Compare visible rows on the placement plane. Cabinet doors and internal
    # shelves can have different depths while sharing the same drawing view.
    def self.project_spacing_point(point, ref, normal, projection)
      return point unless projection
      return point if (point - ref).dot(normal).to_f.abs < 1e-9
      direction = projection[:eye] ? point - projection[:eye] : projection[:direction]
      denominator = direction.dot(normal).to_f
      length = direction.length.to_f
      return nil if length < 1e-9 || denominator.abs / length < 0.05
      if projection[:eye]
        factor = (ref - projection[:eye]).dot(normal).to_f / denominator
        return nil unless factor.finite? && factor > 0
        projection[:eye] + sc(direction, factor)
      else
        point + sc(direction, (ref - point).dot(normal).to_f / denominator)
      end
    end

    # All distances are model units. Without a view retain the coplanar rule;
    # with a view compare projected rows. Ignore the opposite side,
    # perpendicular rows and spans which only touch at an endpoint.
    def self.row_spacing_shift(rows, ref, axis, direction, span, base_distance, step, projection = nil)
      return 0.0 unless step > 0 && span > MM
      normal = axis.cross(direction).normalize
      target = base_distance
      rows.each do |a, b|
        a = project_spacing_point(a, ref, normal, projection)
        b = project_spacing_point(b, ref, normal, projection)
        next unless a && b
        delta = b - a
        next if delta.length.to_f < MM
        next unless delta.normalize.dot(axis).to_f.abs > 0.9999
        av, bv = a - ref, b - ref
        next if av.dot(normal).to_f.abs > MM || bv.dot(normal).to_f.abs > MM
        lo, hi = [av.dot(axis).to_f, bv.dot(axis).to_f].minmax
        next if [hi, span].min - [lo, 0.0].max <= MM * 0.01
        distance = av.dot(direction).to_f
        next unless distance > MM * 0.01
        target = [target, distance + step].max
      end
      [target - base_distance, 0.0].max
    end

    def self.shift_line_row(line, mm)
      return line unless mm && mm > 0
      shift = sc(line[:off].normalize, mm * MM)
      line.merge(off: line[:off] + shift,
                 legs: line[:legs] ? line[:legs] + shift : nil)
    end

    module PointTool
      def space_placement(view, ref, axis, span, off, legs)
        @row_shift_mm = 0.0
        # Explicit VCB length retains user control. Free dragging still keeps
        # the configured minimum separation when another HP row is present.
        return [off, legs] if @leg_policy == 'custom'
        @spacing_rows ||= HP::AutoDim.spacing_rows(view.model)
        projection = nil
        if view.respond_to?(:camera) && view.camera
          camera = view.camera
          projection = camera.perspective? ? {eye: camera.eye} : {direction: camera.direction}
        end
        shift = HP::AutoDim.row_spacing_shift(@spacing_rows, ref, axis, off.normalize,
                    span, off.length.to_f, HP::AutoDim.step_mm * HP::AutoDim::MM, projection)
        @row_shift_mm = shift / HP::AutoDim::MM
        moved = HP::AutoDim.shift_line_row({off: off, legs: legs}, @row_shift_mm)
        [moved[:off], moved[:legs]]
      end
    end
  end
end
