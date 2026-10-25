base=File.expand_path('../hp_autodim_2193/regression_test.rb',__dir__)
ARGV[0] ||= File.expand_path('../../src/hp_auto_dim_2.19.4/hp_auto_dim',__dir__)
source=File.read(base)
old="all?{|d|d.text.empty?},'numeric override can freeze native dimension display'"
replacement="all?{|d|d.text.empty? || d.text==AD.strip_zeros(Sketchup.format_length(d.measurement))},'integer display does not match current measurement'"
raise 'Base label assertion changed; review regression adapter' unless source.include?(old)
source=source.sub(old,replacement)
eval(source,TOPLEVEL_BINDING,base)
