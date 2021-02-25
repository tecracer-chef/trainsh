# Run static code checkers against the pack
#
desc "Run static checks"

task :lint do
  sh <<~EOS
    rubocop && \
    mdl *.md
  EOS
end
