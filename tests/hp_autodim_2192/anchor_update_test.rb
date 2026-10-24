# Lightweight native API substitute. Exercises the shipped anchor methods and
# compute_line directly; no duplicated anchor resolution implementation.
module Geom
  class Vector3d
    attr_accessor :x,:y,:z
    def initialize(x=0,y=0,z=0);@x,@y,@z=x.to_f,y.to_f,z.to_f;end
    def [](i);[x,y,z][i];end
    def +(v);self.class.new(x+v.x,y+v.y,z+v.z);end
    def -(v);Vector3d.new(x-v.x,y-v.y,z-v.z);end
    def *(n);Vector3d.new(x*n,y*n,z*n);end
    def dot(v);x*v.x+y*v.y+z*v.z;end
    def length;Math.sqrt(dot(self));end
    def normalize;self*(1.0/length);end
    def distance(v);(self-v).length;end
  end
  class Point3d < Vector3d;end
  class Transformation
    def initialize(scale=1,offset=0);@scale,@offset=scale,offset;end
    def *(value)
      return value.compose(@scale,@offset) if value.is_a?(Transformation)
      Point3d.new(value.x*@scale+@offset,value.y,value.z)
    end
    def compose(scale,offset);Transformation.new(@scale*scale,@offset*scale+offset);end
    def inverse;Transformation.new(1.0/@scale,-@offset/@scale);end
  end
end
class Bounds
  attr_accessor :min,:max
  def initialize(width);@min,@max=Geom::Point3d.new,Geom::Point3d.new(width,100,100);end
  def empty?;false;end
end
module Sketchup
  class EntitiesObserver;end
  class DefinitionsObserver;end
  class LayersObserver;end
  class ComponentInstance
    attr_accessor :parent,:definition,:transformation
    attr_reader :persistent_id
    def initialize(id,parent,definition);@persistent_id,@parent,@definition=id,parent,definition;@transformation=Geom::Transformation.new;end
    def valid?;true;end
  end
  class Group < ComponentInstance;end
end
class Vertex
  attr_accessor :parent,:position,:valid
  attr_reader :persistent_id
  def initialize(id,parent,x,y=0);@persistent_id,@parent,@position,@valid=id,parent,Geom::Point3d.new(x,y),true;end
  def valid?;@valid;end
end
class Edge
  attr_accessor :parent,:start,:end
  attr_reader :persistent_id
  def initialize(id,parent,a,b);@persistent_id,@parent,@start,@end=id,parent,a,b;end
  def valid?;true;end
end
Definition=Struct.new(:bounds,:entities)
Model=Struct.new(:entities,:lookup)
Input=Struct.new(:position,:vertex,:edge,:degrees_of_freedom,:instance_path)
module Zlib
  def self.crc32(s);s.hash;end
end
module HP
  module AutoDim
    MM=1.0
    IDENTITY_TR=Geom::Transformation.new
    def self.entity_by_pid(model,pid);model.lookup[pid];end
    def self.inst_product(instances);instances.reduce(IDENTITY_TR){|tr,i|tr*i.transformation};end
    def self.trk_for(*);nil;end
    def self.resolve_by_trk(model,anchor);anchor['trk'] && anchor['trk']['resolved'];end
    def self.log_once(message);raise message;end
    def self.world_anchor(pos,*);{'p'=>[pos.x,pos.y,pos.z],'path'=>[]};end
    def self.sc(v,n);v*n;end
    def self.adjust_by_surfaces(_model,_set,points,_axis);points;end
    def self.leg_spec(*);[150,nil,true];end
    def self.point_off_legs(*);[Geom::Vector3d.new(0,150),Geom::Vector3d.new(0,15)];end
    def self.settings_fp;'settings';end
    def self.point_fp(p);[p.x,p.y,p.z];end
    def self.shift_line_row(line,_mm);line;end
  end
end
root=File.expand_path('../../src/hp_auto_dim_2.19.2/hp_auto_dim',__dir__)
if ARGV.include?('--baseline-2.19.1')
  old = File.read(File.expand_path('../../src/hp_auto_dim_2.19.1/hp_auto_dim/main.rb',__dir__))
  a = old.index('    def self.resolve_bound'); b = old.index('    def self.world_anchor',a)
  HP::AutoDim.module_eval(old[a...b])
  a = old.index('    def self.make_anchor'); b = old.index('    # ================= Dim liên tiếp / Dim cắt',a)
  HP::AutoDim.module_eval(old[a...b])
