#!/usr/bin/env perl

=head1 DESCRIPTION

This is the atelier::recipe_book class, the main tool for containing a list of
recipes and materials, and for creating the graph of all recipes starting at
some point and ending at some point.

This is not your usual Djikstra search. In addition to the fact that nodes have
both names and TYPES (categories like (Ore) or (Thread)), we also have reused
nodes (so it's a graph, not a tree that we're creating), and we also have the
additional requirement that the result be "interesting".

It would have been much simpler to make simply a least-spanning-tree and then
limit everything else to that length. However, that's a bit boring. There are
some unique and interesting paths that are just a little bit longer than the
shortest path, and I wanted to show them, too. This is more closely defined as:

All unique paths without common subtrees.

So, the algorithm works as follows:

1. For each node, do a depth first search down the tree of things that either
the current node can directly fit into, or that one of the current node's
categories can fit into
2. Each layer, keep track of both the name of the thing used, and also the
category it was "used as", to make sure it's not reused on a subtree
3. When a dead end is reached, keep track of it so that later traversals
don't waste their time
4. But for dead ends, keep track of the depth at which the dead end was determined,
because sometimes it was only considered a dead end due to an arbitrary depth
limit, and trying again a little lower might let it complete
5. Critically, also keep track of where other recipes are used in the tree thus
far, so that:
5A. If a subtree finds the same recipe at a shallower point, it can quit early,
since the previous usage would be more efficient
5B. If a subtree finds the same recipe at a deeper point, it can invalidate
that deeper point so that it's not used by any subtrees leading into that
inefficient path
6. For the invalidation, it uses two methods:
6A. It "redepth's" that subtree to mark it as being earlier on the graph, so that
in the chain extraction process later, it can tell there's something disjoint and
not "count" that subtree
6B. It also removes all linkages from that subtree going forwards, effectively 
destroying it and having to recreate it; this is critical because a subtree found
later on, on some alternate path, might not have the same restrictions as one
from where we are now - there's no way to fix it, it has to be remade

This "yanking" of later subtrees forwards is finite because it can only go so
far as the root node, so this trends towards being very restrictive, and is
one of the main reasons why the algorithm is pretty fast. The depth restriction
ended up being unneeded for Ryza, even though it has 183 recipes and as many
materials, and a 200-factorial set of permutations in a depth first search would
ordinarily be impossible. However, these restrictions of no reuse of a recipe,
or of anything "used as" a particular category, and also of this "yanking later
similar subtrees forwards" makes it so that even the most complex paths take a
second of running time.

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

package atelier::recipe_book;

require Exporter;
our @ISA = qw(Exporter);

our $DEBUG = 0;
sub DPAT { my $depth = shift; return substr("-+-|" x (($depth+3)/4), 0, $depth); }
sub DEBUG { my $depth = shift; print DPAT($depth), @_, "\n" if $DEBUG; }


use atelier::recipe;
use atelier::material;
use atelier::synthesis;

sub new {
  my $class  = shift;
  my $file   = shift;
  my $filter = shift || sub { my %a = @_; return 1 if $a{Type} !~ /synth|gather|material/oi; };
  my $delim  = shift || ",";
  my $self   = {
    by_name       => {}, # -> name -> material
    by_category   => {}, # -> cat  -> name -> material 
    by_optional   => {}, # -> opt  -> name -> material
    by_required   => {}, # -> ing  -> name -> material
    by_antecedent => {}, # -> name -> from -> material
    by_precedent  => {}, # -> from -> name -> material

    # global caches, not jsut local ones for the given branch:
    dead_end      => {}, # -> name  -> depth at which it was determined to be a dead end (try again if shallower)
    already_found => {}, # -> label -> recipe array (as though went thru calculations)
  };
  $self = bless $self, $class;
  $self->add_materials($file, $filter, $delim);
  return $self;
}

sub clear_cache($) {
  my $self = shift;
  $self->{dead_end     } = {};
  $self->{already_found} = {};
}

