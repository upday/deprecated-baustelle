File.open("Makefile", "w") do |makefile|
  makefile.puts <<-MAKEFILE
clean:
  rm -fr build .gradle

install: build

build:
\tgradle build

  MAKEFILE
end