else
  load File.join(root,'anchors.rb')
end
source=File.read(File.join(root,'main.rb'))
a=source.index('    def self.cont_segments');b=source.index('    def self.draw_line_set',a)
HP::AutoDim.module_eval(source[a...b],File.join(root,'main.rb'))
def close(a,b);raise "#{a} != #{b}" unless (a-b).abs<1e-6;end
hp=HP::AutoDim
model=Model.new([], {})
vertex=Vertex.new(1,model,1000,50);model.lookup[1]=vertex
# Reproduce a picked vertex projected to the measurement axis: 50mm off-axis.
anchor=hp.make_anchor(model,Input.new(vertex.position,vertex,nil,0,[]),Geom::Point3d.new(1000,0),true)
raise 'projection lost source binding' unless anchor['v']==1
close(hp.resolve_anchor(model,anchor).y,0)
vertex.position=Geom::Point3d.new(1500,50)
close(hp.resolve_anchor(model,anchor).x,1500)
# Mid-edge source follows edited endpoints, retaining projection.
a=Vertex.new(2,model,0,50);b=Vertex.new(3,model,1000,50)
edge=Edge.new(4,model,a,b);model.lookup[4]=edge
mid=hp.make_anchor(model,Input.new(Geom::Point3d.new(500,50),nil,edge,1,[]),Geom::Point3d.new(500,0),true)
b.position=Geom::Point3d.new(2000,50)
close(hp.resolve_anchor(model,mid).x,1000)
close(hp.resolve_anchor(model,mid).y,0)
# Group scale and internal Push/Pull, followed by Make Unique: old vertex is
# still valid globally but belongs to another definition and MUST be rejected.
definition=Definition.new(Bounds.new(1000),[])
group=Sketchup::Group.new(10,model,definition);model.lookup[10]=group
v=Vertex.new(11,definition,1000);model.lookup[11]=v
nested=hp.make_anchor(model,Input.new(v.position,v,nil,0,[group]),v.position,true)
group.transformation=Geom::Transformation.new(1.5,25)
close(hp.resolve_anchor(model,nested).x,1525)
v.position=Geom::Point3d.new(1200);definition.bounds=Bounds.new(1200)
close(hp.resolve_anchor(model,nested).x,1825)
group.definition=Definition.new(Bounds.new(2000),[])
raise 'stale definition accepted' if hp.resolve_bound(model,nested)
close(hp.resolve_anchor(model,nested).x,3025)
# Existing old-format anchors can use their original root tracking fallback.
old=nested.dup;old.delete('local_ratio');old['trk']={'resolved'=>Geom::Point3d.new(3025)}
close(hp.resolve_anchor(model,old).x,3025)
# Losing a source cannot silently reuse its old p/w and claim success.
model.lookup.delete(1)
raise 'stale world fallback' unless hp.resolve_anchor(model,anchor).nil?
# The actual shipped compute_line must measure the new resolved endpoint.
model.lookup[1]=vertex
start=Vertex.new(20,model,0,50);model.lookup[20]=start
first=hp.make_anchor(model,Input.new(start.position,start,nil,0,[]),Geom::Point3d.new(0),true)
set={'mode'=>'cont','anchors'=>[first,anchor],'axis'=>[1,0,0],'od'=>[0,1,0],'dm'=>[0,150,0],'perp'=>[0,0,1]}
line=hp.compute_line(model,set)
close(line[:segs].first[:len],1500)
vertex.position=Geom::Point3d.new(1800,50)
changed=hp.compute_line(model,set)
close(changed[:segs].first[:len],1800)
raise 'unchanged signature' if changed[:sig]==line[:sig]
puts 'PASS: projected vertex/edge resize, group Scale, internal edit, Make Unique, legacy fallback, lost-source rejection, actual compute_line length/signature'
# Exercise the real refresh_all orchestration with native rendering mocked only
# at its boundary. The real compute_line/anchor methods above remain in use.
class Numeric
  def mm; self; end
end
module JSON
  def self.generate(value);Marshal.dump(value);end
  def self.parse(value);Marshal.load(value);end
end
module Sketchup
  class << self;attr_accessor :status_text;end
