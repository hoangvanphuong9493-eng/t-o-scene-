# Standalone geometry substitute for numerical tests. This is NOT SketchUp.
class Numeric
  def mm; to_f/25.4; end
end
module Geom
  class Vector3d
    attr_accessor :x,:y,:z
    def initialize(x=0,y=0,z=0);@x,@y,@z=x.to_f,y.to_f,z.to_f;end
    def [](i);[x,y,z][i];end
    def to_a;[x,y,z];end
    def +(v);self.class.new(x+v.x,y+v.y,z+v.z);end
    def -(v);Vector3d.new(x-v.x,y-v.y,z-v.z);end
    def *(n);Vector3d.new(x*n,y*n,z*n);end
    def dot(v);x*v.x+y*v.y+z*v.z;end
    def cross(v);Vector3d.new(y*v.z-z*v.y,z*v.x-x*v.z,x*v.y-y*v.x);end
    def length;Math.sqrt(dot(self));end
    def normalize;self*(1.0/length);end
    def distance(v);(self-v).length;end
    def transform(t);t*self;end
  end
  class Point3d < Vector3d
    def -(v)
      klass=v.is_a?(Point3d) ? Vector3d : Point3d
      klass.new(x-v.x,y-v.y,z-v.z)
    end
  end
  class Transformation
    def initialize(values=nil)
      @v=values || [1,0,0,0,1,0,0,0,1,0,0,0,1]
      @v=[@v[0],@v[1],@v[2],@v[4],@v[5],@v[6],@v[8],@v[9],@v[10],@v[12],@v[13],@v[14],@v[15]] if @v.size==16
    end
    def xaxis;Vector3d.new(*@v[0,3]);end
    def yaxis;Vector3d.new(*@v[3,3]);end
    def zaxis;Vector3d.new(*@v[6,3]);end
    def origin;Point3d.new(*@v[9,3]);end
    def *(value)
      if value.is_a?(Transformation)
        cols=[self*value.xaxis,self*value.yaxis,self*value.zaxis,self*value.origin]
        return Transformation.new(cols.flat_map(&:to_a)+[1])
      end
      xyz=3.times.map{|i|@v[i]*value.x+@v[i+3]*value.y+@v[i+6]*value.z+(value.is_a?(Point3d) ? @v[i+9] : 0)}
      value.class.new(*xyz)
    end
    def inverse
      a,b,c=xaxis,yaxis,zaxis;det=a.dot(b.cross(c));rows=[b.cross(c)*(1/det),c.cross(a)*(1/det),a.cross(b)*(1/det)]
      out=Transformation.new(3.times.flat_map{|i|rows.map{|r|r[i]}}+[0,0,0,1])
      offset=out*(Vector3d.new(*@v[9,3])*(-1))
      Transformation.new(3.times.flat_map{|i|rows.map{|r|r[i]}}+offset.to_a+[1])
    end
    def to_a;[@v[0],@v[1],@v[2],0,@v[3],@v[4],@v[5],0,@v[6],@v[7],@v[8],0,@v[9],@v[10],@v[11],@v[12]];end
  end
  class BoundingBox
    def initialize;@points=[];end
    def add(*points);@points.concat(points.flatten);self;end
    def empty?;@points.empty?;end
    def min;Point3d.new(*3.times.map{|i|@points.map{|p|p[i]}.min});end
    def max;Point3d.new(*3.times.map{|i|@points.map{|p|p[i]}.max});end
    def corner(i);Point3d.new(*3.times.map{|a|i&(1<<a)==0 ? min[a] : max[a]});end
    def center;Point3d.new(*3.times.map{|i|(min[i]+max[i])/2});end
    def width;max.x-min.x;end
    def height;max.y-min.y;end
    def depth;max.z-min.z;end
    def contains?(p);3.times.all?{|i|p[i]>=min[i]-1e-8 && p[i]<=max[i]+1e-8};end
  end
