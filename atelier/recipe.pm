#!/usr/bin/env perl

=head1 DESCRIPTION

The atelier::recipe class definition, which contains atelier::material objects for
the actual type and category and ingredient information, and also atelier::synthesis
objects, which are the linkage objects that point from one recipe to another along
a chain. Generally there's one recipe per material, and materials are unique, though
in the case of "material add (foo)" when a recipe can have an optional category,
there will be an extra copy.

Other than accessors and mutators, there's also redepth and the extract_chains
functions. 

Redepth is for setting the base of a subtree to a new depth (because in
the algorithm, if a subtree is found to be "deeper" somewhere else in the graph, it's
"grabbed and pulled forwards"). However in doing so, it needs to invalidate every
subtree that connects to it thus far. It's too complex to try to disconnect it going
backwards, so it simply yanks all synthesis pointers going forwards from anywhere on
that subtree, and also changes the "depth from root node". Later, during extract,
mismatches of these depths are taken as information for ignoring these dead subtrees.

And as for extract_chain - the main recipe_book's graph generation makes a node graph
but not a list of recipe lists. This does a depth first search to make a list of all
paths from the graph. However, it's also careful to look for depth mismatches or dead
ends that were the algorithm's way to mark inefficient trees so that they don't end up
in the final list.

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

package atelier::recipe;

require Exporter;
our @ISA = qw(Exporter);

our $DEBUG = 0;
sub DPAT { my $depth = shift; return substr("-+-|" x (($depth+3)/4), 0, $depth); }
sub DEBUG { my $depth = shift; print DPAT($depth), @_, "\n" if $DEBUG; }

sub new {
  my $class = shift;
  my $mat   = shift;
  my $depth = shift || undef;
  my $from  = shift || undef;
  my $into  = shift || undef;
  my $found = shift || 0;
  my $self  = {
    material => $mat,
    from     => [ defined $from ? ($from) : () ],
    into     => [ defined $into ? ($into) : () ],
    depth    => $depth,
    found    => $found,
  };
  return bless $self, $class;
}

sub material($) { my $self = shift; return   $self->{material}; }
sub from($)     { my $self = shift; return @{$self->{from}};    }
sub into($)     { my $self = shift; return @{$self->{into}};    }

sub depth($)    { my $self = shift; $self->{depth}; }
sub setdepth($$){ my $self = shift; $self->{depth} = shift; }

sub found($)    { my $self = shift; $self->{found}; }
sub setfound($$){ my $self = shift; $self->{found} = shift; }

sub redepth($$) {
  my $self  = shift;
  my $depth = shift;
  DEBUG($self->depth,"redepthing ", $self->material->label, " from curr depth ", $self->depth, " but first diving to end");
  $_->into->redepth($depth+1) for $self->into;
  DEBUG($self->depth,"redepthing ", $self->material->label, " from curr depth ", $self->depth, " setting to $depth and erasing forward links");
  $self->setdepth($depth);
  $self->delinto();
}

sub addinto($@) { my $self = shift; push @{$self->{into}}, @_; }
sub addfrom($@) { my $self = shift; push @{$self->{from}}, @_; }

sub delinto($)  { my $self = shift;        $self->{into} = []; }
sub delfrom($)  { my $self = shift;        $self->{from} = []; }

sub extract_chains($) {
  my $self = shift;
  my %chain_list;
  my @current_chain;
  $self->_extract_chains(\%chain_list, \@current_chain, 1);
  return sort { scalar @$a <=> @$b } values %chain_list;
}

sub _extract_chains($$$$) {
  my $self  = shift;
  my $list  = shift;
  my $curr  = shift;
  my $depth = shift;
  push @{$curr}, $self->material->label;
  # if we're at a leaf in the node, write the current path
  # otherwise dig deeper
  DEBUG($depth, "extract_chains ", $self->material->label, " this->depth=", $self->depth);
  if(scalar $self->into) {
    my %seen;
    foreach my $synth ( $self->into ) {
      if( $synth->into->found ) {
        DEBUG($depth, "accepting next link ", $synth->into->material->label, " depth ", $synth->into->depth, " that is the found item");
        $synth->_extract_chains($list, $curr, $depth+1);
      }
      elsif( $synth->into->depth == $self->depth + 1 ) {
        DEBUG($depth, "accepting next link ", $synth->into->material->label, " depth ", $synth->into->depth, " == this->depth+1 =", $self->depth + 1);
        $synth->_extract_chains($list, $curr, $depth+1);
      } else {
        DEBUG($depth, "rejecting next link ", $synth->into->material->label, " depth ", $synth->into->depth, " != this->depth+1 =", $self->depth + 1);
        # otherwise this is a reforged chain that got yanked from later in the 
        # graph downwards, so it's no longer valid, as a shorter chain is better
      }
    }
  }
  elsif( $self->found ) {
    DEBUG($depth, "creating chain ", join("->", @{$curr}));
    $list->{join ",", @{$curr}} = [@{$curr}];
  } else {
    DEBUG($depth, "dead link");
  }
  pop @{$curr};
}

1;
