# Ruby 2.7+. Only label formatting and placement spacing changed in this patch.
require_relative '../hp_autodim_2193/model_fixture'
require_relative '../hp_autodim_2193/render_api'
load_plugin_for_geometry(ARGV[0] || File.expand_path('../../src/hp_auto_dim_2.19.4/hp_auto_dim',__dir__))
AD = HP::AutoDim
@checks = 0
def check(value, message)
  raise message unless value
  @checks += 1
end
def near(a, b, message);check((a-b).abs < 1e-7, "#{message}: #{a} != #{b}");end
module Sketchup
  def self.format_length(value);format('%.1f', value*25.4);end
end
model=Sketchup::Model.new;model.definitions={};Sketchup.active_model=model
label_group=model.entities.add_group
label_group.set_attribute(AD::PLUGIN_ID,'set','label')
d=label_group.entities.add_dimension_linear(ORIGIN,Geom::Point3d.new(600.mm,0,0),Geom::Vector3d.new(0,150.mm,0))
AD.set_clean_text(d,600.mm)
check(d.text=='600','600.0 was not cleaned')
[599.4,247.5,458.8,16.7].each do |length|
  d.end=Geom::Point3d.new(length.mm,0,0);AD.set_clean_text(d,length.mm)
  check(d.text.empty?,"fractional #{length} lost native text")
end
[100,600,1200,2000].each do |length|
  d.end=Geom::Point3d.new(length.mm,0,0);AD.set_clean_text(d,length.mm)
  check(d.text==length.to_s,"integer #{length} label wrong after resize")
end
d.end=Geom::Point3d.new(600.4.mm,0,0);AD.set_clean_text(d,600.4.mm)
check(d.text.empty? && Sketchup.format_length(d.start[1].distance(d.end[1]))=='600.4','integer override froze a later fractional measurement')
module Sketchup
  def self.format_length(value);format('%.1f mm', value*25.4);end
end
AD.set_clean_text(d,1000.mm);check(d.text=='1000 mm','unit suffix was lost')
module Sketchup
  def self.format_length(value);format('%.1f', value*25.4);end
end
# Nested dimensions keep native display: changing a parent Scale cannot leave
# a static numeric override. Ordinary top-level HP sets use the cleaned label.
source=model.entities.add_group
nested=source.entities.add_group
nested_dimension=nested.entities.add_dimension_linear(ORIGIN,Geom::Point3d.new(600.mm,0,0),Geom::Vector3d.new(0,150.mm,0))
AD.set_clean_text(nested_dimension,600.mm)
check(nested_dimension.text.empty?,'nested dimension received a frozen number')

# Reproduce same-view rows on different depth planes: doors vs cabinet frame.
label_group.erase!
def row(model, distance, depth, scene=38895)
  group=model.entities.add_group;group.set_attribute(AD::PLUGIN_ID,'set',"row-#{distance}");group.set_attribute(AD::PLUGIN_ID,'scene_id',scene)
  a=Geom::Point3d.new((1000+distance-135).mm,depth.mm,0)
  b=Geom::Point3d.new(a.x,a.y,2000.mm)
  dimension=group.entities.add_dimension_linear(a,b,Geom::Vector3d.new(135.mm,0,0))
  dimension.set_attribute(AD::PLUGIN_ID,'set',"row-#{distance}")
  group
end
old=row(model,150,-617.5)
Camera=Struct.new(:direction,:eye,:perspective) do
  def perspective?;!!perspective;end
end
View=Struct.new(:model,:camera)
view=View.new(model,Camera.new(Y_AXIS,nil,false))
ref=Geom::Point3d.new(1000.mm,-600.mm,0);axis=Z_AXIS;direction=X_AXIS
rows=AD.spacing_rows(model)
near(AD.row_spacing_shift(rows,ref,axis,direction,2000.mm,150.mm,120.mm),0,'old coplanar filter reproduction')
tool=Object.new.extend(AD::PointTool)
off,legs=tool.space_placement(view,ref,axis,2000.mm,AD.sc(direction,150.mm),AD.sc(direction,15.mm))
near(off.length/1.mm,270,'second row must be 120mm outside previous row across depth')
near((off-legs).length/1.mm,135,'spacing changed witness length')
near(tool.leg_fields['row_shift_mm'],120,'placement failed to save spacing shift')
# Free dragging formerly bypassed the entire spacing feature.
free=Object.new.extend(AD::PointTool);free.instance_variable_set(:@leg_policy,'free')
free_off,_=free.space_placement(view,ref,axis,2000.mm,AD.sc(direction,150.mm),AD.sc(direction,15.mm))
near(free_off.length/1.mm,270,'free dragging did not retain minimum separation')
far_off,_=free.space_placement(view,ref,axis,2000.mm,AD.sc(direction,500.mm),AD.sc(direction,15.mm))
near(far_off.length/1.mm,500,'free dragging farther out was incorrectly clamped')
# VCB explicitly entered length keeps its existing override behavior.
custom=Object.new.extend(AD::PointTool);custom.instance_variable_set(:@leg_policy,'custom')
custom_off,_=custom.space_placement(view,ref,axis,2000.mm,AD.sc(direction,150.mm),AD.sc(direction,15.mm))
near(custom_off.length/1.mm,150,'explicit VCB length behavior changed')
row(model,270,-600)
third=Object.new.extend(AD::PointTool)
third_off,_=third.space_placement(view,ref,axis,2000.mm,AD.sc(direction,150.mm),AD.sc(direction,15.mm))
near(third_off.length/1.mm,390,'third row must clear both existing rows')
# Same-view projection in a perspective camera; compare against ray-plane math.
perspective={eye:Geom::Point3d.new(1000.mm,-1000.mm,1000.mm)}
shift=AD.row_spacing_shift([rows.first],ref,axis,direction,2000.mm,150.mm,120.mm,perspective)
near((150.mm+shift)/1.mm,150*400.0/382.5+120,'perspective projection spacing')
# Other-side, disjoint spans, hidden rows, and other scenes do not displace it.
left=[Geom::Point3d.new(850.mm,-617.5.mm,0),Geom::Point3d.new(850.mm,-617.5.mm,2000.mm)]
near(AD.row_spacing_shift([left],ref,axis,direction,2000.mm,150.mm,120.mm,{direction:Y_AXIS}),0,'opposite-side row affected placement')
near(AD.row_spacing_shift(rows,ref,axis,direction,2000.mm,150.mm,120.mm,{direction:X_AXIS}),0,'edge-on camera made an invalid projection')
old.hidden=true
row(model,900,-600,38896)
visible=AD.spacing_rows(model)
# The generic API substitute models Group as a ComponentInstance subclass,
# while native SketchUp uses distinct classes: compare unique captured rows.
check(visible.map{|pair|pair.map(&:to_a)}.uniq.size==1,'hidden or other-scene row entered spacing snapshot')
# Persisted shift still uses the original compute_line: placement and rebuild agree.
set={'mode'=>'cont','anchor_mode'=>'native','anchors'=>[AD.world_anchor(ref),AD.world_anchor(ref+AD.sc(axis,2000.mm))],
     'axis'=>axis.to_a,'od'=>direction.to_a,'perp'=>Y_AXIS.to_a,'dm'=>off.to_a,'gap'=>150,'skip_mm'=>20}.merge(tool.leg_fields)
line=AD.compute_line(model,set)
near(line[:off].length/1.mm,270,'rebuild lost the saved row spacing')
near(line[:segs].first[:len]/1.mm,2000,'presentation patch changed measured length')
puts "PASS #{@checks} focused label/placement assertions."