sub add_materials($$) {
  my $self   = shift;
  my $file   = shift;
  my $filter = shift || undef; # closure that takes hash of row data
  my $delim  = shift || ",";
  my $csv;
  open $csv, "<$file" or die "Cannot open file $file $!";
  my $header = scalar(<$csv>);
  chomp $header;
  my @header = split /$delim/, $header;
  while(<$csv>) {
    chomp;
    my @data = split /$delim/;
    my %data = map { $header[$_] => $data[$_] } (0 .. $#data);
    next if defined $filter and $filter->(%data);
    my $material = new atelier::material( $data{Name}, 
                                          $data{Type} || "Material",
                                          [grep /\S/oi, grep { defined $_ } map { $data{     "Category $_"} } (1 .. 4)],
                                          [grep /\S/oi, grep { defined $_ } map { $data{ "Add Category $_"} } (1 .. 4)],
                                          [grep /\S/oi, grep { defined $_ } map { $data{   "Ingredient $_"} } (1 .. 4)],
                                          [grep /\S/oi, grep { defined $_ } map { $data{  "From Recipe $_"} } (1 .. 2)],
                                        );
    $self->{by_name      }->{$material->name}                     = $material;
    $self->{by_category  }->{$_             }->{$material->name } = $material for $material->category;
    $self->{by_optional  }->{$_             }->{$material->name } = $material for $material->optional;
    $self->{by_required  }->{$_             }->{$material->name } = $material for $material->required;
    $self->{by_antecedent}->{$material->name}->{$_              } = $material for $material->from    ;
    $self->{by_precedent }->{$_             }->{$material->name } = $material for $material->from    ;
  }
  close $csv;
}

# takes material label or category name
sub getdeadend($$)  { my $self = shift; my $label = shift(); return exists $self->{dead_end}->{$label} ? $self->{dead_end}->{$label} : undef; }
sub setdeadend($$$) { my $self = shift; my $label = shift();               $self->{dead_end}->{$label} = shift(); }

# takes material label or category name, returns recipe array or ()
sub getalreadyfound($$)  { my $self = shift; my $label = shift(); return () unless exists $self->{already_found}->{$label}; return @{$self->{already_found}->{$label}}; }
sub setalreadyfound($$$) { my $self = shift; my $label = shift(); my $recs = shift;       $self->{already_found}->{$label} = [@$recs]; }

sub byname(      $$) { my $self = shift; my $search = shift; return exists $self->{by_name      }->{$search} ?          $self->{by_name      }->{$search}  : undef }
sub bycategory(  $$) { my $self = shift; my $search = shift; return exists $self->{by_category  }->{$search} ?   keys %{$self->{by_category  }->{$search}} : ()    }
sub byoptional(  $$) { my $self = shift; my $search = shift; return exists $self->{by_optional  }->{$search} ?   keys %{$self->{by_optional  }->{$search}} : ()    }
sub byrequired(  $$) { my $self = shift; my $search = shift; return exists $self->{by_required  }->{$search} ?   keys %{$self->{by_required  }->{$search}} : ()    }
sub byantecedent($$) { my $self = shift; my $search = shift; return exists $self->{by_antecedent}->{$search} ?   keys %{$self->{by_antecedent}->{$search}} : ()    }
sub byprecedent( $$) { my $self = shift; my $search = shift; return exists $self->{by_precedent }->{$search} ?   keys %{$self->{by_precedent }->{$search}} : ()    }

sub manycategory(  $@) { my $self = shift; my @search = @_; return   keys %{{ map { exists $self->{by_category  }->{$_} ? %{$self->{by_category  }->{$_}} : () } @search }} }
sub manyoptional(  $@) { my $self = shift; my @search = @_; return   keys %{{ map { exists $self->{by_optional  }->{$_} ? %{$self->{by_optional  }->{$_}} : () } @search }} }
sub manyrequired(  $@) { my $self = shift; my @search = @_; return   keys %{{ map { exists $self->{by_required  }->{$_} ? %{$self->{by_required  }->{$_}} : () } @search }} }
sub manyantecedent($@) { my $self = shift; my @search = @_; return   keys %{{ map { exists $self->{by_antecedent}->{$_} ? %{$self->{by_antecedent}->{$_}} : () } @search }} }
sub manyprecedent( $@) { my $self = shift; my @search = @_; return   keys %{{ map { exists $self->{by_precedent }->{$_} ? %{$self->{by_precedent }->{$_}} : () } @search }} }

sub allname(      $) { my $self = shift; keys %{$self->{by_name      }}; }
sub allcategory(  $) { my $self = shift; keys %{$self->{by_category  }}; }
sub alloptional(  $) { my $self = shift; keys %{$self->{by_optional  }}; }
sub allrequired(  $) { my $self = shift; keys %{$self->{by_required  }}; }
sub allantecedent($) { my $self = shift; keys %{$self->{by_antecedent}}; }
sub allprecedent( $) { my $self = shift; keys %{$self->{by_precedent }}; }

# given name and current depth of processing
sub checkalreadyfound($$$) {
  my $self  = shift;
  my $name  = shift;
  my $depth = shift;
  my @alreadyfound = $self->getalreadyfound($name);
  if( @alreadyfound ) {
    my $alreadylen = scalar @alreadyfound;
    my $minfound = undef;
    my $maxfound = undef;
    foreach my $af ( @alreadyfound ) {
      $minfound = (not defined $minfound) ? $af->depth : ($af->depth < $minfound) ? $af->depth : $minfound;
      $maxfound = (not defined $maxfound) ? $af->depth : ($af->depth > $maxfound) ? $af->depth : $maxfound;
    }
    DEBUG($depth, $name, " ", "alreadyfound ",
          join(", ",(map { $_->material->label . "(" . $_->depth . ")" } @alreadyfound)),
          " current depth $depth, min $minfound max $maxfound");
    my @alreadymin; # anything past that has been cut off somewhere along the line and should be left behind
    foreach my $af ( @alreadyfound ) {
      push @alreadymin, $af if $af->depth == $minfound;
    }
    if( $minfound > $depth ) {
      # annihilate it all and let it get recalced later, as there's no way to save it. Once you yank it out of
      # it's context, there's no telling what else will change. at least by making sure that this always reduces
      # the depth over time makes it finite, so it can't explode exponentially.
      DEBUG($depth, $name, " ", "alreadyfound > current depth: redepth and annihiliate it so it can me remade");
      $_->redepth($depth) for @alreadymin;
      return undef;
    } elsif( $minfound < $depth ) {
      DEBUG($depth, $name, " ", "alreadyfound < current depth: halt");
      return [];
    }
    my %seen;
    my @nonblank = grep { scalar($_->into) > 0 } grep { !$seen{$_}++ } @alreadymin;
    DEBUG($depth, $name, " ", "alreadyfound == current depth: return without redepthing") if @nonblank;
    return \@nonblank                                                                     if @nonblank;
    DEBUG($depth, $name, " ", "alreadyfound == current depth: no nonblanks, must recalc");
    return undef;
  }
  return undef;
}

sub _find_recursive_graph($$$$$$) {
  my $self   = shift;
  my $item   = shift; # material, not recipe
  my $finish = shift; # material, not recipe
  my $cache  = shift; # hash of found material names and type names
  my $depth  = shift;
  my $maxdep = shift;
  my $layer;

  DEBUG($depth, $item->label, " ", "find_recursive_graph");

  DEBUG($depth, $item->label, " ", "reject depth ", $depth, " > ", $maxdep) if defined $maxdep and $depth > $maxdep;
  return ()                                                                 if defined $maxdep and $depth > $maxdep;

  # first check to see if we're done
  # note: we're not checking if we have the endpoint elsewhere on the tree - that makes it a bit boring, we could
  # never have differently-sized branches ever if we did that - implement that here if that changes
  if( $item->name eq $finish->name or $item->iscategory($finish->name) ) {
    DEBUG($depth, $item->label, " ", "found item or category");
    return atelier::recipe->new($item, $depth, undef, undef, 1);
  }
  elsif( $item->isoptional($finish->name) ) {
    DEBUG($depth, $item->label, " ", "found item or category, add ", $finish->name);
    return atelier::recipe->new($item->add($finish->name), $depth, undef, undef, 1);
  }

  # if we're just barely at the edge of the depth limit and haven't already found the result, quit now
  DEBUG($depth, $item->label, " ", "rejecting depth == maxdepth") if defined $maxdep and $depth == $maxdep;
  return ()                                                       if defined $maxdep and $depth == $maxdep;
  
  # only check for the item itself not being used again, it's okay if we needed a leather
  # category before and now also need an item that happens to be leather but isn't being used
  # for that purpose
  DEBUG($depth, $item->label, " ", "rejecting cache already exists") if exists $cache->{$item->name};
  return ()                                                          if exists $cache->{$item->name};

  # above is the local cache, this is the global cache that we know won't pan out, don't bother
  # but only if it's deeper in, as the rejection might have been because of depth cutoff, so a
  # shallower start might return data
  my $deadend = $self->getdeadend($item->label);
  DEBUG($depth, $item->label, " ", "rejecting dead end $deadend <= $depth") if defined $deadend and $deadend <= $depth;
  return ()                                                                 if defined $deadend and $deadend <= $depth;

  # also, if we already found this item has a positive result, just short circuit and return it, don't calc again
  my $alreadyfound = $self->checkalreadyfound($item->label, $depth);
  return @$alreadyfound if ref $alreadyfound;

  # clone it so we don't affect things below us
  $cache = { %{$cache}, $item->name => 1 };
  $layer = { %{$cache}, map { $_=>1 } ( $item->name, $item->category, $item->optional ) };

  # otherwis e moveforward potentially adding to te movehe recipe, and returning list of recipes if they have any child nodes by the end
  # add to the main recipe as we go, and check to see if it's empty later
  # separately, the optional recipes will get filled with separate recipes, because they have different versions of the item
  my @optional_recipes;
  my $main_recipe = atelier::recipe->new($item, $depth);

  # look for recipe graph that start with ones that take this item as a direct ingredient (by name, not type)
  foreach my $next ($self->byrequired($item->name)) {
    DEBUG($depth, $item->label, " ", "trying material $next");
    my @found = $self->_find_recursive_graph($self->byname($next), $finish, $cache, $depth+1, $maxdep);
    next unless @found;
    my %seen;
    atelier::synthesis->new("Synth", $main_recipe, $_) for grep { !$seen{$_}++ } @found;
  }

  # then look for recipes that take any of this item's mandatory categories
  # but skip any that we've seen before, which is why we didn't add %norepeat in yet, as we'd skip everything
  foreach my $cat ($item->category) {
    DEBUG($depth, $item->label, " ", "trying category $cat");
    DEBUG($depth, $item->label, " ", "rejecting cache exists") if exists $cache->{$cat};
    next                                                       if exists $cache->{$cat};
    my $deadend = $self->getdeadend($cat);
    DEBUG($depth, $item->label, " ", "rejecting dead end $deadend <= $depth") if defined $deadend and $deadend <= $depth;
    next                                                                      if defined $deadend and $deadend <= $depth;
    my @allfound;
    my $found = 0;
    foreach my $next ($self->byrequired($cat)) {
      DEBUG($depth, $item->label, " ", "trying category $cat material $next");
      my @found = $self->_find_recursive_graph($self->byname($next), $finish, {%$cache, $cat=>1}, $depth+1, $maxdep);
      next unless @found;
      push @allfound, @found;
      $found++
    }
    $self->setdeadend($cat, $depth+1) unless $found;
    next unless @allfound;
    my %seen;
    atelier::synthesis->new("Synth", $main_recipe, $_) for grep { !$seen{$_}++ } @allfound;
  }

  # then look for recipes that take any of this item's OPTIONAL categories
  foreach my $cat ($item->optional) {
    DEBUG($depth, $item->label, " ", "trying opt category $cat");
    DEBUG($depth, $item->label, " ", "rejecting cache exists") if exists $cache->{$cat};
    next                                    if exists $cache->{$cat};
    my $deadend = $self->getdeadend($cat);
    DEBUG($depth, $item->label, " ", "rejecting dead end $deadend <= $depth") if defined $deadend and $deadend <= $depth;
    next                                                                      if defined $deadend and $deadend <= $depth;
    my @allfound;
    my $found = 0;
    foreach my $next ($self->byrequired($cat)) {
      DEBUG($depth, $item->label, " ", "trying category $cat material $next");
      my @found = $self->_find_recursive_graph($self->byname($next), $finish, {%$cache, $cat=>1}, $depth+1, $maxdep);
      next unless @found;
      push @allfound, @found;
      $found++
    }
    $self->setdeadend($cat, $depth+1) unless $found;
    next unless @allfound;
    my $addrecipe = atelier::recipe->new($item->add($cat), $depth);
    my %seen;
    atelier::synthesis->new("Synth", $addrecipe, $_) for grep { !$seen{$_}++ } @allfound;
    push @optional_recipes, $addrecipe;
  }

  # finally, look for recipes that can be converted into from this one
  foreach my $next ($self->byprecedent($item->name)) {
    DEBUG($depth, $item->label, " ", "trying antecedent $next");
    my @found = $self->_find_recursive_graph($self->byname($next), $finish, $cache, $depth+1, $maxdep);
    next unless @found;
    my %seen;
    atelier::synthesis->new("Convert", $main_recipe, $_) for grep { !$seen{$_}++ } @found;
  }

  my @recipes = @optional_recipes;
  push @recipes, $main_recipe if scalar $main_recipe->into;
  my %seen;
  @recipes = grep { !$seen{$_}++ } @recipes;
  DEBUG($depth, $item->label, " ", "found recipes starting with ", $_->material->label, " ", join ", ", map { $_->type . " " . $_->into->material->label } $_->into ) for @recipes;

  if( @recipes ) {
    $self->setalreadyfound($item->label, \@recipes);
  } else {
    $self->setdeadend($item->label, $depth);
  }
  return @recipes;
}

sub find_recipe_graph($$$) {
  my $self   = shift;
  my $start  = shift; # name of recipe, type, or itself a recipe object (might be a non-recipe material)
  my $finish = shift; # name of recipe, type, or itself a recipe object
  my $maxdep = shift || undef;

  $self->clear_cache();

  my  $start_item = ref $start  ? $start  : $self->byname($start ) ? $self->byname($start ) : $self->bycategory($start ) ? atelier::material->new($start ,"Type",[$start ]) : undef;
  my $finish_item = ref $finish ? $finish : $self->byname($finish) ? $self->byname($finish) : $self->bycategory($finish) ? atelier::material->new($finish,"Type",[$finish]) :
                                                                                              $self->byoptional($finish) ? atelier::material->new($finish,"Type",[$finish]) : undef;

  # first check if it's possible at all. if we can't even identify it, toss it:
  return () if not defined $start_item or not defined $finish_item;

  # then check whether there are any ingredient requirements that include any of the categories or optional categories at all
  # or at least something that can be converted at all, otherwise boot it
  return () if not scalar $self->manyrequired(  $start_item->category ) and
               not scalar $self->manyrequired(  $start_item->optional ) and
               not scalar $self->manyrequired(  $start_item->name     ) and
               not scalar $self->manyprecedent( $start_item->name     );

  my $cache = {};
  return $self->_find_recursive_graph($start_item, $finish_item, $cache, 1, $maxdep);
}








1;
