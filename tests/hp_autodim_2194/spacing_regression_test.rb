base=File.expand_path('../hp_autodim_2191/spacing_test.rb',__dir__)
ENV['HP_AUTODIM_TEST_VERSION']='2.19.4'
source=File.read(base)
raise 'Base policy assertion changed; review adapter' unless source.include?('%w[custom free]')
# Free dragging now keeps minimum row separation; the focused suite tests it.
source=source.sub('%w[custom free]','%w[custom]')
eval(source,TOPLEVEL_BINDING,base)
