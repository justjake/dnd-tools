Gem::Specification.new do |s|
    s.name        = 'pathfinder-dnd-tools'
    s.version     = '0.1.1'
    s.date        = '2013-03-19'
    s.summary     = 'D&D Tools'
    s.description = 'Companion tools for the Pathfinder Google Drive character sheet template'
    s.author      = 'Jake Teton-Landis'
    s.email       = 'just.1.jake@gmail.com'
    s.files       = Dir['lib/**/*.rb'] + Dir['bin/*']
    s.homepage    = 'http://jake.teton-landis.org/projects/pathfinder-dnd'

    s.bindir      = 'bin'
    s.executables = ['pathfinder']

    s.add_runtime_dependency 'pry'
    s.add_runtime_dependency 'google_drive'
    s.add_runtime_dependency 'oauth2'
end
