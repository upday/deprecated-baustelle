# baustelle.yaml description

<%= breadcrumbs %>

<% articles(current_category).each do |article| %>
* <%= link_to current_category, article %>
<% end %>