end
ORIGIN=Geom::Point3d.new
X_AXIS=Geom::Vector3d.new(1,0,0)
Y_AXIS=Geom::Vector3d.new(0,1,0)
Z_AXIS=Geom::Vector3d.new(0,0,1)
module Sketchup
  class << self;attr_accessor :active_model,:status_text;end
  def self.read_default(_id,_key,default);default;end
  class Color;def initialize(*);end;end
  class EntitiesObserver;end
  class DefinitionsObserver;end
  class LayersObserver;end
  class ModelObserver;end
  class AppObserver;end
  class PagesObserver;end
  class Layer
    def visible?;true;end
    def folder;nil;end
  end
  class Entity
    attr_accessor :parent,:persistent_id,:attributes,:hidden
    def initialize(id,parent,attrs={});@persistent_id,@parent,@attributes=id,parent,attrs;end
    def valid?;true;end
    def hidden?;!!@hidden;end
    def visible?;!hidden?;end
    def layer;@layer||=Layer.new;end
    def get_attribute(dict,key,default=nil);(@attributes[dict] || {}).fetch(key,default);end
    def set_attribute(dict,key,value);(@attributes[dict]||={})[key]=value;end
  end
  class Vertex < Entity
    attr_accessor :position
    def initialize(id,parent,point);super(id,parent);@position=Geom::Point3d.new(*point);end
  end
  class Edge < Entity
    attr_accessor :start,:end,:curve
    def initialize(id,parent,a,b);super(id,parent);@start,@end=a,b;end
    def length;start.position.distance(self.end.position);end
    def bounds;Geom::BoundingBox.new.add(start.position,self.end.position);end
    def line;[start.position,(self.end.position-start.position).normalize];end
  end
  class Loop
    attr_reader :vertices,:edges
    def initialize(vertices,edges,outer);@vertices,@edges,@outer=vertices,edges,outer;end
    def outer?;@outer;end
  end
  class Face < Entity
    PointOutside=1;PointInside=2;PointOnEdge=4;PointOnVertex=8
    attr_accessor :plane,:loops
    def normal;Geom::Vector3d.new(*plane[0,3]);end
    def outer_loop;loops.first;end
    def vertices;loops.flat_map(&:vertices).uniq;end
    def edges;loops.flat_map(&:edges).uniq;end
    def classify_point(point)
      drop=3.times.max_by{|i|plane[i].abs};axes=[0,1,2]-[drop];x,y=axes.map{|i|point[i]}
      statuses=loops.map do |loop|
        pts=loop.vertices.map{|v|axes.map{|i|v.position[i]}};inside=false;boundary=false
        pts.each_with_index do |(ax,ay),i|
          bx,by=pts[(i+1)%pts.size]
          cross=(x-ax)*(by-ay)-(y-ay)*(bx-ax)
          boundary ||= cross.abs<1e-7 && x>=[ax,bx].min-1e-7 && x<=[ax,bx].max+1e-7 && y>=[ay,by].min-1e-7 && y<=[ay,by].max+1e-7
          inside=!inside if (ay>y)!=(by>y) && x<(bx-ax)*(y-ay)/(by-ay)+ax
        end
        boundary ? :boundary : (inside ? :inside : :outside)
      end
      return PointOnEdge if statuses.include?(:boundary)
      statuses.first==:inside && statuses.drop(1).none?{|s|s==:inside} ? PointInside : PointOutside
    end
    def bounds;Geom::BoundingBox.new.add(vertices.map(&:position));end
  end
  class Curve;end
  class ArcCurve < Curve
    attr_accessor :center,:normal,:radius,:edges,:first_edge
    def start_angle;0;end
    def end_angle;2*Math::PI;end
  end
  class Dimension < Entity;end
  class DimensionLinear < Dimension;end
  class SectionPlane < Entity;end
  class Entities < Array
    attr_accessor :parent
    def initialize(parent);super();@parent=parent;end
    def add_observer(*);true;end
  end
  class ComponentDefinition < Entity
    attr_accessor :entities,:name
    def initialize(id,name);super(id,nil);@name=name;@entities=Entities.new(self);end
    def bounds
      box=Geom::BoundingBox.new
      entities.each do |e|
        if e.is_a?(Group) || e.is_a?(ComponentInstance)
          b=e.bounds;box.add((0..7).map{|i|b.corner(i)}) unless b.empty?
        elsif e.is_a?(Edge)
          box.add(e.start.position,e.end.position)
        elsif e.is_a?(Face)
          box.add(e.vertices.map(&:position))
        elsif e.is_a?(DimensionLinear)
          b=e.bounds;box.add(b.min,b.max)
        end
      end
      box
    end
  end
  class ComponentInstance < Entity
    attr_accessor :definition,:transformation,:name
    def initialize(row,parent,definitions)
      super(row['id'],parent,row['attrs']||{});@name=row['name'];@definition=definitions[row['definition']];@transformation=Geom::Transformation.new(row['transform'])
    end
    def bounds
      b=definition.bounds;out=Geom::BoundingBox.new
      out.add((0..7).map{|i|transformation*b.corner(i)}) unless b.empty?;out
    end
  end
  class Group < ComponentInstance;end
  class Model
    attr_accessor :entities,:lookup,:definitions
    def initialize;@entities=Entities.new(self);@lookup={};end
    def find_entity_by_persistent_id(ids);ids.is_a?(Array) ? ids.map{|id|lookup[id]} : lookup[ids];end
  end
end
module Digest
  class SHA256
    def self.hexdigest(value);value.hash.to_s;end # change detector only in tests
  end
end
module Zlib
  def self.crc32(string)
    crc=0xffffffff
    string.bytes.each do |byte|
      crc^=byte
      8.times{crc=(crc>>1)^((crc&1)==1 ? 0xedb88320 : 0)}
    end
    crc^0xffffffff
  end
end
module JSON
  def self.generate(value);Marshal.dump(value);end
  def self.parse(value);Marshal.load(value);end
end
