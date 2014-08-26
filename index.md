---
layout: page
title: Practical Solutions | Home
---
Practical Solutions
===================
Practical = ( partial | ugly | temporary | works-for-me | works-for-now ) 

{% for post in site.posts %}
## [{{ post.title }}]({{ site.url }}{{ post.url }})
{{ post.date | date_to_string }}

{{ post.excerpt | split:"</p>" | first | strip_html}}

{% endfor %} 
