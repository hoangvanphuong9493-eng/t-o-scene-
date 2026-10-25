# Reuse only the initial synthetic cabinet setup, then drive production
# ModelObserver -> timer -> run_background -> refresh_all, not direct refresh.
base=File.expand_path('../hp_autodim_2193/regression_test.rb',__dir__)
ARGV[0] ||= File.expand_path('../../src/hp_auto_dim_2.19.5/hp_auto_dim',__dir__)
script=File.read(base);boundary=script.index('# Changing the part count')
raise 'Cabinet setup boundary moved' unless boundary
context=TOPLEVEL_BINDING
eval(script[0...boundary],context,base)
model=context.local_variable_get(:model);root=context.local_variable_get(:root)
sets=context.local_variable_get(:sets);cut=context.local_variable_get(:cut);cont=context.local_variable_get(:cont)
obj=context.local_variable_get(:obj);std=context.local_variable_get(:std);shelf=context.local_variable_get(:shelf)
left=context.local_variable_get(:left);right=context.local_variable_get(:right);top=context.local_variable_get(:top);bottom=context.local_variable_get(:bottom)
root.set_attribute('fuji_dict','comp_type','FujiFrame')
[[left,'ENDL'],[right,'ENDR'],[top,'TOP'],[bottom,'BOTTOM']].each{|part,type|part.set_attribute('fuji_dict','sheet_type',type)}
class Sketchup::InputPoint;end
module Sketchup
  class << self;attr_accessor :vcb_label,:vcb_value;end
end
class LifecycleView
  attr_reader :camera,:model
  attr_accessor :tooltip
  def initialize(model)
    @model=model
    @camera=Struct.new(:eye,:target,:up,:height,:direction) do
      def perspective?;false;end
    end.new(Geom::Point3d.new(0,-200,100),ORIGIN,Z_AXIS,200,Y_AXIS)
  end
  def invalidate;end
end
class Sketchup::Model
  attr_accessor :observer_hooks
  def active_view;@test_view||=LifecycleView.new(self);end
  alias no_observer_start_operation start_operation
  alias no_observer_commit_operation commit_operation
  def start_operation(*args)
    observer_hooks&.onTransactionStart(self);no_observer_start_operation(*args)
  end
  def commit_operation
    no_observer_commit_operation;observer_hooks&.onTransactionCommit(self)
  end
end
module UI
  class << self;attr_accessor :timers;end
  self.timers={}
  def self.start_timer(_delay,_repeat,&block);@id=(@id||0)+1;timers[@id]=block;@id;end
  def self.stop_timer(id);timers.delete(id);end
  def self.run_queued
    iterations=0
    until timers.empty?
      id,block=timers.first;timers.delete(id);block.call;iterations+=1
      raise 'timer did not quiesce' if iterations>100
    end
  end
end
model.observer_hooks=AD::HPModelObserver.new
model.selection=[]
# Keep callback tests deterministic, then inject a budget expiration below.
clock=0.0
AD.define_singleton_method(:monotonic){clock}
@checks=0
def check(value,message);raise message unless value;@checks+=1;end
def near_values(model,set,expected,label)
 actual=measurements(model,set)
 check(actual.size==expected.size && actual.zip(expected).all?{|a,b|(a-b).abs<0.00001},"#{label}: #{actual} != #{expected}")
end
def edit(model)
 model.start_operation('simulated source edit',true)
 yield
 model.commit_operation
 UI.run_queued
end
# The uploaded model has a moved DIM group and no remaining set for its ID.
# Reproduce the deletion first, without any source geometry changing.
edit(model) do
 sets.each do |set|
  group=AD.dim_items(model.entities,set['id']).first
  group.transformation=Geom::Transformation.new([1,0,0,0,1,0,0,0,1,205.mm,0,0,1])
  model.entities.modified(group)
 end
end
sets.each{|set|check(AD.load_sets(model).any?{|saved|saved['id']==set['id']},"moving #{set['mode']} deleted its tracking record")}
edit(model){move_panel_z(shelf,100.mm)}
near_values(model,cut,[1164,1182],'observer/timer updates moved cut group')
sets.each do |set|
 group=AD.dim_items(model.entities,set['id']).first
 check(group && (group.transformation.origin.x-205.mm).abs<1e-8,"#{set['mode']} lost placement translation")
