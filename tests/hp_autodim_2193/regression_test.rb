# Synthetic cabinet, not the user's uploaded model. Run with Ruby 3.2+.
require_relative 'model_fixture'
require_relative 'render_api'
load_plugin_for_geometry(ARGV[0] || File.expand_path('../../src/hp_auto_dim_2.19.3-rc1/hp_auto_dim',__dir__))
module UI
  def self.messagebox(message);raise message;end
end
module SecureRandom
  def self.hex(_n);@n=(@n||0)+1;"synthetic#{@n}";end
end
class Sketchup::Model
  attr_accessor :selection
end
module HP
  module AutoDim
    # Tag-folder/scene API has a separate suite; geometry/rendering uses this tag.
    def self.tag_for(_model,_set);Sketchup::Layer.new;end
    def self.new_scene_tag(_model,set);set['tag_schema']=219;Sketchup::Layer.new;end
  end
end
Input=Struct.new(:position,:vertex,:edge,:degrees_of_freedom,:instance_path)
HP=::HP unless defined?(HP)
AD=HP::AutoDim
@checks=0
def check(value,message)
  raise message unless value
  @checks+=1
end
def values_close(actual,expected,message)
  check(actual.size==expected.size && actual.zip(expected).all?{|a,b|(a-b).abs<0.00001},"#{message}: #{actual.inspect} != #{expected.inspect}")
end
def dimensions(model,set)
  context=%w[cont cut chain].include?(set['mode']) ? model.entities : AD.ctx_entities(model,set['ctx'])
  AD.dim_items(context,set['id']).flat_map{|g|g.entities.grep(Sketchup::DimensionLinear)}
end
def measurements(model,set);dimensions(model,set).map{|d|d.measurement*25.4};end

def add_circle(model,parent,z,identity)
  definition=Sketchup::ComponentDefinition.new(model.next_id,'Hinge')
  model.definitions[definition.persistent_id]=definition
  vertices=24.times.map do |i|
    t=2*Math::PI*i/24
    v=Sketchup::Vertex.new(model.next_id,definition,[Math.cos(t)*17.5.mm,0,Math.sin(t)*17.5.mm]);model.lookup[v.persistent_id]=v;v
  end
  edges=24.times.map do |i|
    e=Sketchup::Edge.new(model.next_id,definition,vertices[i],vertices[(i+1)%24]);definition.entities<<e;model.lookup[e.persistent_id]=e;e
  end
  curve=Sketchup::ArcCurve.new;curve.center=ORIGIN;curve.normal=Y_AXIS;curve.radius=17.5.mm;curve.edges=edges;curve.first_edge=edges.first;edges.each{|e|e.curve=curve}
  attrs={'fuji_dict'=>{'sheet_id'=>identity}}
  group=Sketchup::Group.new({'id'=>model.next_id,'name'=>'','attrs'=>attrs,'definition'=>definition.persistent_id,'transform'=>[1,0,0,0,1,0,0,0,1,25.mm,-605.mm,z.mm,1]},parent,model.definitions)
  parent.entities<<group;model.lookup[group.persistent_id]=group;group
end

def seed_set(model,set)
  mode=set['mode']
  if %w[cut cont chain].include?(mode)
    layout=AD.compute_line(model,set)
    count=AD.replace_dims(model.entities,set,nil){AD.draw_line_set(model.entities,nil,set,layout)}
  else
    context=AD.ctx_entities(model,set['ctx']);selection=AD.resolve_sources(model,set).compact
    layout=mode=='obj' ? AD.compute_obj(selection,true) : AD.compute_layout(context,selection)
    count=AD.replace_dims(context,set,nil){mode=='obj' ? AD.draw_obj_dims(context,nil,layout,150.mm) : AD.layout_dims(context,nil,layout,150.mm)}
  end
  set['sig']=layout[:sig];set['ndim']=count;set['draw_fp']=AD.settings_fp
end

def anchor(model,root,part,point)
  vertex=part.entities.grep(Sketchup::Face).flat_map(&:vertices).uniq.find{|v|v.position.distance(point)<1e-8}
  raise 'fixture vertex not found' unless vertex
  world=root.transformation*(part.transformation*vertex.position)
  AD.make_anchor(model,Input.new(world,vertex,nil,0,[root,part]),world,true)
end

