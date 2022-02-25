#!/usr/bin/env perl

=head1 DESCRIPTION

Command line utility equivalent of the cgi_finder tool, to determine the recipes
that get from material or type A to material or type B. This assumes you have data files.

=head1 USAGE

recipe_finder.pl from to -r recipe.csv [options]

=head1 OPTIONS

--materials materials.csv - for specifying a file of non-recipe materials

--delimiter , - for specifying file delimiter, in case it's a tab or pipe instead of a comma

--depth # - for limiting results to a depth of #

--type list,of,types - for limiting the recipes to a comma separated list of what's in the Type column

--chapter chapter - for restricting to recipes up to and including that chapter only

=head1 EXAMPLE

recipe_finder.pl "Flame Black Sand" "(Dragon)" -r recipe.csv -m materials.csv 5 -f synthesis,gathering,materials -c 6

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

use Getopt::Long;

use lib ".";

use atelier::recipe_book;
use atelier::recipe;

my $depth         = undef;
my $delim         = undef;
my $chapter       = undef;
my $recipe_file   = undef;
my $material_file = undef;
my $type_filter   = undef;

$SIG{__DIE__} = sub { print STDERR @_; exec "perldoc $0"; };

GetOptions( "depth=i"    => \$depth,
            "delim=s"    => \$delim,
            "chapter=f"  => \$chapter,
            "recipe=s"   => \$recipe_file,
            "material=s" => \$material_file,
            "type=s"     => \$type_filter,
            "verbose"    => sub { $atelier::recipe::DEBUG = $atelier::recipe_book::DEBUG = 1 },
            "help"       => sub { exec "perldoc $0"; },
          );
my $from = shift @ARGV or die "No 'from' specified";
my $to   = shift @ARGV or die "No 'to' specified";
die "No recipe file specified" unless $recipe_file;

my $type   = defined $type_filter ? "(?i:" . ( join( "|", map { s/\s//go; $_ } split( /,/o, $type_filter ) ) ) . ")" : undef;
my $filter = undef;
if( defined $type_filter or defined $chapter ) {
  $filter = sub { my %data = @_; 
                  return 1 if defined $type_filter   and $data{Type}    !~ /$type/oi; 
                  return 1 if defined $chapter       and
                                      $data{Chapter} and
                              defined $data{Chapter} and $data{Chapter} > $chapter;
                  return 0;
                };
}

my $rb = atelier::recipe_book->new($recipe_file, $filter, $delim) or die "Cannot open recipe file $recipe_file: $!";

$rb->add_materials($material_file, $filter, $delim) or die "Cannot open material file $material_file: $!" if $material_file;

my @rc = $rb->find_recipe_graph($from, $to, $depth);

foreach my $chain (sort { scalar @{$a} <=> scalar @{$b} } sort { @{$a} <=> @{$b} } map { $_->extract_chains } @rc) {
  my $len = scalar(@$chain);
  print "$len steps: ", join(" ==> ", @{$chain}), "\n";
}

