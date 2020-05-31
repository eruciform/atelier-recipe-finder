#!/bin/env perl -w

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
  my $self  = {
    name     => $name,
    type     => $type,
    label    => $name, # label is changed for "Add" materials, but don't change name, it's used for taxonomy searches
    category => { map {$_=>1} @{$cat}  },
    optional => { map {$_=>1} @{$opt}  },
    required => { map {$_=>1} @{$req}  },
    from     => { map {$_=>1} @{$from} },
  };
  return bless $self, $class;
}

sub clone($) { 
  my $self  = shift;
  my $clone = {
    name     => $self->name,
    type     => $self->type,
    label    => $self->label,
    category => { map {$_=>1} $self->category },
    optional => { map {$_=>1} $self->optional },
    required => { map {$_=>1} $self->required },
    from     => { map {$_=>1} $self->from     },
  };
  return bless $clone, ref $self;
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

1;