model=Sketchup::Model.new;model.definitions={};Sketchup.active_model=model
root=model.entities.add_group;root.name='Synthetic Cabinet'
left=create_box(model,root.definition,[0,-600,18].map(&:mm),[18,0,2400].map(&:mm),'left')
right=create_box(model,root.definition,[1182,-600,18].map(&:mm),[1200,0,2400].map(&:mm),'right')
bottom=create_box(model,root.definition,[0,-600,0].map(&:mm),[1200,0,18].map(&:mm),'bottom')
top=create_box(model,root.definition,[18,-600,2382].map(&:mm),[1182,-27,2400].map(&:mm),'top')
center=create_box(model,root.definition,[591,-600,18].map(&:mm),[609,-27,2382].map(&:mm),'divider')
shelf=create_box(model,root.definition,[609,-600,1100].map(&:mm),[1182,-27,1118].map(&:mm),'shelf')
door=create_box(model,root.definition,[0,-618,0].map(&:mm),[599.6,-600,2400].map(&:mm),'door')
door.name='Canh test'
holes=[100,800,1600,2300].map.with_index{|z,i|add_circle(model,door.definition,z,"hinge#{i}")}
obj={'id'=>'obj','ctx'=>0,'sel'=>[root.persistent_id],'sel_info'=>[AD.track_info(root)],'mode'=>'obj','pgid'=>38895}
std={'id'=>'std','ctx'=>0,'sel'=>[root.persistent_id],'sel_info'=>[AD.track_info(root)],'mode'=>'std','pgid'=>38895}
a=anchor(model,root,left,Geom::Point3d.new(18.mm,-600.mm,18.mm))
b=anchor(model,root,right,Geom::Point3d.new(1182.mm,-600.mm,18.mm))
cont={'id'=>'cont','mode'=>'cont','anchor_mode'=>'native','anchors'=>[a,b],'axis'=>[1,0,0],'od'=>[0,0,-1],'dm'=>[0,0,-150.mm],'perp'=>[0,0,1],'skip_mm'=>20,'gap'=>150,'cmode'=>'base','pgid'=>38895,'leg_policy'=>'settings'}
c0=anchor(model,root,top,Geom::Point3d.new(1182.mm,-600.mm,2400.mm))
c1=AD.world_anchor(root.transformation*Geom::Point3d.new(1182.mm,-600.mm,-10.mm))
cut={'id'=>'cut','mode'=>'cut','a0'=>c0,'a1'=>c1,'axis'=>[0,0,-1],'od'=>[1,0,0],'dm'=>[150.mm,0,0],'perp'=>[1,0,0],'skip_mm'=>20,'gap'=>150,'cmode'=>'base','pgid'=>38895,'leg_policy'=>'settings'}
[cont,cut].each{|s|AD.configure_live_set(model,s)}
check(cont['follow_surfaces'] && cont['scan_full_span'],'sourced new chain did not enable live topology')
sets=[obj,std,cont,cut];sets.each{|s|seed_set(model,s)};AD.save_sets(model,sets);AD.refresh_all(model,true)
values_close(measurements(model,obj),[1200,2400],'object base dimensions')
values_close(measurements(model,cont),[573,573],'chain current partitions')
values_close(measurements(model,cut),[1264,1082],'cut current shelves')
values_close(measurements(model,std),[599.6,100,700,800,700,100,2400],'door and hinge current geometry')
# Changing the part count while endpoint positions/bounds remain unchanged.
added=create_box(model,root.definition,[609,-600,500].map(&:mm),[1182,-27,518].map(&:mm),'extra')
AD.note_transaction(model);AD.refresh_all(model,false)
values_close(measurements(model,cut),[1264,582,482],'inserted shelf')
added.erase!;AD.note_transaction(model);AD.refresh_all(model,false)
values_close(measurements(model,cut),[1264,1082],'deleted shelf')
move_panel_z(shelf,100.mm);AD.note_transaction(model);AD.refresh_all(model,false)
values_close(measurements(model,cut),[1164,1182],'moved shelf')
# Rebuild an anchored part, with a new instance, definition, vertices and edges.
rebuilt_point=anchor(model,root,left,Geom::Point3d.new(18.mm,-600.mm,18.mm))
old_path=rebuilt_point['path'].dup
left.erase!
new_left=create_box(model,root.definition,[0,-600,18].map(&:mm),[18,0,2400].map(&:mm),'left')
resolved=AD.resolve_anchor(model,rebuilt_point)
check(resolved && rebuilt_point['path'].last==new_left.persistent_id && rebuilt_point['path']!=old_path,'semantic part rebind failed')
values_close(resolved.to_a.map{|v|v*25.4},[18,-600,18],'rebuilt point must be actual new vertex')
# Missing parts must not bind to a neighbouring part by a bbox proportion.
new_left.erase!
check(AD.resolve_anchor(model,rebuilt_point).nil?,'deleted semantic part drifted to neighbour')
AD.note_transaction(model);AD.refresh_all(model,false)
values_close(measurements(model,cont),[591,573],'deleted original endpoint part is rescanned from source section')
new_left=create_box(model,root.definition,[0,-600,18].map(&:mm),[18,0,2400].map(&:mm),'left')
AD.note_transaction(model);AD.refresh_all(model,false)
# Retarget selected object after identical-size regeneration, then resize it.
nested={'id'=>'nested','ctx'=>root.persistent_id,'sel'=>[new_left.persistent_id],'sel_info'=>[AD.track_info(new_left)],'mode'=>'obj','pgid'=>38895}
seed_set(model,nested);sets=AD.load_sets(model);sets<<nested;AD.save_sets(model,sets);AD.refresh_all(model,true)
new_left.erase!
replacement=create_box(model,root.definition,[0,-600,18].map(&:mm),[18,0,2400].map(&:mm),'left')
AD.note_transaction(model);AD.refresh_all(model,false)
# Same size yielded no redraw. Now geometry changes but saved old PID is still gone.
replacement.transformation=Geom::Transformation.new([1,0,0,0,1,0,0,0,1.1,0,0,0,1]);replacement.parent.entities.modified(replacement)
AD.note_transaction(model);AD.refresh_all(model,false)
values_close(measurements(model,nested),[600,2620.2],'rebound object fingerprint follows later edits')
# Native annotation bounds inside cabinet must not enlarge measured geometry.
physical=AD.physical_bounds(root,model)
values_close(measurements(model,obj),[physical.width*25.4,physical.depth*25.4],'nested DIM excluded from object bounds')
# Two matching semantic IDs are ambiguous and must never be guessed.
create_box(model,root.definition,[0,-600,18].map(&:mm),[18,0,2400].map(&:mm),'left')
ambiguous=Marshal.load(Marshal.dump(rebuilt_point));ambiguous['path']=old_path
check(AD.resolve_anchor(model,ambiguous).nil?,'ambiguous semantic match was guessed')
# Move and remove a hinge, exercising the real geometry fingerprint and renderer.
hole=holes.last
hole.transformation=Geom::Transformation.new([1,0,0,0,1,0,0,0,1,0,0,-50.mm,1])*hole.transformation;hole.parent.entities.modified(hole)
AD.note_transaction(model);AD.refresh_all(model,false)
values_close(measurements(model,std),[599.6,150,650,800,700,100,2400],'hinge moved')
hole.erase!;AD.note_transaction(model);AD.refresh_all(model,false)
values_close(measurements(model,std),[599.6,800,800,700,100,2400],'hinge removed')
extra_hole=add_circle(model,door.definition,2000,'new-hinge');AD.note_transaction(model);AD.refresh_all(model,false)
values_close(measurements(model,std),[599.6,400,400,800,700,100,2400],'hinge added')
# Explicit manual dimensions must be preserved, and stale HP labels detected.
manual=model.entities.add_dimension_linear(ORIGIN,Geom::Point3d.new(100.mm,0,0),Geom::Vector3d.new(0,10.mm,0))
current=AD.load_sets(model).find{|s|s['id']=='cont'}
check(AD.verify_set(model,current)==:ok,'audit failed on correct current DIM')
dimensions(model,cont).first.text='9999'
check(AD.verify_set(model,current)==:mismatch,'audit missed stale custom text')
AD.refresh_all(model,true)
check(manual.valid? && manual.text=='' && (manual.measurement-100.mm).abs<1e-8,'manual dimension changed')
# Physical dimensions, selected source tags, and annotation ownership stay intact.
check(root.attributes['HP_AutoDim'].nil?,'source root acquired HP ownership')
puts "PASS #{@checks} synthetic geometry/render/refresh/verification assertions covering all four DIM types."
# Clean up the deliberately ambiguous duplicate and exercise scaled/transformed source.
root.entities.grep(Sketchup::Group).select{|g|AD.part_identity(g)&.fetch('value',nil)=='left' && g!=replacement}.each(&:erase!)
root.transformation=Geom::Transformation.new([0.8,0,0,0,1,0,0,0,1.25,100.mm,50.mm,25.mm,1])
model.entities.modified(root);AD.note_transaction(model);AD.refresh_all(model,false)
values_close(measurements(model,obj),[960,3300],'nonuniform scale and source translation: object')
values_close(measurements(model,cont),[458.4,458.4],'nonuniform scale and source translation: live chain')
values_close(measurements(model,cut),[22.5,1455,22.5,1477.5,22.5],'nonuniform scale and source translation: cut')
values_close(measurements(model,std),[479.68,500,500,1000,875,125,3000],'nonuniform scale and source translation: doors/centers')
AD.load_sets(model).each{|s|check(AD.verify_set(model,s)==:ok,"audit after scale: #{s['mode']}")}
# A transient native rendering error must preserve the old drawing, report it,
# and retry on the next update even if geometry has not changed again.
class Sketchup::Entities
  class << self;attr_accessor :fail_dimension_once;end
  alias successful_add_dimension_linear add_dimension_linear
  def add_dimension_linear(*args)
    if self.class.fail_dimension_once
      self.class.fail_dimension_once=false
      raise 'injected one-shot native dimension failure'
    end
    successful_add_dimension_linear(*args)
  end
