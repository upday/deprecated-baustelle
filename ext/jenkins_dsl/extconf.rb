File.open("Makefile", "w") do |makefile|
  makefile.puts <<-MAKEFILE
.PHONY: all

all: gradle

gradle:
\twhich gradle || (echo "Gradle not found" && exit 1)
  MAKEFILE
end
