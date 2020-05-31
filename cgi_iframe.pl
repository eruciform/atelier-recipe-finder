#!/usr/bin/env perl

=head1 DESCRIPTION

This cgi_iframe tool is generally embedded into a website, which returns a webpage that
contains the menu and iframe that will actually respond to recipe finding requests.

Just make sure to fill in the properties on the url line, in order to tell it how to render
things:
materials       = 0 for not including materials, just recipes; 1 to include all
types           = comma separated list of types (defined in the csv data files) to include,
                  generally synthesis,gathering,material
chapters        = comma separated list of chapters, if desired (only needed for data that
                  actually includes chapters, like Ryza and Escha, and only if the data is
                  in the data files [optional]
chapter_default = initial chapter setting (generally set it to the last one so it's
                  most permissive [optional]
depth           = 1,99 would mean permit 1-99 recipe depth, meaning chains of synthesis only
                  up to that length [optional]
depth_default   = initial setting for depth [optional]
game            = string that refers to which game in the atelier/files.pm file, so that
                  you don't let people point to any old data file in your directory

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
print $q->header();

my $materials   = param("materials");       # include materials (true|false)
my $types       = param("types");           # comma separated types, i.e. synthesis, material, gathering
my $chap        = param("chapters");        # include chapters, comma separated [optional]
my $dchap       = param("chapter_default"); # default chapter [optional]
my $depth       = param("depth");           # min, max, comma separated [optional]
my $ddepth      = param("depth_default");   # default depth [optional]
my $game        = param("game");            # which game? uses atelier::files to find files (you must fill this in)

if( not defined $game ) {
  print "<h1>atelier::cgi_iframe not set up properly</h1>\n";
  exit();
}

$types = "" if not defined $types;
$chap  = "" if not defined $chap;
$depth = "" if not defined $depth;

$types =~ s/[^\w\d,]//goi;  # little
$chap  =~ s/[^\w\d,.]//goi; # bobby
$depth =~   s/[^\d,]//goi;  # tables

my $MAT = $materials ? $materials !~ /[0f]/oi ? 1 : 0 : 0; # anything other than false or 0 is true
my $TYP = join "|", split /,/oi, $types or undef;
my @CTR = $chap  ?  split /,/oi, $chap  : ();
my @DEP = $depth ?  split /,/oi, $depth : ();
my $GAM = $game;

chdir( dirname( __FILE__ ) );
my $rb = atelier::recipe_book->new( 
  $RECIPES{$GAM}, 
  sub { my %a = @_; return 1 if $a{Type} !~ /$TYP/i; }, 
  $DELIMITER 
) or die();

my $to_opt = "";
my %tofound;
foreach my $type ( grep { not $tofound{$_}++ } sort($rb->allcategory(), $rb->alloptional, $rb->allname)) {
  $to_opt .= sprintf('<option value="%s">%s</option>'."\n",$type,$type);
}

$rb->add_materials( $MATERIALS{$GAM}, undef, $DELIMITER ) if $MAT;

my $from_opt = "";
my %fromfound;
foreach my $type ( grep { not $fromfound{$_}++ } sort($rb->allcategory(), $rb->alloptional, $rb->allname)) {
  $from_opt .= sprintf('<option value="%s">%s</option>'."\n",$type,$type);
}

my $chap_opt = "";
foreach my $c ( @CTR ) {
  my $default = $dchap ? $c eq $dchap ? "selected" : "" : "";
  $chap_opt .= sprintf('<option value="%s" %s>%s</option>'."\n",$c,$default,$c);
}

my $dep_opt = "";
foreach my $c ( @DEP ? $DEP[0]..$DEP[1] : () ) {
  my $default = $ddepth ? $c eq $ddepth ? "selected" : "" : "";
  $dep_opt .= sprintf('<option value="%s" %s>%s</option>'."\n",$c,$default,$c);
}

print <<"FORM1";
<link rel="stylesheet" href="cgi_finder.css">
<form action="cgi_finder.pl" method="get">
  <label for="from_type">From Type:</label>
  <select id="from_type" name="from_type">
$from_opt
  </select>
  <label for="to_type">To Type:</label>
  <select id="to_type" name="to_type">
$to_opt
  </select>
FORM1

print <<"CHAPTER" if @CTR;
  <label for="chapter">In Chapter:</label>
  <select id="chapter" name="chapter">
$chap_opt
  </select>
CHAPTER

print <<"DEPTH" if @DEP;
  <label for="depth">Synth Chain  Max:</label>
  <select id="depth" name="depth">
$dep_opt
  </select>
DEPTH

print <<"FORM2";
  <input type="submit" value="BAKE ME A CAKE!" formtarget="atelier_recipe_results">
  <input type="hidden" id="game"      name="game"      value="$GAM">
  <input type="hidden" id="materials" name="materials" value="$MAT">
FORM2

$TYP = join ",", split /,/oi, $types || undef;
print <<"FORM3" if $TYP;
  <input type="hidden" id="types"     name="types"     value="$TYP">
FORM3

print <<"FORM4" if $TYP;
</form>
<iframe id="atelier_recipe_results" name="atelier_recipe_results"></iframe>
FORM4