end
Sketchup::Entities.fail_dimension_once=true
move_panel_z(shelf,10.mm);AD.note_transaction(model);AD.refresh_all(model,false)
values_close(measurements(model,cut),[22.5,1455,22.5,1477.5,22.5],'failed staging preserves old cut DIM')
AD.refresh_all(model,false)
values_close(measurements(model,cut),[22.5,1442.5,22.5,1490,22.5],'same geometry retries after transient render failure')
# A failure in in-place object updates must restore both endpoints and labels.
class Sketchup::DimensionLinear
  class << self;attr_accessor :fail_start_once;end
  alias successful_start= start=
  def start=(point)
    if self.class.fail_start_once
      self.class.fail_start_once=false
      raise 'injected one-shot endpoint setter failure'
    end
    self.successful_start=point
  end
end
Sketchup::DimensionLinear.fail_start_once=true
root.transformation=Geom::Transformation.new([0.9,0,0,0,1,0,0,0,1.25,100.mm,50.mm,25.mm,1])
model.entities.modified(root);AD.note_transaction(model);AD.refresh_all(model,false)
values_close(measurements(model,obj),[960,3300],'failed in-place object update restores previous measurements')
AD.refresh_all(model,false)
values_close(measurements(model,obj),[1080,3300],'object retries failed in-place update')
puts "PASS #{@checks} total synthetic assertions including nonuniform Scale, source moves, transient native failures and retry safety."
# A manual dimension drawn inside an HP group is not permission to erase it.
set=AD.load_sets(model).find{|s|s['id']=='cont'}
group=AD.dim_items(model.entities,set['id']).first
inside_manual=group.entities.add_dimension_linear(ORIGIN,Geom::Point3d.new(40.mm,0,0),Geom::Vector3d.new(0,10.mm,0))
check(AD.dim_set_state(model,set)==:edited,'manual additions inside HP group not detected')
AD.erase_dims(model.entities,set['id'])
check(group.valid? && inside_manual.valid?,'clearing HP DIM erased manually drawn dimension inside group')
check(group.get_attribute(AD::PLUGIN_ID,'set',nil).nil?,'mixed-content group retained HP deletion ownership')
puts "PASS #{@checks} assertions including protection for manual dimensions inside an HP group."
# Visibility uses the supported native raytest method and applies to true hits.
class Sketchup::Model
  attr_accessor :test_occluder
  def raytest(ray,_visible);test_occluder ? [ray.first+ray.last*1.0,[]] : nil;end
