# encoding: UTF-8
module HP
  module AutoDim
    DIM_TYPES = {'obj' => 'Đối tượng', 'cont' => 'Liên tiếp',
                 'chain' => 'Liên tiếp', 'cut' => 'Cắt', 'std' => 'Cánh + tim lỗ'}.freeze

    def self.scene_tag_name(_model)
      TAG_PREFIX # legacy lookup only
    end

    def self.dim_folder(model)
      model.layers.folders.find { |folder| folder.name == 'HP DIM' } || model.layers.add_folder('HP DIM')
    end

    def self.configure_dim_visibility(model, tag)
      owner = tag.get_attribute(PLUGIN_ID, 'scene_owner', nil)
      return if owner.nil?
      model.pages.each do |page|
        page.use_hidden_layers = true unless page.use_hidden_layers?
        page.set_visibility(tag, owner == 0 || page.persistent_id == owner)
      end
      tag.visible = owner == 0 || current_pgid(model) == owner
    end

    def self.new_scene_tag(model, set)
      owner = set['pgid'] || current_pgid(model)
      mode = set['mode'] || 'std'
      kind = DIM_TYPES.fetch(mode, DIM_TYPES['std'])
      page = page_by_id(model, owner)
      scene_name = page ? page.name : (owner == 0 ? 'Không scene' : "Scene đã xóa #{owner}")
      tag = model.layers.find do |layer|
        layer.get_attribute(PLUGIN_ID, 'scene_owner', nil) == owner &&
          layer.get_attribute(PLUGIN_ID, 'dim_kind', nil) == kind
      end
      unless tag
        name = "#{scene_name} — DIM #{kind}"
        # Never adopt an unrelated tag, even if its name matches.
        base = name
        index = 1
        while model.layers[name]
          name = "#{base} (#{owner}-#{index})"
          index += 1
        end
        tag = model.layers.add(name)
        tag.set_attribute(PLUGIN_ID, 'scene_owner', owner)
        tag.set_attribute(PLUGIN_ID, 'dim_kind', kind)
      end
      tag.folder = dim_folder(model)
      set['pgid'] = owner
      set['tag_schema'] = 219
      remember_tag(tag, set)
      configure_dim_visibility(model, tag)
      tag
    end

    def self.tag_for(model, set)
      # Refreshing legacy dimensions is not an implicit migration.
      return new_scene_tag(model, set) if set['tag_schema'] == 219
      tag = find_set_tag(model, set)
      tag ||= model.layers[TAG_PREFIX] || model.layers.add(TAG_PREFIX)
      remember_tag(tag, set)
    end

    # Explicit, undoable migration. Only HP entities with a known set ID qualify.
    def self.consolidate_tags
      model = Sketchup.active_model
      return unless model
      leave_hp_groups(model)
      @updating = true
      model.start_operation('HP Chuyển DIM sang Tags theo scene', true)
      started = true
      sets = load_sets(model)
      legacy_pages = {}
      model.pages.each do |page|
        pid = page.get_attribute(PLUGIN_ID, 'dim_tag_pid', nil)
        legacy_pages[pid] = page.persistent_id if pid
      end
      tags = {}
      sets.each do |set|
        if set['pgid'].nil?
          page = model.pages.find { |item| set['tag'] == "#{TAG_PREFIX}_#{item.name}" }
          owner = legacy_pages[set['tag_pid']] || (page && page.persistent_id)
          raise 'Bộ DIM cũ thiếu scene; chưa chuyển dữ liệu.' unless owner
          set['pgid'] = owner
        end
        tags[set['id']] = [new_scene_tag(model, set), set['pgid']]
      end
      seen = {}
      count = 0
      visit = lambda do |entities|
        return if seen[entities.object_id]
        seen[entities.object_id] = true
        candidates = entities.grep(Sketchup::Group) + entities.grep(Sketchup::ComponentInstance) + entities.grep(Sketchup::Dimension)
        candidates.uniq.each do |entity|
          entry = tags[entity.get_attribute(PLUGIN_ID, 'set', nil)]
          if entry && (entity.is_a?(Sketchup::Group) || entity.is_a?(Sketchup::Dimension))
            entity.layer = entry[0]
            entity.set_attribute(PLUGIN_ID, 'scene_id', entry[1])
            count += 1
          end
          visit.call(entity.definition.entities) if entity.is_a?(Sketchup::Group) || entity.is_a?(Sketchup::ComponentInstance)
        end
      end
      visit.call(model.entities)
      save_sets(model, sets)
      model.commit_operation
      started = false
      Sketchup.status_text = "HP Auto Dim: đã chuyển #{count} nhóm/DIM sang thư mục HP DIM"
      count
    rescue StandardError => error
      model.abort_operation if started
      UI.messagebox("Không chuyển được Tags DIM: #{error.message}")
      false
    ensure
      @updating = false
    end

    class HPDimPagesObserver < Sketchup::PagesObserver
      def initialize(model); @model = model; end
      def onElementAdded(_pages, _page)
        # Only tag metadata is inspected; no geometry/sets scan or migration.
        @model.layers.each do |tag|
          HP::AutoDim.configure_dim_visibility(@model, tag) unless tag.get_attribute(PLUGIN_ID, 'scene_owner', nil).nil?
        end
      end
    end
  end
end