end
class Model
  attr_accessor :saved_sets,:rendered_lengths,:operations
  def get_attribute(*);JSON.generate(saved_sets);end
  def start_operation(*);self.operations=(operations||0)+1;end
  def commit_operation;end
  def abort_operation;raise 'unexpected abort';end
end
module HP
  module AutoDim
    PLUGIN_ID='HP_AutoDim'
    class AutoBudgetExceeded < StandardError;end
    def self.runtime(model)
      @states||={};@states[model.object_id]||={fp_cache:{},geometry_cache:{},slow_sets:{},pid_cache:{},regions:{}}
    end
    def self.check_auto_budget!;end
    def self.background_busy?(*);false;end
    def self.load_sets(model);model.saved_sets;end
    def self.save_sets(model,sets);model.saved_sets=sets;end
    def self.prune_watchers(*);end
    def self.current_pgid(*);1;end
    def self.update_eligible?(set,page);set['pgid']==page;end
    def self.set_pids(*);[];end
    def self.entities_by_pid(*);{};end
    def self.dim_set_state(*);:ok;end
    def self.set_fp(model,set)
      set['anchors'].map{|a|p=resolve_anchor(model,a);p && [p.x,p.y,p.z]}.hash
    end
    def self.remember_region(*);end
    def self.offset_mm;150;end
    def self.leave_hp_groups(*);end
    def self.tag_for(*);nil;end
    def self.replace_dims(*);yield;end
    def self.draw_line_set(_entities,_tag,_set,line)
      @test_model.rendered_lengths=line[:segs].map{|s|s[:len]};line[:segs].size
    end
    def self.record_time(*);end
  end
end
a=source.index('    def self.refresh_all');b=source.index('    # ---- kiểm tra định kỳ',a)
hp.module_eval(source[a...b])
set.merge!('id'=>'regression','pgid'=>1,'sig'=>changed[:sig],'ndim'=>1,'draw_fp'=>'settings')
model.saved_sets=[set];hp.instance_variable_set(:@test_model,model)
# Background update sees new geometry (1800 -> 2000).
vertex.position=Geom::Point3d.new(2000,50)
hp.refresh_all(model,false)
close(model.rendered_lengths.first,2000)
# No geometry change: cached fingerprint avoids another render/operation.
count=model.operations
hp.refresh_all(model,false)
raise 'unneeded operation' unless count==model.operations
# Explicit refresh must work even if cached and must clear stale lookup state.
vertex.position=Geom::Point3d.new(2200,50)
hp.runtime(model)[:pid_cache][:stale]=true
hp.refresh_all(model,true)
close(model.rendered_lengths.first,2200)
raise 'manual cache not cleared' unless hp.runtime(model)[:pid_cache].empty?
# Missing source preserves previous drawing and reports failure, not false success.
model.lookup.delete(1)
hp.refresh_all(model,true)
close(model.rendered_lengths.first,2200)
raise 'no failure status' unless Sketchup.status_text.include?('chưa cập nhật')
puts 'PASS: actual refresh_all auto/manual updates, unchanged-cache skip, explicit cache reset, lost-source preservation/status'
# Object DIM: run shipped bounds/layout and drawing specs, checking the
# numerical endpoints passed to native add_dimension_linear.
module Sketchup;class Face;end;end
module HP
  module AutoDim
    def self.leg_mm;15;end
    def self.dim(_entities,_tag,a,b,_offset)
      (@object_lengths||=[]) << a.distance(b);1
    end
  end
end
a=source.index('    def self.box_of');b=source.index('    # Trục toàn cục',a)
hp.module_eval(source[a...b])
a=source.index('    def self.obj_items');b=source.index('    def self.run_obj',a)
hp.module_eval(source[a...b])
group.definition=Definition.new(Bounds.new(1000),[])
layout=hp.compute_obj([group],false)
hp.instance_variable_set(:@object_lengths,[])
hp.draw_obj_dims([],nil,layout,150)
close(hp.instance_variable_get(:@object_lengths).first,1500)
group.definition.bounds=Bounds.new(1200)
resized=hp.compute_obj([group],false)
hp.instance_variable_set(:@object_lengths,[])
hp.draw_obj_dims([],nil,resized,150)
close(hp.instance_variable_get(:@object_lengths).first,1800)
raise 'object signature stale' if layout[:sig]==resized[:sig]
puts 'PASS: actual object layout/drawing endpoints track Scale and internal bounds changes'