end
# Topology changes must reach the renderer through callbacks as well.
added=nil
edit(model){added=create_box(model,root.definition,[609,-600,500].map(&:mm),[1182,-27,518].map(&:mm),'extra')}
near_values(model,cut,[1164,682,482],'automatic inserted shelf')
edit(model){added.erase!}
near_values(model,cut,[1164,1182],'automatic removed shelf')
edit(model){added=create_box(model,root.definition,[300,-600,18].map(&:mm),[318,-27,2382].map(&:mm),'extra-divider')}
near_values(model,cont,[282,273,573],'automatic inserted divider')
edit(model){added.erase!}
near_values(model,cont,[573,573],'automatic removed divider')
holes=context.local_variable_get(:holes);door=context.local_variable_get(:door)
last_hole=holes.last
edit(model){last_hole.transformation=Geom::Transformation.new([1,0,0,0,1,0,0,0,1,25.mm,-605.mm,2250.mm,1]);last_hole.parent.entities.modified(last_hole)}
near_values(model,std,[599.6,150,650,800,700,100,2400],'automatic moved hinge')
edit(model){last_hole.erase!}
near_values(model,std,[599.6,800,800,700,100,2400],'automatic removed hinge')
edit(model){added=add_circle(model,door.definition,2000,'new-hinge')}
near_values(model,std,[599.6,400,400,800,700,100,2400],'automatic inserted hinge')
edit(model){added.erase!;add_circle(model,door.definition,2300,'hinge3')}
near_values(model,std,[599.6,100,700,800,700,100,2400],'automatic restored hinge')
# Integer labels must update through the real observer/timer pipeline as well.
edit(model) do
 root.transformation=Geom::Transformation.new([1.2,0,0,0,1,0,0,0,1,0,0,0,1]);model.entities.modified(root)
end
near_values(model,obj,[1440,2400],'auto object resize')
near_values(model,cont,[21.6,687.6,687.6,21.6],'auto chain resize')
near_values(model,std,[719.52,100,700,800,700,100,2400],'auto doors resize')
check(dimensions(model,obj).first.text=='1440','integer label did not update through timer')
# Idle tool retained after Esc must not lock all parameter edits indefinitely.
tool=AD::HPChainTool.allocate;tool.instance_variable_set(:@phase,:place)
tool.begin_interaction
edit(model) do
 root.transformation=Geom::Transformation.new([1.1,0,0,0,1,0,0,0,1,0,0,0,1]);model.entities.modified(root)
end
near_values(model,obj,[1440,2400],'active placement defers automatic refresh')
check(AD.runtime(model)[:pending],'pending edit lost during placement')
tool.onCancel(0,model.active_view)
check(!AD.interacting?(model),'Esc left an idle point tool blocking updates')
AD.poll;UI.run_queued
near_values(model,obj,[1320,2400],'auto resumes after Esc without switching tools')
tool.deactivate(model.active_view)
# Both point tools: idle first point can update; unfinished placements cannot.
[[AD::HPDimTool,[:first],[:second,:place]], [AD::HPChainTool,[:p1],[:p2,:place,:next]]].each do |klass,idle,busy|
 candidate=klass.allocate;candidate.begin_interaction
 idle.each{|phase|candidate.instance_variable_set(:@phase,phase);check(!AD.interacting?(model),"#{klass} #{phase} blocked idle updates")}
 busy.each{|phase|candidate.instance_variable_set(:@phase,phase);check(AD.interacting?(model),"#{klass} #{phase} allowed mid-placement update")}
 candidate.onCancel(0,model.active_view)
 check(!AD.interacting?(model),"#{klass} Esc did not release idle updates")
 candidate.deactivate(model.active_view)
end
# Save and Undo/Redo notifications must leave the queue able to resume.
model.observer_hooks.onPreSaveModel(model)
edit(model) do
 root.transformation=Geom::Transformation.new([1.0,0,0,0,1,0,0,0,1,0,0,0,1]);model.entities.modified(root)
end
near_values(model,obj,[1320,2400],'saving guard defers updates')
model.observer_hooks.onPostSaveModel(model);AD.poll;UI.run_queued
near_values(model,obj,[1200,2400],'resume after saving')
root.transformation=Geom::Transformation.new([1.1,0,0,0,1,0,0,0,1,0,0,0,1]);model.observer_hooks.onTransactionUndo(model);UI.run_queued
near_values(model,obj,[1320,2400],'undo notification recalculates')
root.transformation=Geom::Transformation.new;model.observer_hooks.onTransactionRedo(model);UI.run_queued
near_values(model,obj,[1200,2400],'redo notification recalculates')
# A different manual edit pauses, but must not erase its saved source linkage.
group=AD.dim_items(model.entities,cut['id']).first
edit(model){group.transformation=Geom::Transformation.new([1.1,0,0,0,1,0,0,0,1,205.mm,0,0,1]);model.entities.modified(group)}
check(AD.load_sets(model).any?{|saved|saved['id']==cut['id']},'manual Scale silently discarded source record')
edit(model){group.transformation=Geom::Transformation.new([1,0,0,0,1,0,0,0,1,205.mm,0,0,1]);model.entities.modified(group);move_panel_z(shelf,10.mm)}
near_values(model,cut,[1154,1192],'restored translation-only group resumes')
# Emulate the already-orphaned group in the uploaded file; recovery is explicit.
AD.save_sets(model,AD.load_sets(model).reject{|set|set['id']==cut['id']})
old_group=AD.dim_items(model.entities,cut['id']).first
model.selection=[old_group]
check(AD.recover_selected_cut,'explicit orphan recovery failed')
restored=AD.load_sets(model).find{|set|set['id']==cut['id']}
check(restored && restored['scan_source_pid']==root.persistent_id && restored['scan_full_span'],'recovery did not save source linkage')
near_values(model,restored,[1154,1192],'orphan remeasured current full source')
edit(model){move_panel_z(shelf,10.mm)}
near_values(model,restored,[1144,1202],'recovered orphan updates through observer/timer')
# Multiple candidate sources require explicit source selection, never guessing.
AD.save_sets(model,AD.load_sets(model).reject{|set|set['id']==restored['id']})
second=model.entities.add_group;second.set_attribute('fuji_dict','comp_type','FujiFrame')
model.selection=[AD.dim_items(model.entities,restored['id']).first]
original_ui=UI.method(:messagebox);messages=[]
UI.define_singleton_method(:messagebox){|message|messages<<message}
check(!AD.recover_selected_cut && !messages.empty?,'ambiguous source was guessed')
check(!AD.load_sets(model).any?{|set|set['id']==restored['id']},'ambiguous recovery changed records')
model.selection<<root
check(AD.recover_selected_cut,'explicit chosen source was rejected')
# Failed recovery must be read-only: never replace a manual, duplicate,
# transformed, differently-scened or ambiguous orphan by a guessed layout.
restored=AD.load_sets(model).find{|set|set['id']==cut['id']}
AD.save_sets(model,AD.load_sets(model).reject{|set|set['id']==restored['id']})
orphan=AD.dim_items(model.entities,restored['id']).first
model.selection=[orphan,root]
unchanged=AD.load_sets(model)
reject_recovery=lambda do |label|
 messages.clear
 check(!AD.recover_selected_cut && !messages.empty?,"#{label} was not rejected")
 check(orphan.valid? && AD.load_sets(model)==unchanged,"#{label} changed group or records")