end
camera={eye:Geom::Point3d.new(0,-100,0),dir:Y_AXIS,persp:false}
model.test_occluder=true
check(!AD.visible_from_cam?(model,ORIGIN,camera),'visible-only ignored native occlusion')
source_set=AD.load_sets(model).find{|s|s['id']=='cut'}
first=AD.resolve_anchor(model,source_set['a0']);last=AD.resolve_anchor(model,source_set['a1']);axis=Geom::Vector3d.new(*source_set['axis'])
first,last=AD.scan_span(model,source_set,first,last,axis)
check(AD.cut_hits(model,first,last,camera,'base',true,source_set['scan_source_pid']).empty?,'hidden true intersections still included')
model.test_occluder=false
check(!AD.cut_hits(model,first,last,camera,'base',true,source_set['scan_source_pid']).empty?,'visible true intersections missing')
# Correct normal math under nonuniform transforms: normal stays perpendicular.
t=Geom::Transformation.new([2,0,0,0,1,0,0,0,0.5,0,0,0,1]);n=Geom::Vector3d.new(1,1,0).normalize
transformed=AD.transformed_normal(t,n);tangent=t*Geom::Vector3d.new(1,-1,0)
check(transformed.dot(tangent).abs<1e-8,'normal used vector transform instead of inverse transpose')
puts "PASS #{@checks} total assertions including visible-only native API use and transformed hole normals."
# Removing every named door must produce zero door DIM, not DIM the cabinet
# as though the whole box had become a new door; later doors must reappear.
door.erase!;AD.note_transaction(model);AD.refresh_all(model,false)
values_close(measurements(model,std),[],'all doors removed: no stale door or cabinet-as-door DIM')
empty=AD.load_sets(model).find{|s|s['id']=='std'}
check(empty && empty['ndim']==0 && empty['allow_empty'],'empty named-door set lost live tracking')
new_door=create_box(model,root.definition,[0,-618,0].map(&:mm),[599.6,-600,2400].map(&:mm),'new-door')
new_door.name='Canh new';AD.note_transaction(model);AD.refresh_all(model,false)
values_close(measurements(model,std),[539.64,3000],'new door after empty state is measured automatically')
puts "PASS #{@checks} total assertions, including zero-door state and regeneration after doors are added again."
# Rotation binds measurement directions to the source, instead of projecting
# a rotated cabinet onto a stale world X/Z axis.
root.transformation=Geom::Transformation.new([0,0.9,0,-1,0,0,0,0,1.25,100.mm,50.mm,25.mm,1])
model.entities.modified(root);AD.note_transaction(model);AD.refresh_all(model,false)
values_close(measurements(model,obj),[1080,3300],'rotated cabinet object dimensions')
values_close(measurements(model,cut),[22.5,1442.5,22.5,1490,22.5],'rotated cabinet cut follows local axis/side')
# Recreate the deliberately released horizontal chain to test its live frame.
seed_set(model,cont);saved=AD.load_sets(model).reject{|s|s['id']==cont['id']};saved<<cont;AD.save_sets(model,saved)
values_close(measurements(model,cont),[515.7,515.7],'rotated cabinet chain follows source local direction')
# Independent projected-vertex regression remains correct in root/free geometry.
vertex=Sketchup::Vertex.new(model.next_id,model,[1000.mm,50.mm,0]);model.lookup[vertex.persistent_id]=vertex
projected=AD.make_anchor(model,Input.new(vertex.position,vertex,nil,0,[]),Geom::Point3d.new(1000.mm,0,0),true)
vertex.position=Geom::Point3d.new(1400.mm,50.mm,0)
values_close(AD.resolve_anchor(model,projected).to_a.map{|v|v*25.4},[1400,0,0],'projected pick retains original vertex linkage')
puts "PASS #{@checks} total assertions, including source rotation and projected vertex updates."
# Selected semantic object removed completely -> zero DIM; a replacement with
# the same unique logical identity becomes measurable again automatically.
replacement.erase!;AD.note_transaction(model);AD.refresh_all(model,false)
values_close(measurements(model,nested),[],'deleted selected semantic object removes its owned dimensions')
empty_obj=AD.load_sets(model).find{|s|s['id']=='nested'}
check(empty_obj && empty_obj['allow_empty'] && AD.verify_set(model,empty_obj)==:ok,'known-empty object cannot be verified')
replacement2=create_box(model,root.definition,[0,-600,18].map(&:mm),[18,0,2400].map(&:mm),'left')
AD.note_transaction(model);AD.refresh_all(model,false)
values_close(measurements(model,nested),[600,2382],'same logical object recreated after zero-object state')
check(AD.load_sets(model).flat_map{|s|dimensions(model,s)}.all?{|d|d.text.empty?},'numeric override can freeze native dimension display')
puts "PASS #{@checks} total assertions, including selected-object deletion/recreation and native measurement labels."
# Scene switches invalidate old visibility fingerprints and request a deferred
# update, without parsing sets or scanning geometry in the idle poll itself.
class Sketchup::Page
  def initialize(id=38895);@id=id;end
  def persistent_id;@id;end
