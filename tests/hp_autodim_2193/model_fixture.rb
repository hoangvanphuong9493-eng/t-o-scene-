require_relative 'geometry_api'
def build_fixture(fixture)
  model=Sketchup::Model.new
  defs={}
  fixture['definitions'].each{|row|defs[row['id']]=Sketchup::ComponentDefinition.new(row['id'],row['name'])}
  fixture['definitions'].each do |row|
    definition=defs[row['id']];definition.attributes=row['attrs'] || {};verts={};edges={}
    row['vertices'].each do |v|
      vertex=Sketchup::Vertex.new(v['id'],definition,v['p']);verts[v['id']]=vertex;model.lookup[v['id']]=vertex
    end
    row['edges'].each do |e|
      edge=Sketchup::Edge.new(e['id'],definition,verts[e['start']],verts[e['end']]);edges[e['id']]=edge;model.lookup[e['id']]=edge;definition.entities<<edge
    end
    row['faces'].each do |f|
      face=Sketchup::Face.new(f['id'],definition);face.plane=f['plane']
      face.loops=f['loops'].each_with_index.map do |ring,index|
        vertices=ring.map{|v|verts[v]}
        selected=edges.values.select{|e|ring.include?(e.start.persistent_id)&&ring.include?(e.end.persistent_id)}
        Sketchup::Loop.new(vertices,selected,index==0)
      end
      definition.entities<<face;model.lookup[f['id']]=face
    end
    row['curves'].each do |c|
      curve=Sketchup::ArcCurve.new;curve.center=Geom::Point3d.new(*c['center']);curve.normal=Geom::Vector3d.new(*c['normal']);curve.radius=c['radius'];curve.first_edge=edges[c['first']]
      curve.edges=row['edges'].select{|e|e['curve']==c['id']}.map{|e|edges[e['id']]}
      curve.edges.each{|e|e.curve=curve}
    end
    row['instances'].each do |inst|
      entity=Sketchup::Group.new(inst,definition,defs);definition.entities<<entity;model.lookup[entity.persistent_id]=entity
    end
  end
  root=Sketchup::Group.new(fixture['root'],model,defs);model.entities<<root;model.lookup[root.persistent_id]=root
  model.definitions=defs
  model
end

def load_plugin_for_geometry(path)
  module_source="module HP;module AutoDim;PLUGIN_ID='HP_AutoDim';end;end"
  Object.class_eval(module_source)
  %w[tracking interaction scheduler rendering tagging spacing anchors live_geometry verification recovery].each do |name|
    file=File.join(path,"#{name}.rb");next unless File.exist?(file)
    code=File.read(file).lines.reject{|line|line.start_with?('require ')}.join
    Object.class_eval(code,file)
  end
  code=File.read(File.join(path,'main.rb'))
  code=code[0...code.index('    unless file_loaded?(__FILE__)')]+"  end\nend\n"
  code=code.lines.reject{|line|line.start_with?('require ' )||line.start_with?('require_relative ')}.join
  Object.class_eval(code,File.join(path,'main.rb'))
  HP::AutoDim.instance_variable_set(:@prefs,{
    'offset_mm'=>150.0,'leg_mm'=>15.0,'step_mm'=>120.0,'stagger_mm'=>60.0,'thick_mm'=>20.0,
    'cut_mode'=>'base','vis_only'=>0,'lat_mm'=>150.0,'obj_two_d'=>1,'max_dia_mm'=>100.0,
    'hole_kw'=>'hole,drill,khoan','leaf_kw'=>'canh,door,cua,leaf'})
end
