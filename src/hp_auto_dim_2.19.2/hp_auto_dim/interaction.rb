# encoding: UTF-8
module HP
  module AutoDim
    # The VCB explicitly says mm. Bare numbers must not inherit metres/inches
    # from the model; a unit suffix still uses SketchUp's native length parser.
    def self.parse_leg_mm(text)
      value = text.to_s.strip
      return nil if value == '-'
      raise ArgumentError, 'Nhập chiều dài dương hoặc dấu -' if value.empty?
      mm = if value.match?(/\A[+]?(?:\d+(?:[.,]\d*)?|[.,]\d+)\z/)
             Float(value.tr(',', '.'))
           else
             value.to_l.to_f / MM
           end
      raise ArgumentError, 'Chiều dài chân DIM phải lớn hơn 0' unless mm.finite? && mm > 0
      mm
    end

    def self.leg_spec(set)
      case set['leg_policy']
      when 'free'
        [set['gap'] || offset_mm, nil, false]
      when 'custom'
        length = set['leg_len_mm'].to_f
        raise ArgumentError, 'Chiều dài chân DIM không hợp lệ' unless length.finite? && length > 0
        [leg_mm + length, length, true]
      else
        [offset_mm, leg_len_mm > 0 ? leg_len_mm : nil, true]
      end
    end

    # Point-by-point DIMs use the picked line, rather than the furthest bounding
    # box of another object, as their reference for the witness legs.
    def self.point_off_legs(axis, od, gap_mm, length = nil)
      direction = od - sc(axis, od.dot(axis).to_f)
      direction = direction.normalize
      gap = [gap_mm.to_f * MM, 0.01 * MM].max
      small = length ? leg_mm * MM : [leg_mm * MM, gap * 0.5].min
      [sc(direction, gap), sc(direction, small)]
    end

    def self.interacting?(model)
      !runtime(model).fetch(:active_tools, {}).empty?
    end

    def self.begin_interaction(model, tool)
      state = runtime(model)
      (state[:active_tools] ||= {})[tool.object_id] = true
      if state[:timer]
        UI.stop_timer(state[:timer])
        state[:timer] = nil
        state[:pending] = true
      end
    end

    def self.end_interaction(model, tool)
      return unless live_model?(model)
      state = runtime(model)
      (state[:active_tools] ||= {}).delete(tool.object_id)
      schedule_update(model) if state[:pending] && !interacting?(model)
    end

    module PointTool
      def begin_interaction
        @interaction_model = Sketchup.active_model
        HP::AutoDim.begin_interaction(@interaction_model, self)
      end

      def deactivate(view)
        view.tooltip = ''
        HP::AutoDim.end_interaction(@interaction_model, self) if @interaction_model
        @interaction_model = nil
        view.invalidate
      end

      def remember_reference
        @reference_ip ||= Sketchup::InputPoint.new
        @reference_ip.copy!(@ip)
      end

      def pick_input(view, x, y, reference = false)
        if reference && @reference_ip && @reference_ip.valid?
          @ip.pick(view, x, y, @reference_ip)
        else
          @ip.pick(view, x, y)
        end
        view.tooltip = @ip.valid? ? @ip.tooltip : ''
        @ip.valid?
      end

      def snapped_axis(origin)
        return nil unless @ip.valid? && @ip.degrees_of_freedom <= 1
        delta = @ip.position - origin
        delta.length.to_f > MM ? delta.normalize : nil
      end

      def leg_spec
        HP::AutoDim.leg_spec('leg_policy' => (@leg_policy || 'settings'),
                            'leg_len_mm' => @leg_len, 'gap' => @gap_mm)
      end

      def leg_fields
        {'leg_policy' => (@leg_policy || 'settings'), 'leg_len_mm' => @leg_len,
         'row_shift_mm' => (@row_shift_mm || 0.0)}
      end

      def set_leg_input(text)
        @leg_len = HP::AutoDim.parse_leg_mm(text)
        @leg_policy = @leg_len ? 'custom' : 'free'
      end
    end
  end
end
