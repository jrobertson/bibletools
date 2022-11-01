Gem::Specification.new do |s|
  s.name = 'bibletools'
  s.version = '0.1.0'
  s.summary = 'Performs a word count within a specified book. Returns the verses within a specified book for a given keyword.'
  s.authors = ['James Robertson']
  s.add_runtime_dependency('nokorexi', '~> 0.7', '>=0.7.0')
  s.add_runtime_dependency('yawc', '~> 0.3', '>=0.3.0')
  s.files = Dir["lib/bibletools.rb"]
  s.signing_key = '../privatekeys/bibletools.pem'
  s.cert_chain  = ['gem-public_cert.pem']
  s.license = 'MIT'
  s.email = 'digital.robertson@gmail.com'
  s.homepage = 'https://github.com/jrobertson/bibletools'
end
