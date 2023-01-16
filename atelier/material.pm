#!/usr/bin/env perl

=head1 DESCRIPTION

Class definition for atelier::material, the root data for one row of info from the
recipes or materials files. The atelier::recipe objects wrap around this and are used
as the "node" and "tree" elements that hold materials.

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

package atelier::material;

require Exporter;
our @ISA = qw(Exporter);

sub new {
  my $class = shift;
  my $name  = shift;
  my $type  = shift;
  my $cat   = shift;
  my $opt   = shift || [];
  my $req   = shift || [];
  my $from  = shift || [];
  my $ftype = shift || [];
  # The "from" hash no longer simply points to 1 if there is a "from" recipe,
  # instead it points to a hash of "type" names that it came from. So if this material
  # came from X as type Convert and Y as type Convert and Y also as type EV-Link,
  # then:
  # self->{from} = { X=>{Convert=>1}, Y=>{Convert=>1, "EV-Link"=>1} }
  my %fromhash = ();
  for my $n (0 .. $#{$from}) {
    $fromhash{$from->[$n]} ||= {};
    $fromhash{$from->[$n]}->{($n <= $#{$ftype} ? $ftype->[$n] : "Convert")} = 1;
  }
  my $self  = {
    name     => $name,
    type     => $type,
    label    => $name, # label is changed for "Add" materials, but don't change name, it's used for taxonomy searches
    category => { map {$_=>1} @{$cat}  },
    optional => { map {$_=>1} @{$opt}  },
    required => { map {$_=>1} @{$req}  },
    from     => \%fromhash,
  };
  return bless $self, $class;
}

sub clone($) { 
  my $self  = shift;
  my %fromhash = ();
  for my $f ( $self->from ) {
    $fromhash{$f} = { %{$self->{from}->{$f}} };
  }
  my $clone = {
    name     => $self->name,
    type     => $self->type,
    label    => $self->label,
    category => { map {$_=>1} $self->category },
    optional => { map {$_=>1} $self->optional },
    required => { map {$_=>1} $self->required },
    from     => \%fromhash,
  };
  return bless $clone, ref $self;
}

sub replace_from($$$@) {
  # used for "*" requirement of the Failure Ash in Atelier Sophie
  my $self  = shift;
  my $cat   = shift;
  my $types = shift; # must be a hash of 1s, this should be reworked
  my @with  = @_;
  return unless $self->isfrom($cat);
  delete $self->{from}->{$cat};
  $self->{from} = { %{$self->{from}}, map {$_->name=>$types} @with };
}

sub add($$) {
  my $self  = shift;
  my $add   = shift;
  my $clone = $self->clone();
  $clone->{label} = $self->name . " + Add " . $add;
  return $clone;
}

sub iscategory($$) { my $self = shift; return exists $self->{category}->{shift()}; }
sub isoptional($$) { my $self = shift; return exists $self->{optional}->{shift()}; }
sub isrequired($$) { my $self = shift; return exists $self->{required}->{shift()}; }
sub isfrom    ($$) { my $self = shift; return exists $self->{from    }->{shift()}; }

sub name(    $) { my $self = shift; return        $self->{name     }; }
sub label(   $) { my $self = shift; return        $self->{label    }; }
sub type(    $) { my $self = shift; return        $self->{type     }; }
sub category($) { my $self = shift; return keys %{$self->{category}}; }
sub optional($) { my $self = shift; return keys %{$self->{optional}}; }
sub required($) { my $self = shift; return keys %{$self->{required}}; }
sub from    ($) { my $self = shift; return keys %{$self->{from    }}; }

sub fromtypes($$) { my $self = shift; my $from = shift; return keys %{$self->{from}->{$from}}; }

1;
