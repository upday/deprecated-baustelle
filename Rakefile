require "bundler/gem_tasks"
require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:spec)

task :default => :spec



module Documentation
  extend self

  attr_accessor :current_category, :current_article

  def build_dir
    dest = ENV.fetch("DESTDIR", "build")
    system "mkdir -p #{dest}"
    dest
  end

  def index_tree
    @index_tree ||= Dir["doc/*"].select(&File.method(:directory?)).
                  map(&File.method(:basename)).inject({}) do |index, category|
      index[category] = articles(category)
      index
    end
  end

  def articles(category)
    Dir["doc/#{category}/*-*.md"].map(&File.method(:basename))
  end

  def title(category, article="index.md")
    File.readlines(File.join("doc", category, article)).first[/^#\s*(.*)$/, 1]
  end

  def render_template(category, article="index.md")
    ERB.new(File.read(File.join("doc", category, article))).
      result(binding)
  end

  def output_file_name(category, article="index.md")
    [category, article].join('-')
  end

  def link_to(category, article="index.md", title: title(category, article))
    article = File.basename(article, '.md')
    ref = [category, article].join('-')
    "[[#{title}|#{ref}]]"
  end

  def render_home
    ERB.new(File.read(File.join("doc", "Home.md"))).result(binding)
  end
end

task :doc do
  destdir = ENV.fetch("DESTDIR", "docs-compiled")
  system "mkdir -p #{destdir} && rm -fr #{destdir}/*"

  File.open(File.join(destdir, "Home.md"), 'w') do |file|
    file.puts Documentation.render_home
  end

  Documentation.index_tree.each do |category, articles|
    Documentation.current_category = category
    Documentation.current_article = "index.md"
    File.open(File.join(destdir, Documentation.output_file_name(category)), 'w') do |file|
      file.puts Documentation.render_template(category)
    end

    articles.each do |article|
      Documentation.current_article = article
      File.open(File.join(destdir, Documentation.output_file_name(category, article)), 'w') do |file|
        file.puts Documentation.render_template(category, article)
      end
    end
  end
end