end
class Sketchup::Pages
  attr_writer :selected_page
  def selected_page;@selected_page || first;end
end
module UI
  def self.start_timer(_delay,_repeat,&block);@timer_count=(@timer_count||0)+1;@timers||={};@timers[@timer_count]=block;@timer_count;end
  def self.stop_timer(id);(@timers||={}).delete(id);end
end
class Sketchup::Model
  attr_accessor :attribute_reads
  alias counted_get_attribute get_attribute
  def get_attribute(*args);self.attribute_reads=(attribute_reads||0)+1;counted_get_attribute(*args);end
end
state=AD.runtime(model);state[:last_page]=38895;state[:pending]=false;state[:timer]=nil
state[:fp_cache]['old-scene']=true;model.attribute_reads=0
model.pages.selected_page=Sketchup::Page.new(38896)
AD.poll
check(state[:last_page]==38896 && state[:pending] && state[:timer],'scene switch did not queue deferred refresh')
check(state[:fp_cache].empty?,'scene switch kept previous visibility fingerprint')
check(model.attribute_reads==0,'idle scene detector parsed model data before deferred update')
puts "PASS #{@checks} total assertions including scene-switch refresh scheduling without idle geometry/JSON scans."
# Recess tolerance must follow depth, not borrow a shortened shelf from a
# neighbouring horizontal position merely because it lies within 150mm.
model.pages.selected_page=Sketchup::Page.new(38895)
before=measurements(model,cut)
short_panel=create_box(model,root.definition,[609,-600,1800].map(&:mm),[1060,-27,1818].map(&:mm),'short-of-measuring-edge')
AD.note_transaction(model);AD.refresh_all(model,false)
values_close(measurements(model,cut),before,'nearby panel missing the measurement plane is excluded')
short_panel.erase!
recessed=create_box(model,root.definition,[609,-560,1800].map(&:mm),[1182,-27,1818].map(&:mm),'true-recessed-shelf')
AD.note_transaction(model);AD.refresh_all(model,false)
values_close(measurements(model,cut),[22.5,705,22.5,715,22.5,1490,22.5],'true shelf set back in depth is included within tolerance')
puts "PASS #{@checks} total assertions, including cross-bay rejection and actual recessed-shelf inclusion."
# Preview stores geometry on point confirmation; per-frame draw does not rescan.
Camera=Struct.new(:eye,:direction) do
  def perspective?;false;end
