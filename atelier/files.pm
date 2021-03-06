#!/usr//bin/env perl

=head1 DESCRIPTION

Used by cgi_finder and cgi_iframe to tell where your data files are. You'll need to change
that by hand, and add new games and game files as needed. Keep recipes and materials separate
so that the API can choose one or both.

=head1 FORMAT

All files require fields:
Name
Type
Category 1

And recipes should include:
Ingredient 1

And can also include:
Ingredient 2
Ingredient 3
Ingredient 4
Category 2
Category 3
Category 4
Add Category 1 - for when a recipe optionally can add a category
Add Category 2
Add Category 3
Add Category 4
From Recipe 1 - for when a recipe can be made directly from another as in Ryza
From Recipe 2
Chapter

=head1 LICENSE

This file is part of Atelier Recipe Finder.

Atelier Recipe Finder is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

Atelier Recipe Finder is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with Atelier Recipe Finder.  If not, see <https://www.gnu.org/licenses/>.

=head1 COPYRIGHT

Copyright 2020, Sean Cusack (eruciform)

=head1 WEBSITE

http://eruciform.com

https://github.com/eruciform/atelier-recipe-finder

=cut

use strict;

package atelier::files;

use Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw(%RECIPES %MATERIALS $DELIMITER);

our $DELIMITER = ",";

# Fill in other games as needed, or change the directory where this can be found

our %RECIPES = ( 
  ryza => "./ryza_recipes.csv",
);

our %MATERIALS = ( 
  ryza => "./ryza_materials.csv",
);

1;