end
placement=orphan.transformation
orphan.transformation=Geom::Transformation.new([1.1,0,0,0,1,0,0,0,1,205.mm,0,0,1])
reject_recovery.call('scaled orphan');orphan.transformation=placement
orphan.set_attribute(AD::PLUGIN_ID,'scene_id',38896)
reject_recovery.call('other-scene orphan');orphan.set_attribute(AD::PLUGIN_ID,'scene_id',38895)
name=orphan.name;orphan.name='Unknown annotation'
reject_recovery.call('unknown orphan type');orphan.name=name
manual=orphan.entities.add_dimension_linear(ORIGIN,Geom::Point3d.new(100.mm,0,0),Geom::Vector3d.new(0,10.mm,0))
reject_recovery.call('orphan containing manual DIM')
check(manual.valid? && (manual.measurement-100.mm).abs<1e-8,'failed recovery changed manual DIM');manual.erase!
duplicate=model.entities.add_group;duplicate.set_attribute(AD::PLUGIN_ID,'set',restored['id'])
reject_recovery.call('duplicate set ID');duplicate.erase!
boundary=right.get_attribute('fuji_dict','sheet_type')
right.set_attribute('fuji_dict','sheet_type','unknown')
reject_recovery.call('missing boundary panel');right.set_attribute('fuji_dict','sheet_type',boundary)
extra=create_box(model,root.definition,[1182,-600,18].map(&:mm),[1200,0,2400].map(&:mm),'ambiguous-boundary')
extra.set_attribute('fuji_dict','sheet_type','ENDR')
reject_recovery.call('ambiguous boundary panels');extra.erase!
direction=model.active_view.camera.direction;model.active_view.camera.direction=X_AXIS
reject_recovery.call('edge-on camera');model.active_view.camera.direction=direction
check(AD.recover_selected_cut,'valid recovery after rejected attempts failed')
# The budget guard preserves old dimensions and metadata; full refresh retries.
restored=AD.load_sets(model).find{|set|set['id']==cut['id']}
before=measurements(model,restored)
original_compute=AD.method(:compute_line);injected=false
AD.define_singleton_method(:compute_line) do |current_model,set|
 if set['id']==restored['id'] && instance_variable_get(:@auto_deadline) && !injected
  injected=true
  raise AD::AutoBudgetExceeded,'injected automatic budget expiration'
 end
 original_compute.call(current_model,set)
end
edit(model){move_panel_z(shelf,10.mm)}
check(injected && AD.runtime(model)[:slow_sets].key?(restored['id']),'budget failure did not enter guarded retry state')
near_values(model,restored,before,'budget failure keeps previous dimensions')
check(AD.load_sets(model).any?{|set|set['id']==restored['id']},'budget failure deleted metadata')
check(!AD.instance_variable_get(:@updating) && AD.instance_variable_get(:@auto_deadline).nil?,'budget failure left update locked')
AD.define_singleton_method(:compute_line,original_compute)
AD.refresh_all(model,true)
near_values(model,restored,[1134,1212],'manual full refresh retries guarded set')
check(AD.runtime(model)[:slow_sets].empty?,'manual full refresh did not clear guarded retry state')
UI.define_singleton_method(:messagebox,original_ui)
puts "PASS #{@checks} lifecycle assertions via actual observer/timer/background functions."
