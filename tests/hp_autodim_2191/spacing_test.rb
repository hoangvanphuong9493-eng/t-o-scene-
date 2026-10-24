# Pure Ruby geometry substitute for row placement regression tests.
class V
  attr_reader :x, :y, :z
  def initialize(x, y, z = 0); @x, @y, @z = x.to_f, y.to_f, z.to_f; end
  def +(v); V.new(x+v.x, y+v.y, z+v.z); end
  def -(v); V.new(x-v.x, y-v.y, z-v.z); end
  def *(n); V.new(x*n, y*n, z*n); end
  def dot(v); x*v.x + y*v.y + z*v.z; end
  def cross(v); V.new(y*v.z-z*v.y, z*v.x-x*v.z, x*v.y-y*v.x); end
  def length; Math.sqrt(dot(self)); end
  def normalize; self * (1.0 / length); end
  def transform(t); self + t.translation; end
end
module Geom
  class Transformation
    attr_reader :translation
    def initialize(v = V.new(0,0,0)); @translation = v; end
    def *(other); self.class.new(translation + other.translation); end
  end
end
module Sketchup
  class Group; end
  class ComponentInstance; end
  class DimensionLinear; end
end
module HP
  module AutoDim
    MM = 1.0 # Tests use mm directly, independent of model display units.
    PLUGIN_ID = 'HP_AutoDim'
    def self.sc(vector, scalar); vector * scalar; end
    def self.step_mm; 120; end
    def self.current_pgid(model); 1; end
  end
end
load File.expand_path("../../src/hp_auto_dim_#{ENV.fetch('HP_AUTODIM_TEST_VERSION', '2.19.1')}/hp_auto_dim/spacing.rb", __dir__)
def close(a, b); raise "#{a} != #{b}" unless (a-b).abs < 0.00001; end
hp = HP::AutoDim
ref, axis, direction = V.new(0,0), V.new(1,0), V.new(0,1)
row = ->(y, x0=0, x1=1000, z=0) { [V.new(x0,y,z), V.new(x1,y,z)] }
shift = ->(rows, side=direction) { hp.row_spacing_shift(rows, ref, axis, side, 1000, 150, 120) }
close(shift.call([row.call(150)]), 120) # reported bug: second row 270
close(shift.call([row.call(150),row.call(270)]), 240) # third row 390
close(shift.call([row.call(150,1000,1500)]), 0) # adjacent span
close(shift.call([row.call(-150)]), 0) # opposite side
close(shift.call([row.call(-150)], V.new(0,-1)), 120)
close(shift.call([row.call(150,200,800)]), 120) # partial overlap
close(shift.call([row.call(150,0,1000,25)]), 0) # different plane
close(shift.call([[V.new(50,10),V.new(50,800)]]), 0) # perpendicular
close(shift.call([[V.new(1000,150),V.new(0,150)]]), 120) # reverse direction
close(hp.row_spacing_shift([row.call(150)],ref,axis,direction,1000,150,0),0)
line = {off: V.new(0,150), legs: V.new(0,15)}
moved = hp.shift_line_row(line,120)
close(moved[:off].y,270)
close(moved[:legs].y,135)
close((moved[:off]-moved[:legs]).length,135) # witness length retained
# Same helper drives preview; explicit length/free placement bypass auto spacing.
tool = Object.new.extend(hp::PointTool)
view = Struct.new(:model).new(Object.new)
class << hp; alias capture_spacing_rows spacing_rows; end
def hp.spacing_rows(_model); [[V.new(0,150),V.new(1000,150)]]; end
preview = tool.space_placement(view,ref,axis,1000,line[:off],line[:legs])
close(preview.first.y,270)
close(tool.instance_variable_get(:@row_shift_mm),120)
%w[custom free].each do |policy|
 tool.instance_variable_set(:@leg_policy,policy)
 close(tool.space_placement(view,ref,axis,1000,line[:off],line[:legs]).first.y,150)
 close(tool.instance_variable_get(:@row_shift_mm),0)
end
puts 'PASS: second/third rows 120mm apart, sides, overlap, planes, perpendicular/reverse rows, preview, witness length, custom/free override'

# Exercise real capture: source transforms, manual/hidden/other-scene filtering.
class Layer
  def visible?; true; end
  def folder; nil; end
end
class Sketchup::DimensionLinear
  def initialize(hp=true, hidden=false); @hp, @hidden = hp, hidden; end
  def hidden?; @hidden; end
  def layer; Layer.new; end
  def get_attribute(_dict,key,*); key == 'set' && @hp ? 'set-1' : nil; end
  def start; [nil,V.new(0,15)]; end
  def end; [nil,V.new(1000,15)]; end
  def offset_vector; V.new(0,135); end
end
class Sketchup::Group
  def initialize(entities,owner=nil); @entities,@owner=entities,owner; end
  attr_reader :entities
  def hidden?; false; end
  def layer; Layer.new; end
  def get_attribute(*); @owner; end
  def definition; self; end
  def transformation; Geom::Transformation.new(V.new(0,10)); end
end
model = Struct.new(:entities).new([
 Sketchup::Group.new([Sketchup::DimensionLinear.new,Sketchup::DimensionLinear.new(false),Sketchup::DimensionLinear.new(true,true)],1),
 Sketchup::Group.new([Sketchup::DimensionLinear.new],2)])
captured=hp.capture_spacing_rows(model)
raise 'capture filtering' unless captured.size==1
close(captured[0][0].y,160)
puts 'PASS: capture filters manual/hidden/other-scene DIM and applies source transform'