end
View=Struct.new(:model,:camera) do
  attr_accessor :line_stipple,:line_width,:drawing_color
  def draw_points(*);end
end
view=View.new(model,Camera.new(Geom::Point3d.new(0,-100,0),Y_AXIS))
tool=AD::HPChainTool.allocate
points=cont['anchors'].map{|a|{anchor:a,pos:AD.resolve_anchor(model,a)}}
axis=AD.measuring_direction(model,cont,'axis');offset=AD.measuring_direction(model,cont,'od')
tool.instance_variable_set(:@pts,points);tool.instance_variable_set(:@axis,axis);tool.instance_variable_set(:@od,offset)
tool.instance_variable_set(:@off,AD.sc(offset,150.mm));tool.instance_variable_set(:@legs,AD.sc(offset,15.mm))
tool.instance_variable_set(:@gap_mm,150);tool.instance_variable_set(:@leg_policy,'settings');tool.instance_variable_set(:@phase,:place)
tool.prepare_topology_preview(view)
preview=tool.instance_variable_get(:@topology_preview)
check(preview && !preview[:segs].empty?,'confirmed chain preview has no dynamic geometry')
original_compute=AD.method(:compute_line);original_preview=AD.method(:draw_segments_preview)
captured=nil
AD.define_singleton_method(:compute_line){|*|raise 'geometry scan from draw callback'}
AD.define_singleton_method(:draw_segments_preview){|_view,line,_skip|captured=line}
tool.draw(view)
check(captured && captured[:segs]==preview[:segs],'draw did not use cached confirmed geometry')
AD.define_singleton_method(:compute_line,original_compute);AD.define_singleton_method(:draw_segments_preview,original_preview)
check(captured[:off].length>0 && captured[:legs].length>0,'preview lost witness layout')
puts "PASS #{@checks} total assertions including cached dynamic preview without per-frame geometry scans."
# Definition identity matters even when its name, instance PID and revision
# counter match a previous definition: cache entries cannot cross definitions.
AD.physical_bounds(root,model)
new_body=create_box(model,root.definition,[0,-600,18].map(&:mm),[18,0,2600].map(&:mm),'replacement-definition-test')
new_definition=new_body.definition
new_body.erase!
replacement2.definition=new_definition
AD.note_transaction(model)
values_close([AD.physical_bounds(root,model).depth*25.4],[3250],'same-name definition replacement invalidates physical bounds cache')
puts "PASS #{@checks} total geometry/render/update/verification assertions."
