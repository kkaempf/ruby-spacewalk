task :clean do
  `rm -rf *~`
  `rm -rf */*~`
  `rm -rf */*/*~`
  `rm -f Gemfile.lock`
  `rm -rf .yardoc`
  `rm -rf pkg`
end
