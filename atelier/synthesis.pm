#!/opt/bin/env perl

=head1 DESCRIPTION

This is the atelier::synthesis class. It's a glue object that points one recipe in the
graph to the next and affixes some information on it like "Synth" for a direct synthesis
step, or other things like "Convert" as used in Ryza when one recipe can become another.

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

package atelier::synthesis;

require Exporter;
our @ISA = qw(Exporter);

sub new {
  my $class = shift;
  my $type  = shift;
  my $from  = shift;
  my $into  = shift;
  my $self  = {
    type  => $type,
    from  => $from,
    into  => $into,
  };
  $from->addinto($self);
  $into->addfrom($self);
  return bless $self, $class;
}

sub type( $) { my $self = shift; return $self->{type}; }
sub from( $) { my $self = shift; return $self->{from}; }
sub into( $) { my $self = shift; return $self->{into}; }

sub _extract_chains($$$$) {
  my $self  = shift;
  my $list  = shift;
  my $curr  = shift;
  my $depth = shift;
  push @{$curr}, $self->type;
  $self->into->_extract_chains($list, $curr, $depth);
  pop @{$curr};
}

1;
