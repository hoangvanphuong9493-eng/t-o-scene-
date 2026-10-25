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

    # All distances are model units. Ignore rows on another plane, on the
    # opposite side, perpendicular, or merely touching the end of this span.
    def self.row_spacing_shift(rows, ref, axis, direction, span, base_distance, step)
      return 0.0 unless step > 0 && span > MM
      normal = axis.cross(direction).normalize
      target = base_distance
      rows.each do |a, b|
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
        # Explicit VCB length or free mouse placement retains user control.
        return [off, legs] unless (@leg_policy || 'settings') == 'settings'
        @spacing_rows ||= HP::AutoDim.spacing_rows(view.model)
        shift = HP::AutoDim.row_spacing_shift(@spacing_rows, ref, axis, off.normalize,
                    span, off.length.to_f, HP::AutoDim.step_mm * HP::AutoDim::MM)
        @row_shift_mm = shift / HP::AutoDim::MM
        moved = HP::AutoDim.shift_line_row({off: off, legs: legs}, @row_shift_mm)
        [moved[:off], moved[:legs]]
      end
    end
  end
end
