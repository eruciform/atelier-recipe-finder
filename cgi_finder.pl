#!/usr/bin/env perl -w

=head1 DESCRIPTION

This cgi_finder executable runs the actual finding logic. It is generally referenced by
a website iframe created by cgi_iframe that creates a proper menu and iframe.

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

use CGI ':standard';
use strict;

use File::Basename;
use lib dirname( __FILE__ );

use atelier::recipe_book;
use atelier::files;

my $q = new CGI;

our $from_type = param("from_type");
our $to_type   = param("to_type");
our $chapter   = param("chapter");
our $depth     = param("depth");

our $game      = param("game");
our $types     = param("types");
our $materials = param("materials");

print $q->header();

$types   = "" unless defined $types;
$chapter = "" unless defined $chapter;

$types   =~ s/[^\w\d,]//goi;  # little bobby tables
$chapter =~ s/[^\w\d,.]//goi; # little bobby tables

my $MAT = $materials ? $materials !~ /[0f]/oi ? 1 : 0 : 0; # anything other than false or 0 is true
my $TYP = join "|", split /,/oi, $types or undef;
my $CTR = $chapter ? $chapter : undef;
my $GAM = $game;

print <<"HEAD";
<html>
  <head>
    <link rel="stylesheet" href="cgi_finder.css">
  </head>
  <body>
HEAD

chdir( dirname( __FILE__ ) );
my $rb = atelier::recipe_book->new( 
  $RECIPES{$GAM}, 
  sub { my %a = @_; 
        return 1 if $a{Type} !~ /$TYP/i;
        return 0 if not $chapter;
        return 1 if not $a{Chapter} or $a{Chapter} > $chapter; },
  $DELIMITER 
) or die();
$rb->add_materials( $MATERIALS{$GAM}, undef, $DELIMITER ) if $MAT;

my @paths = $rb->find_recipe_graph( $from_type, $to_type, $depth || undef );
my @chains;
foreach my $path ( @paths ) {
  foreach my $chain ( $path->extract_chains() ) {
    push @chains, $chain;
  }
}
foreach my $chain ( sort { scalar @$a <=> scalar @$b } @chains ) {
  print "<p>";
  my $i = 0;
  foreach my $link ( @$chain ) {
    if( $i%2 ) {
      print map { "<span class=action>$_</span>" } $link;
    } else {
      print map { "<span class=material>$_</span>" } $link;
    }
    $i++;
  }
  print "</p><hr>\n";
}

if( not @chains ) {
  print "<h1>No path found from $from_type to $to_type</h1>";
}

print <<"TAIL";
  </body>
</html>
TAIL



















