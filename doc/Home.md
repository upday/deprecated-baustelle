# Documentation wiki

<% index_tree.each do |category, articles| do %>
## <%= title(category) %>
<% articles.each do |article| %>
* <%= link_to category, article %>
<% end %>
