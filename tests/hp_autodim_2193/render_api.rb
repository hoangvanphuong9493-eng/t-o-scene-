# Native storage/observer boundary substitute. Production refresh/render methods
# are loaded unchanged; changes are kept in this isolated in-memory test model.
module Sketchup
  def self.format_length(value);format('%.3f',value*25.4);end
  class Entity
    attr_writer :layer
    def valid?;!@erased;end
    def delete_attribute(dict,key);(@attributes[dict]||{}).delete(key);end
    def erase!
      parent.entities.delete(self) if parent.respond_to?(:entities)
      @erased=true
    end
  end
  class Layer
    def name;'Test DIM';end
    def persistent_id;1;end
    def get_attribute(*);nil;end
    def set_attribute(*);end
  end
  class DimensionLinear
    TEXT_OUTSIDE_START=1;TEXT_OUTSIDE_END=2;TEXT_CENTERED=0;ALIGNED_TEXT_ABOVE=0
    attr_accessor :offset_vector,:text,:text_position,:aligned_text_position
    def initialize(id,parent,a,b,offset)
      super(id,parent);@a,@b,@offset_vector=a,b,offset;@text='';@text_position=0;@aligned_text_position=0
    end
    def start;[nil,@a];end
    def end;[nil,@b];end
    def start=(point);raise 'Expected Point3d' unless point.is_a?(Geom::Point3d);@a=point;end
    def end=(point);raise 'Expected Point3d' unless point.is_a?(Geom::Point3d);@b=point;end
    def has_aligned_text?;false;end
    def measurement;@a.distance(@b);end
    def bounds;Geom::BoundingBox.new.add(@a,@b,@a+offset_vector,@b+offset_vector);end
  end
  class ComponentDefinition
    def instances;@instances||=[];end
  end
  class ComponentInstance
    alias geometry_initialize initialize
    def initialize(*args)
      geometry_initialize(*args);definition.instances<<self
    end
    def entities;definition.entities;end
  end
  class Entities
    def add_observer(observer);(@observers||=[])<<observer;true;end
    def remove_observer(observer);(@observers||=[]).delete(observer);end
    def <<(entity)
      super(entity);(@observers||=[]).each{|o|o.onElementAdded(self,entity) if o.respond_to?(:onElementAdded)};self
    end
    def delete(entity)
      result=super(entity);(@observers||=[]).each{|o|o.onElementRemoved(self,entity.persistent_id) if o.respond_to?(:onElementRemoved)};result
    end
    def modified(entity)
      (@observers||=[]).each{|o|o.onElementModified(self,entity) if o.respond_to?(:onElementModified)}
    end
    def erase_entities(items);items.each(&:erase!);end
    def add_group
      model=Sketchup.active_model;id=model.next_id;definition=ComponentDefinition.new(id,'Generated')
      model.definitions[id]=definition
      group=Group.new({'id'=>model.next_id,'name'=>'','attrs'=>{},'definition'=>id,'transform'=>nil},parent,model.definitions)
      self<<group;model.lookup[group.persistent_id]=group;group
    end
    def add_dimension_linear(a,b,offset)
      model=Sketchup.active_model;dimension=DimensionLinear.new(model.next_id,parent,a,b,offset);self<<dimension;model.lookup[dimension.persistent_id]=dimension;dimension
    end
  end
  class Page
    def persistent_id;38895;end
  end
  class Pages < Array
    def selected_page;first;end
  end
  class Model
    def next_id;@counter=(@counter||1000000)+1;end
    def attributes;@attrs||={};end
    def get_attribute(dict,key,default=nil);(attributes[dict]||{}).fetch(key,default);end
    def set_attribute(dict,key,value);(attributes[dict]||={})[key]=value;end
    def active_path;nil;end
    def active_entities;entities;end
    def pages;@pages||=Pages.new([Page.new]);end
    def valid?;true;end
    def start_operation(*);@operations=(@operations||0)+1;end
    def commit_operation;end
    def abort_operation;raise 'unexpected abort in test boundary';end
  end
end

def create_box(model,parent,min,max,identity)
  definition=Sketchup::ComponentDefinition.new(model.next_id,'Synthetic panel')
  definition.set_attribute('fuji_dict','sheet_id',identity)
  model.definitions[definition.persistent_id]=definition
  vertices=8.times.map do |i|
    p=3.times.map{|a|(i&(1<<a))==0 ? min[a] : max[a]}
    v=Sketchup::Vertex.new(model.next_id,definition,p);model.lookup[v.persistent_id]=v;v
  end
  rings=[[0,2,6,4],[1,5,7,3],[0,4,5,1],[2,3,7,6],[0,1,3,2],[4,6,7,5]]
  edge_map={}
  rings.each do |ring|
    edges=ring.each_with_index.map do |vi,i|
      key=[vi,ring[(i+1)%4]].sort
      edge_map[key]||=begin
        e=Sketchup::Edge.new(model.next_id,definition,vertices[key[0]],vertices[key[1]])
        definition.entities<<e;model.lookup[e.persistent_id]=e;e
      end
    end
    f=Sketchup::Face.new(model.next_id,definition)
    points=ring.map{|i|vertices[i]};normal=(points[1].position-points[0].position).cross(points[2].position-points[0].position).normalize
    f.plane=normal.to_a+[-normal.dot(points.first.position)]
    f.loops=[Sketchup::Loop.new(points,edges,true)];definition.entities<<f;model.lookup[f.persistent_id]=f
  end
  row={'id'=>model.next_id,'name'=>'','attrs'=>{'fuji_dict'=>{'sheet_id'=>identity}},'definition'=>definition.persistent_id,'transform'=>nil}
  group=Sketchup::Group.new(row,parent,model.definitions);parent.entities<<group;model.lookup[group.persistent_id]=group;group
end

def move_panel_z(panel,delta)
  vertices=panel.entities.grep(Sketchup::Face).flat_map(&:vertices).uniq
  vertices.each{|v|v.position=Geom::Point3d.new(v.position.x,v.position.y,v.position.z+delta)}
  panel.entities.grep(Sketchup::Face).each do |face|
    normal=face.normal;face.plane=normal.to_a+[-normal.dot(face.vertices.first.position)];panel.entities.modified(face)
  end
end
