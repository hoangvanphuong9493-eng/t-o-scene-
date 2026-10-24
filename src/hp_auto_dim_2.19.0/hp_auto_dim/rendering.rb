# encoding: UTF-8
module HP
  module AutoDim
    # DimensionLinear#start/end return [associated_entity, Point3d], unlike
    # Edge#start/end. Only free-point HP dimensions are updated in place.
    def self.dimension_point(dimension, endpoint)
      value = dimension.public_send(endpoint)
      return nil unless value.is_a?(Array) && value.size == 2 && value[0].nil?
      value[1]
    end

    def self.restore_in_place(batch)
      (batch || []).reverse_each do |entry|
        group, layer, snapshots, scene = entry
        snapshots.each do |dimension, start, finish, offset, text, dim_layer, position, aligned|
          next unless dimension.valid?
          dimension.start = start
          dimension.end = finish
          dimension.offset_vector = offset
          dimension.text = text
          dimension.layer = dim_layer
          dimension.text_position = position
          dimension.aligned_text_position = aligned
        end
        group.layer = layer if group.valid?
        if group.valid?
          scene.nil? ? group.delete_attribute(PLUGIN_ID, 'scene_id') : group.set_attribute(PLUGIN_ID, 'scene_id', scene)
        end
      end
    end

    def self.try_update_dims(entities, set, tag)
      return nil unless @in_place_allowed && set['mode'] == 'obj'
      items = dim_items(entities, set['id'])
      return nil unless items.size == 1 && items.first.is_a?(Sketchup::Group)
      group = items.first
      return nil unless group.transformation.to_a == IDENTITY_TR.to_a
      return nil if group.definition.respond_to?(:instances) && group.definition.instances.size != 1
      dimensions = group.entities.grep(Sketchup::DimensionLinear)
      return nil if dimensions.empty? || dimensions.size != set['ndim'].to_i
      return nil unless dimensions.all? { |dimension| dimension_point(dimension, :start) && dimension_point(dimension, :end) }
      @dim_specs = []
      begin
        count = yield
        specs = @dim_specs
      ensure
        @dim_specs = nil
      end
      return nil unless count == dimensions.size && specs.size == count
      snapshots = dimensions.map do |dimension|
        [dimension, dimension_point(dimension, :start), dimension_point(dimension, :end),
         dimension.offset_vector, dimension.text, dimension.layer,
         dimension.text_position, dimension.aligned_text_position]
      end
      entry = [group, group.layer, snapshots, group.get_attribute(PLUGIN_ID, 'scene_id', nil)]
      begin
        dimensions.each_with_index do |dimension, index|
          check_auto_budget!
          start, finish, offset = specs[index]
          dimension.start = start
          dimension.end = finish
          dimension.offset_vector = offset
          dimension.layer = tag
          set_clean_text(dimension, start.distance(finish).to_f)
          place_text_outside(dimension, start, finish, offset)
        end
        group.layer = tag
        group.set_attribute(PLUGIN_ID, 'scene_id', set['pgid']) unless set['pgid'].nil?
        (@in_place_batch ||= []) << entry
      rescue StandardError
        restore_in_place([entry])
        raise
      end
      count
    end
  end
end
