# encoding: UTF-8
# Run ONLY in a new, completely empty SketchUp model with the candidate installed:
# load 'C:/path/to/sketchup_native_smoke.rb'
# Leaves a disposable QA cabinet in that empty model. Never opens/closes a file,
# modifies global preferences, or runs against an existing model.
require 'json'
module HP
  module AutoDimNativeQA
    def self.box(parent, low, high, key, name = '')
      group = parent.add_group
      group.name = name
      group.set_attribute('fuji_dict', 'sheet_id', key)
      x0, y0, z0 = low.map(&:mm)
      x1, y1, z1 = high.map(&:mm)
      face = group.entities.add_face([x0, y0, z0], [x1, y0, z0], [x1, y1, z0], [x0, y1, z0])
      face.reverse! if face.normal.z < 0
      face.pushpull(z1 - z0)
      group
    end

    def self.anchor(root, part, xyz)
      point = Geom::Point3d.new(*xyz.map(&:mm))
      vertex = part.entities.grep(Sketchup::Edge).flat_map { |edge| [edge.start, edge.end] }.uniq.find { |v| v.position.distance(point) < 0.001.mm }
      raise 'QA could not find source vertex' unless vertex
      world = root.transformation * (part.transformation * point)
      bounds = part.definition.bounds
      ratio = 3.times.map { |i| span = bounds.max[i] - bounds.min[i]; span.abs < 1e-9 ? 0.5 : (point[i] - bounds.min[i]) / span }
      {'path' => [root.persistent_id, part.persistent_id], 'p' => point.to_a, 'w' => world.to_a,
       'v' => vertex.persistent_id, 'local_ratio' => ratio,
       'path_hints' => [{'identity' => HP::AutoDim.part_identity(root)}, {'identity' => HP::AutoDim.part_identity(part)}]}
    end

    def self.values(model, set)
      context = %w[cont cut chain].include?(set['mode']) ? model.entities : HP::AutoDim.ctx_entities(model, set['ctx'])
      HP::AutoDim.dim_items(context, set['id']).flat_map { |item| item.entities.grep(Sketchup::DimensionLinear) }
        .map { |dimension| dimension.start[1].distance(dimension.end[1]).to_f / 1.mm.to_f }
    end

    def self.check(actual, expected, name, result)
      pass = actual.size == expected.size && actual.zip(expected).all? { |a, b| (a - b).abs <= 0.01 }
      result['checks'] << {'name' => name, 'pass' => pass, 'actual_mm' => actual, 'expected_mm' => expected}
      raise "#{name}: #{actual.inspect}, expected #{expected.inspect}" unless pass
    end

    def self.run
      model = Sketchup.active_model
      unless defined?(HP::AutoDim::PLUGIN_VERSION) && HP::AutoDim.respond_to?(:follow_partitions) && HP::AutoDim.respond_to?(:verify_set)
        raise 'Install the HP Auto Dim 2.19.3 candidate first.'
      end
      unless model.entities.empty? && model.pages.length == 0 && HP::AutoDim.load_sets(model).empty?
        UI.messagebox('Bài kiểm tra chỉ chạy trong model mới hoàn toàn trống, chưa có scene và chưa có DIM HP. Model hiện tại được giữ nguyên.')
        return
      end
      plugin = HP::AutoDim
      original_prefs = plugin.instance_variable_get(:@prefs)
      result = {'sketchup_version' => Sketchup.version, 'plugin_version' => plugin::PLUGIN_VERSION,
                'checks' => [], 'native_run' => true, 'passed' => false}
      plugin.instance_variable_set(:@prefs, {'offset_mm' => 150.0, 'leg_mm' => 15.0, 'step_mm' => 120.0,
        'stagger_mm' => 60.0, 'thick_mm' => 20.0, 'cut_mode' => 'base', 'vis_only' => 0, 'lat_mm' => 150.0,
        'obj_two_d' => 1, 'max_dia_mm' => 100.0, 'hole_kw' => 'hole,drill,khoan', 'leaf_kw' => 'canh,door,cua,leaf',
        'auto_update' => 0, 'live_partitions' => 1})
      plugin.instance_variable_set(:@settings_fp, nil)
      model.start_operation('HP QA dựng mẫu độc lập', true)
      building = true
      root = model.entities.add_group
      root.name = 'HP QA — disposable cabinet'
      left = box(root.entities, [0, -600, 18], [18, 0, 2400], 'qa-left')
      right = box(root.entities, [1182, -600, 18], [1200, 0, 2400], 'qa-right')
      box(root.entities, [0, -600, 0], [1200, 0, 18], 'qa-bottom')
      top = box(root.entities, [18, -600, 2382], [1182, -27, 2400], 'qa-top')
      box(root.entities, [591, -600, 18], [609, -27, 2382], 'qa-divider')
      box(root.entities, [609, -600, 1100], [1182, -27, 1118], 'qa-shelf')
      door = box(root.entities, [0, -618, 0], [599.6, -600, 2400], 'qa-door', 'Canh QA')
      [100, 800, 1600, 2300].each do |z|
        hole = door.entities.add_group
        hole.entities.add_circle(Geom::Point3d.new(25.mm, -605.mm, z.mm), Y_AXIS, 17.5.mm, 24)
      end
      model.commit_operation
      building = false
      model.selection.clear
      model.selection.add(root)
      plugin.run_obj
      plugin.run_holes
      cont = {'mode' => 'cont', 'anchor_mode' => 'native',
        'anchors' => [anchor(root, left, [18, -600, 18]), anchor(root, right, [1182, -600, 18])],
        'axis' => [1, 0, 0], 'od' => [0, 0, -1], 'dm' => [0, 0, -150.mm.to_f],
        'perp' => [0, 0, 1], 'skip_mm' => 20, 'gap' => 150, 'cmode' => 'base', 'leg_policy' => 'settings'}
      cut = {'mode' => 'cut', 'a0' => anchor(root, top, [1182, -600, 2400]),
        'a1' => plugin.world_anchor(Geom::Point3d.new(1182.mm, -600.mm, -10.mm)),
        'axis' => [0, 0, -1], 'od' => [1, 0, 0], 'dm' => [150.mm.to_f, 0, 0],
        'perp' => [1, 0, 0], 'skip_mm' => 20, 'gap' => 150, 'cmode' => 'base', 'leg_policy' => 'settings'}
      raise 'Native chain creation failed' unless plugin.create_line_set(model, cont)
      raise 'Native cut creation failed' unless plugin.create_line_set(model, cut)
      plugin.refresh_all(model, true)
      sets = plugin.load_sets(model)
      object = sets.find { |set| set['mode'] == 'obj' }
      leaves = sets.find { |set| set['mode'] == 'std' }
      raise 'Object/door commands did not create sets' unless object && leaves
      check(values(model, object), [1200, 2400], 'object geometry', result)
      check(values(model, leaves), [599.6, 100, 700, 800, 700, 100, 2400], 'door and hinge geometry', result)
      check(values(model, cont), [573, 573], 'horizontal partitions', result)
      check(values(model, cut), [1264, 1082], 'vertical shelves', result)
      model.start_operation('HP QA thêm đợt', true)
      extra = box(root.entities, [609, -600, 500], [1182, -27, 518], 'qa-extra')
      model.commit_operation
      plugin.note_transaction(model)
      plugin.refresh_all(model, false)
      check(values(model, cut), [1264, 582, 482], 'add shelf', result)
      model.start_operation('HP QA xóa đợt', true)
      extra.erase!
      model.commit_operation
      plugin.note_transaction(model)
      plugin.refresh_all(model, false)
      check(values(model, cut), [1264, 1082], 'delete shelf', result)
      plugin.load_sets(model).each do |set|
        state = plugin.verify_set(model, set)
        result['checks'] << {'name' => "native verification #{set['mode']}", 'pass' => state == :ok, 'state' => state.to_s}
        raise "Native verification: #{state}" unless state == :ok
      end
      result['passed'] = true
    rescue StandardError => error
      model.abort_operation if building
      result ||= {'checks' => [], 'native_run' => true, 'passed' => false}
      result['error'] = error.message
      result['location'] = error.backtrace.first
    ensure
      if defined?(original_prefs) && plugin
        plugin.instance_variable_set(:@prefs, original_prefs)
        plugin.instance_variable_set(:@settings_fp, nil)
      end
      if result
        text = JSON.pretty_generate(result)
        puts text
        path = UI.savepanel('Lưu biên bản kiểm tra SketchUp thật', nil, 'HP_AutoDim_native_QA.json')
        File.write(path, text) if path
        UI.messagebox(result['passed'] ? 'Kiểm tra hình học cơ bản trong SketchUp đã đạt. Chưa thay thế thử Undo/Redo, lưu/mở lại, scene, timer và Fuji thật.' : "Kiểm tra CHƯA đạt: #{result['error']}")
      end
    end
  end
end
HP::AutoDimNativeQA.run
