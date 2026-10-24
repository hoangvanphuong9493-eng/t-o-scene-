# encoding: UTF-8
require 'sketchup.rb'
require 'json'
require 'zlib'
require 'securerandom'
require_relative 'tracking'
require_relative 'interaction'
require_relative 'scheduler'
require_relative 'rendering'
require_relative 'tagging'
require_relative 'spacing'

module HP
  module AutoDim
    TAG_PREFIX  = 'HP_DIM'.freeze
    ICON_DIR    = File.join(File.dirname(__FILE__), 'icons').freeze
    MM          = 1.mm.to_f
    IDENTITY_TR = Geom::Transformation.new

    # ================= Cài đặt =================
    # Cài đặt được đọc một lần rồi giữ trong bộ nhớ: chúng được dùng rất nhiều
    # lần trong mỗi lượt cập nhật/vẽ. Mọi thay đổi đều đi qua set_pref.
    def self.pref(key, default)
      @prefs ||= {}
      @prefs[key] = Sketchup.read_default(PLUGIN_ID, key, nil) unless @prefs.key?(key)
      value = @prefs[key]
      value.nil? ? default : value
    end

    def self.set_pref(key, value)
      Sketchup.write_default(PLUGIN_ID, key, value)
      (@prefs ||= {})[key] = value
      @settings_fp = nil
    end

    def self.raw_offset_mm; pref('offset_mm', 100.0).to_f; end
    # chiều dài chân dim (từ đầu chân tới đường dim); 0 = dùng "Chân dim cách đối tượng"
    def self.leg_len_mm;   pref('leg_len_mm', 0.0).to_f; end

    # khoảng cách từ mép đối tượng tới đường dim (mặc định): = khoảng hở + chiều dài chân nếu có chọn chiều dài chân
    def self.offset_mm
      ll = leg_len_mm
      ll > 0 ? leg_mm + ll : raw_offset_mm
    end
    def self.max_dia_mm; pref('max_dia_mm', 100.0).to_f; end
    def self.thick_mm;   pref('thick_mm', 18.0).to_f; end
    def self.lat_mm;     pref('lat_mm', 100.0).to_f; end
    def self.step_mm;    pref('step_mm', 80.0).to_f; end
    def self.stagger_mm; pref('stagger_mm', 60.0).to_f; end
    def self.leg_mm;     pref('leg_mm', 5.0).to_f; end
    def self.obj_two_d?; pref('obj_two_d', 0).to_i == 1; end
    def self.text_off_mm; pref('text_off_mm', 45.0).to_f; end
    def self.vis_only?;  pref('vis_only', 1).to_i == 1; end

    # chế độ Dim cắt: 'section' = đúng điểm mặt cắt (chỉ giao điểm thật), 'base' = từ đáy đối tượng (có dung sai ngang)
    def self.cut_mode
      pref('cut_mode', 'section').to_s == 'base' ? 'base' : 'section'
    end

    def self.cut_mode_name
      cut_mode == 'base' ? 'từ đáy đối tượng' : 'đúng mặt cắt'
    end

    def self.toggle_cut_mode
      set_pref('cut_mode', cut_mode == 'base' ? 'section' : 'base')
      Sketchup.status_text = "Dim cắt: chế độ #{cut_mode_name}"
    end
    def self.cut_skip?;  pref('cut_skip', 1).to_i == 1; end
    def self.auto_update?; pref('auto_update', 1).to_i == 1; end

    def self.norm(str)
      s = str.to_s.downcase
      s = s.unicode_normalize(:nfd).gsub(/\p{Mn}/, '')
      s.gsub('đ', 'd')
    rescue
      str.to_s.downcase
    end

    def self.kw_list(key, default)
      pref(key, default).to_s.split(',')
              .map { |k| norm(k.strip) }.reject(&:empty?)
    end

    def self.hole_kw; kw_list('hole_kw', 'hole,drill,khoan'); end
    def self.leaf_kw; kw_list('leaf_kw', 'canh,door,cua,leaf'); end

    # ================= Vector an toàn (Float) =================
    def self.sc(v, k)
      k = k.to_f
      Geom::Vector3d.new(v.x.to_f * k, v.y.to_f * k, v.z.to_f * k)
    end

    def self.at(o, ua, s, ub, t)
      s = s.to_f
      t = t.to_f
      Geom::Point3d.new(o.x.to_f + ua.x.to_f * s + ub.x.to_f * t,
                        o.y.to_f + ua.y.to_f * s + ub.y.to_f * t,
                        o.z.to_f + ua.z.to_f * s + ub.z.to_f * t)
    end

    def self.proj(p, o, ua, ub)
      d = p - o
      [d.dot(ua).to_f, d.dot(ub).to_f]
    end

    # group chứa các dim do HP tạo ra
    def self.hp_dim?(en)
      en.is_a?(Sketchup::Group) && !en.get_attribute(PLUGIN_ID, 'set').nil?
    end

    # thoát khỏi các group dim của HP nếu đang mở bên trong (tránh xóa/tạo dim lồng vào group cũ)
    def self.leave_hp_groups(model)
      8.times do
        path = model.active_path
        break if path.nil? || path.empty?
        break unless path.any? { |e| hp_dim?(e) }
        model.close_active
      end
    rescue StandardError => err
      puts "HP leave group: #{err.message}"
    end

    def self.visible?(en)
      return false if hp_dim?(en)
      en.visible? && layer_visible?(en.layer)
    end

    # ---- nhóm các dim sinh ra từ 1 thao tác vào 1 group ----
    def self.group_name(mode)
      case mode
      when 'cont' then 'HP Dim liên tiếp'
      when 'cut', 'chain' then 'HP Dim cắt'
      when 'obj' then 'HP Kích thước đối tượng'
      else 'HP Kích thước cánh'
      end
    end

    def self.begin_group(ents, sid, tag, name, page = current_pgid(Sketchup.active_model))
      g = ents.add_group
      g.name = name
      g.layer = tag
      g.set_attribute(PLUGIN_ID, 'set', sid)
      g.set_attribute(PLUGIN_ID, 'scene_id', page) unless page.nil?
      @cur_group = g
      g
    end

    def self.end_group
      g = @cur_group
      @cur_group = nil
      g.erase! if g && g.valid? && g.entities.length == 0
      g
    end

    # ---- camera dùng để lọc chi tiết bị che (lưu cùng bộ dim) ----
    def self.cam_from_view(view)
      c = view.camera
      { eye: c.eye, dir: c.direction, persp: c.perspective? }
    end

    def self.cam_to_a(cam)
      { 'eye' => [cam[:eye].x.to_f, cam[:eye].y.to_f, cam[:eye].z.to_f],
        'dir' => [cam[:dir].x.to_f, cam[:dir].y.to_f, cam[:dir].z.to_f],
        'persp' => cam[:persp] }
    end

    def self.cam_from_a(h)
      return nil unless h && vis_only?
      { eye: Geom::Point3d.new(h['eye'][0], h['eye'][1], h['eye'][2]),
        dir: Geom::Vector3d.new(h['dir'][0], h['dir'][1], h['dir'][2]),
        persp: h['persp'] }
    end

    # điểm wp có nhìn thấy từ camera không (không bị chi tiết khác che)
    def self.visible_from_cam?(model, wp, cam)
      return true unless cam
      if cam[:persp]
        to = cam[:eye] - wp
        dist = to.length.to_f
        return true if dist < 3.0 * MM
        dir = to.normalize
      else
        dir = sc(cam[:dir], -1)
        dist = nil
      end
      start = wp + sc(dir, 1.5 * MM)
      hit = model.raytrace([start, dir], true)
      return true unless hit
      return true if dist && start.distance(hit[0]).to_f >= dist - 3.0 * MM
      false
    rescue StandardError
      true
    end

    # các mặt cắt (Section Plane) đang bật
    def self.section_planes(model)
      out = []
      [model.entities, model.active_entities].uniq.each do |ents|
        ents.grep(Sketchup::SectionPlane).each do |sp|
          out << sp.get_plane if sp.active?
        end
      end
      out
    rescue StandardError
      []
    end

    # đưa điểm p vào đúng mặt cắt (nếu mặt cắt song song với trục đo); không có thì trả nil
    def self.section_project(model, p, axis, planes = nil)
      planes ||= section_planes(model)
      best = nil
      bd = nil
      planes.each do |pl|
        n = Geom::Vector3d.new(pl[0].to_f, pl[1].to_f, pl[2].to_f)
        nl = n.length.to_f
        next if nl < 1e-9
        nn = n.normalize
        next if nn.dot(axis).to_f.abs > 0.02
        dist = (pl[0].to_f * p.x.to_f + pl[1].to_f * p.y.to_f + pl[2].to_f * p.z.to_f + pl[3].to_f) / nl
        if bd.nil? || dist.abs < bd
          bd = dist.abs
          best = p - sc(nn, dist)
        end
      end
      best
    end

    def self.closest_pt_seg(p, a, b)
      ab = b - a
      l2 = ab.dot(ab).to_f
      return a if l2 < 1e-12
      t = [[(p - a).dot(ab).to_f / l2, 0.0].max, 1.0].min
      Geom::Point3d.new(a.x.to_f + ab.x.to_f * t, a.y.to_f + ab.y.to_f * t, a.z.to_f + ab.z.to_f * t)
    end

    # bỏ phần ".0" của số tròn cho gọn (100.0 -> 100)
    def self.strip_zeros(str)
      str.to_s.sub(/(\d)\.0+(?=\D|\z)/, '\1')
    end

    def self.fmt(l)
      strip_zeros(Sketchup.format_length(l.to_f))
    end

    def self.mid(a, b)
      Geom::Point3d.new((a.x.to_f + b.x.to_f) / 2.0, (a.y.to_f + b.y.to_f) / 2.0, (a.z.to_f + b.z.to_f) / 2.0)
    end

    # ================= Tag tổng; giữ ID scene để theo dõi từng bộ DIM =================
    def self.find_set_tag(model, s)
      if s['tag_pid']
        tag = model.layers.find { |layer| layer.persistent_id == s['tag_pid'] }
        return tag if tag
      end
      mode = s['mode'] || 'std'
      ents = %w[chain cut cont].include?(mode) ? model.entities : ctx_entities(model, s['ctx'])
      item = dim_items(ents, s['id']).first if ents
      return item.layer if item && item.layer && item.layer.name != 'Layer0'
      name = s['tag'] || TAG_PREFIX
      model.layers[name]
    end

    def self.remember_tag(tag, s)
      s['tag'] = tag.name
      s['tag_pid'] = tag.persistent_id
      tag.set_attribute(PLUGIN_ID, 'owned_tag', true) unless tag.get_attribute(PLUGIN_ID, 'owned_tag', false)
      tag
    end

    def self.tag_owned?(tag)
      tag && tag.get_attribute(PLUGIN_ID, 'owned_tag', false)
    end

    def self.current_pgid(model)
      pg = model.pages.selected_page
      pg ? pg.persistent_id : 0
    end

    def self.page_by_id(model, id)
      model.pages.to_a.find { |p| p.persistent_id == id }
    end

    # tag chỉ hiện ở scene của nó; bật "Visible Tags" cho scene đó để quay lại luôn thấy dim
    def self.apply_scene_visibility(model, tag, pg)
      return unless pg
      begin
        pg.use_hidden_layers = true unless pg.use_hidden_layers?
      rescue StandardError => e
        puts "HP scene flag: #{e.message}"
      end
      model.pages.each { |p| p.set_visibility(tag, p == pg) }
    rescue StandardError => e
      puts "HP scene tag: #{e.message}"
    end

    def self.same_scene?(model, s, pgid = current_pgid(model))
      return s['pgid'] == pgid unless s['pgid'].nil?
      # Older sets stored only a tag name.
      tag = find_set_tag(model, s)
      tag && tag.name == scene_tag_name(model)
    end

    # bộ dim thuộc scene đang xem? (chỉ cập nhật bộ dim của scene hiện tại, tránh tính sai khi các scene ẩn/hiện khác nhau)
    def self.set_in_scene?(s, cur_pgid)
      if s['pgid'].nil?
        return s['tag'].nil? || s['tag'] == scene_tag_name(Sketchup.active_model)
      end
      s['pgid'] == 0 || s['pgid'] == cur_pgid
    end

    def self.frame_of(e, ptr = IDENTITY_TR)
      case e
      when Sketchup::Group, Sketchup::ComponentInstance
        bb = e.definition.bounds
        return nil if bb.empty?
        t  = ptr * e.transformation
        p0 = bb.min
        o  = t * p0
        vx = (t * Geom::Point3d.new(bb.max.x, p0.y, p0.z)) - o
        vy = (t * Geom::Point3d.new(p0.x, bb.max.y, p0.z)) - o
        vz = (t * Geom::Point3d.new(p0.x, p0.y, bb.max.z)) - o
        vs = [vx, vy, vz].sort_by { |v| v.length.to_f }
        [o, vs[1], vs[2], vs[0].length.to_f]
      when Sketchup::Face
        pts  = e.vertices.map(&:position)
        edge = e.edges.max_by { |x| x.length.to_f }
        u = edge.line[1].normalize
        n = e.normal
        v = n.cross(u).normalize
        us = pts.map { |p| (p - ORIGIN).dot(u).to_f }
        vs = pts.map { |p| (p - ORIGIN).dot(v).to_f }
        ns = (pts[0] - ORIGIN).dot(n).to_f
        o  = ORIGIN + sc(u, us.min) + sc(v, vs.min) + sc(n, ns)
        a  = sc(u, us.max - us.min)
        b  = sc(v, vs.max - vs.min)
        [o, a, b, 0.0]
      end
    end

    def self.corners_of(e)
      if e.is_a?(Sketchup::Face)
        e.vertices.map(&:position)
      else
        bb = e.definition.bounds
        t  = e.transformation
        (0..7).map { |i| t * bb.corner(i) }
      end
    end

    def self.box_of(e)
      bb = e.definition.bounds
      return nil if bb.empty?
      t  = e.transformation
      p0 = bb.min
      o  = t * p0
      vx = (t * Geom::Point3d.new(bb.max.x, p0.y, p0.z)) - o
      vy = (t * Geom::Point3d.new(p0.x, bb.max.y, p0.z)) - o
      vz = (t * Geom::Point3d.new(p0.x, p0.y, bb.max.z)) - o
      [o, [vx, vy, vz]]
    end

    # Trục toàn cục: B = chiều đứng (gần trục Z nhất), A = chiều ngang
    def self.global_axes(f)
      o, va, vb = f
      c1 = va.normalize
      c2 = vb.normalize
      z1 = c1.z.to_f.abs
      z2 = c2.z.to_f.abs
      if z1 > z2 && z1 > 0.5
        ub, ua = c1, c2
      else
        ub, ua = c2, c1
      end
      ub = sc(ub, -1) if ub.z.to_f.abs > 0.5 && ub.z.to_f < 0
      ax = ua.x.to_f
      ay = ua.y.to_f
      big = ax.abs >= ay.abs ? ax : ay
      ua = sc(ua, -1) if big < 0
      [o, ua, ub]
    end

    # ================= Nhận diện lỗ =================
    def self.circle_from_points(pts, tr, max_r, out)
      n = pts.size
      return if n < 8
      cx = pts.inject(0.0) { |s, p| s + p.x.to_f } / n
      cy = pts.inject(0.0) { |s, p| s + p.y.to_f } / n
      cz = pts.inject(0.0) { |s, p| s + p.z.to_f } / n
      c  = Geom::Point3d.new(cx, cy, cz)
      rs = pts.map { |p| p.distance(c).to_f }
      rmin = rs.min
      rmax = rs.max
      return if rmin <= 0.0 || rmax > max_r || (rmax / rmin) > 1.03
      nor = (pts[0] - c).cross(pts[n / 4] - c)
      return if nor.length.to_f < 1e-9
      nor = nor.normalize
      return if pts.any? { |p| (p - c).dot(nor).abs.to_f > 0.03 * rmax }
      out << [tr * c, tr * nor]
    end

    def self.name_match?(en, kw)
      return false if kw.empty?
      nm = norm("#{en.name} #{en.definition.name}")
      kw.any? { |k| nm.include?(k) }
    end

    def self.full_circle?(c)
      c.is_a?(Sketchup::ArcCurve) &&
        ((c.end_angle - c.start_angle).abs.to_f - 2 * Math::PI).abs < 1e-3
    end

    def self.gather(entities, tr, out, st)
      check_auto_budget!
      entities.each do |en|
        next if st[:skip] && st[:skip].include?(en)
        case en
        when Sketchup::Edge
          c = en.curve
          next unless c
          next unless c.first_edge == en
          if c.is_a?(Sketchup::ArcCurve)
            out << [tr * c.center, tr * c.normal] if full_circle?(c) && c.radius.to_f <= st[:max_r]
          else
            pts = c.vertices.map(&:position)
            pts = pts[0...-1] if pts.size > 1 && pts.first == pts.last
            circle_from_points(pts, tr, st[:max_r], out) if pts.size == c.edges.size
          end
        when Sketchup::Face
          next unless st[:recurse]
          en.loops.each do |l|
            next if l.outer?
            circle_from_points(l.vertices.map(&:position), tr, st[:max_r], out)
          end
        when Sketchup::Group, Sketchup::ComponentInstance
          if name_match?(en, st[:kw])
            out << [tr * (en.transformation * en.definition.bounds.center), nil]
          elsif st[:recurse]
            gather(en.definition.entities, tr * en.transformation, out, st)
          end
        end
      end
    end

    def self.in_region?(c, nor, o, ua, ub, n, a, b, tol_pl)
      if nor && nor.length.to_f > 0
        return false if nor.normalize.dot(n).abs.to_f < 0.99
      end
      d = c - o
      return false if d.dot(n).abs.to_f > tol_pl
      s = d.dot(ua).to_f
      t = d.dot(ub).to_f
      tp = 1.0 * MM
      s >= -tp && s <= a + tp && t >= -tp && t <= b + tp
    end

    def self.key3(c)
      q = 0.5 * MM
      [(c.x.to_f / q).round, (c.y.to_f / q).round, (c.z.to_f / q).round]
    end

    def self.find_holes(leaf, f, pool)
      o, va, vb, thick = f
      max_r = max_dia_mm.mm.to_f / 2.0
      circles = []
      st = { max_r: max_r, kw: hole_kw, recurse: true, skip: nil }
      e = leaf[:e]
      if e.is_a?(Sketchup::Face)
        e.loops.each do |l|
          next if l.outer?
          circle_from_points(l.vertices.map(&:position), IDENTITY_TR, max_r, circles)
        end
        e.edges.each do |ed|
          c = ed.curve
          next unless c && c.first_edge == ed && full_circle?(c) && c.radius.to_f <= max_r
          circles << [c.center, c.normal]
        end
      else
        gather(e.definition.entities, leaf[:tr] * e.transformation, circles, st)
      end
      ua = va.normalize
      ub = vb.normalize
      n  = ua.cross(ub).normalize
      a  = va.length.to_f
      b  = vb.length.to_f
      tol_pl = thick + 2.0 * MM
      res = {}
      circles.each do |c, nor|
        res[key3(c)] ||= c if in_region?(c, nor, o, ua, ub, n, a, b, tol_pl)
      end
      pool.reject! do |c, nor|
        ok = in_region?(c, nor, o, ua, ub, n, a, b, tol_pl)
        res[key3(c)] ||= c if ok
        ok
      end
      res.values
    end

    # ================= Tìm các cánh =================
    def self.collect_by_name(entities, tr, kwl, out, pool, stp)
      check_auto_budget!
      entities.each do |en|
        next unless en.is_a?(Sketchup::Group) || en.is_a?(Sketchup::ComponentInstance)
        next unless visible?(en)
        if name_match?(en, kwl)
          out << { e: en, tr: tr }
        else
          t = tr * en.transformation
          gather(en.definition.entities, t, pool, stp)
          collect_by_name(en.definition.entities, t, kwl, out, pool, stp)
        end
      end
    end

    def self.has_circle?(entities)
      entities.any? { |en| en.is_a?(Sketchup::Edge) && full_circle?(en.curve) }
    end

    def self.collect_by_owner(entities, tr, out, pool, stp)
      check_auto_budget!
      entities.each do |en|
        next unless en.is_a?(Sketchup::Group) || en.is_a?(Sketchup::ComponentInstance)
        next unless visible?(en)
        ents = en.definition.entities
        if has_circle?(ents)
          out << { e: en, tr: tr }
        else
          t = tr * en.transformation
          gather(ents, t, pool, stp)
          collect_by_owner(ents, t, out, pool, stp)
        end
      end
    end

    def self.gather_leaves(sel, ctx)
      leaves = []
      pool   = []
      max_r  = max_dia_mm.mm.to_f / 2.0
      stp = { max_r: max_r, kw: hole_kw, recurse: false, skip: nil }
      gather(ctx, IDENTITY_TR, pool, stp.merge(skip: sel))
      kwl = leaf_kw
      sel.each do |e|
        if e.is_a?(Sketchup::Face) || name_match?(e, kwl)
          leaves << { e: e, tr: IDENTITY_TR }
          next
        end
        t  = e.transformation
        n0 = leaves.size
        gather(e.definition.entities, t, pool, stp)
        collect_by_name(e.definition.entities, t, kwl, leaves, pool, stp)
        collect_by_owner(e.definition.entities, t, leaves, pool, stp) if leaves.size == n0
        leaves << { e: e, tr: IDENTITY_TR } if leaves.size == n0
      end
      [leaves, pool]
    end

    # ================= Tạo kích thước =================
    def self.dim(ents, tag, p1, p2, offv)
      check_auto_budget!
      return 0 if p1.distance(p2).to_f < MM
      return 0 if offv.length.to_f < 1e-6
      if @dim_specs
        @dim_specs << [p1, p2, offv]
        return 1
      end
      tgt = (@cur_group && @cur_group.valid?) ? @cur_group.entities : ents
      d = tgt.add_dimension_linear(p1, p2, offv)
      d.layer = tag
      d.set_attribute(PLUGIN_ID, 'set', @cur_set) if @cur_set
      set_clean_text(d, p1.distance(p2).to_f)
      place_text_outside(d, p1, p2, offv)
      1
    end

    # số tròn thì bỏ .0 (chữ cố định, dim được vẽ lại mỗi khi cập nhật nên vẫn đúng)
    def self.set_clean_text(d, len)
      base = Sketchup.format_length(len)
      txt  = strip_zeros(base)
      d.text = txt == base ? '' : txt
    rescue StandardError
      nil
    end

    # đặt chữ số dim lệch ra phía ngoài (xa đối tượng) so với đường dim
    def self.place_text_outside(d, p1, p2, offv)
      mode = pref('text_position', 'center')
      position = case mode
                 when 'start' then Sketchup::DimensionLinear::TEXT_OUTSIDE_START
                 when 'end' then Sketchup::DimensionLinear::TEXT_OUTSIDE_END
                 else Sketchup::DimensionLinear::TEXT_CENTERED
                 end
      d.text_position = position
      if d.respond_to?(:has_aligned_text?) && d.has_aligned_text?
        d.aligned_text_position = Sketchup::DimensionLinear::ALIGNED_TEXT_ABOVE
      end
    rescue StandardError => err
      unless @text_warned
        @text_warned = true
        puts "HP Auto Dim: không đặt được vị trí chữ dim (#{err.message})"
      end
    end

    # chuỗi kích thước chiều cao: điểm đo nằm ở MÉP NGOÀI của đối tượng (s_edge) để chân dim không xiên vào cánh
    def self.chain(ents, tag, p0, ua, ub, job, line_s, s_edge)
      top = job[:top]
      bot = job[:bot]
      ts  = job[:ts].map { |t| [[t, bot].max, top].min }.sort.reverse
      pts = [top] + ts + [bot]
      offv = sc(ua, line_s - s_edge)
      cnt = 0
      pts.each_cons(2) do |t1, t2|
        cnt += dim(ents, tag, at(p0, ua, s_edge, ub, t1), at(p0, ua, s_edge, ub, t2), offv)
      end
      cnt
    end

    def self.layout_dims(ents, tag, lay, off, step = nil)
      step ||= step_mm.mm.to_f
      p0 = lay[:p0]
      ua = lay[:ua]
      ub = lay[:ub]
      leaves = lay[:leaves]
      s0o, s1o, t0o, t1o = lay[:ov]
      cnt = 0

      # hàng trên: chiều rộng tổng của từng cánh
      ivs = {}
      leaves.each do |lf|
        next if lf[:s1] - lf[:s0] < MM
        key = [(lf[:s0] / (0.5 * MM)).round, (lf[:s1] / (0.5 * MM)).round]
        ivs[key] ||= [lf[:s0], lf[:s1], lf[:t1]]
      end
      chosen = []
      last_end = -1e12
      ivs.values.sort_by(&:first).each do |iv|
        if iv[0] >= last_end - MM
          chosen << iv
          last_end = iv[1]
        end
      end
      small = [leg_mm.mm.to_f, off * 0.5].min
      chosen.each do |a0, a1, _tt|
        cnt += dim(ents, tag, at(p0, ua, a0, ub, t1o + small), at(p0, ua, a1, ub, t1o + small), sc(ub, off - small))
      end

      # chuỗi chiều cao + tim lỗ: cánh giống nhau chỉ lấy 1 dim, khác nhau hiện bên phải
      rq = lambda { |x| (x / (0.5 * MM)).round }
      jobs = []
      leaves.sort_by { |lf| lf[:s0] + lf[:s1] }.each do |lf|
        next if lf[:t1] - lf[:t0] < MM
        tmap = {}
        lf[:holes].each do |_, t|
          tt = [[t, lf[:t0]].max, lf[:t1]].min
          tmap[rq.call(tt)] ||= tt
        end
        tsl = tmap.values.sort.reverse
        seq = [lf[:t1]] + tsl + [lf[:t0]]
        sig = seq.each_cons(2).map { |x, y| ((x - y) / (0.1 * MM)).round }
        jobs << { ts: tsl, top: lf[:t1], bot: lf[:t0], sig: sig }
      end
      seen = {}
      uniq = []
      jobs.each do |j|
        next if seen[j[:sig]]
        seen[j[:sig]] = true
        uniq << j
      end
      left = []
      right = []
      seen_tot = {}
      uniq.each_with_index do |j, i|
        list = i == 0 ? left : right
        tot_sig = ((j[:top] - j[:bot]) / (0.1 * MM)).round
        list << j
        if j[:ts].empty?
          seen_tot[tot_sig] = true
        elsif !seen_tot[tot_sig]
          list << { ts: [], top: j[:top], bot: j[:bot] }
          seen_tot[tot_sig] = true
        end
      end
      left.each_with_index  { |j, i| cnt += chain(ents, tag, p0, ua, ub, j, s0o - (off + i * step), s0o - small) }
      right.each_with_index { |j, i| cnt += chain(ents, tag, p0, ua, ub, j, s1o + (off + i * step), s1o + small) }
      cnt
    end

    def self.signature(lay)
      r = lambda { |x| (x.to_f / (0.01 * MM)).round }
      parts = [settings_fp, r.call(lay[:p0].x), r.call(lay[:p0].y), r.call(lay[:p0].z),
               (lay[:ua].x.to_f * 1000).round, (lay[:ua].y.to_f * 1000).round, (lay[:ua].z.to_f * 1000).round,
               (lay[:ub].x.to_f * 1000).round, (lay[:ub].y.to_f * 1000).round, (lay[:ub].z.to_f * 1000).round,
               r.call(offset_mm.mm.to_f), r.call(step_mm.mm.to_f)]
      parts += lay[:ov].map { |x| r.call(x) }
      lay[:leaves].each do |lf|
        parts += [r.call(lf[:s0]), r.call(lf[:s1]), r.call(lf[:t0]), r.call(lf[:t1])]
        parts += lf[:holes].map { |s, t| [r.call(s), r.call(t)] }.sort.flatten
      end
      Zlib.crc32(parts.flatten.join(',')).to_s
    end

    def self.compute_layout(ctx, sel)
      raw, pool = gather_leaves(sel, ctx)
      leaves = []
      raw.each do |lr|
        f = frame_of(lr[:e], lr[:tr])
        leaves << lr.merge(f: f) if f
      end
      return nil if leaves.empty?
      p0, ua, ub = global_axes(leaves.first[:f])
      nholes = 0
      leaves.each do |lf|
        f = lf[:f]
        h3 = find_holes(lf, f, pool)
        cs = [f[0], f[0] + f[1], f[0] + f[2], f[0] + f[1] + f[2]]
        pr = cs.map { |c| proj(c, p0, ua, ub) }
        lf[:s0] = pr.map(&:first).min
        lf[:s1] = pr.map(&:first).max
        lf[:t0] = pr.map(&:last).min
        lf[:t1] = pr.map(&:last).max
        lf[:holes] = h3.map { |c| proj(c, p0, ua, ub) }
        nholes += lf[:holes].size
      end
      allp = sel.flat_map { |e| corners_of(e) }.map { |p| proj(p, p0, ua, ub) }
      ov = [allp.map(&:first).min, allp.map(&:first).max, allp.map(&:last).min, allp.map(&:last).max]
      lay = { p0: p0, ua: ua, ub: ub, leaves: leaves, ov: ov, nholes: nholes }
      lay[:sig] = signature(lay)
      lay
    end

    # ================= Lưu "bộ kích thước" để cập nhật tự động =================
    def self.load_sets(model)
      raw = model.get_attribute(PLUGIN_ID, 'sets', '[]')
      raise ArgumentError, 'Dữ liệu HP DIM quá lớn; giữ nguyên dữ liệu, không tự dựng lại.' unless raw.is_a?(String) && raw.bytesize <= 16 * 1024 * 1024
      sets = JSON.parse(raw)
      unless sets.is_a?(Array) && sets.all? { |set| set.is_a?(Hash) && !set['id'].nil? }
        raise ArgumentError, 'Dữ liệu HP DIM không đúng cấu trúc; giữ nguyên DIM và dữ liệu cũ.'
      end
      raise ArgumentError, 'ID bộ DIM bị trùng; giữ nguyên dữ liệu cũ.' unless sets.map { |set| set['id'] }.uniq.size == sets.size
      sets
    rescue JSON::ParserError => error
      raise ArgumentError, "Dữ liệu HP DIM không đọc được; giữ nguyên dữ liệu cũ (#{error.message})."
    end

    def self.save_sets(model, sets)
      raw = JSON.generate(sets)
      model.set_attribute(PLUGIN_ID, 'sets', raw) unless model.get_attribute(PLUGIN_ID, 'sets', '[]') == raw
    end

    def self.new_set_id
      "s#{SecureRandom.hex(16)}"
    end

    def self.ctx_pid(model)
      path = model.active_path
      (path.nil? || path.empty?) ? 0 : path.last.persistent_id
    end

    def self.ctx_entities(model, pid)
      return model.entities if pid.to_i == 0
      e = entity_by_pid(model, pid)
      (e && e.valid? && e.respond_to?(:definition)) ? e.definition.entities : nil
    end

    def self.dim_items(ents, sid)
      return [] unless ents
      if @dim_index && @dim_index[ents.object_id]
        return (@dim_index[ents.object_id][sid] || []).select(&:valid?)
      end
      candidates = ents.grep(Sketchup::Group) + ents.grep(Sketchup::Dimension)
      if @dim_index
        index = (@dim_index[ents.object_id] ||= candidates.each_with_object({}) do |e, out|
          check_auto_budget!
          id = e.get_attribute(PLUGIN_ID, 'set')
          (out[id] ||= []) << e if id
        end)
        return (index[sid] || []).select(&:valid?)
      end
      candidates.select do |entity|
        check_auto_budget!
        entity.get_attribute(PLUGIN_ID, 'set') == sid
      end
    end

    def self.erase_dims(ents, sid)
      items = dim_items(ents, sid)
      ents.erase_entities(items) unless items.empty?
      @dim_index[ents.object_id].delete(sid) if @dim_index && @dim_index[ents.object_id]
    end

    # Stage the replacement before removing the old group. A failed renderer
    # leaves the old dimensions and set metadata available for retry.
    def self.replace_dims(ents, s, tag)
      reused = try_update_dims(ents, s, tag) { yield }
      return reused unless reused.nil?
      old_items = dim_items(ents, s['id'])
      @cur_set = s['id']
      fresh = begin_group(ents, s['id'], tag, group_name(s['mode']), s['pgid'])
      count = yield
      if count.to_i <= 0 && (s['ndim'].to_i > 0 || s['mode'] != 'cont')
        raise 'Không tạo được DIM mới; bộ DIM cũ được giữ nguyên.'
      end
      end_group
      previous = old_items.find { |item| item.is_a?(Sketchup::Group) }
      if previous && fresh.valid?
        fresh.name = previous.name
        fresh.material = previous.material if previous.respond_to?(:material) && previous.material
        fresh.hidden = previous.hidden? if previous.respond_to?(:hidden?)
      end
      if @replacement_batch
        @replacement_batch << [ents, old_items, fresh]
      else
        ents.erase_entities(old_items) unless old_items.empty?
      end
      if @dim_index && @dim_index[ents.object_id]
        @dim_index[ents.object_id][s['id']] = fresh.valid? ? [fresh] : []
      end
      count
    rescue StandardError
      @cur_group = nil
      fresh.erase! if fresh && fresh.valid?
      raise
    ensure
      @cur_set = nil
      @cur_group = nil
    end

    # ---- Kích thước từng cánh + tim lỗ ----
    def self.run_holes
      model = Sketchup.active_model
      sel = model.selection.to_a.select do |e|
        (e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance) || e.is_a?(Sketchup::Face)) && !hp_dim?(e)
      end
      remember_entities(model, sel)
      if sel.empty?
        UI.messagebox('Hãy chọn ít nhất 1 Group / Component / Face.')
        return
      end
      leave_hp_groups(model)
      @updating = true
      ctx = model.active_entities
      lay = compute_layout(ctx, sel)
      return unless lay
      off = offset_mm.mm.to_f
      model.start_operation('HP Dim cánh + lỗ', true)
      tag  = new_scene_tag(model, {'mode' => 'std', 'pgid' => current_pgid(model)})
      sets = load_sets(model)
      cp   = ctx_pid(model)
      pids = sel.map(&:persistent_id)
      ex   = sets.find { |s| same_scene?(model, s) && s['ctx'] == cp && s['sel'].sort == pids.sort && (s['mode'] || 'std') == 'std' }
      sid  = ex ? ex['id'] : new_set_id
      updated = { 'id' => sid, 'ctx' => cp, 'sel' => pids, 'sel_info' => sel.map { |e| track_info(e) }, 'sig' => lay[:sig], 'mode' => 'std', 'tag' => tag.name, 'pgid' => current_pgid(model), 'ndim' => ex ? ex['ndim'] : 0 }
      updated['tag_schema'] = 219
      remember_tag(tag, updated)
      total = replace_dims(ctx, updated, tag) { layout_dims(ctx, tag, lay, off) }
      updated['ndim'] = total
      updated['draw_fp'] = settings_fp
      sets.delete(ex) if ex
      sets << updated
      save_sets(model, sets)
      model.commit_operation
      Sketchup.status_text = "HP Auto Dim: #{lay[:leaves].size} cánh, #{total} kích thước, #{lay[:nholes]} tim lỗ, Tag #{tag.name}"
      if lay[:nholes] == 0
        UI.messagebox("Không tìm thấy lỗ nào.\nKiểm tra: đường kính lỗ tối đa (Cài đặt), lỗ phải nằm trên mặt chính của cánh, hoặc đặt từ khóa tên Component lỗ.")
      end
    rescue => err
      @cur_set = nil
      model.abort_operation
      UI.messagebox("Lỗi: #{err.message}\n#{err.backtrace.first}")
    ensure
      @updating = false
    end

    # ================= Kích thước đối tượng (chọn 1 hoặc nhiều đối tượng) =================
    def self.obj_items(sel)
      items = []
      sel.each do |e|
        check_auto_budget!
        if e.is_a?(Sketchup::Face)
          f = frame_of(e)
          items << { o: f[0], vecs: [f[1], f[2]] } if f
        else
          bx = box_of(e)
          items << { o: bx[0], vecs: bx[1] } if bx
        end
      end
      items
    end

    def self.compute_obj(sel, two_d)
      items = obj_items(sel)
      return nil if items.empty?
      r = lambda { |x| (x.to_f / (0.01 * MM)).round }
      parts = [settings_fp, r.call(offset_mm.mm.to_f), r.call(leg_mm.mm.to_f), two_d ? 1 : 0]
      items.each do |it|
        if two_d && it[:vecs].size == 3
          it[:thin] = (0..2).min_by { |i| it[:vecs][i].length.to_f }
        end
        parts += [r.call(it[:o].x), r.call(it[:o].y), r.call(it[:o].z)]
        it[:vecs].each { |v| parts += [r.call(v.x), r.call(v.y), r.call(v.z)] }
      end
      { items: items, sig: Zlib.crc32(parts.join(',')).to_s }
    end

    # mỗi đối tượng: 3 chiều (dài/rộng/cao) hoặc 2 chiều (bỏ độ dày); chân dim hở khỏi đối tượng
    def self.draw_obj_dims(ents, tag, lay, off)
      small = [leg_mm.mm.to_f, off * 0.5].min
      cnt = 0
      lay[:items].each do |it|
        o = it[:o]
        vecs = it[:vecs]
        next if vecs.any? { |v| v.length.to_f < MM }
        units = vecs.map(&:normalize)
        n = vecs.size
        if n == 2 || it[:thin]
          axes = (0...n).to_a
          axes -= [it[:thin]] if it[:thin]
          a, b = axes[0], axes[1]
          specs = [
            { start: o + vecs[b], v: vecs[a], dir: units[b] },
            { start: o, v: vecs[b], dir: sc(units[a], -1) }
          ]
        else
          specs = [
            { start: o, v: vecs[0], dir: (sc(units[1], -1) + sc(units[2], -1)).normalize },
            { start: o + vecs[0], v: vecs[1], dir: (units[0] + sc(units[2], -1)).normalize },
            { start: o, v: vecs[2], dir: (sc(units[0], -1) + sc(units[1], -1)).normalize }
          ]
        end
        specs.each do |sp|
          p1 = sp[:start] + sc(sp[:dir], small)
          p2 = p1 + sp[:v]
          cnt += dim(ents, tag, p1, p2, sc(sp[:dir], off - small))
        end
      end
      cnt
    end

    def self.run_obj
      model = Sketchup.active_model
      sel = model.selection.to_a.select do |e|
        (e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance) || e.is_a?(Sketchup::Face)) && !hp_dim?(e)
      end
      remember_entities(model, sel)
      if sel.empty?
        UI.messagebox('Hãy chọn ít nhất 1 Group / Component / Face.')
        return
      end
      leave_hp_groups(model)
      @updating = true
      ctx = model.active_entities
      two_d = obj_two_d?
      lay = compute_obj(sel, two_d)
      return unless lay
      model.start_operation('HP Kích thước đối tượng', true)
      tag  = new_scene_tag(model, {'mode' => 'obj', 'pgid' => current_pgid(model)})
      sets = load_sets(model)
      cp   = ctx_pid(model)
      pids = sel.map(&:persistent_id)
      ex   = sets.find { |x| same_scene?(model, x) && x['ctx'] == cp && x['sel'].sort == pids.sort && x['mode'] == 'obj' }
      sid  = ex ? ex['id'] : new_set_id
      updated = { 'id' => sid, 'ctx' => cp, 'sel' => pids, 'sel_info' => sel.map { |e| track_info(e) }, 'sig' => lay[:sig], 'mode' => 'obj', 'two_d' => two_d, 'tag' => tag.name, 'pgid' => current_pgid(model), 'ndim' => ex ? ex['ndim'] : 0 }
      updated['tag_schema'] = 219
      remember_tag(tag, updated)
      n = replace_dims(ctx, updated, tag) { draw_obj_dims(ctx, tag, lay, offset_mm.mm.to_f) }
      updated['ndim'] = n
      updated['draw_fp'] = settings_fp
      sets.delete(ex) if ex
      sets << updated
      save_sets(model, sets)
      model.commit_operation
      Sketchup.status_text = "HP Auto Dim: #{n} kích thước cho #{lay[:items].size} đối tượng, Tag #{tag.name}"
    rescue => err
      @cur_set = nil
      model.abort_operation
      UI.messagebox("Lỗi: #{err.message}\n#{err.backtrace.first}")
    ensure
      @updating = false
    end

    # ================= Điểm neo (bám theo đối tượng, kể cả group lồng sâu) =================
    def self.inst_product(insts)
      t = IDENTITY_TR
      insts.each { |i| t = t * i.transformation }
      t
    end

    # ================= Theo dõi đối tượng (bám theo cả khi bị tạo lại / đổi id) =================
    def self.bb_of(e)
      b = e.bounds
      [b.min.x.to_f, b.min.y.to_f, b.min.z.to_f, b.max.x.to_f, b.max.y.to_f, b.max.z.to_f]
    end

    def self.inst_key(e)
      e.respond_to?(:definition) ? "#{e.name}|#{e.definition.name}" : ''
    end

    def self.track_info(e)
      { 'pid' => e.persistent_id, 'nm' => inst_key(e), 'bb' => bb_of(e) }
    end

    def self.bb_overlap(a, b)
      r = 0.0
      3.times do |i|
        ov = [a[i + 3], b[i + 3]].min - [a[i], b[i]].max
        den = [[a[i + 3] - a[i], b[i + 3] - b[i]].min, MM].max
        r += [[ov / den, 0.0].max, 1.0].min
      end
      r / 3.0
    end

    # tìm lại đối tượng: theo id, nếu mất thì theo tên + vị trí/kích thước gần giống
    def self.find_instance_in(ents, t)
      pid = t['pid']
      if pid
        e = entity_by_pid(Sketchup.active_model, pid)
        return e if e && e.valid? && (e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance))
      end
      return nil unless t['bb']
      best = nil
      bs = 0.3
      ambiguous = false
      candidates = ents.grep(Sketchup::Group) + ents.grep(Sketchup::ComponentInstance)
      candidates.uniq.each do |en|
        check_auto_budget!
        next unless visible?(en)
        next if en.bounds.empty?
        candidate = bb_of(en)
        # Two adjacent cabinets can have identical names and overlap on Y/Z.
        # Averages alone used to rebind a deleted source to its neighbour.
        disjoint = 3.times.any? do |axis|
          old_size = t['bb'][axis + 3] - t['bb'][axis]
          new_size = candidate[axis + 3] - candidate[axis]
          overlap = [t['bb'][axis + 3], candidate[axis + 3]].min - [t['bb'][axis], candidate[axis]].max
          old_size >= MM && new_size >= MM ? overlap <= 0.01 * MM : overlap < -2.0 * MM
        end
        next if disjoint
        sc_ = bb_overlap(t['bb'], candidate)
        sc_ += 0.5 if t['nm'] && t['nm'] != '' && inst_key(en) == t['nm']
        if (sc_ - bs).abs < 0.01 && best
          ambiguous = true
        elsif sc_ > bs
          bs = sc_
          best = en
          ambiguous = false
        end
      end
      ambiguous ? nil : best
    end

    # đối tượng ngoài cùng chứa điểm (để lưu toạ độ tương đối trong hộp bao của nó)
    def self.trk_for(model, insts, pos)
      root = nil
      if insts && !insts.empty? && insts.first.parent.is_a?(Sketchup::Model)
        root = insts.first
      else
        bv = nil
        model.entities.each do |en|
          next unless en.is_a?(Sketchup::Group) || en.is_a?(Sketchup::ComponentInstance)
          next unless visible?(en)
          bb = en.bounds
          next if bb.empty? || !bb.contains?(pos)
          v = bb.width.to_f * bb.height.to_f * bb.depth.to_f
          if root.nil? || v < bv
            root = en
            bv = v
          end
        end
      end
      return nil unless root
      bb = root.bounds
      mn = [bb.min.x.to_f, bb.min.y.to_f, bb.min.z.to_f]
      mx = [bb.max.x.to_f, bb.max.y.to_f, bb.max.z.to_f]
      pp = [pos.x.to_f, pos.y.to_f, pos.z.to_f]
      n = (0..2).map { |i| (mx[i] - mn[i]) < 1e-6 ? 0.5 : (pp[i] - mn[i]) / (mx[i] - mn[i]) }
      t = track_info(root)
      t['n'] = n
      t
    rescue StandardError
      nil
    end

    def self.resolve_by_trk(model, a)
      t = a['trk']
      return nil unless t && t['n']
      e = find_instance_in(model.entities, t)
      return nil unless e
      bb = e.bounds
      mn = [bb.min.x.to_f, bb.min.y.to_f, bb.min.z.to_f]
      mx = [bb.max.x.to_f, bb.max.y.to_f, bb.max.z.to_f]
      t['pid'] = e.persistent_id
      t['bb'] = bb_of(e)
      Geom::Point3d.new(mn[0] + t['n'][0] * (mx[0] - mn[0]),
                        mn[1] + t['n'][1] * (mx[1] - mn[1]),
                        mn[2] + t['n'][2] * (mx[2] - mn[2]))
    end

    # điểm bám vào đỉnh / cạnh còn tồn tại (đi theo hình học khi chỉnh sửa bên trong)
    def self.resolve_bound(model, a)
      return nil unless a['v'] || a['e']
      tr = IDENTITY_TR
      (a['path'] || []).each do |pid|
        inst = entity_by_pid(model, pid)
        return nil unless inst && inst.valid? && inst.respond_to?(:transformation)
        tr = tr * inst.transformation
      end
      if a['v']
        v = entity_by_pid(model, a['v'])
        return tr * v.position if v && v.valid? && v.respond_to?(:position)
      end
      if a['e']
        e = entity_by_pid(model, a['e'])
        if e && e.valid? && e.respond_to?(:start)
          sp = e.start.position
          ep = e.end.position
          r  = a['r'].to_f
          lp = Geom::Point3d.new(sp.x.to_f + (ep.x.to_f - sp.x.to_f) * r,
                                 sp.y.to_f + (ep.y.to_f - sp.y.to_f) * r,
                                 sp.z.to_f + (ep.z.to_f - sp.z.to_f) * r)
          return tr * lp
        end
      end
      nil
    end

    # thứ tự: đỉnh/cạnh -> tỉ lệ trong hộp bao đối tượng (theo kích thước mới) -> vị trí cục bộ -> vị trí ban đầu
    def self.resolve_anchor(model, a)
      return nil unless a
      pt = resolve_bound(model, a)
      return pt if pt
      pt = resolve_by_trk(model, a)
      return pt if pt
      pt = resolve_anchor_exact(model, a)
      return pt if pt
      w = a['w']
      w ? Geom::Point3d.new(w[0], w[1], w[2]) : nil
    end

    def self.resolve_anchor_exact(model, a)
      return nil unless a
      tr = IDENTITY_TR
      ok = true
      (a['path'] || []).each do |pid|
        inst = entity_by_pid(model, pid)
        if inst && inst.valid? && inst.respond_to?(:transformation)
          tr = tr * inst.transformation
        else
          ok = false
          break
        end
      end
      return nil unless ok
      if a['v']
        v = entity_by_pid(model, a['v'])
        return tr * v.position if v && v.valid? && v.respond_to?(:position)
      end
      if a['e']
        e = entity_by_pid(model, a['e'])
        if e && e.valid? && e.respond_to?(:start)
          sp = e.start.position
          ep = e.end.position
          r  = a['r'].to_f
          lp = Geom::Point3d.new(sp.x.to_f + (ep.x.to_f - sp.x.to_f) * r,
                                 sp.y.to_f + (ep.y.to_f - sp.y.to_f) * r,
                                 sp.z.to_f + (ep.z.to_f - sp.z.to_f) * r)
          return tr * lp
        end
      end
      p = a['p']
      return nil unless p
      tr * Geom::Point3d.new(p[0], p[1], p[2])
    end

    def self.world_anchor(pos, model = nil)
      xyz = [pos.x.to_f, pos.y.to_f, pos.z.to_f]
      a = { 'path' => [], 'p' => xyz, 'w' => xyz }
      if model
        t = trk_for(model, [], pos)
        a['trk'] = t if t
      end
      a
    end

    def self.make_anchor(model, ip, pos, direct = false)
      return world_anchor(pos, direct ? nil : model) if ip.nil?
      constrained = ip.position.distance(pos).to_f > 1.0 * MM
      insts = []
      if ip.respond_to?(:instance_path)
        ipath = ip.instance_path
        insts = ipath.to_a.select { |e| e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance) } if ipath
      end
      tr  = inst_product(insts)
      loc = tr.inverse * pos
      a = { 'path' => insts.map(&:persistent_id),
            'p' => [loc.x.to_f, loc.y.to_f, loc.z.to_f],
            'w' => [pos.x.to_f, pos.y.to_f, pos.z.to_f] }
      unless constrained
        if ip.vertex
          a['v'] = ip.vertex.persistent_id
        elsif ip.edge && ip.degrees_of_freedom == 1
          e  = ip.edge
          sp = e.start.position
          ep = e.end.position
          seg = ep - sp
          d2 = seg.dot(seg).to_f
          if d2 > 1e-12
            a['e'] = e.persistent_id
            a['r'] = (loc - sp).dot(seg).to_f / d2
          end
        end
      end
      w = resolve_anchor_exact(model, a)
      return world_anchor(pos, direct ? nil : model) if w.nil? || w.distance(pos).to_f > MM
      t = trk_for(model, insts, pos) unless direct && insts.empty?
      a['trk'] = t if t
      a
    rescue StandardError
      world_anchor(pos, direct ? nil : model)
    end

    # ================= Dim liên tiếp / Dim cắt =================
    def self.auto_axis(pts)
      d = pts.last - pts.first
      return X_AXIS if d.length.to_f < 1e-9
      d = d.normalize
      [X_AXIS, Y_AXIS, Z_AXIS].each do |ax|
        k = d.dot(ax).to_f
        return (k < 0 ? sc(ax, -1) : ax) if k.abs > 0.995
      end
      d
    end

    def self.box_hit?(en, tr, box)
      bb = en.bounds
      return false if bb.empty?
      pts = (0..7).map { |i| tr * bb.corner(i) }
      mn = [pts.map { |p| p.x.to_f }.min, pts.map { |p| p.y.to_f }.min, pts.map { |p| p.z.to_f }.min]
      mx = [pts.map { |p| p.x.to_f }.max, pts.map { |p| p.y.to_f }.max, pts.map { |p| p.z.to_f }.max]
      3.times do |i|
        return false if mx[i] < box[0][i] - MM || mn[i] > box[1][i] + MM
      end
      true
    end

    def self.dist_pt_seg(p, a, b)
      ab = b - a
      l2 = ab.dot(ab).to_f
      return p.distance(a).to_f if l2 < 1e-12
      t = (p - a).dot(ab).to_f / l2
      t = [[t, 0.0].max, 1.0].min
      q = Geom::Point3d.new(a.x.to_f + ab.x.to_f * t, a.y.to_f + ab.y.to_f * t, a.z.to_f + ab.z.to_f * t)
      p.distance(q).to_f
    end

    # hits: giao điểm chính xác; lhits: thêm các mặt vuông góc với đường cắt nằm lệch trong dung sai ngang
    # (để lấy cả chi tiết nằm lõm vào như chân tủ)
    def self.collect_hits(ents, tr, a, b, len, box, hits, lhits = nil, lat = 0.0, vis = nil)
      scales = [tr.xaxis.length.to_f, tr.yaxis.length.to_f, tr.zaxis.length.to_f]
      return if scales.any? { |scale| !scale.finite? || scale < 1e-9 }
      determinant = tr.xaxis.dot(tr.yaxis.cross(tr.zaxis)).to_f
      return if !determinant.finite? || determinant.abs / scales.inject(:*) < 1e-12
      inv = tr.inverse
      la = inv * a
      lb = inv * b
      ld = lb - la
      ldl = ld.length.to_f
      ldn = ldl > 1e-12 ? ld.normalize : nil
      avg = scales.inject(:+) / 3.0
      tol_local = lat / (avg > 1e-9 ? avg : 1.0)
      lax, lay, laz = la.x.to_f, la.y.to_f, la.z.to_f
      lbx, lby, lbz = lb.x.to_f, lb.y.to_f, lb.z.to_f
      ents.each do |en|
        check_auto_budget!
        case en
        when Sketchup::Face
          # Kiểm tra mặt phẳng trước (1 lệnh API, không tạo đối tượng mới):
          # phần lớn các mặt bị loại ngay tại đây.
          pl = en.plane
          nl = Math.sqrt(pl[0] * pl[0] + pl[1] * pl[1] + pl[2] * pl[2])
          next if nl < 1e-12
          d0 = (pl[0] * lax + pl[1] * lay + pl[2] * laz + pl[3]) / nl
          d1 = (pl[0] * lbx + pl[1] * lby + pl[2] * lbz + pl[3]) / nl
          next if (d0 > 1e-6 && d1 > 1e-6) || (d0 < -1e-6 && d1 < -1e-6)
          next unless visible?(en)
          n  = en.normal
          den = d0 - d1
          next if den.abs < 1e-9
          u = d0 / den
          next unless u.finite?
          next if u < -1e-9 || u > 1.0 + 1e-9
          pt = Geom::Point3d.new(la.x.to_f + (lb.x.to_f - la.x.to_f) * u,
                                 la.y.to_f + (lb.y.to_f - la.y.to_f) * u,
                                 la.z.to_f + (lb.z.to_f - la.z.to_f) * u)
          c = en.classify_point(pt)
          if c == Sketchup::Face::PointInside || c == Sketchup::Face::PointOnEdge ||
             c == Sketchup::Face::PointOnVertex
            hits << u * len
          elsif lhits && ldn && n.dot(ldn).to_f.abs > 0.9995
            bq = nil
            bd = nil
            en.outer_loop.edges.each do |e|
              q = closest_pt_seg(pt, e.start.position, e.end.position)
              dd = pt.distance(q).to_f
              if bd.nil? || dd < bd
                bd = dd
                bq = q
              end
            end
            if bd && bd <= tol_local
              lhits << u * len if vis.nil? || vis.call(tr * bq)
            end
          end
        when Sketchup::Group, Sketchup::ComponentInstance
          next unless visible?(en)
          next unless box_hit?(en, tr, box)
          collect_hits(en.definition.entities, tr * en.transformation, a, b, len, box, hits, lhits, lat, vis)
        end
      end
    end

    # trả về mảng khoảng cách (tính từ a) của các mặt bị đoạn a-b cắt qua
    def self.cut_hits(model, a, b, cam = nil, mode = nil)
      mode ||= cut_mode
      len = (b - a).length.to_f
      return [] if len < MM
      lat = mode == 'base' ? lat_mm.mm.to_f : 0.0
      box = [[[a.x.to_f, b.x.to_f].min - lat, [a.y.to_f, b.y.to_f].min - lat, [a.z.to_f, b.z.to_f].min - lat],
             [[a.x.to_f, b.x.to_f].max + lat, [a.y.to_f, b.y.to_f].max + lat, [a.z.to_f, b.z.to_f].max + lat]]
      hits = []
      lat_hits = []
      vis = cam ? lambda { |wp| visible_from_cam?(model, wp, cam) } : nil
      collect_hits(model.entities.grep(Sketchup::Face), IDENTITY_TR, a, b, len, box, hits)
      model.entities.each do |en|
        next unless en.is_a?(Sketchup::Group) || en.is_a?(Sketchup::ComponentInstance)
        next unless visible?(en)
        next unless box_hit?(en, IDENTITY_TR, box)
        h  = []
        lh = []
        collect_hits(en.definition.entities, en.transformation, a, b, len, box, h, (mode == 'base' ? lh : nil), lat, vis)
        next if h.empty?
        hits.concat(h)
        lat_hits.concat(lh)
      end
      return [] if hits.empty?
      # bề mặt lấy thêm (nằm lệch/lõm) chỉ dùng để KÉO DÀI chuỗi ở hai đầu,
      # không chen vào giữa các bề mặt cắt thật (tránh chi tiết thấp hơn mặt cắt làm vỡ ô dim)
      emin = hits.min
      emax = hits.max
      lat_hits.each { |v| hits << v if v < emin - 0.5 * MM || v > emax + 0.5 * MM }
      hits.sort!
      out = []
      hits.each { |h| out << h if out.empty? || (h - out.last) > 0.2 * MM }
      out
    end

    # các đoạn dim: chiếu các điểm lên đường thẳng qua ref theo phương axis
    def self.line_segments(pts, axis, ref)
      ss = pts.map { |p| (p - ref).dot(axis).to_f }.sort
      uniq = []
      ss.each { |v| uniq << v if uniq.empty? || (v - uniq.last) > 0.1 * MM }
      qs = uniq.map { |v| ref + sc(axis, v) }
      segs = []
      qs.each_cons(2) { |p, q| segs << { p1: p, p2: q, len: p.distance(q).to_f } }
      segs
    end

    # hướng kéo dim: trục toạ độ (vuông góc với trục đo) gần nhất với hướng chuột kéo
    def self.pick_offset_dir(dm, axis, lock = nil)
      cands = lock ? [lock] : [X_AXIS, Y_AXIS, Z_AXIS]
      best = nil
      bs = -1.0
      cands.each do |c|
        o = c - sc(axis, c.dot(axis).to_f)
        next if o.length.to_f < 0.5
        o = o.normalize
        v = dm.dot(o).to_f.abs
        if v > bs
          best = o
          bs = v
        end
      end
      best
    end

    # vector chân dim = dm chiếu lên hướng kéo od (od=nil: tự chọn trục toạ độ)
    def self.line_offset(dm, axis, perp, od = nil)
      if od
        o = od - sc(axis, od.dot(axis).to_f)
        od = o.length.to_f > 1e-6 ? o.normalize : nil
      end
      od ||= pick_offset_dir(dm, axis)
      return sc(perp, 5.0 * MM) unless od
      k = dm.dot(od).to_f
      return sc(od, k < 0 ? -5.0 * MM : 5.0 * MM) if k.abs < 3.0 * MM
      sc(od, k)
    end

    def self.view_perp(axis, view)
      perp = axis.cross(view.camera.direction)
      perp = axis.axes[0] if perp.length.to_f < 1e-3
      perp.normalize
    end

    def self.seg_excluded?(s, _i, sg)
      sk = s['skip_mm'].to_f
      sk > 0 && (sg[:len] / MM) <= sk + 0.01
    end

    # giao của đường thẳng (o, dir) với hộp AABB: trả về [t_vào, t_ra] hoặc nil
    def self.line_aabb_interval(o, dir, mn, mx, pad = MM)
      t0 = -1e12
      t1 = 1e12
      oo = [o.x.to_f, o.y.to_f, o.z.to_f]
      dd = [dir.x.to_f, dir.y.to_f, dir.z.to_f]
      3.times do |i|
        if dd[i].abs < 1e-9
          return nil if oo[i] < mn[i] - pad || oo[i] > mx[i] + pad
        else
          ta = (mn[i] - pad - oo[i]) / dd[i]
          tb = (mx[i] + pad - oo[i]) / dd[i]
          ta, tb = tb, ta if ta > tb
          t0 = ta if ta > t0
          t1 = tb if tb < t1
          return nil if t0 > t1
        end
      end
      [t0, t1]
    end

    # Khoảng (theo trục, tính từ a0) mà các đối tượng ngoài cùng bị đường đo xuyên qua chiếm giữ
    def self.object_extent(model, a0, axis, d)
      object_extent_range(model, a0, axis, 0.0, d)
    end

    def self.object_extent_range(model, a0, axis, lo, hi)
      elo = nil
      ehi = nil
      pa = a0 + sc(axis, lo)
      pb = a0 + sc(axis, hi)
      len = hi - lo
      return nil if len < MM
      box = [[[pa.x.to_f, pb.x.to_f].min, [pa.y.to_f, pb.y.to_f].min, [pa.z.to_f, pb.z.to_f].min],
             [[pa.x.to_f, pb.x.to_f].max, [pa.y.to_f, pb.y.to_f].max, [pa.z.to_f, pb.z.to_f].max]]
      tol = 20.0 * MM
      model.entities.each do |en|
        next unless en.is_a?(Sketchup::Group) || en.is_a?(Sketchup::ComponentInstance)
        next unless visible?(en)
        bb = en.bounds
        next if bb.empty?
        iv = line_aabb_interval(a0, axis,
                                [bb.min.x.to_f, bb.min.y.to_f, bb.min.z.to_f],
                                [bb.max.x.to_f, bb.max.y.to_f, bb.max.z.to_f])
        next unless iv
        next if iv[1] < lo - tol || iv[0] > hi + tol
        h = []
        collect_hits(en.definition.entities, en.transformation, pa, pb, len, box, h)
        next if h.empty?
        elo = elo ? [elo, iv[0]].min : iv[0]
        ehi = ehi ? [ehi, iv[1]].max : iv[1]
      end
      elo ? [elo, ehi] : nil
    end

    # danh sách vị trí các bề mặt (tính từ ref theo trục) trong phạm vi đối tượng
    def self.surface_list(model, ref, axis, lo, hi, cam = nil, mode = nil)
      ex = object_extent_range(model, ref, axis, lo - 1.0 * MM, hi + 1.0 * MM)
      return [] unless ex
      elo = [ex[0], lo].min - 5.0 * MM
      ehi = [ex[1], hi].max + 5.0 * MM
      hits = cut_hits(model, ref + sc(axis, elo), ref + sc(axis, ehi), cam, mode)
      hits.map { |h| elo + h }
    end

    # ghi nhớ mỗi điểm của dim liên tiếp đang nằm trên bề mặt thứ mấy (để bám theo khi đổi kích thước)
    def self.annotate_surfaces(model, set)
      return unless set['mode'] == 'cont'
      return if set['anchor_mode'] == 'native'
      return if set['anchors'].all? { |anchor| resolve_bound(model, anchor) }
      pts = set['anchors'].map { |a| resolve_anchor(model, a) }
      return if pts.size < 2 || pts.any?(&:nil?)
      axis = Geom::Vector3d.new(set['axis'][0], set['axis'][1], set['axis'][2])
      ref  = pts.first
      ss   = pts.map { |p| (p - ref).dot(axis).to_f }
      list = surface_list(model, ref, axis, ss.min, ss.max, cam_from_a(set['cam']), set['cmode'])
      return if list.size < 2
      set['hn'] ||= list.size
      return unless set['hn'] == list.size
      set['anchors'].each_with_index do |a, i|
        next if a['hi']
        best = nil
        list.each_with_index do |v, j|
          dd = (v - ss[i]).abs
          best = [dd, j] if best.nil? || dd < best[0]
        end
        a['hi'] = best[1] if best && best[0] < 3.0 * MM
      end
    rescue StandardError => err
      puts "HP annotate: #{err.message}"
    end

    # khi đối tượng đổi kích thước: điểm nào đang nằm trên bề mặt thì bám theo đúng bề mặt đó
    def self.adjust_by_surfaces(model, s, pts, axis)
      return pts unless s['hn']
      return pts if s['anchor_mode'] == 'native' || s['anchors'].all? { |anchor| resolve_bound(model, anchor) }
      idx = s['anchors'].map { |a| a['hi'] }
      j0 = idx.index { |v| !v.nil? }
      return pts unless j0
      ref = pts.first
      ss  = pts.map { |p| (p - ref).dot(axis).to_f }
      list = surface_list(model, ref, axis, ss.min, ss.max, cam_from_a(s['cam']), s['cmode'])
      return pts unless list.size == s['hn']
      base = pts[j0]
      pts.each_with_index.map do |p, i|
        if idx[i] && resolve_bound(model, s['anchors'][i]).nil?
          base + sc(axis, list[idx[i]] - list[idx[j0]])
        else
          p
        end
      end
    end

    def self.signed_dir(dm, od)
      return od unless od
      dm.dot(od).to_f < 0 ? sc(od, -1) : od
    end

    # hộp bao (min, max) của các đối tượng ngoài cùng đang hiển thị - tính 1 lần rồi dùng lại cho mượt
    def self.root_boxes(model)
      out = []
      model.entities.each do |en|
        next unless en.is_a?(Sketchup::Group) || en.is_a?(Sketchup::ComponentInstance)
        next unless visible?(en)
        bb = en.bounds
        next if bb.empty?
        out << [[bb.min.x.to_f, bb.min.y.to_f, bb.min.z.to_f], [bb.max.x.to_f, bb.max.y.to_f, bb.max.z.to_f]]
      end
      out
    end

    # trả về [hướng (vuông góc trục), khoảng từ đường đo tới mép ngoài đối tượng theo hướng đó]
    def self.gap_parts(model, ref, axis, lo, hi, od, boxes = nil)
      boxes ||= root_boxes(model)
      o2 = od - sc(axis, od.dot(axis).to_f)
      o2 = o2.length.to_f > 1e-6 ? o2.normalize : od
      pad = lat_mm.mm.to_f
      oo = [o2.x.to_f, o2.y.to_f, o2.z.to_f]
      rr = [ref.x.to_f, ref.y.to_f, ref.z.to_f]
      ext = 0.0
      boxes.each do |mn, mx|
        iv = line_aabb_interval(ref, axis, mn, mx, pad)
        next unless iv
        next if iv[1] < lo - 20.0 * MM || iv[0] > hi + 20.0 * MM
        e = 0.0
        3.times do |i|
          x1 = (mn[i] - rr[i]) * oo[i]
          x2 = (mx[i] - rr[i]) * oo[i]
          e += (x1 > x2 ? x1 : x2)
        end
        ext = e if e > ext
      end
      [o2, ext]
    end

    # [vector tới đường dim, vector tới điểm bắt đầu chân dim (cách mép đối tượng một khoảng hở nhỏ)]
    def self.off_legs(model, ref, axis, lo, hi, od, gap_mm = nil, boxes = nil, length = nil)
      gap = (gap_mm || offset_mm).to_f * MM
      o2, ext = gap_parts(model, ref, axis, lo, hi, od, boxes)
      total = ext + gap
      total = 5.0 * MM if !length && total < 5.0 * MM
      if gap > 0
        small = length ? leg_mm * MM : [leg_mm * MM, gap * 0.5].min
        legs = sc(o2, ext + small)
      else
        legs = Geom::Vector3d.new(0, 0, 0)
      end
      [sc(o2, total), legs]
    end

    # so le: đoạn ngắn đẩy ra hàng ngoài (xen kẽ 2 hàng) để chữ không đè nhau
    def self.seg_offset_list(segs, off, initial_run = 0)
      step  = step_mm.mm.to_f
      short = stagger_mm.mm.to_f
      od = off.length.to_f > 1e-9 ? off.normalize : nil
      run = initial_run
      list = []
      segs.each_with_index do |sg, i|
        skip = block_given? ? yield(i, sg) : false
        if skip
          list << nil
          run = 0
          next
        end
        if od && sg[:len] < short
          row = 1 + (run % 2)
          run += 1
        else
          row = 0
          run = 0
        end
        list << (row == 0 ? off : off + sc(od, row * step))
      end
      list
    end

    def self.cont_segments(pts, axis, ref)
      qs = pts.map { |p| ref + sc(axis, (p - ref).dot(axis).to_f) }
      segs = []
      qs.each_cons(2) do |x, y|
        d = x.distance(y).to_f
        segs << { p1: x, p2: y, len: d } if d > MM
      end
      segs
    end

    def self.compute_line(model, s)
      if s['mode'] == 'cont'
        return nil unless s['anchors'] && s['axis']
        pts = s['anchors'].map { |a| resolve_anchor(model, a) }
        return nil if pts.size < 2 || pts.any?(&:nil?)
        axis = Geom::Vector3d.new(s['axis'][0], s['axis'][1], s['axis'][2])
        pts  = adjust_by_surfaces(model, s, pts, axis)
        ref  = pts.first
        segs = cont_segments(pts, axis, ref)
        return nil if segs.empty?
      else
        return nil unless s['a0'] && s['a1']
        a0 = resolve_anchor(model, s['a0'])
        a1 = resolve_anchor(model, s['a1'])
        return nil unless a0 && a1
        v = a1 - a0
        return nil if v.length.to_f < MM
        axis = s['axis'] ? Geom::Vector3d.new(s['axis'][0], s['axis'][1], s['axis'][2]) : v.normalize
        pls = nil
        if s['sect'] == 'dyn'
          pls = section_planes(model)
        elsif s['sect'] == 'static' && s['plane']
          pls = [s['plane']]
        end
        if pls && !pls.empty?
          q0 = section_project(model, a0, axis, pls)
          q1 = section_project(model, a1, axis, pls)
          if q0 && q1
            a0 = q0
            a1 = q1
            v = a1 - a0
          end
        end
        d = v.dot(axis).to_f
        if d < 0
          axis = sc(axis, -1)
          d = -d
        end
        return nil if d < MM
        lo = 0.0
        hi = d
        hits = cut_hits(model, a0 + sc(axis, lo), a0 + sc(axis, hi), cam_from_a(s['cam']), s['cmode'] || 'base')
        return nil if hits.size < 2
        pts  = hits.map { |h| a0 + sc(axis, lo + h) }
        ref  = a0
        segs = line_segments(pts, axis, a0)
      end
      perp = s['perp'] ? Geom::Vector3d.new(s['perp'][0], s['perp'][1], s['perp'][2]) : axis.axes[0]
      od   = s['od'] ? Geom::Vector3d.new(s['od'][0], s['od'][1], s['od'][2]) : nil
      dm   = Geom::Vector3d.new(s['dm'][0], s['dm'][1], s['dm'][2])
      legs = nil
      if od
        gap, length, fixed_leg = leg_spec(s)
        if s['mode'] == 'cont'
          off, legs = point_off_legs(axis, od, gap, length)
        else
          ss = pts.map { |q| (q - ref).dot(axis).to_f }
          off, legs = off_legs(model, ref, axis, ss.min, ss.max, od, gap, nil, length)
        end
      else
        off = line_offset(dm, axis, perp, od)
      end
      r = lambda { |x| (x.to_f / (0.01 * MM)).round }
      parts = [settings_fp, r.call(ref.x), r.call(ref.y), r.call(ref.z),
               r.call(off.x), r.call(off.y), r.call(off.z),
               (axis.x.to_f * 1000).round, (axis.y.to_f * 1000).round, (axis.z.to_f * 1000).round,
               s['skip_mm'].to_f]
      parts += [r.call(legs.x), r.call(legs.y), r.call(legs.z)] if legs
      parts << (fixed_leg ? 1 : 0)
      segs.each do |sg|
        parts << r.call(sg[:len])
        parts.concat(point_fp(sg[:p1]))
        parts.concat(point_fp(sg[:p2]))
      end
      parts << s['row_shift_mm'].to_f if s['row_shift_mm'].to_f > 0
      line = { pts: pts, axis: axis, ref: ref, off: off, legs: legs, fixed_leg: fixed_leg, segs: segs, sig: Zlib.crc32(parts.join(',')).to_s }
      shift_line_row(line, s['row_shift_mm'])
    end

    def self.draw_line_set(ents, tag, s, line, start_index = 0)
      legs = line[:legs]
      base = legs ? line[:off] - legs : line[:off]
      offs = seg_offset_list(line[:segs], base) { |i, sg| seg_excluded?(s, i, sg) }
      cnt = 0
      line[:segs].each_with_index do |sg, i|
        next if i < start_index
        o = offs[i]
        next unless o
        # Keep the configured witness length even on staggered short segments.
        # Move the witness starts with the row, retaining the same measured span.
        shift = legs || Geom::Vector3d.new(0, 0, 0)
        if line[:fixed_leg]
          shift = shift + (o - base)
          o = base
        end
        p1 = sg[:p1] + shift
        p2 = sg[:p2] + shift
        cnt += dim(ents, tag, p1, p2, o)
      end
      cnt
    end

    def self.append_cont_dims(model, existing, set, tag, line)
      return nil unless set['anchor_mode'] == 'native' && existing['draw_fp'] == settings_fp
      old_anchors = existing['anchors'] || []
      return nil unless set['anchors'].size == old_anchors.size + 1
      return nil unless set['anchors'][0, old_anchors.size] == old_anchors
      keys = (existing.keys + set.keys).uniq - %w[anchors sig ndim draw_fp]
      return nil unless keys.all? { |key| existing[key] == set[key] }
      items = dim_items(model.entities, set['id'])
      return nil unless items.size == 1 && items.first.is_a?(Sketchup::Group)
      group = items.first
      return nil unless group.transformation.to_a == IDENTITY_TR.to_a
      return nil if group.definition.respond_to?(:instances) && group.definition.instances.size != 1
      previous = compute_line(model, existing)
      return nil unless previous && previous[:sig] == existing['sig']
      index = previous[:segs].size
      return nil unless line[:segs].size == index + 1
      @cur_set = set['id']
      added = draw_line_set(group.entities, tag, set, line, index)
      expected = seg_excluded?(set, index, line[:segs][index]) ? 0 : 1
      raise 'Không thêm được đoạn DIM mới' unless added == expected
      existing['ndim'].to_i + added
    ensure
      @cur_set = nil
    end

    # hướng kéo dim mặc định: trục toạ độ vuông góc, ưu tiên bên trái (dim đứng) / bên dưới (dim ngang)
    def self.auto_offset_dir(axis, view)
      cam = view.camera
      right = cam.xaxis
      up = cam.yaxis
      vertical = axis.dot(up).to_f.abs >= axis.dot(right).to_f.abs
      pref = vertical ? sc(right, -1) : sc(up, -1)
      best = nil
      bs = -2.0
      [X_AXIS, Y_AXIS, Z_AXIS].each do |c|
        o = c - sc(axis, c.dot(axis).to_f)
        next if o.length.to_f < 0.5
        o = o.normalize
        k = o.dot(pref).to_f
        if k.abs > bs
          bs = k.abs
          best = k < 0 ? sc(o, -1) : o
        end
      end
      best || axis.axes[0].normalize
    end

    # Tạo bộ dim ngay (không hỏi) từ dữ liệu của tool
    def self.create_line_set(model, set)
      leave_hp_groups(model)
      @updating = true
      model.start_operation('HP Dim', true)
      set['pgid'] = current_pgid(model)
      tag = new_scene_tag(model, set)
      set['id']  = new_set_id
      set['tag'] = tag.name
      remember_tag(tag, set)
      set['pgid'] = current_pgid(model)
      annotate_surfaces(model, set)
      ln = compute_line(model, set)
      unless ln
        model.abort_operation
        UI.messagebox('Không tạo được kích thước: đường cắt không đi qua đủ bề mặt.')
        return false
      end
      @cur_set = set['id']
      begin_group(model.entities, set['id'], tag, group_name(set['mode']), set['pgid'])
      n = draw_line_set(model.entities, tag, set, ln)
      end_group
      @cur_set = nil
      if n == 0 && set['mode'] != 'cont'
        model.abort_operation
        UI.messagebox('Không có kích thước nào để tạo (mọi đoạn đều nhỏ hơn hoặc bằng độ dày đã cài).')
        return false
      end
      set['sig'] = ln[:sig]
      set['ndim'] = n
      set['draw_fp'] = settings_fp
      sets = load_sets(model)
      sets << set
      save_sets(model, sets)
      model.commit_operation
      Sketchup.status_text = "HP Auto Dim: #{n} kích thước, Tag #{tag.name}"
      true
    rescue => err
      @cur_set = nil
      model.abort_operation
      UI.messagebox("Lỗi tạo dim: #{err.message}\n#{err.backtrace.first}")
      false
    ensure
      @updating = false
    end

    # vẽ lại ngay bộ dim liên tiếp đã tạo (khi thêm điểm mới)
    def self.update_cont_set(model, set)
      existing = load_sets(model).find { |saved| saved['id'] == set['id'] }
      return false unless existing && dim_set_state(model, existing) == :ok
      leave_hp_groups(model)
      @updating = true
      model.start_operation('HP Dim liên tiếp', true)
      annotate_surfaces(model, set)
      ln = compute_line(model, set)
      unless ln
        model.abort_operation
        return false
      end
      tag = tag_for(model, set)
      nd = append_cont_dims(model, existing, set, tag, ln)
      nd = replace_dims(model.entities, set, tag) { draw_line_set(model.entities, tag, set, ln) } if nd.nil?
      set['sig'] = ln[:sig]
      set['ndim'] = nd
      set['draw_fp'] = settings_fp
      sets = load_sets(model)
      idx = sets.index { |x| x['id'] == set['id'] }
      if idx
        sets[idx] = set
      else
        sets << set
      end
      save_sets(model, sets)
      model.commit_operation
      true
    rescue => err
      @cur_set = nil
      model.abort_operation
      UI.messagebox("Lỗi cập nhật dim: #{err.message}\n#{err.backtrace.first}")
      false
    ensure
      @updating = false
    end

    def self.draw_segments_preview(view, line, skip_mm)
      legs = line[:legs]
      base = legs ? line[:off] - legs : line[:off]
      offs = seg_offset_list(line[:segs], base, line[:short_run] || 0) { |_i, sg| skip_mm > 0 && (sg[:len] / MM) <= skip_mm + 0.01 }
      view.line_width = 2
      view.drawing_color = INFO_BLUE
      view.line_stipple = ''
      line[:segs].each_with_index do |sg, i|
        off = offs[i]
        next unless off
        shift = legs || Geom::Vector3d.new(0, 0, 0)
        if line[:fixed_leg]
          shift = shift + (off - base)
          off = base
        end
        q1 = sg[:p1] + shift
        q2 = sg[:p2] + shift
        a = q1 + off
        b = q2 + off
        view.draw_lines([q1, a, q2, b, a, b])
        sp = view.screen_coords(mid(a, b))
        begin
          view.draw_text(Geom::Point3d.new(sp.x + 4, sp.y - 18, 0), fmt(sg[:len]),
                         size: 12, bold: true, color: INFO_TEXT)
        rescue StandardError
          view.draw_text(Geom::Point3d.new(sp.x + 4, sp.y - 18, 0), fmt(sg[:len]))
        end
      end
      view.line_stipple = ''
    end

    # ---------------- Tool: Dim liên tiếp (:chain = các ô chia, bỏ độ dày) / Dim cắt (:cut = mọi khoảng cách) ----------------
    class HPDimTool
      include PointTool
      AXIS_COLORS = { x: Sketchup::Color.new(220, 40, 40), y: Sketchup::Color.new(40, 170, 40),
                      z: Sketchup::Color.new(40, 80, 220) }.freeze
      MM_T = 1.mm.to_f

      def initialize(mode)
        @mode = mode
        reset
      end

      def reset
        @phase = :first
        @ip = Sketchup::InputPoint.new
        @reference_ip = nil
        @p0 = nil
        @a0 = nil
        @p1 = nil
        @a1 = nil
        @axis_lock = nil
        @cur_axis = nil
        @od = nil
        @off_lock = nil
        @boxes = nil
        @spacing_rows = nil
        @row_shift_mm = 0.0
        @gap_mm = nil
        @line = nil
        @m = nil
        @last_t = 0.0
        @last_key = nil
      end

      # gõ cao độ Z (theo đơn vị model) vào ô VCB để cắt đúng tại độ cao đó; gõ '-' để bỏ
      def onUserText(text, view)
        t = text.to_s.strip
        if @phase == :place
          set_leg_input(t)
          update_leg_layout(view)
          status
          view.invalidate
          return
        end
        @cut_z = (t == '-' || t.empty?) ? nil : t.to_l.to_f
        @last_key = nil
        status
        refresh_preview(view, true) if @p0 && @p1
        view.invalidate
      rescue StandardError
        UI.beep
      end

      def guard
        yield
      rescue => err
        puts "HP tool lỗi: #{err.message}\n#{err.backtrace.first(3).join("\n")}"
        UI.messagebox("Lỗi HP Auto Dim: #{err.message}\n#{err.backtrace.first}")
        reset
      end

      def activate
        @cut_z = nil
        @leg_len = nil
        @leg_policy = 'settings'
        begin_interaction
        reset
        status
        Sketchup.active_model.active_view.invalidate
      end

      def resume(view)
        status
        view.invalidate
      end

      def onCancel(_reason, view)
        reset
        status
        view.invalidate
      end

      def skip_mm
        HP::AutoDim.cut_skip? ? HP::AutoDim.thick_mm : 0.0
      end

      def status
        what = "DIM CẮT [#{HP::AutoDim.cut_mode_name}] (Tab: đổi chế độ; gõ số + Enter ở ô VCB: cắt tại cao độ Z)"
        case @phase
        when :first
          Sketchup.status_text = "#{what}: click điểm đầu"
        when :second
          Sketchup.status_text = "#{what}: rê chuột trái/phải/trên/dưới rồi click điểm cuối. Phím ←Y →X ↑Z khóa trục, ↓ tự động"
        else
          Sketchup.status_text = "#{what}: kéo dim ra vị trí mong muốn rồi click. Phím ←Y →X ↑Z khóa hướng kéo, ↓ tự động"
        end
        if @phase == :place
          Sketchup.vcb_label = 'Dài chân dim (mm)'
          Sketchup.vcb_value = @leg_len ? @leg_len.round(1).to_s : 'mặc định (gõ số + Enter)'
        else
          Sketchup.vcb_label = 'Cao độ cắt Z'
          Sketchup.vcb_value = if @cut_z
                                 HP::AutoDim.fmt(@cut_z)
                               elsif HP::AutoDim.section_planes(Sketchup.active_model).empty?
                                 'theo điểm click'
                               else
                                 'theo mặt cắt SketchUp'
                               end
        end
      end

      def axis_name
        ax = @axis_lock || @cur_axis
        return 'tự động' unless ax
        pre = @axis_lock ? '' : 'auto '
        return "#{pre}X (đỏ)" if ax.parallel?(X_AXIS)
        return "#{pre}Y (xanh lá)" if ax.parallel?(Y_AXIS)
        "#{pre}Z (xanh dương)"
      end

      def toggle_axis(ax)
        if @phase == :place
          @off_lock = (@off_lock && @off_lock.parallel?(ax)) ? nil : ax
        else
          @axis_lock = (@axis_lock && @axis_lock.parallel?(ax)) ? nil : ax
        end
      end

      # mã phím mũi tên: Windows 37-40, macOS 123-126
      def onKeyDown(key, _repeat, _flags, view)
        case key
        when 9 then HP::AutoDim.toggle_cut_mode
        when 39, 124 then toggle_axis(X_AXIS)
        when 37, 123 then toggle_axis(Y_AXIS)
        when 38, 126 then toggle_axis(Z_AXIS)
        when 40, 125
          if @phase == :place
            @off_lock = nil
          else
            @axis_lock = nil
          end
        else return
        end
        @last_key = nil
        status
        view.invalidate
      end

      # chọn trục theo hướng rê chuột trên màn hình
      def auto_axis_by_screen(view, x, y)
        s0 = view.screen_coords(@p0)
        mvx = x - s0.x
        mvy = y - s0.y
        mlen = Math.sqrt(mvx * mvx + mvy * mvy)
        return @cur_axis if mlen < 4
        best = nil
        bc = -1.0
        len = view.pixels_to_model(100, @p0).to_f
        [X_AXIS, Y_AXIS, Z_AXIS].each do |a|
          sa = view.screen_coords(@p0 + HP::AutoDim.sc(a, len))
          vx = sa.x - s0.x
          vy = sa.y - s0.y
          vl = Math.sqrt(vx * vx + vy * vy)
          next if vl < 3
          c = ((vx * mvx + vy * mvy) / (vl * mlen)).abs
          if c > bc
            bc = c
            best = a
          end
        end
        best
      end

      # phía đặt dim tạm thời (lúc chọn điểm cuối) theo phía chuột lệch khỏi đường đo
      def offset_dir_by_mouse(view, axis, x, y)
        s0  = view.screen_coords(@p0)
        len = view.pixels_to_model(100, @p0).to_f
        sa  = view.screen_coords(@p0 + HP::AutoDim.sc(axis, len))
        mv  = [x - s0.x, y - s0.y]
        av  = [sa.x - s0.x, sa.y - s0.y]
        avl = Math.sqrt(av[0] * av[0] + av[1] * av[1])
        lat = mv
        if avl > 3
          u = [av[0] / avl, av[1] / avl]
          dt = mv[0] * u[0] + mv[1] * u[1]
          lat = [mv[0] - dt * u[0], mv[1] - dt * u[1]]
        end
        latl = Math.sqrt(lat[0] * lat[0] + lat[1] * lat[1])
        return(@od || HP::AutoDim.auto_offset_dir(axis, view)) if latl < 8
        best = nil
        bs = 0.0
        [X_AXIS, Y_AXIS, Z_AXIS].each do |c|
          o = c - HP::AutoDim.sc(axis, c.dot(axis).to_f)
          next if o.length.to_f < 0.5
          o = o.normalize
          sp = view.screen_coords(@p0 + HP::AutoDim.sc(o, len))
          cv = [sp.x - s0.x, sp.y - s0.y]
          cl = Math.sqrt(cv[0] * cv[0] + cv[1] * cv[1])
          next if cl < 3
          k = (cv[0] * lat[0] + cv[1] * lat[1]) / (cl * latl)
          if k.abs > bs
            bs = k.abs
            best = k < 0 ? HP::AutoDim.sc(o, -1) : o
          end
        end
        best || @od || HP::AutoDim.auto_offset_dir(axis, view)
      end

      def update_end(view, x, y)
        unless @ip.valid?
          @p1 = @line = nil
          return
        end
        axis = @axis_lock || snapped_axis(@p0) || auto_axis_by_screen(view, x, y)
        return unless axis
        @cur_axis = axis
        @od = offset_dir_by_mouse(view, axis, x, y)
        pos = @ip.position
        if @ip.degrees_of_freedom == 3
          cp = Geom.closest_points([@p0, axis], view.pickray(x, y))
          pos = cp[0] if cp
        end
        d = (pos - @p0).dot(axis).to_f
        @p1 = @p0 + HP::AutoDim.sc(axis, d)
        refresh_preview(view, false)
      end

      # khoảng đo CHỈ trong điểm đầu - điểm cuối
      def refresh_preview(view, force)
        if @p1.nil? || @p1.distance(@p0).to_f < MM_T
          @line = nil
          @last_key = nil
          return
        end
        now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        key = [@p1.x.to_f.round(3), @p1.y.to_f.round(3), @p1.z.to_f.round(3)]
        key += [@od.x.to_f.round(2), @od.y.to_f.round(2), @od.z.to_f.round(2)] if @od
        unless force
          return if key == @last_key
          return if @line && now - @last_t < 0.25
        end
        model  = view.model
        axis0  = (@p1 - @p0).normalize
        planes = @cut_z ? [[0.0, 0.0, 1.0, -@cut_z]] : HP::AutoDim.section_planes(model)
        a0p = @p0
        a1p = @p1
        @sect = nil
        unless planes.empty?
          q0 = HP::AutoDim.section_project(model, @p0, axis0, planes)
          q1 = HP::AutoDim.section_project(model, @p1, axis0, planes)
          if q0 && q1 && q0.distance(q1).to_f > MM_T
            a0p = q0
            a1p = q1
            @sect = @cut_z ? 'static' : 'dyn'
          end
        end
        axis = (a1p - a0p).normalize
        hits = HP::AutoDim.cut_hits(model, a0p, a1p, HP::AutoDim.vis_only? ? HP::AutoDim.cam_from_view(view) : nil, HP::AutoDim.cut_mode)
        if hits.size >= 2
          pts = hits.map { |h| a0p + HP::AutoDim.sc(axis, h) }
          od  = @od || HP::AutoDim.auto_offset_dir(axis, view)
          gap, length, fixed = leg_spec
          off, legs = HP::AutoDim.off_legs(model, a0p, axis, 0.0, a1p.distance(a0p).to_f, od, gap, @boxes, length)
          @line = { pts: pts, axis: axis, ref: a0p, a1p: a1p, off: off, legs: legs, od: od, fixed_leg: fixed,
                    segs: HP::AutoDim.line_segments(pts, axis, a0p) }
        else
          @line = nil
        end
        @last_t = now
        @last_key = key
      end

      # lúc đặt dim: vị trí chuột quyết định phía và khoảng cách
      def update_place(view, x, y)
        return unless @line
        ref = @line[:ref]
        m = Geom.intersect_line_plane(view.pickray(x, y), [ref, view.camera.direction])
        return unless m
        @m = m
        dm   = m - ref
        axis = @line[:axis]
        od   = HP::AutoDim.pick_offset_dir(dm, axis, @off_lock) || @line[:od]
        od   = HP::AutoDim.signed_dir(dm, od)
        hi   = @line[:a1p].distance(ref).to_f
        o2, ext = HP::AutoDim.gap_parts(view.model, ref, axis, 0.0, hi, od, @boxes)
        if @leg_policy == 'free'
          @gap_mm = [dm.dot(o2).to_f - ext, 5.0 * MM_T - ext].max / MM_T
        else
          @gap_mm = leg_spec[0]
        end
        @line = @line.merge(od: od)
        update_leg_layout(view)
      end

      def update_leg_layout(view)
        return unless @line
        gap, length, fixed = leg_spec
        @gap_mm = gap
        off, legs = HP::AutoDim.off_legs(view.model, @line[:ref], @line[:axis], 0.0,
                    @line[:a1p].distance(@line[:ref]).to_f, @line[:od], gap, @boxes, length)
        off, legs = space_placement(view, @line[:ref], @line[:axis],
                    @line[:a1p].distance(@line[:ref]).to_f, off, legs)
        @line = @line.merge(off: off, legs: legs, fixed_leg: fixed)
      end

      def onMouseMove(_flags, x, y, view)
        case @phase
        when :first
          pick_input(view, x, y)
        when :second
          pick_input(view, x, y, true)
          update_end(view, x, y)
        else
          update_place(view, x, y)
        end
        view.invalidate
      end

      def onLButtonDown(_flags, x, y, view)
        guard do
          case @phase
          when :first
            pick_input(view, x, y)
            next unless @ip.valid?
            remember_reference
            @p0 = @ip.position
            @a0 = HP::AutoDim.make_anchor(view.model, @ip, @p0)
            @boxes = HP::AutoDim.root_boxes(view.model)
            @phase = :second
            status
          when :second
            pick_input(view, x, y, true)
            update_end(view, x, y)
            refresh_preview(view, true)
            if @p1 && @line
              @a1 = HP::AutoDim.make_anchor(view.model, @ip, @p1)
              @phase = :place
              @m = @p0 + @line[:off]
              status
            else
              UI.messagebox("Đường cắt chưa đi qua đủ bề mặt. Hãy chọn điểm cuối khác.")
            end
          else
            update_place(view, x, y)
            finalize(view)
          end
          view.invalidate
        end
      end

      def finalize(view)
        return unless @line
        update_leg_layout(view)
        model = view.model
        ax  = @line[:axis]
        od  = @line[:od]
        d   = @p1.distance(@p0).to_f
        perp = HP::AutoDim.view_perp(ax, view)
        ext = false
        set = { 'mode' => (@mode == :cut ? 'cut' : 'chain'),
                'a0' => @a0, 'a1' => @a1,
                'axis' => [ax.x.to_f, ax.y.to_f, ax.z.to_f],
                'od' => [od.x.to_f, od.y.to_f, od.z.to_f],
                'dm' => [@line[:off].x.to_f, @line[:off].y.to_f, @line[:off].z.to_f],
                'perp' => [perp.x.to_f, perp.y.to_f, perp.z.to_f],
                'skip_mm' => skip_mm,
                'gap' => (@gap_mm || (@leg_len ? HP::AutoDim.leg_mm + @leg_len : HP::AutoDim.offset_mm)),
                'cam' => HP::AutoDim.cam_to_a(HP::AutoDim.cam_from_view(view)),
                'cmode' => HP::AutoDim.cut_mode,
                'sect' => @sect,
                'plane' => (@sect == 'static' ? [0.0, 0.0, 1.0, -@cut_z] : nil),
                'ext' => ext }.merge(leg_fields)
        reset
        status
        HP::AutoDim.create_line_set(model, set)
      end

      def draw(view)
        view.line_stipple = ''
        view.line_width = 2
        view.draw_points([@p0], 9, 2, Sketchup::Color.new(220, 40, 40)) if @p0
        if @phase == :first
          @ip.draw(view) if @ip.valid?
        else
          ax = @axis_lock || @cur_axis
          if ax && @phase == :second
            c = AXIS_COLORS[ax.parallel?(X_AXIS) ? :x : (ax.parallel?(Y_AXIS) ? :y : :z)]
            view.drawing_color = c
            view.line_stipple = '-'
            len = view.pixels_to_model(2000, @p0).to_f
            view.draw_lines([@p0 - HP::AutoDim.sc(ax, len), @p0 + HP::AutoDim.sc(ax, len)])
            view.line_stipple = ''
          end
          if @p1
            view.drawing_color = Sketchup::Color.new(220, 40, 40)
            view.draw_lines([@p0, @p1])
            view.draw_points([@p1], 9, 2, Sketchup::Color.new(220, 40, 40))
          end
          HP::AutoDim.draw_segments_preview(view, @line, skip_mm) if @line
          @ip.draw(view) if @phase == :second && @ip.valid?
        end
      rescue => err
        puts "HP draw lỗi: #{err.message}"
      end

      def getExtents
        bb = Geom::BoundingBox.new
        bb.add(@p0) if @p0
        bb.add(@p1) if @p1
        bb
      end
    end

    # ---------------- Tool: DIM LIÊN TIẾP (viết lại) ----------------
    # B1: click điểm 1.  B2: rê chuột (trục tự nhận theo hướng rê, hoặc khóa bằng ← → ↑) rồi click điểm 2.
    # B3: kéo ra vị trí mong muốn rồi click -> tạo dim đầu tiên.
    # B4: click điểm 3, 4, ... -> mỗi điểm tạo thêm 1 dim nối tiếp từ điểm liền trước, thẳng hàng dim đầu.
    # Esc / Enter: kết thúc chuỗi. Mọi dim tự cập nhật khi đối tượng thay đổi.
    class HPChainTool
      include PointTool
      AXIS_COLORS = { x: Sketchup::Color.new(220, 40, 40), y: Sketchup::Color.new(40, 170, 40),
                      z: Sketchup::Color.new(40, 80, 220) }.freeze
      RED = Sketchup::Color.new(220, 40, 40)
      MMT = 1.mm.to_f

      def initialize
        reset
      end

      def reset
        @phase = :p1
        @ip = Sketchup::InputPoint.new
        @reference_ip = nil
        @pts = []
        @axis_lock = nil
        @axis = nil
        @cand_axis = nil
        @p1c = nil
        @od = nil
        @off_lock = nil
        @off = nil
        @legs = nil
        @pre_off = nil
        @pre_legs = nil
        @gap_mm = nil
        @cand = nil
        @set = nil
        @boxes = nil
        @spacing_rows = nil
        @row_shift_mm = 0.0
        @short_run = 0
      end

      def skip_mm
        HP::AutoDim.cut_skip? ? HP::AutoDim.thick_mm : 0.0
      end

      def guard
        yield
      rescue => err
        puts "HP dim liên tiếp lỗi: #{err.message}\n#{err.backtrace.first(3).join("\n")}"
        UI.messagebox("Lỗi HP Auto Dim (Dim liên tiếp): #{err.message}\n#{err.backtrace.first}")
        reset
      end

      def activate
        @leg_len = nil
        @leg_policy = 'settings'
        begin_interaction
        reset
        status
        Sketchup.active_model.active_view.invalidate
      end

      def resume(view)
        status
        view.invalidate
      end

      def finish(view)
        reset
        status
        view.invalidate
      end

      def onCancel(_reason, view)
        finish(view)
      end

      def onReturn(view)
        finish(view)
      end

      def status
        txt = case @phase
              when :p1    then 'DIM LIÊN TIẾP: click điểm 1'
              when :p2    then 'DIM LIÊN TIẾP: rê chuột trái/phải/trên/dưới rồi click điểm 2. Phím ←Y →X ↑Z khóa trục, ↓ tự động'
              when :place then 'DIM LIÊN TIẾP: chọn phía rồi click; chân DIM theo cài đặt. Gõ chiều dài (mm) + Enter; gõ - để kéo tự do. ←Y →X ↑Z khóa hướng, ↓ tự động'
              else 'DIM LIÊN TIẾP: click điểm 3, 4... mỗi điểm nối tiếp từ điểm trước. Esc hoặc Enter để kết thúc'
              end
        Sketchup.status_text = txt
        if @phase == :place || @phase == :next
          Sketchup.vcb_label = 'Dài chân dim (mm)'
          Sketchup.vcb_value = @leg_policy == 'free' ? 'kéo chuột (-)' : (@leg_len || HP::AutoDim.leg_len_mm).round(1).to_s
        else
          Sketchup.vcb_label = 'Trục'
          Sketchup.vcb_value = axis_name
        end
      end

      # gõ chiều dài chân dim (mm) vào ô VCB rồi Enter; gõ '-' để về lại kéo chuột
      def onUserText(text, view)
        t = text.to_s.strip
        before = [@leg_policy, @leg_len, @gap_mm, @off, @legs]
        set_leg_input(t)
        update_leg_layout if @axis && @od
        if @phase == :next && @set
          saved = @set.dup
          @set.merge!(leg_fields).merge!('gap' => @gap_mm)
          unless HP::AutoDim.update_cont_set(view.model, @set)
            @set.replace(saved)
            @leg_policy, @leg_len, @gap_mm, @off, @legs = before
          end
        end
        status
        view.invalidate
      rescue StandardError
        UI.beep
      end

      def axis_text(ax)
        return 'X (đỏ)' if ax.parallel?(X_AXIS)
        return 'Y (xanh lá)' if ax.parallel?(Y_AXIS)
        return 'Z (xanh dương)' if ax.parallel?(Z_AXIS)
        'theo điểm bắt'
      end

      def axis_name
        if @phase == :p1 || @phase == :p2
          return "khóa #{axis_text(@axis_lock)}" if @axis_lock
          return "tự động #{axis_text(@cand_axis)}" if @cand_axis
          return 'tự động'
        end
        @axis ? axis_text(@axis) : 'tự động'
      end

      def onKeyDown(key, _repeat, _flags, view)
        sym = case key
              when 39, 124 then :x
              when 37, 123 then :y
              when 38, 126 then :z
              when 40, 125 then :free
              end
        return unless sym
        ax = { x: X_AXIS, y: Y_AXIS, z: Z_AXIS }[sym]
        case @phase
        when :p1, :p2
          if sym == :free
            @axis_lock = nil
          else
            @axis_lock = (@axis_lock && @axis_lock.parallel?(ax)) ? nil : ax
          end
        when :place
          if sym == :free
            @off_lock = nil
          else
            @off_lock = (@off_lock && @off_lock.parallel?(ax)) ? nil : ax
          end
        else
          return
        end
        status
        view.invalidate
      end

      # trục theo hướng rê chuột trên màn hình
      def auto_axis_by_screen(view, x, y, p0)
        s0 = view.screen_coords(p0)
        mvx = x - s0.x
        mvy = y - s0.y
        mlen = Math.sqrt(mvx * mvx + mvy * mvy)
        return @cand_axis if mlen < 4
        best = nil
        bc = -1.0
        len = view.pixels_to_model(100, p0).to_f
        [X_AXIS, Y_AXIS, Z_AXIS].each do |a|
          sa = view.screen_coords(p0 + HP::AutoDim.sc(a, len))
          vx = sa.x - s0.x
          vy = sa.y - s0.y
          vl = Math.sqrt(vx * vx + vy * vy)
          next if vl < 3
          c = ((vx * mvx + vy * mvy) / (vl * mlen)).abs
          if c > bc
            bc = c
            best = a
          end
        end
        best
      end

      # phía đặt dim theo phía chuột lệch khỏi đường đo
      def offset_dir_by_mouse(view, axis, x, y, p0)
        s0  = view.screen_coords(p0)
        len = view.pixels_to_model(100, p0).to_f
        sa  = view.screen_coords(p0 + HP::AutoDim.sc(axis, len))
        mv  = [x - s0.x, y - s0.y]
        av  = [sa.x - s0.x, sa.y - s0.y]
        avl = Math.sqrt(av[0] * av[0] + av[1] * av[1])
        lat = mv
        if avl > 3
          u = [av[0] / avl, av[1] / avl]
          dt = mv[0] * u[0] + mv[1] * u[1]
          lat = [mv[0] - dt * u[0], mv[1] - dt * u[1]]
        end
        latl = Math.sqrt(lat[0] * lat[0] + lat[1] * lat[1])
        if latl < 8
          return @od if @od
          return HP::AutoDim.auto_offset_dir(axis, view)
        end
        best = nil
        bs = 0.0
        [X_AXIS, Y_AXIS, Z_AXIS].each do |c|
          o = c - HP::AutoDim.sc(axis, c.dot(axis).to_f)
          next if o.length.to_f < 0.5
          o = o.normalize
          sp = view.screen_coords(p0 + HP::AutoDim.sc(o, len))
          cv = [sp.x - s0.x, sp.y - s0.y]
          cl = Math.sqrt(cv[0] * cv[0] + cv[1] * cv[1])
          next if cl < 3
          k = (cv[0] * lat[0] + cv[1] * lat[1]) / (cl * latl)
          if k.abs > bs
            bs = k.abs
            best = k < 0 ? HP::AutoDim.sc(o, -1) : o
          end
        end
        best || @od || HP::AutoDim.auto_offset_dir(axis, view)
      end

      def update_p2(view, x, y)
        p0 = @pts[0][:pos]
        unless @ip.valid?
          @p1c = @pre_off = nil
          return
        end
        axis = @axis_lock || snapped_axis(p0) || auto_axis_by_screen(view, x, y, p0)
        return unless axis
        @cand_axis = axis
        @od = offset_dir_by_mouse(view, axis, x, y, p0)
        pos = @ip.position
        if @ip.degrees_of_freedom == 3
          cp = Geom.closest_points([p0, axis], view.pickray(x, y))
          pos = cp[0] if cp
        end
        d = (pos - p0).dot(axis).to_f
        @p1c = p0 + HP::AutoDim.sc(axis, d)
        if @p1c.distance(p0).to_f > MMT && @od
          gap, length, @fixed_leg = leg_spec
          @pre_off, @pre_legs = HP::AutoDim.point_off_legs(axis, @od, gap, length)
        else
          @pre_off = nil
        end
      end

      # kéo dim: chuột quyết định phía và khoảng cách (hít về khoảng cách cài đặt khi gần)
      def update_place(view, x, y)
        p0 = @pts[0][:pos]
        m = Geom.intersect_line_plane(view.pickray(x, y), [p0, view.camera.direction])
        return unless m
        dm = m - p0
        od = HP::AutoDim.pick_offset_dir(dm, @axis, @off_lock) || @od
        return unless od
        od = HP::AutoDim.signed_dir(dm, od)
        if @leg_policy == 'free'
          o2 = (od - HP::AutoDim.sc(@axis, od.dot(@axis).to_f)).normalize
          @gap_mm = [dm.dot(o2).to_f / MMT, 5.0].max
        end
        @od = od
        update_leg_layout
      end

      def update_leg_layout(view = Sketchup.active_model.active_view)
        @gap_mm, length, @fixed_leg = leg_spec
        @off, @legs = HP::AutoDim.point_off_legs(@axis, @od, @gap_mm, length)
        @off, @legs = space_placement(view, @pts.first[:pos], @axis,
                      @pts.first[:pos].distance(@pts[1][:pos]).to_f, @off, @legs)
      end

      def remember_rows
        segs = HP::AutoDim.cont_segments(@pts.map { |point| point[:pos] }, @axis, @pts.first[:pos])
        @short_run = segs.reverse.take_while do |segment|
          segment[:len] < HP::AutoDim.stagger_mm.mm &&
            !(skip_mm > 0 && segment[:len] / MMT <= skip_mm + 0.01)
        end.size
      end

      def onMouseMove(_flags, x, y, view)
        case @phase
        when :p1
          pick_input(view, x, y)
        when :p2
          pick_input(view, x, y, true)
          update_p2(view, x, y)
        when :place
          update_place(view, x, y)
        else
          pick_input(view, x, y, true)
          @cand = @ip.valid? ? @ip.position : nil
        end
        view.invalidate
      end

      def onLButtonDown(_flags, x, y, view)
        guard do
          model = view.model
          case @phase
          when :p1
            pick_input(view, x, y)
            next unless @ip.valid?
            pos = @ip.position
            @pts = [{ pos: pos, anchor: HP::AutoDim.make_anchor(model, @ip, pos, true) }]
            remember_reference
            @phase = :p2
          when :p2
            p0 = @pts[0][:pos]
            pick_input(view, x, y, true)
            update_p2(view, x, y)
            next unless @p1c && @p1c.distance(p0).to_f > MMT && @cand_axis
            @axis = (@p1c - p0).normalize
            @pts << { pos: @p1c, anchor: HP::AutoDim.make_anchor(model, @ip, @p1c, true) }
            d = (@p1c - p0).dot(@axis).to_f
            remember_reference
            update_leg_layout
            @phase = :place
          when :place
            update_place(view, x, y)
            od   = @od || HP::AutoDim.auto_offset_dir(@axis, view)
            perp = HP::AutoDim.view_perp(@axis, view)
            set = { 'mode' => 'cont', 'anchor_mode' => 'native',
                    'anchors' => @pts.map { |q| q[:anchor] },
                    'axis' => [@axis.x.to_f, @axis.y.to_f, @axis.z.to_f],
                    'od' => [od.x.to_f, od.y.to_f, od.z.to_f],
                    'dm' => [@off.x.to_f, @off.y.to_f, @off.z.to_f],
                    'perp' => [perp.x.to_f, perp.y.to_f, perp.z.to_f],
                    'skip_mm' => skip_mm,
                    'gap' => @gap_mm,
                    'cmode' => HP::AutoDim.cut_mode,
                    'cam' => HP::AutoDim.cam_to_a(HP::AutoDim.cam_from_view(view)) }.merge(leg_fields)
            if HP::AutoDim.create_line_set(model, set)
              @set = set
              @phase = :next
              remember_rows
            else
              reset
            end
          else
            pick_input(view, x, y, true)
            next unless @ip.valid?
            pos = @ip.position
            p0 = @pts[0][:pos]
            last_s = (@pts.last[:pos] - p0).dot(@axis).to_f
            new_s  = (pos - p0).dot(@axis).to_f
            next if (new_s - last_s).abs < MMT
            anchor = HP::AutoDim.make_anchor(model, @ip, pos, true)
            @pts << { pos: pos, anchor: anchor }
            @set['anchors'] << anchor
            unless HP::AutoDim.update_cont_set(model, @set)
              @pts.pop
              @set['anchors'].pop
            else
              remember_reference
              remember_rows
            end
          end
          status
          view.invalidate
        end
      end

      def draw(view)
        view.line_stipple = ''
        view.line_width = 2
        @pts.each { |q| view.draw_points([q[:pos]], 9, 2, RED) }
        case @phase
        when :p1
          @ip.draw(view) if @ip.valid?
        when :p2
          p0 = @pts[0][:pos]
          ax = @axis_lock || @cand_axis
          if ax
            view.drawing_color = AXIS_COLORS[ax.parallel?(X_AXIS) ? :x : (ax.parallel?(Y_AXIS) ? :y : :z)]
            view.line_stipple = '-'
            len = view.pixels_to_model(2000, p0).to_f
            view.draw_lines([p0 - HP::AutoDim.sc(ax, len), p0 + HP::AutoDim.sc(ax, len)])
            view.line_stipple = ''
          end
          if @p1c && @p1c.distance(p0).to_f > MMT
            view.drawing_color = RED
            view.draw_lines([p0, @p1c])
            view.draw_points([@p1c], 9, 2, RED)
            if @pre_off
              segs = HP::AutoDim.cont_segments([p0, @p1c], (@p1c - p0).normalize, p0)
              HP::AutoDim.draw_segments_preview(view, { segs: segs, off: @pre_off, legs: @pre_legs, fixed_leg: @fixed_leg }, skip_mm)
            end
          end
          @ip.draw(view) if @ip.valid?
        when :place
          p0 = @pts[0][:pos]
          if @off
            segs = HP::AutoDim.cont_segments(@pts.map { |q| q[:pos] }, @axis, p0)
            HP::AutoDim.draw_segments_preview(view, { segs: segs, off: @off, legs: @legs, fixed_leg: @fixed_leg }, skip_mm)
          end
        else
          p0 = @pts[0][:pos]
          if @cand && @off
            last = @pts.last[:pos]
            segs = HP::AutoDim.cont_segments([last, @cand], @axis, p0)
            HP::AutoDim.draw_segments_preview(view, { segs: segs, off: @off, legs: @legs, fixed_leg: @fixed_leg, short_run: @short_run }, skip_mm)
            q = p0 + HP::AutoDim.sc(@axis, (@cand - p0).dot(@axis).to_f)
            if @cand.distance(q).to_f > MMT
              view.drawing_color = HP::AutoDim::INFO_GRAY
              view.line_stipple = '-'
              view.line_width = 1
              view.draw_lines([@cand, q])
              view.line_stipple = ''
            end
          end
          @ip.draw(view) if @ip.valid?
        end
      rescue => err
        puts "HP draw lỗi: #{err.message}"
      end

      def getExtents
        bb = Geom::BoundingBox.new
        @pts.each { |q| bb.add(q[:pos]) }
        bb.add(@cand) if @cand
        bb.add(@p1c) if @p1c
        bb
      end
    end

    def self.start_cont_tool
      Sketchup.active_model.select_tool(HPChainTool.new)
    end

    def self.start_dim_tool(mode)
      Sketchup.active_model.select_tool(HPDimTool.new(mode))
    end

    # ================= Hiển thị kích thước (overlay + đo nhanh) =================
    INFO_BLUE = Sketchup::Color.new(30, 90, 200)
    INFO_TEXT = Sketchup::Color.new(10, 40, 120)
    INFO_GRAY = Sketchup::Color.new(120, 120, 120)

    def self.info_on?
      model = Sketchup.active_model
      model && !!runtime(model)[:info_on]
    end

    def self.ov_dim(view, p1, p2, dir, len)
      pm = mid(p1, p2)
      d  = view.pixels_to_model(28, pm).to_f
      v  = sc(dir, d)
      a  = p1 + v
      b  = p2 + v
      view.drawing_color = INFO_BLUE
      view.line_width = 2
      view.line_stipple = ''
      view.draw_lines([p1, a, p2, b, a, b])
      sp = view.screen_coords(mid(a, b))
      begin
        view.draw_text(Geom::Point3d.new(sp.x + 4, sp.y - 18, 0), fmt(len),
                       size: 13, bold: true, color: INFO_TEXT)
      rescue StandardError
        view.draw_text(Geom::Point3d.new(sp.x + 4, sp.y - 18, 0), fmt(len))
      end
    end

    def self.draw_box_dims(view, etr, o, vecs)
      n = vecs.size
      ctr = o
      vecs.each { |v| ctr = ctr + sc(v, 0.5) }
      wire = []
      vecs.each_with_index do |v, i|
        len = v.length.to_f
        next if len < MM
        u = v.normalize
        others = (0...n).to_a - [i]
        combos = others.size == 2 ? [[0, 0], [0, 1], [1, 0], [1, 1]] : [[0], [1]]
        best = nil
        combos.each do |cb|
          st = o
          others.each_with_index { |j, k| st = st + sc(vecs[j], cb[k]) }
          wire << (etr * st) << (etr * (st + v)) if n == 3
          s1 = view.screen_coords(etr * st)
          s2 = view.screen_coords(etr * (st + v))
          vertical = (s2.y - s1.y).abs > (s2.x - s1.x).abs
          score = vertical ? (s1.x + s2.x) : -(s1.y + s2.y)
          best = [score, st] if best.nil? || score < best[0]
        end
        st = best[1]
        d = (st + sc(v, 0.5)) - ctr
        d = d - sc(u, d.dot(u).to_f)
        if d.length.to_f < 1e-9
          d = sc(vecs[others[0]].normalize, -1)
        end
        ov_dim(view, etr * st, etr * (st + v), (etr * d).normalize, len)
      end
      unless wire.empty?
        view.drawing_color = INFO_GRAY
        view.line_width = 1
        view.line_stipple = '-'
        view.draw_lines(wire)
        view.line_stipple = ''
      end
    end

    # vẽ kích thước cho 1 đối tượng bất kỳ (cạnh / mặt / group / component)
    def self.draw_entity_dims(view, e, etr)
      case e
      when Sketchup::Group, Sketchup::ComponentInstance
        bx = box_of(e)
        draw_box_dims(view, etr, bx[0], bx[1]) if bx
      when Sketchup::Face
        f = frame_of(e)
        draw_box_dims(view, etr, f[0], [f[1], f[2]]) if f
      when Sketchup::Edge
        p1 = etr * e.start.position
        p2 = etr * e.end.position
        dir = (p2 - p1).cross(view.camera.direction)
        dir = X_AXIS if dir.length.to_f < 1e-9
        ov_dim(view, p1, p2, dir.normalize, e.length.to_f)
      end
    end

    def self.def_world(d, model, depth)
      return IDENTITY_TR if depth > 30
      path = model.active_path
      if path && !path.empty?
        t = IDENTITY_TR
        path.each do |inst|
          t = t * inst.transformation
          return t if inst.definition == d
        end
      end
      insts = d.instances.select(&:valid?)
      vis = insts.select { |i| visible?(i) }
      insts = vis unless vis.empty?
      inst = insts.first
      return IDENTITY_TR unless inst
      par = inst.parent
      base = par.is_a?(Sketchup::Model) ? IDENTITY_TR : def_world(par, model, depth + 1)
      base * inst.transformation
    end

    def self.world_tr(e, model)
      d = e.parent
      return IDENTITY_TR if d.is_a?(Sketchup::Model)
      return model.edit_transform unless d.respond_to?(:instances)
      def_world(d, model, 0)
    end

    # Chọn nhiều đối tượng: hộp bao chung chỉ tính lại khi vùng chọn hoặc
    # model thay đổi, không tính lại ở mỗi khung hình khi xoay/zoom.
    def self.big_selection_info(model, sel)
      edges = sel.grep(Sketchup::Edge)
      if edges.size == sel.size && edges.size <= 40
        return [:edges, edges.map { |e| [e, world_tr(e, model)] }]
      end
      bb = Geom::BoundingBox.new
      sel.each do |e|
        next unless e.respond_to?(:bounds)
        w = world_tr(e, model)
        eb = e.bounds
        next if eb.empty?
        (0..7).each { |i| bb.add(w * eb.corner(i)) }
      end
      return [:none] if bb.empty?
      [:box, bb.min, [Geom::Vector3d.new(bb.width.to_f, 0, 0),
                      Geom::Vector3d.new(0, bb.height.to_f, 0),
                      Geom::Vector3d.new(0, 0, bb.depth.to_f)]]
    end

    def self.draw_info(view)
      model = view.model
      return unless runtime(model)[:info_on]
      selection = model.selection
      n = selection.length
      return if n == 0
      if n > 100
        view.draw_text(Geom::Point3d.new(20, 30, 0), "Đã chọn #{n} đối tượng. Chọn tối đa 100 đối tượng để xem kích thước.")
        return
      end
      if n > 12
        path = model.active_path
        members = selection.to_a
        key = [model.object_id, members.map(&:persistent_id), runtime(model)[:tx],
               (path || []).map(&:persistent_id)]
        if @info_key != key
          @info_data = big_selection_info(model, members)
          @info_key = key
        end
        data = @info_data
        case data[0]
        when :edges
          data[1].each { |e, tr| draw_entity_dims(view, e, tr) if e.valid? }
        when :box
          draw_box_dims(view, IDENTITY_TR, data[1], data[2])
        end
        return
      end
      selection.each { |e| draw_entity_dims(view, e, world_tr(e, model)) }
    rescue => err
      @info_key = nil
      log_once("HP overlay error: #{err.message} #{err.backtrace.first}")
    end

    if defined?(Sketchup::Overlay)
      class HPOverlay < Sketchup::Overlay
        def initialize
          super('hp_autodim_size_overlay', 'HP - Kích thước đối tượng được chọn')
        end

        def draw(view)
          HP::AutoDim.draw_info(view)
        end
      end
    end

    def self.toggle_info
      unless defined?(Sketchup::Overlay)
        UI.messagebox('Chức năng này cần SketchUp 2023 trở lên.')
        return
      end
      m = Sketchup.active_model
      state = runtime(m)
      state[:info_on] = !state[:info_on]
      attach(m)
      begin
        if state[:info_on]
          ov = ensure_overlay(m)
          ov.enabled = true if ov
        else
          ov = (@overlays || {})[m.object_id]
          ov.enabled = false if ov
        end
      rescue StandardError => err
        log_once("HP overlay: #{err.message}")
      end
      m.active_view.invalidate
    end

    # ---------------- Tool đo nhanh: rê chuột vào cạnh / mặt / chi tiết (kể cả group lồng sâu) ----------------
    class HPInspectTool
      def activate
        @levels = []
        @level = 0
        @key = nil
        Sketchup.status_text = 'ĐO NHANH: rê chuột vào cạnh/mặt/chi tiết. ↑ lên cấp group cha, ↓ xuống cấp con. Esc thoát.'
      end

      def deactivate(view)
        view.invalidate
      end

      def onCancel(_reason, view)
        Sketchup.active_model.select_tool(nil)
      end

      def onKeyDown(key, _repeat, _flags, view)
        return if @levels.empty?
        if key == VK_UP
          @level = [@level + 1, @levels.size - 1].min
        elsif key == VK_DOWN
          @level = [@level - 1, 0].max
        end
        view.invalidate
      end

      def onMouseMove(_flags, x, y, view)
        ph = view.pick_helper
        ph.do_pick(x, y)
        @levels = []
        if ph.count > 0
          best = ph.best_picked
          idx = (0...ph.count).find { |i| ph.leaf_at(i) == best } || 0
          path = ph.path_at(idx) || []
          insts = path.select { |e| e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance) }
          leaf = path.last
          key = path.map(&:object_id)
          if key != @key
            @key = key
            @level = 0
          end
          unless leaf.nil? || insts.include?(leaf)
            @levels << { e: leaf, tr: HP::AutoDim.inst_product(insts) }
          end
          (insts.size - 1).downto(0) do |k|
            @levels << { e: insts[k], tr: HP::AutoDim.inst_product(insts[0...k]) }
          end
          @level = [@level, @levels.size - 1].min
          @level = 0 if @level < 0
        end
        view.invalidate
      end

      def draw(view)
        return if @levels.empty?
        lv = @levels[@level]
        HP::AutoDim.draw_entity_dims(view, lv[:e], lv[:tr]) if lv
      rescue => err
        HP::AutoDim.log_once("HP inspect error: #{err.message}")
      end
    end

    def self.start_inspect
      Sketchup.active_model.select_tool(HPInspectTool.new)
    end

    # ================= Chọn / chỉnh sửa dim =================
    def self.dim_group_sid(g)
      g.get_attribute(PLUGIN_ID, 'set')
    end

    def self.enter_dim_group(g)
      Sketchup.active_model.active_path = [g]
    rescue StandardError => err
      UI.messagebox("Không vào được nhóm dim: #{err.message}")
    end

    # bung nhóm dim thành dim rời và ngừng tự cập nhật bộ dim này (để chỉnh sửa tay)
    def self.release_dim_group(g)
      model = Sketchup.active_model
      sid = dim_group_sid(g)
      leave_hp_groups(model)
      @updating = true
      model.start_operation('HP Bung nhóm dim', true)
      save_sets(model, load_sets(model).reject { |x| x['id'] == sid })
      res = g.explode
      (res || []).each { |e| e.delete_attribute(PLUGIN_ID, 'set') if e.respond_to?(:delete_attribute) }
      model.commit_operation
    rescue => err
      model.abort_operation
      UI.messagebox("Lỗi: #{err.message}")
    ensure
      @updating = false
    end

    def self.delete_dim_group(g)
      model = Sketchup.active_model
      sid = dim_group_sid(g)
      leave_hp_groups(model)
      @updating = true
      model.start_operation('HP Xóa bộ dim', true)
      save_sets(model, load_sets(model).reject { |x| x['id'] == sid })
      g.erase!
      model.commit_operation
    rescue => err
      model.abort_operation
      UI.messagebox("Lỗi: #{err.message}")
    ensure
      @updating = false
    end

    # Tool: click vào dim (kể cả dim nằm trong nhóm) -> tự vào nhóm và chọn đúng dim đó
    class HPPickDimTool
      def activate
        @hover = nil
        Sketchup.status_text = 'CHỌN DIM HP: rê chuột vào dim (đường hoặc số), click để chọn đúng dim đó. Esc để thoát.'
      end

      def deactivate(view)
        view.invalidate
      end

      def onCancel(_reason, _view)
        Sketchup.active_model.select_tool(nil)
      end

      def find_dim(view, x, y)
        ph = view.pick_helper
        begin
          ph.do_pick(x, y, 14)
        rescue StandardError
          ph.do_pick(x, y)
        end
        ph.count.times do |i|
          path = ph.path_at(i) || []
          return path if path.last.is_a?(Sketchup::Dimension)
        end
        nil
      end

      def onMouseMove(_flags, x, y, view)
        path = find_dim(view, x, y)
        @hover = path ? path.last : nil
        view.tooltip = @hover ? "Dim: #{@hover.text.to_s.empty? ? 'đo tự động' : @hover.text}" : ''
        view.invalidate
      end

      def onLButtonDown(_flags, x, y, view)
        path = find_dim(view, x, y)
        return unless path
        dim = path.last
        groups = path[0...-1].select { |e| e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance) }
        model = view.model
        model.active_path = groups unless groups.empty?
        model.selection.clear
        model.selection.add(dim)
        model.select_tool(nil)
      rescue => err
        puts "HP chọn dim lỗi: #{err.message}"
      end
    end

    def self.start_pickdim
      Sketchup.active_model.select_tool(HPPickDimTool.new)
    end

    # ================= Cập nhật tự động =================
    # bộ dim còn nguyên? (người dùng xóa group / xóa bớt dim thì không vẽ lại nữa)
    # Không phụ thuộc vào 'ndim': bộ dim tạo từ bản cũ không lưu số dim, trước
    # đây bị coi là "còn nguyên" nên xóa xong vẫn bị vẽ lại khi đối tượng đổi.
    def self.dim_set_state(model, s)
      mode = s['mode'] || 'std'
      ndim = s['ndim'].to_i
      # Dim liên tiếp được phép chưa có dim nào (mọi đoạn đều ≤ độ dày ván).
      return :ok if mode == 'cont' && s.key?('ndim') && ndim == 0
      ents = %w[chain cut cont].include?(mode) ? model.entities : ctx_entities(model, s['ctx'])
      return :ok unless ents
      items = dim_items(ents, s['id'])
      return :deleted if items.empty?
      g = items.find { |item| item.is_a?(Sketchup::Group) }
      return :edited if items.grep(Sketchup::Group).size > 1
      return :edited if g && g.transformation.to_a != IDENTITY_TR.to_a
      cnt = g ? g.entities.grep(Sketchup::Dimension).size : items.grep(Sketchup::Dimension).size
      return :deleted if cnt == 0
      ndim > 0 && cnt < ndim ? :edited : :ok
    rescue StandardError => err
      puts "HP dim_set_state: #{err.message}"
      :ok
    end

    def self.report_error(msg)
      @err_seen ||= {}
      return if @err_seen[msg]
      @err_seen[msg] = true
      puts "HP Auto Dim: #{msg}"
      UI.messagebox("HP Auto Dim - lỗi khi cập nhật kích thước:\n#{msg}")
    end

    # ---- dấu vân tay từng bộ dim: chỉ tính lại khi đối tượng được dim thật sự thay đổi (giảm giật/lag) ----
    def self.tracked_pids(s)
      pids = {}
      (s['sel'] || []).each { |pid| pids[pid] = true }
      arr = s['anchors'] || [s['a0'], s['a1']]
      arr.compact.each do |a|
        t = a['trk']
        pids[t['pid']] = true if t && t['pid']
        f = (a['path'] || []).first
        pids[f] = true if f
      end
      pids.keys.sort
    end

    def self.settings_fp
      @settings_fp ||= [offset_mm, leg_mm, step_mm, stagger_mm, pref('text_position', 'center'), thick_mm, cut_skip? ? 1 : 0, cut_mode,
       vis_only? ? 1 : 0, lat_mm, obj_two_d? ? 1 : 0, max_dia_mm,
       pref('hole_kw', ''), pref('leaf_kw', '')].join('|')
    end

    # mọi pid mà một bộ dim cần tra cứu (để tra một lượt cho tất cả các bộ)
    def self.set_pids(s)
      pids = tracked_pids(s)
      pids << s['ctx'] if s['ctx'].to_i != 0
      (s['anchors'] || [s['a0'], s['a1']]).compact.each do |a|
        pids.concat(a['path'] || [])
        pids << a['v'] if a['v']
        pids << a['e'] if a['e']
      end
      pids
    end

    # vị trí đỉnh/cạnh mà điểm neo bám vào (kể cả hình học rời ở ngoài cùng)
    def self.anchor_fp(model, s)
      out = []
      (s['anchors'] || [s['a0'], s['a1']]).compact.each do |a|
        if a['v']
          v = entity_by_pid(model, a['v'])
          v && v.respond_to?(:position) ? out.concat(point_fp(v.position)) : out << 'xv'
        end
        if a['e']
          e = entity_by_pid(model, a['e'])
          if e && e.respond_to?(:start)
            out.concat(point_fp(e.start.position))
            out.concat(point_fp(e.end.position))
          else
            out << 'xe'
          end
        end
      end
      out
    end

    def self.set_fp(model, s)
      parts = [settings_fp, s['leg_policy'], s['leg_len_mm'], s['gap']]
      if s['mode'] == 'obj'
        found = entities_by_pid(model, s['sel'] || [])
        parts << s['ctx']
        (s['sel'] || []).each do |pid|
          check_auto_budget!
          entity = found[pid]
          if entity && entity.valid?
            parts << pid
            parts << (entity.hidden? ? 1 : 0) << (layer_visible?(entity.layer) ? 1 : 0)
            if entity.is_a?(Sketchup::Face)
              parts.concat(entity_geometry_fp(entity, model))
            else
              bounds = entity.definition.bounds
              parts.concat(point_fp(bounds.min)) unless bounds.empty?
              parts.concat(point_fp(bounds.max)) unless bounds.empty?
              parts.concat(entity.transformation.to_a.map { |value| value.to_f.round(9) })
            end
          else
            parts << "missing-#{pid}"
          end
        end
        return Digest::SHA256.hexdigest(parts.join('|'))
      end
      if s['mode'] == 'cont' && s['anchor_mode'] == 'native'
        watch_anchor_geometry(model, s)
        s['anchors'].each do |anchor|
          check_auto_budget!
          position = resolve_anchor(model, anchor)
          parts.concat(position ? point_fp(position) : ['missing-anchor'])
        end
        return Digest::SHA256.hexdigest(parts.join('|'))
      end
      pids = tracked_pids(s)
      found = entities_by_pid(model, pids)
      pids.each do |pid|
        e = found[pid]
        if e && e.valid? && e.respond_to?(:bounds)
          parts.concat(entity_geometry_fp(e, model))
        else
          parts << "x#{pid}"
        end
      end
      if %w[chain cut cont].include?(s['mode'])
        parts.concat(anchor_fp(model, s))
        parts.concat(section_planes(model).flatten.map { |v| v.to_f.round(9) }) if s['sect'] == 'dyn'
        # Chỉ các đối tượng nằm gần đường đo; chưa biết vùng thì theo mọi thay đổi.
        # (Chưa biết vùng chỉ xảy ra trước lần tính đầu tiên của bộ dim.)
        parts << "g#{runtime(model)[:geometry_epoch]}" unless region_fp(model, s, parts)
      end
      Digest::SHA256.hexdigest(parts.join('|'))
    end

    def self.refresh_all(model, force, only_ids = nil, snapshot = nil)
      return if @updating || model.nil?
      if !force && background_busy?(model, runtime(model))
        runtime(model)[:pending] = true
        return
      end
      sets = snapshot || load_sets(model)
      return if sets.empty?
      update_started = true
      started_at = Time.now
      @updating = true
      @dim_index = runtime(model)[:job] ? runtime(model)[:job][:dim_index] : {}
      @replacement_batch = []
      @in_place_allowed = !force
      @in_place_batch = []
      raw_before = model.get_attribute(PLUGIN_ID, 'sets', '[]')
      state = runtime(model)
      cache = state[:fp_cache]
      cache.clear if force
      state[:geometry_cache].clear if force
      state[:slow_sets].clear if force
      prune_watchers(model) if force
      todo = []
      gone = []
      fails = 0
      cur_pg = current_pgid(model)
      candidates = sets.select { |set| update_eligible?(set, cur_pg) && (!only_ids || only_ids.include?(set['id'])) }
      entities_by_pid(model, candidates.flat_map { |set| set_pids(set) })
      candidates.each do |s|
        begin
          fp = nil
          check_auto_budget!
          if dim_set_state(model, s) != :ok
            gone << s
            next
          end
          mode = s['mode'] || 'std'
          fp = set_fp(model, s)
          next if !force && cache[s['id']] == fp
          drawing_changed = s['draw_fp'] != settings_fp
          if %w[chain cut cont].include?(mode)
            line = compute_line(model, s)
            if line
              remember_region(model, s, line)
              fp = set_fp(model, s)
            end
            if line.nil?
              cache[s['id']] = fp
              fails += 1
            elsif force || drawing_changed || line[:sig] != s['sig']
              todo << [s, model.entities, line, fp]
            else
              cache[s['id']] = fp
            end
          else
            ctx = ctx_entities(model, s['ctx'])
            info = s['sel_info'] || []
            sel = []
            if ctx
              (s['sel'] || []).each_with_index do |pid, i|
                e = entity_by_pid(model, pid)
                e = nil unless e && e.valid?
                if e.nil? && info[i] && info[i]['nm'].to_s != ''
                  e = find_instance_in(ctx, info[i])
                end
                sel << e if e
              end
            end
            if ctx.nil? || sel.empty?
              cache[s['id']] = fp
              fails += 1
              next
            end
            lay = (mode == 'obj') ? compute_obj(sel, obj_two_d?) : compute_layout(ctx, sel)
            if lay.nil?
              cache[s['id']] = fp
              fails += 1
              next
            end
            if sel.size == (s['sel'] || []).size
              lay[:resolved_sel] = sel
            end
            if force || drawing_changed || lay[:sig] != s['sig']
              todo << [s, ctx, lay, fp]
            else
              cache[s['id']] = fp
            end
          end
        rescue => err
          fails += 1
          if err.is_a?(AutoBudgetExceeded)
            state[:slow_sets][s['id']] = monotonic + 30.0
          else
            cache[s['id']] = fp if fp
          end
          log_once("HP Auto Dim compute: #{err.message} (#{err.backtrace.first})")
        end
      end
      if fails > 0
        Sketchup.status_text = "HP Auto Dim: #{fails} bộ dim chưa cập nhật được (không tìm thấy lại đối tượng)"
      end
      return if todo.empty? && gone.empty?
      leave_hp_groups(model)
      # Keep automatic updates chained to the user's edit; manual refresh is
      # independently undoable. Render failures are handled before old DIMs go.
      model.start_operation('HP Auto Dim cập nhật', true, false, !force)
      operation_started = true
      unless gone.empty?
        gone.each { |g| sets.delete(g) }
        Sketchup.status_text = "HP Auto Dim: #{gone.size} bộ dim đã bị xóa/sửa tay nên không tự vẽ lại nữa"
      end
      off = offset_mm.mm.to_f
      todo.each do |s, ents, lay, fp|
        begin
          updated = JSON.parse(JSON.generate(s))
          if lay[:resolved_sel]
            updated['sel'] = lay[:resolved_sel].map(&:persistent_id)
            updated['sel_info'] = lay[:resolved_sel].map { |entity| track_info(entity) }
          end
          tag = tag_for(model, updated)
          cnt = replace_dims(ents, updated, tag) do
            if %w[chain cut cont].include?(s['mode'])
              draw_line_set(ents, tag, updated, lay)
            elsif s['mode'] == 'obj'
              draw_obj_dims(ents, tag, lay, off)
            else
              layout_dims(ents, tag, lay, off)
            end
          end
          updated['sig'] = lay[:sig]
          updated['ndim'] = cnt
          updated['draw_fp'] = settings_fp
          updated['two_d'] = obj_two_d? if s['mode'] == 'obj'
          s.replace(updated)
          cache[s['id']] = fp
        rescue => err
          cache[s['id']] = fp
          state[:slow_sets][s['id']] = monotonic + 30.0 if err.is_a?(AutoBudgetExceeded)
          fails += 1
          log_once("HP Auto Dim giữ DIM cũ: #{err.message} (#{err.backtrace.first})")
        end
      end
      @cur_set = nil
      save_sets(model, sets)
      persistence_done = true
      @replacement_batch.each do |entities, old_items, _fresh|
        entities.erase_entities(old_items.select(&:valid?)) unless old_items.empty?
      end
      model.commit_operation
      operation_started = false
      cache.delete_if { |id, _| sets.none? { |s| s['id'] == id } }
      Sketchup.status_text = "HP Auto Dim: #{fails} bộ chưa cập nhật; DIM cũ được giữ nguyên." if fails > 0
    rescue => err
      @cur_set = nil
      if operation_started
        if force
          model.abort_operation
        else
          # Aborting a transparent operation would also undo the user's edit.
          # Before persistence, staged groups can simply be discarded instead.
          unless persistence_done
            restore_in_place(@in_place_batch)
            (@replacement_batch || []).each { |_entities, _old, fresh| fresh.erase! if fresh.valid? }
            if model.get_attribute(PLUGIN_ID, 'sets', '[]') != raw_before
              model.set_attribute(PLUGIN_ID, 'sets', raw_before)
            end
          end
          model.commit_operation
        end
      end
      runtime(model)[:fp_cache].clear if model
      sets.replace(JSON.parse(raw_before)) if sets && raw_before && !persistence_done
      puts "HP Auto Dim cập nhật: #{err.message} (#{err.backtrace.first})"
    ensure
      if update_started
        @updating = false
        @dim_index = nil
        @replacement_batch = nil
        @in_place_allowed = false
        @in_place_batch = nil
        record_time(model, :refresh, Time.now - started_at)
      end
    end

    # ---- kiểm tra định kỳ (nhẹ): chỉ các đối tượng đang được dim ----
    def self.poll_sets(m)
      raw = m.get_attribute(PLUGIN_ID, 'sets', '[]')
      return [] if raw == '[]'
      state = runtime(m)
      if raw != state[:poll_raw]
        state[:poll_raw] = raw
        state[:poll_sets] = (JSON.parse(raw) rescue [])
      end
      state[:poll_sets] || []
    end

    # Overlay chỉ được đăng ký khi bật "Hiển thị kích thước khi chọn": SketchUp
    # gọi overlay ở MỌI khung hình khi xoay/zoom.
    def self.ensure_overlay(model)
      return nil unless defined?(Sketchup::Overlay) && model
      @overlays ||= {}
      ov = @overlays[model.object_id]
      unless ov
        ov = HPOverlay.new
        model.overlays.add(ov)
        @overlays[model.object_id] = ov
      end
      ov
    rescue StandardError => err
      log_once("HP overlay: #{err.message}")
      nil
    end

    # ================= Xóa kích thước =================
    def self.clear_dims(all = false)
      model = Sketchup.active_model
      sets = load_sets(model)
      selected = all ? sets : sets.select { |s| same_scene?(model, s) }
      owner = model.pages.selected_page || model
      tag_pid = owner.get_attribute(PLUGIN_ID, 'dim_tag_pid', nil)
      current_tag = model.layers.find { |layer| layer.persistent_id == tag_pid } if tag_pid
      current_tag ||= model.layers[scene_tag_name(model)]
      tag_ids = selected.map { |s| find_set_tag(model, s) }.compact.map(&:persistent_id)
      tag_ids << current_tag.persistent_id if current_tag
      selected_ids = selected.each_with_object({}) { |set, out| out[set['id']] = true }
      page = current_pgid(model)
      shared_pid = model.get_attribute(PLUGIN_ID, 'global_tag_pid', nil)
      # Manually edited groups stop being tracked but remain HP-owned. Include
      # those groups when clearing; leave unrelated dimensions on the same tag.
      extra = []
      seen = {}
      visit = lambda do |entities|
        return if seen[entities.object_id]
        seen[entities.object_id] = true
        items = []
        candidates = entities.grep(Sketchup::Group) + entities.grep(Sketchup::ComponentInstance) + entities.grep(Sketchup::Dimension)
        candidates.uniq.each do |entity|
          if (entity.is_a?(Sketchup::Group) || entity.is_a?(Sketchup::Dimension)) && entity.get_attribute(PLUGIN_ID, 'set')
            sid = entity.get_attribute(PLUGIN_ID, 'set')
            scene = entity.get_attribute(PLUGIN_ID, 'scene_id', nil)
            old_tag = entity.layer && entity.layer.persistent_id != shared_pid && entity.layer.name != TAG_PREFIX
            legacy_match = scene.nil? && old_tag && tag_ids.include?(entity.layer.persistent_id)
            items << entity if all || selected_ids[sid] || scene == page || legacy_match
          elsif entity.is_a?(Sketchup::Group) || entity.is_a?(Sketchup::ComponentInstance)
            visit.call(entity.definition.entities)
          end
        end
        extra << [entities, items] unless items.empty?
      end
      visit.call(model.entities)
      return UI.messagebox('Chưa có kích thước nào của HP Auto Dim.') if selected.empty? && extra.empty?
      leave_hp_groups(model)
      @updating = true
      model.start_operation('HP Xóa kích thước', true)
      operation_started = true
      selected.each do |s|
        ents = %w[chain cut cont].include?(s['mode']) ? model.entities : ctx_entities(model, s['ctx'])
        erase_dims(ents, s['id']) if ents
      end
      extra.each do |entities, items|
        remaining = items.select(&:valid?)
        entities.erase_entities(remaining) unless remaining.empty?
      end
      save_sets(model, sets - selected)
      model.commit_operation
      operation_started = false
      runtime(model)[:fp_cache].clear
    rescue StandardError => error
      model.abort_operation if operation_started
      UI.messagebox("Lỗi xóa DIM: #{error.message}")
    ensure
      @updating = false
    end

    # ================= Cài đặt / Menu / Toolbar =================
    def self.settings
      modes = ['Đúng mặt cắt', 'Từ đáy đối tượng (có dung sai ngang)']
      text_modes = {'Giữa' => 'center', 'Ngoài đầu' => 'start', 'Ngoài cuối' => 'end'}
      r = UI.inputbox(
        ['Chân dim cách đối tượng (mm)', 'Khoảng hở giữa đối tượng và đầu chân dim (mm)',
         'CHIỀU DÀI chân dim (mm, 0 = theo ô "Chân dim cách đối tượng")',
         'Các dim sau cách dim trước (mm)', 'Dim ngắn hơn (mm) sẽ so le ra hàng ngoài',
         'Vị trí chữ DIM',
         'Độ dày ván (mm)', 'Dim cắt + Dim liên tiếp: bỏ đoạn độ dày',
         'Dim cắt: chế độ tính',
         'Dim cắt (từ đáy đối tượng): chỉ tính chi tiết nhìn thấy',
         'Dim cắt (từ đáy đối tượng): dung sai ngang (mm)',
         'Kích thước đối tượng: chỉ 2 chiều (bỏ chiều nhỏ nhất)',
         'Đường kính lỗ tối đa (mm)', 'Từ khóa tên Component lỗ (dấu phẩy)',
         'Từ khóa tên CÁNH (dấu phẩy, không dấu)'],
        [raw_offset_mm.to_s, leg_mm.to_s, leg_len_mm.to_s, step_mm.to_s, stagger_mm.to_s, text_modes.key(pref('text_position', 'center')) || 'Giữa',
         thick_mm.to_s, cut_skip? ? 'Có' : 'Không', cut_mode == 'base' ? modes[1] : modes[0],
         vis_only? ? 'Có' : 'Không', lat_mm.to_s, obj_two_d? ? 'Có' : 'Không', max_dia_mm.to_s,
         pref('hole_kw', 'hole,drill,khoan').to_s,
         pref('leaf_kw', 'canh,door,cua,leaf').to_s],
        ['', '', '', '', '', text_modes.keys.join('|'), '', 'Có|Không', modes.join('|'), 'Có|Không', '', 'Có|Không', '', '', ''],
        'HP Auto Dim - Cài đặt')
      return unless r
      numeric_indices = [0, 1, 2, 3, 4, 6, 10, 12]
      begin
        numeric_indices.each { |i| r[i] = Float(r[i]); raise ArgumentError unless r[i].finite? }
        raise ArgumentError if [1, 2, 3, 4, 6, 10].any? { |i| r[i] < 0 } || r[12] <= 0
      rescue ArgumentError, TypeError
        UI.messagebox('Cài đặt không hợp lệ: nhập số hữu hạn; khoảng hở, chiều dài và độ dày không âm, đường kính lỗ lớn hơn 0.')
        return
      end
      set_pref('offset_mm', r[0].to_f)
      set_pref('leg_mm', r[1].to_f)
      set_pref('leg_len_mm', r[2].to_f)
      set_pref('step_mm', r[3].to_f)
      set_pref('stagger_mm', r[4].to_f)
      set_pref('text_position', text_modes.fetch(r[5], 'center'))
      set_pref('thick_mm', r[6].to_f)
      set_pref('cut_skip', r[7] == 'Có' ? 1 : 0)
      set_pref('cut_mode', r[8] == modes[1] ? 'base' : 'section')
      set_pref('vis_only', r[9] == 'Có' ? 1 : 0)
      set_pref('lat_mm', r[10].to_f)
      set_pref('obj_two_d', r[11] == 'Có' ? 1 : 0)
      set_pref('max_dia_mm', r[12].to_f)
      set_pref('hole_kw', r[13].to_s)
      set_pref('leaf_kw', r[14].to_s)
      model = Sketchup.active_model
      invalidate_tracking(model)
      refresh_all(model, true)
    end

    # ---- Kiểm tra hiệu năng: lag do plugin tính toán hay do số dim phải vẽ ----
    def self.perf_text(stat)
      return 'chưa chạy' unless stat
      format('%d lần, gần nhất %.0f ms, lâu nhất %.0f ms', stat[:count], stat[:last] * 1000, stat[:max] * 1000)
    end

    def self.diagnose
      model = Sketchup.active_model
      state = runtime(model)
      sets = load_sets(model)
      ids = {}
      sets.each { |s| ids[s['id']] = true }
      cur = current_pgid(model)
      groups = 0
      orphans = 0
      hp_dims = 0
      shown = 0
      all_dims = model.entities.grep(Sketchup::Dimension).size
      model.definitions.each do |d|
        next if d.image?
        insts = d.instances
        n = d.entities.grep(Sketchup::Dimension).size
        all_dims += n * insts.size
        next unless d.group?
        insts.each do |g|
          sid = g.get_attribute(PLUGIN_ID, 'set')
          next unless sid
          groups += 1
          hp_dims += n
          shown += n if g.visible? && layer_visible?(g.layer)
          orphans += 1 unless ids[sid]
        end
      end
      refresh = state[:perf][:refresh]
      lines = [
        "Bộ DIM tự cập nhật: #{sets.size} (scene hiện tại: #{sets.count { |s| set_in_scene?(s, cur) }})",
        "Nhóm DIM của HP: #{groups} (đã ngừng theo dõi: #{orphans})",
        "Dim của HP: #{hp_dims}, đang hiển thị: #{shown}",
        "Tổng số dim trong model (kể cả dim vẽ tay/plugin khác): #{all_dims}",
        "Đang theo dõi thay đổi: #{state[:watchers].size} nhóm/component",
        "Tự cập nhật: #{auto_update? ? 'Bật' : 'Tắt'}; Hiển thị kích thước khi chọn: #{info_on? ? 'Bật' : 'Tắt'}",
        "Cập nhật tự động: #{perf_text(refresh)}",
        "Từng lượt cập nhật nền: #{perf_text(state[:perf][:background_slice])}",
        "Bộ DIM quá nặng đang chờ cập nhật đầy đủ: #{state[:slow_sets].size}"
      ]
      advice = []
      if shown > 1500 || all_dims > 3000
        advice << '- Có rất nhiều dim đang hiển thị: SketchUp phải vẽ lại từng dim ở mỗi khung hình khi xoay. ' \
                  'Có thể ẩn thư mục HP DIM khi dựng hình, bật lại khi cần xem/xuất bản vẽ.'
      end
      if refresh && refresh[:max] > 0.5
        advice << '- Cập nhật tự động đang nặng: có thể tắt "Tự động cập nhật khi đối tượng thay đổi" ' \
                  'và bấm "Cập nhật kích thước" khi cần.'
      end
      if advice.empty?
        advice << '- Số liệu phiên này chưa ghi nhận lượt cập nhật chậm; số liệu này chưa xác định được ' \
                  'nguyên nhân SketchUp đóng khi mở file. Có thể tắt HP Auto Dim để đối chiếu trên cùng model.'
      end
      text = lines.join("\n") + "\n\nGợi ý:\n" + advice.join("\n")
      puts "HP Auto Dim - kiểm tra hiệu năng\n#{text}"
      UI.messagebox("HP Auto Dim - kiểm tra hiệu năng\n\n#{text}")
    rescue StandardError => err
      UI.messagebox("Lỗi kiểm tra: #{err.message}")
    end

    def self.about
      UI.messagebox("#{PLUGIN_NAME} v#{PLUGIN_VERSION}\nDIM mới dùng tag riêng theo scene và loại trong thư mục HP DIM.\nDIM cũ: dùng lệnh Chuyển DIM cũ sang Tags theo scene (HP DIM).")
    end

    def self.make_cmd(title, tip, icon)
      c = UI::Command.new(title) { yield }
      c.tooltip = tip
      c.status_bar_text = tip
      c.small_icon = File.join(ICON_DIR, "#{icon}_16.png")
      c.large_icon = File.join(ICON_DIR, "#{icon}_24.png")
      c
    end

    unless file_loaded?(__FILE__)
      c_chain = make_cmd('Dim liên tiếp', 'Click điểm 1, điểm 2, kéo ra đặt dim, rồi click các điểm tiếp theo (nối tiếp); Enter/Esc để xong', 'chain') { start_cont_tool }
      c_obj   = make_cmd('Kích thước đối tượng', 'Chọn 1 hoặc nhiều đối tượng: tạo kích thước dài, rộng, cao của từng đối tượng', 'objdim') { run_obj }
      c_pick  = make_cmd('Chọn dim', 'Click vào dim (kể cả trong nhóm) để chọn đúng dim đó và chỉnh sửa', 'pickdim') { start_pickdim }
      c_cut   = make_cmd('Dim cắt', 'Click điểm đầu, điểm cuối, đặt dim: tự dim các khoảng cách giao cắt (đợt, phào...)', 'cut') { start_dim_tool(:cut) }
      c_holes = make_cmd('Kích thước cánh + tim lỗ', 'Tạo kích thước từng cánh, tim lỗ, so le', 'holes') { run_holes }
      c_probe = make_cmd('Đo nhanh', 'Rê chuột vào cạnh/mặt/chi tiết (kể cả group lồng sâu) để xem kích thước', 'inspect') { start_inspect }
      c_info  = make_cmd('Hiển thị kích thước khi chọn', 'Bật/tắt hiển thị kích thước trực tiếp lên đối tượng được chọn', 'info') { toggle_info }
      c_info.set_validation_proc { info_on? ? MF_CHECKED : MF_UNCHECKED }
      c_upd   = make_cmd('Cập nhật kích thước', 'Cập nhật lại kích thước theo đối tượng hiện tại', 'update') { refresh_all(Sketchup.active_model, true) }
      c_auto  = UI::Command.new('Tự động cập nhật khi đối tượng thay đổi') do
        set_pref('auto_update', auto_update? ? 0 : 1)
      end
      c_auto.set_validation_proc { auto_update? ? MF_CHECKED : MF_UNCHECKED }
      c_clear = make_cmd('Xóa kích thước (scene hiện tại)', 'Xóa bộ DIM thuộc scene hiện tại, giữ bộ DIM của scene khác', 'clear') { clear_dims(false) }
      c_set   = make_cmd('Cài đặt', 'Cài đặt khoảng cách / độ dày / nhận diện cánh và lỗ', 'settings') { settings }

      c_m1 = UI::Command.new('Dim cắt: đúng mặt cắt') { set_pref('cut_mode', 'section') }
      c_m1.set_validation_proc { cut_mode == 'section' ? MF_CHECKED : MF_UNCHECKED }
      c_m2 = UI::Command.new('Dim cắt: từ đáy đối tượng (dung sai ngang)') { set_pref('cut_mode', 'base') }
      c_m2.set_validation_proc { cut_mode == 'base' ? MF_CHECKED : MF_UNCHECKED }

      menu = UI.menu('Extensions').add_submenu("#{PLUGIN_NAME} v#{PLUGIN_VERSION}")
      menu.add_item(c_chain)
      menu.add_item(c_cut)
      menu.add_item(c_obj)
      menu.add_item(c_pick)
      menu.add_item(c_m1)
      menu.add_item(c_m2)
      menu.add_item(c_holes)
      menu.add_item(c_probe)
      menu.add_item(c_info)
      menu.add_separator
      menu.add_item(c_upd)
      menu.add_item(c_auto)
      menu.add_item(c_clear)
      menu.add_item('Xóa TẤT CẢ kích thước HP (mọi scene)') { clear_dims(true) }
      menu.add_item(c_set)
      menu.add_item('Chuyển DIM cũ sang Tags theo scene (HP DIM)') { consolidate_tags }
      menu.add_item('Kiểm tra hiệu năng (lag)') { diagnose }
      menu.add_item('Thông tin') { about }

      tb = UI::Toolbar.new('HP Auto Dim')
      [c_chain, c_cut, c_obj, c_pick, c_holes, c_probe, c_info, c_upd, c_clear, c_set].each { |c| tb.add_item(c) }
      tb.restore
      tb.show

      UI.add_context_menu_handler do |cmenu|
        sel = Sketchup.active_model.selection
        g = sel.size == 1 ? sel[0] : nil
        if g && HP::AutoDim.hp_dim?(g)
          cmenu.add_separator
          cmenu.add_item('HP: Vào sửa dim (nhóm này)') { HP::AutoDim.enter_dim_group(g) }
          cmenu.add_item('HP: Bung nhóm, ngừng tự cập nhật') { HP::AutoDim.release_dim_group(g) }
          cmenu.add_item('HP: Xóa bộ dim này') { HP::AutoDim.delete_dim_group(g) }
        end
      end
      Sketchup.add_observer(HPAppObserver.new)
      defer_attach(Sketchup.active_model)
      @poll_timer = UI.start_timer(3.0, true) { poll }

      file_loaded(__FILE__)
    end
  end
end
