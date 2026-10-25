# encoding: UTF-8
module HP
  module AutoDim
    class AutoBudgetExceeded < StandardError; end

    def self.monotonic
      Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end

    def self.live_model?(model)
      model && model.valid?
    rescue StandardError
      false
    end

    # Budget checks are inside Ruby geometry/render loops. A native API call
    # cannot be interrupted; this is a bound on work between native calls.
    def self.check_auto_budget!
      raise AutoBudgetExceeded, 'Bộ DIM phức tạp: dùng Cập nhật kích thước để tính đầy đủ.' if @auto_deadline && monotonic > @auto_deadline
    end

    def self.background_busy?(model, state)
      state[:saving] || state[:transaction_open] || interacting?(model) ||
        (model.active_path || []).any? { |entity| hp_dim?(entity) }
    end

    def self.update_eligible?(set, page)
      set['mode'] == 'obj' || set_in_scene?(set, page)
    end

    # Opening a document registers observers later and does not inspect saved
    # DIMs, resolve PIDs, create overlays, or start a geometry refresh.
    def self.defer_attach(model)
      return unless live_model?(model)
      state = runtime(model)
      return if state[:attach_timer] || (@attached && @attached[model.object_id])
      state[:attach_timer] = UI.start_timer(0.2, false) do
        state[:attach_timer] = nil
        if !live_model?(model)
          forget_model(model)
        elsif @runtimes && @runtimes[model.object_id].equal?(state)
          attach(model)
        end
      end
    end

    def self.attach(model)
      @attached ||= {}
      return if !live_model?(model) || @attached[model.object_id]
      state = runtime(model)
      state[:last_page] = current_pgid(model)
      state[:model_observer] = HPModelObserver.new
      model.add_observer(state[:model_observer])
      state[:pages_observer] = HPDimPagesObserver.new(model)
      model.pages.add_observer(state[:pages_observer])
      state[:tags_observer] = HPTagObserver.new(model)
      model.layers.add_observer(state[:tags_observer])
      # Source observers are attached lazily, only for geometry actually used
      # by a DIM. Object dimensions need only current bounds/transformation.
      @attached[model.object_id] = true
    end

    def self.schedule_update(model)
      return if @updating || !live_model?(model) || !auto_update?
      state = runtime(model)
      state[:pending] = true
      state[:job] = nil
      return if background_busy?(model, state)
      UI.stop_timer(state[:timer]) if state[:timer]
      state[:timer] = UI.start_timer(1.0, false) do
        state[:timer] = nil
        run_background(model, state)
      end
    end

    def self.poll
      return if @updating || !auto_update?
      model = Sketchup.active_model
      return unless live_model?(model) && @runtimes
      state = @runtimes[model.object_id]
      # The idle timer does zero entity/JSON/fingerprint work on an untouched
      # document. It only resumes work previously requested by a user edit.
      return unless state
      page = current_pgid(model)
      state[:last_page] = page if state[:last_page].nil?
      if state[:last_page] != page
        state[:last_page] = page
        state[:pending] = true
        state[:job] = nil
        state[:fp_cache].clear
        state[:geometry_cache].clear
        state[:root_index] = nil
        state[:cache_epoch] += 1
      end
      return unless state[:pending] && !state[:timer]
      return if background_busy?(model, state) || camera_moving?(model)
      schedule_update(model)
    rescue StandardError => error
      log_once("HP chờ cập nhật: #{error.message}")
    end

    def self.run_background(model, state)
      return unless @runtimes && @runtimes[model.object_id].equal?(state)
      unless live_model?(model)
        forget_model(model)
        return
      end
      return unless auto_update?
      if @updating || Sketchup.active_model != model || background_busy?(model, state) || camera_moving?(model)
        state[:pending] = true
        return
      end
      page = current_pgid(model)
      remember_entities(model, model.selection.to_a) if model.selection.length <= 128
      remember_entities(model, model.active_path || [])
      job = state[:job]
      raw = model.get_attribute(PLUGIN_ID, 'sets', '[]')
      if !job || job[:generation] != state[:generation] || job[:page] != page || job[:raw] != raw
        sets = load_sets(model)
        now = monotonic
        queue = sets.select do |set|
          update_eligible?(set, page) && now >= state[:slow_sets].fetch(set['id'], 0.0)
        end
        job = {sets: sets, queue: queue, position: 0, generation: state[:generation],
               page: page, raw: raw, dim_index: {}}
        state[:job] = job
      end
      started = monotonic
      processed = 0
      while job[:position] < job[:queue].size
        set = job[:queue][job[:position]]
        @auto_deadline = monotonic + 0.15
        refresh_all(model, false, [set['id']], job[:sets])
        @auto_deadline = nil
        job[:raw] = model.get_attribute(PLUGIN_ID, 'sets', '[]')
        job[:position] += 1
        processed += 1
        break if processed >= 8 || monotonic - started >= 0.025
      end
      record_time(model, :background_slice, monotonic - started)
      if job[:position] < job[:queue].size
        state[:timer] = UI.start_timer(0.05, false) do
          state[:timer] = nil
          run_background(model, state)
        end
      else
        state[:job] = nil
        state[:pending] = false
        unless state[:slow_sets].empty?
          Sketchup.status_text = 'HP Auto Dim: bộ DIM quá nặng được giữ nguyên; dùng Cập nhật kích thước để tính đầy đủ.'
        end
      end
    rescue StandardError => error
      state[:job] = nil
      state[:pending] = false
      log_once("HP cập nhật nền: #{error.message}")
    ensure
      @auto_deadline = nil
    end

    class HPModelObserver < Sketchup::ModelObserver
      def onTransactionStart(model)
        return if HP::AutoDim.instance_variable_get(:@updating)
        HP::AutoDim.runtime(model)[:transaction_open] = true
      end

      def onTransactionCommit(model)
        return if HP::AutoDim.instance_variable_get(:@updating)
        HP::AutoDim.runtime(model)[:transaction_open] = false
        HP::AutoDim.note_transaction(model)
        HP::AutoDim.schedule_update(model)
      end

      def onTransactionUndo(model)
        return if HP::AutoDim.instance_variable_get(:@updating)
        HP::AutoDim.runtime(model)[:transaction_open] = false
        HP::AutoDim.note_transaction(model)
        HP::AutoDim.invalidate_tracking(model)
        HP::AutoDim.schedule_update(model)
      end
      alias onTransactionRedo onTransactionUndo

      def onTransactionAbort(model)
        return if HP::AutoDim.instance_variable_get(:@updating)
        HP::AutoDim.runtime(model)[:transaction_open] = false
        HP::AutoDim.invalidate_tracking(model)
      end
      alias onTransactionEmpty onTransactionAbort

      def onActivePathChanged(model)
        HP::AutoDim.schedule_update(model)
      end

      def onPreSaveModel(model)
        state = HP::AutoDim.runtime(model)
        state[:saving] = true
        UI.stop_timer(state[:timer]) if state[:timer]
        state[:timer] = nil
      end

      def onPostSaveModel(model)
        HP::AutoDim.runtime(model)[:saving] = false
      end

      def onDeleteModel(model)
        HP::AutoDim.forget_model(model)
      end
    end

    class HPAppObserver < Sketchup::AppObserver
      def onNewModel(model); HP::AutoDim.defer_attach(model); end
      def onOpenModel(model); HP::AutoDim.defer_attach(model); end
      def expectsStartupModelNotifications; true; end
    end
  end
end
