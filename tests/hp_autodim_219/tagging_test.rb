# Run with Ruby; intentionally does not load SketchUp or geometry rendering.
module Sketchup
  class PagesObserver; end
  class Group; end
  class ComponentInstance; end
  class Dimension; end
  class << self; attr_accessor :active_model, :status_text; end
end
module UI
  def self.messagebox(message); raise message; end
end
class Item
  attr_accessor :name, :persistent_id, :folder, :visible, :layer, :entities
  def initialize(name, id); @name, @persistent_id, @attrs = name, id, {}; end
  def get_attribute(dict, key, default = nil); @attrs.fetch([dict, key], default); end
  def set_attribute(dict, key, value); @attrs[[dict, key]] = value; end
end
class TagList < Array
  attr_reader :folders
  def initialize; super; @folders = []; end
  def [](key); key.is_a?(String) ? find { |tag| tag.name == key } : super; end
  def add(name); tag = Item.new(name, size + 100); self << tag; tag; end
  def add_folder(name); folder = Item.new(name, 1); @folders << folder; folder; end
end
class Page < Item
  attr_accessor :use_hidden_layers
  def initialize(*args); super; @visibility = {}; end
  def use_hidden_layers?; !!@use_hidden_layers; end
  def set_visibility(tag, value); @visibility[tag] = value; end
  def visibility(tag); @visibility[tag]; end
end
class Pages < Array
  attr_accessor :selected_page
end
class Model
  attr_accessor :layers, :pages, :entities, :sets
  def initialize
    @layers, @pages, @entities, @sets = TagList.new, Pages.new, [], []
    @pages.push(Page.new('Scene A', 1), Page.new('Scene B', 2))
    @pages.selected_page = @pages.first
  end
  def start_operation(*); end
  def commit_operation; end
  def abort_operation; end
end
module HP
  module AutoDim
    PLUGIN_ID = 'HP_AutoDim'
    TAG_PREFIX = 'HP_DIM'
    def self.current_pgid(model); model.pages.selected_page.persistent_id; end
    def self.page_by_id(model, id); model.pages.find { |p| p.persistent_id == id }; end
    def self.remember_tag(tag, set)
      set['tag'], set['tag_pid'] = tag.name, tag.persistent_id
      tag.set_attribute(PLUGIN_ID, 'owned_tag', true)
      tag
    end
    def self.find_set_tag(model, set); model.layers[set['tag']]; end
    def self.leave_hp_groups(*); end
    def self.load_sets(model); model.sets; end
    def self.save_sets(model, sets); model.sets = sets; end
  end
end
load File.expand_path('../../src/hp_auto_dim_2.19.0/hp_auto_dim/tagging.rb', __dir__)
def assert(value); raise 'Assertion failed' unless value; end
hp = HP::AutoDim
model = Model.new
Sketchup.active_model = model
kinds = %w[obj cont cut std]
a = kinds.map { |mode| hp.new_scene_tag(model, {'mode'=>mode, 'pgid'=>1}) }
b = kinds.map { |mode| hp.new_scene_tag(model, {'mode'=>mode, 'pgid'=>2}) }
assert(model.layers.folders.map(&:name) == ['HP DIM'])
assert((a + b).uniq.size == 8)
assert(a.first.name == 'Scene A — DIM Đối tượng')
assert(a.all? { |tag| model.pages[0].visibility(tag) && !model.pages[1].visibility(tag) })
assert(b.all? { |tag| !model.pages[0].visibility(tag) && model.pages[1].visibility(tag) })
assert(hp.new_scene_tag(model, {'mode'=>'chain', 'pgid'=>1}) == a[1])
model.pages.selected_page = model.pages[1]
(a + b).each { |tag| hp.configure_dim_visibility(model, tag) }
assert(a.none?(&:visible) && b.all?(&:visible))
old = model.layers.add('HP_DIM')
legacy = {'id'=>'old', 'mode'=>'obj', 'pgid'=>1, 'tag'=>'HP_DIM'}
assert(hp.tag_for(model, legacy) == old && !legacy.key?('tag_schema'))
# Manual DIM and source component share the old layer: neither may be retagged.
Sketchup.send(:remove_const, :Dimension)
Sketchup.send(:remove_const, :Group)
Sketchup.send(:remove_const, :ComponentInstance)
class Sketchup::Dimension < Item; end
class Sketchup::Group < Item
  def definition; self; end
end
class Sketchup::ComponentInstance < Sketchup::Group; end
manual = Sketchup::Dimension.new('manual', 30); manual.layer = old
owned = Sketchup::Dimension.new('HP', 31); owned.layer = old
owned.set_attribute(hp::PLUGIN_ID, 'set', 'old')
source = Sketchup::ComponentInstance.new('source', 32); source.layer = old; source.entities = [owned, manual]
model.entities = [source]; model.sets = [legacy]
assert(hp.consolidate_tags == 1)
assert(owned.layer == a[0] && manual.layer == old && source.layer == old)
assert(legacy['tag_schema'] == 219)
assert(hp.consolidate_tags == 1 && model.layers.size == 9)
new_page = Page.new('Scene C', 3); model.pages << new_page
hp::HPDimPagesObserver.new(model).onElementAdded(model.pages, new_page)
assert((a+b).none? { |tag| new_page.visibility(tag) })
puts 'PASS: folder, 8 scene/type tags, visibility, reuse, legacy refresh, migration, manual/source safety, idempotence, new scene'
