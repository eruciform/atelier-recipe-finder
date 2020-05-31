Atelier Recipe Finder
=====================

Description
-----------

This tool is for calculating the most interesting, least inefficient paths from one ingredient or type
to another ingredient or type, in the Atelier series of JRPGs. This assumes you have the recipe and
material data in a couple of CSVs, as long as they're formatted with the correct headers.

It includes a few CGI tools and a command line utility.

Initial Setup
-------------

Clone the repo into a CGI-friendly directory that allows perl CGIs named \*.pl

<pre>
#> cd cgi
#> cat .htaccess
<Files *>
AddHandler cgi-script .pl
</Files>
#> git clone https://github.com/eruciform/atelier-recipe-finder.git
</pre>

Put your data files (recipe.csv and material.csv) somewhere accessible, perhaps in that CGI directory
as a default.

Edit atelier/files.pm to add or edit your game to point to those files. The directories will be with
respect to the cgi or command line utilities, so "./recipe.csv" means in the same directory as the
cgi or command line tools.

<pre>
#> grep '=>' atelier/files.pm 
   ryza => "./ryza_recipes.csv",
   ryza => "./ryza_materials.csv",
</pre>

CGI Setup
---------

Point a link or an iframe to the cgi\_iframe.pl utility, with the necessary parameters set, such as whether
you want to include materials, depth, or chapter restrictions, which game it points to, etc.

Example:

<pre>
<iframe src="/static/cgi/atelier-recipe-finder/cgi_iframe.pl?types=gathering,synthesis,materials&game=ryza&cgi=cgi_finder.pl&chapters=1,2,3,4,4.5,5,6,6.5,7,8,9,10,11&chapter_default=11&materials=1" width="100%" height="800px" style="border: 0px;"></iframe>
</pre>

Command Line
------------

You can also run the recipe\_finder.pl command to get data that way, just to test it out, or if you're not setting up a website.

<pre>
./recipe_finder.pl "Flame Black Sand" "(Dragon)" -r ../ryza_recipes.csv -m ../ryza_materials.csv --chapter 6.5
</pre>


