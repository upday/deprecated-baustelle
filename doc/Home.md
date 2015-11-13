# Documentation wiki

<% index_tree.each do |category, articles| %>

# <%= link_to category %> #

<% articles.each do |article| %>
* <%= link_to category, article %>
<% end %>
<% end %>
