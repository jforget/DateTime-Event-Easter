# -*- encoding: utf-8; indent-tabs-mode: nil -*-
#
#     Perl DateTime extension for computing the dates for Easter and related feasts
#     Copyright © 2003-2004, 2015, 2019 Rick Measham and Jean Forget, all rights reserved
#
#     See the license in the embedded documentation below.
#
package DateTime::Event::Easter;

use utf8;
use DateTime;
use DateTime::Set;
use Carp;
use Params::Validate qw( validate SCALAR BOOLEAN OBJECT );

use strict;
use warnings;
use vars qw(
    $VERSION @ISA @EXPORT @EXPORT_OK 
);

require Exporter;

@ISA = qw(Exporter);

@EXPORT_OK = qw(easter);
$VERSION = '1.07';

sub new {
    my $class = shift;
    my %args  = validate( @_,
                    {   easter  => { type => SCALAR, default => 'western', optional => 1, regex => qr/^(western|eastern)$/i },
                        day     => { type => SCALAR, default => 'sunday' , optional => 1 },
                        as      => { type => SCALAR, default => 'point'  , optional => 1 },
                    }
                );
    
    my %self;
    my $offset;
    if ($args{day} =~ /^fat/i) {
        $offset = -47;
    }
    elsif ($args{day} =~ /^ash/i) {
        # First day of lent. Lent lasts for 40 days, excluding sundays.
        # This translates to a 46-day duration, including sundays.
        $offset = -46;
    }
    elsif ($args{day} =~ /^ascension/i) {
        $offset = 39;
    }
    elsif ($args{day} =~ /^pentecost/i) {
        $offset = 49;
    }
    elsif ($args{day} =~ /^trinity/i) {
        $offset = 56;
    }
    elsif ($args{day} =~ /^palm/i) {
        $offset = -7;
    } elsif ($args{day} =~ /saturday/i) {
        $offset = -1;
    } elsif ($args{day} =~ /friday/i) {
        $offset = -2;
    } elsif ($args{day} =~ /thursday/i) {
        $offset = -3;
    } elsif ($args{day} =~ /^\-?\d+$/i) {
        $offset = $args{day};
        if ($offset < -80 || $offset > 250) {
          croak "The number of days must be between -80 and 250";
        }
    } else {
        $offset = 0;
    }
    $self{offset} = DateTime::Duration->new(days=>$offset);
    $self{easter} = lc $args{easter};
   
    if ($self{easter} eq 'eastern') {
        require DateTime::Calendar::Julian;
    }

    # Set to return points or spans
    die("Argument 'as' must be 'point' or 'span'.") unless $args{as} =~ /^(point|span)s?$/i;
    $self{as} = lc $1;

    return bless \%self, $class;
    
}


sub following {
  my $self = shift;
  my $dt   = shift;
  croak ("Dates need to be datetime objects")
    unless $dt->can('utc_rd_values');

    my $class = ref($dt);
    if ($self->{easter} eq 'eastern' && $class ne 'DateTime::Calendar::Julian') {
        $dt = DateTime::Calendar::Julian->from_object(object=>$dt);
    } elsif ($class ne 'DateTime') {
        $dt = DateTime->from_object(object=>$dt);
    }

    my $easter_this_year = $self->_easter($dt->year)+$self->{offset};

    my $easter = ($easter_this_year > $dt) 
        ? $easter_this_year
        : $self->_easter($dt->year+1)+$self->{offset};

    $easter = $class->from_object(object=>$easter) if (ref($easter) ne $class);
    return ($self->{as} eq 'span') 
        ? _tospan($easter)
        : $easter;
}

sub previous {
  my $self = shift;
  my $dt   = shift;
  croak ("Dates need to be datetime objects")
    unless $dt->can('utc_rd_values');
   
    my $class = ref($dt);
    if ($self->{easter} eq 'eastern' && $class ne 'DateTime::Calendar::Julian') {
        $dt = DateTime::Calendar::Julian->from_object(object=>$dt);
    } elsif ($class ne 'DateTime') {
        $dt = DateTime->from_object(object=>$dt);
    }

    my $easter_this_year = $self->_easter($dt->year)+$self->{offset};

    my $easter = ($easter_this_year->ymd lt $dt->ymd)
       ? $easter_this_year
       : $self->_easter($dt->year-1)+$self->{offset};


    $easter = $class->from_object(object=>$easter) if (ref($easter) ne $class);
    return ($self->{as} eq 'span') 
        ? _tospan($easter)
        : $easter;
}

sub closest {
  my $self = shift;
  my $dt   = shift;
  croak ("Dates need to be datetime objects")
    unless $dt->can('utc_rd_values');

    my $class = ref($dt);
    if ($class ne 'DateTime') {
      $dt = DateTime->from_object(object => $dt);
    }

    if ($self->is($dt)) {
      my $easter = $dt->clone->truncate(to=>'day');
      $easter    = $class->from_object(object=>$easter) if (ref($easter) ne $class);
      return ($self->{as} eq 'span') 
                        ? _tospan($easter)
                        : $easter;
    }
    my $following_easter = $self->following($dt);
    my $following_delta  = $following_easter - $dt;
    my $previous_easter  = $self->previous($dt);
        
    my $easter = ($previous_easter + $following_delta < $dt) 
        ? $following_easter 
        : $previous_easter;
    $easter = $class->from_object(object=>$easter) if (ref($easter) ne $class);
    return ($self->{as} eq 'span') 
        ? _tospan($easter)
        : $easter;
}

sub is {
  my $self = shift;
  my $dt   = shift;
  croak ("Dates need to be datetime objects")
    unless $dt->can('utc_rd_values');

    my $class = ref($dt);
    if ($class ne 'DateTime') {
        $dt = DateTime->from_object(object=>$dt);
    }

    if ($self->{easter} eq 'eastern') {
        $dt = DateTime::Calendar::Julian->from_object(object=>$dt)   
    }

    my $easter_this_year = $self->_easter($dt->year)+$self->{offset};

    return ($easter_this_year->ymd eq $dt->ymd) ? 1 : 0;
}

sub as_list {
    my $self = shift;
    my %args  = validate( @_,
                    {   from        => { type => OBJECT },
                        to          => { type => OBJECT },
                        inclusive   => { type => SCALAR, default => 0 },
                    }
                );
    
    # Make sure our args are in the right order
    ($args{from}, $args{to}) = sort ($args{from}, $args{to});
                
    my @set = ();
    
    if ($args{inclusive}) {
        if ($self->is($args{from})) {
            push @set, ($self->{as} eq 'span') 
                       ? _tospan($args{from})
                       : $args{from};
        }
        if ($self->is($args{to})) {
            push @set, ($self->{as} eq 'span') 
                       ? _tospan($args{to})
                       : $args{to};
        }
    }
    
    my $checkdate = $args{from};

    while ($checkdate < $args{to}) {
        my $check_obj = $self->following($checkdate);
        $checkdate = ($self->{as} eq 'span') 
                   ? $check_obj->start
                   : $check_obj;
        push(@set, $check_obj) if ($checkdate < $args{to});
    }
    
    return ($self->{as} eq 'span')
           ? sort { $a->start cmp $b->start} @set
           : sort @set;
}

sub as_old_set {
    my $self = shift;
    return DateTime::Set->from_datetimes( dates => [ $self->as_list(@_) ] );
}
sub as_set {
        my $self   = shift;
        my %args   = @_;
        my %args_1 = @_;
        if (exists $args{inclusive}) {
          croak("You must specify both a 'from' and a 'to' datetime")
                    unless ref($args{to})   =~ /DateTime/
                    and    ref($args{from}) =~ /DateTime/;
          if ($self->{as} eq 'point') {
            if ($args{inclusive}) {
                    $args{start}  = delete $args{from};
                    $args{end}    = delete $args{to};
            } else {
                    $args{after}  = delete $args{from};
                    $args{before} = delete $args{to};
            }
            delete $args{inclusive};
          }
        }
        elsif (exists $args{from} or exists $args{to}) {
          croak("You must specify both a 'from' and a 'to' datetime")
                     unless ref($args{to})   =~ /DateTime/
                     and    ref($args{from}) =~ /DateTime/;
          if ($self->{as} eq 'point') {
            $args{after}  = delete $args{from};
            $args{before} = delete $args{to};
          }
        }
        if ($self->{as} eq 'span') {
          $args_1{from} = delete $args_1{after}  if exists $args_1{after};
          $args_1{to}   = delete $args_1{before} if exists $args_1{before};
          my @list = $self->as_list(%args_1);
          return DateTime::SpanSet->from_spans( spans => [ @list ] ); 
        }
        else {
          return DateTime::Set->from_recurrence( 
                  next      => sub { return $_[0] if $_[0]->is_infinite; $self->following( $_[0] ) },
                  previous  => sub { return $_[0] if $_[0]->is_infinite; $self->previous(  $_[0] ) },
                  %args
                  );
        }
}

sub as_span {
    my $self = shift;
    $self->{as} = 'span';
    return $self;
}

sub as_point {
    my $self = shift;
    $self->{as} = 'point';
    return $self;
}

sub _tospan {
   return DateTime::Span->from_datetime_and_duration(
                start => $_[0],
                hours => 24,
   );
}

sub _easter {
    my $self = shift;
    my $year = shift;
    return ($self->{easter} eq 'eastern') 
        ? eastern_easter($year) 
        : western_easter($year);
}

sub western_easter {
    my $year = shift;
    croak "Year value '$year' should be numeric." if $year!~/^\-?\d+$/;
    
    my $golden_number = $year % 19;
    #quasicentury is so named because its a century, only its 
    # the number of full centuries rather than the current century
    my $quasicentury = int($year / 100);
    my $epact = ($quasicentury - int($quasicentury/4) - int(($quasicentury * 8 + 13)/25) + ($golden_number*19) + 15) % 30;
    my $interval = $epact - int($epact/28)*(1 - int(29/($epact+1)) * int((21 - $golden_number)/11) );
    my $weekday = ($year + int($year/4) + $interval + 2 - $quasicentury + int($quasicentury/4)) % 7;
    
    my $offset = $interval - $weekday;
    my $month = 3 + int(($offset+40)/44);
    my $day = $offset + 28 - 31* int($month/4);
    
    return DateTime->new(year=>$year, month=>$month, day=>$day);
}
*easter = \&western_easter; #alias so people can call 'easter($year)' externally

sub eastern_easter {
    my $year = shift;
    croak "Year value '$year' should be numeric." if $year!~/^\-?\d+$/;
    
    my $golden_number = $year % 19;

    my $interval = ($golden_number * 19 + 15) % 30;
    my $weekday = ($year + int($year/4) + $interval) % 7;
   
    my $offset = $interval - $weekday;
    my $month = 3 + int(($offset+40)/44);
    my $day = $offset + 28 - 31* int($month/4);

    return DateTime::Calendar::Julian->new(year=>$year, month=>$month, day=>$day);
}

# Ending a module with an unspecified number, which could be zero, is wrong.
# Therefore the custom of ending a module with a boring "1".
# Instead of that, end it with some verse.
q{
Il reviendra z-à Pâques, mironton mironton mirontaine,
Il reviendra z-à Pâques
Ou à la Trinité.
Ou à la Trinité...
};
__END__

=encoding utf-8

=head1 NAME

DateTime::Event::Easter - Returns Easter events for DateTime objects

=head1 SYNOPSIS

  use DateTime::Event::Easter;
  
  $dt = DateTime->new( year   => 2002,
                       month  =>    3,
                       day    =>   31,
                     );
  
  
  $easter_sunday = DateTime::Event::Easter->new();

  $previous_easter_sunday = $easter_sunday->previous($dt);
  # Sun, 15 Apr 2001 00:00:00 UTC
  
  $following_easter_sunday = $easter_sunday->following($dt);
  # Sun, 20 Apr 2003 00:00:00 UTC
  
  $closest_easter_sunday = $easter_sunday->closest($dt);
  # Sun, 31 Mar 2002 00:00:00 UTC
  
  $is_easter_sunday = $easter_sunday->is($dt);
  # 1
  
  $palm_sunday = DateTime::Event::Easter->new(day=>'Palm Sunday');


  $dt2 = DateTime->new( year   => 2006,
                        month  =>    4,
                        day    =>   30,
                      );
  
  $set  = $palm_sunday->as_set (from => $dt, to => $dt2, inclusive => 1);
  @list = $palm_sunday->as_list(from => $dt, to => $dt2, inclusive => 1);
  # Sun, 13 Apr 2003 00:00:00 UTC
  # Sun, 04 Apr 2004 00:00:00 UTC
  # Sun, 20 Mar 2005 00:00:00 UTC
  # Sun, 09 Apr 2006 00:00:00 UTC
  
  $datetime_set = $palm_sunday->as_set;
  # A set of every Palm Sunday ever. See DateTime::Set for more information.

=head1 DESCRIPTION

The DateTime::Event::Easter module returns Easter events for DateTime
objects. From a given datetime, it can tell you the previous, the
following and the closest Easter event. The 'is' method will tell you if
the given DateTime is an Easter Event.

Easter Events can be Fat Tuesday, Ash Wednesday, Palm Sunday, Maundy
Thursday, Good Friday, Black Saturday, Easter Sunday, Ascension,
Pentecost and Trinity Sunday. If that's not enough, the module will
also accept an offset so you can get the date for Quasimodo (the next
sunday after Easter Sunday) by passing 7.

=head1 BACKGROUND

Easter Sunday is the Sunday following the first full moon on or
following the Official Vernal Equinox. The Official Vernal Equinox is
March 21st. Easter Sunday is never on the full moon. Thus the earliest
Easter can be is March 22nd.

In the orthodox world, although they now use the Gregorian Calendar
rather than the Julian, they still take the first full moon on or after the
Julian March 21st. As the Julian calendar is slowly getting further and
further out of sync with the Gregorian, the first full moon after this
date can be a completely different one than for the western Easter. This
is why the Orthodox churches celebrate Easter later than western
churches.

=head1 CONSTRUCTOR

=head2 C<new> constructor

This class accepts the following options to its C<new> constructor:

=over 4

=item * easter => ([western]|eastern)

DateTime::Event::Easter understands two calculations for Easter. For
simplicity we've called them 'western' and 'eastern'.

Western Easter is the day celebrated by the Catholic and Protestant
churches. It falls on the first Sunday after the first Full
Moon on or after March 21st.

Eastern Easter, as celebrated by the Eastern Orthodox Churches similarly
falls on the first Sunday after the first Full Moon on or after
March 21st. However Eastern Easter uses March 21st in the Julian
Calendar.

By default this module uses the Western Easter. Even if you pass a
Julian DateTime to the module, you'll get back Western Easter unless you
specifically ask for Eastern.

If this parameter is not supplied, the western Easter will be used.

=item * day => ([Easter Sunday]|Palm Sunday|Maundy Thursday|Good Friday|Black
Saturday|Fat Tuesday|Ash Wednesday|Ascension|Pentecost|Trinity Sunday|I<n>)

When constructed with a day parameter, the method can return associated
Easter days other than Easter Sunday. The constructor also allows an
integer to be passed here as an offset. For example, Maundy Thursday is
the same as an offset of -3 (Three days before Easter Sunday)
The numeric offset must be in the -80 .. +250 interval.

When constructed without a day parameter, the method uses the date for
Easter Sunday (which is the churches' official day for 'Easter', think
of it a 'Easter Day' if you want)

This parameter also allows the following abreviations: day =>
([Sunday]|Palm|Thursday|Friday|Saturday|Fat|Ash|Ascension|Pentecost|Trinity)

=item * as => ([point]|span)

By default, all returns are single points in time. Namely they are the
moment of midnight for the day in question. If you want Easter 2003 then
you actually get back midnight of April 20th 2003. If you specify 
C<< as => 'span' >> in your constructor, you'll now receive 24 hour spans
rather than moments (or 'points'). I<See also the C<as_span> and C<as_point>
methods below>

=back

=head1 METHODS

For all these methods, unless otherwise noted, C<$dt> is a plain vanilla
DateTime object or a DateTime object from any DateTime::Calendar module
that can handle calls to C<from_object> and C<utc_rd_values> (which should be
all of them, but there's nothing stopping someone making a bad egg).

This class offers the following methods.

=over 4

=item * following($dt)

Returns the DateTime object for the Easter Event after C<$dt>. This will
not return C<$dt>.

=item * previous($dt)

Returns the DateTime object for the Easter Event before C<$dt>. This will
not return C<$dt>.

=item * closest($dt)

Returns the DateTime object for the Easter Event closest to C<$dt>. This
will return midnight of C<$dt> if C<$dt> is the Easter Event.

=item * is($dt)

Return positive (1) if C<$dt> is the Easter Event, otherwise returns false
(0)

=item * as_list(from => $dt, to => $dt2, inclusive => I<([0]|1)>)

Returns a list of Easter Events between I<to> and I<from>.

If the optional I<inclusive> parameter is true (non-zero), the to and
from dates will be included if they are the Easter Event.

If you do not include an I<inclusive> parameter, we assume you do not
want to include these dates (the same behaviour as supplying a false
value)


=item * as_set()

Returns a DateTime::Set of Easter Events.

In the past this method used the same syntax as 'as_list' above. However
we now allow both the above syntax as well as the full options allowable
when creating sets with C<DateTime::Set>. This means you can call
C<< $datetime_set = $palm_sunday->as_set; >> and it will return a 
C<DateTime::Set> of all Palm Sundays. See C<DateTime::Set> for more information.


=item * as_span()

This method switches output to spans rather than points. See the 'as' attribute
of the constructor for more information. The method returns the object for easy
chaining.

=item * as_point()

This method switches output to points rather than spans. See the 'as' attribute
of the constructor for more information. The method returns the object for easy
chaining.


=back

=head1 EXPORTS

This class does not export any methods by default, however the following
exports are supported.

=over 4

=item * easter($year)

Given a Gregorian year, this method will return a DateTime object for
Western Easter Sunday in that year.

=back

=head1 BUGS AND PROBLEMS FOR SPANS

=head2 Inclusion and exclusion of C<from> and C<to> dates in lists and sets

If you build a list or a set of spans and if the C<from> or C<to> limits
coincide with the requested Easter event, the result may be different
from what you expect. For example, you ask for Easter sundays between
2017-04-16T21:43:00 and 2020-04-12T12:34:00.

The inclusive list or set will be:

  2017-04-16T00:00:00 to 2017-04-16T23:59:59
  2018-04-01T00:00:00 to 2018-04-01T23:59:59
  2019-04-21T00:00:00 to 2019-04-21T23:59:59
  2020-04-12T00:00:00 to 2020-04-12T23:59:59

and not:

  2017-04-16T21:43:00 to 2017-04-16T23:59:59
  2018-04-01T00:00:00 to 2018-04-01T23:59:59
  2019-04-21T00:00:00 to 2019-04-21T23:59:59
  2020-04-12T00:00:00 to 2020-04-12T12:34:00

The exclusive list or set will be:

  2018-04-01T00:00:00 to 2018-04-01T23:59:59
  2019-04-21T00:00:00 to 2019-04-21T23:59:59

and not:

  2017-04-16T21:43:01 to 2017-04-16T23:59:59
  2018-04-01T00:00:00 to 2018-04-01T23:59:59
  2019-04-21T00:00:00 to 2019-04-21T23:59:59
  2020-04-12T00:00:00 to 2020-04-12T12:35:59

Remarks and patches welcome.

Note for pedants: the hour C<21:43:01> should actually be
21 hours, 43 minutes, zero seconds and 1 nanosecond.
Likewise, all the times above ending with C<:59> include
999_999_999 nanoseconds.

=head2 Interaction of spans with timezones

It may happen that Palm sunday or Easter sunday coincide
with DST "spring forward" day (for Northern countries). I have not
checked what happens in this case for spans: a bit more than one day
for exactly 24 hours or exactly one day which gives 23 hours?
A similar question exists for DST "fall backward" day in the Southern
countries.

Also, since you can use a numeric C<day> offset up to 250, you can reach
the Northern "fall backwards" and the Southern "spring forward" days, where
the same problem will happen in reverse.

=head2 Building a spanset

For the moment, when building a set with the C<< as => 'set' >> option,
the C<from> and C<to> dates are required and thus the set must be a finite set.

=head1 THE SMALL PRINT

=head2 REFERENCES

=over 4

=item * L<https://github.com/houseabsolute/DateTime.pm/wiki> - The official wiki
of the DateTime project

=item * L<https://www.tondering.dk/claus/calendar.html> - Claus Tøndering's
calendar FAQ

=item * I<Calendrical Calculations> (Third or Fourth Edition) by Nachum Dershowitz and
Edward M. Reingold, Cambridge University Press, see
L<http://www.calendarists.com>
or L<https://www.cambridge.org/us/academic/subjects/computer-science/computing-general-interest/calendrical-calculations-ultimate-edition-4th-edition?format=PB&isbn=9781107683167>,
ISBN 978-0-521-70238-6 for the third edition.

=item * I<La saga des calendriers>, by Jean Lefort, published by I<Belin> (I<Pour la Science>), ISBN 2-90929-003-5
See L<https://www.belin-editeur.com/la-saga-des-calendriers>

=item * I<Le Calendrier>, by Paul Couderc, published by I<Presses universitaires de France> (I<Que sais-je ?>), ISBN 2-13-036266-4
See L<https://catalogue.bnf.fr/ark:/12148/cb329699661>.

=back

=head2 SUPPORT

Support for this module, and for all DateTime modules will be given
through the DateTime mailing list - datetime@perl.org.
See L<https://lists.perl.org/list/datetime.html>.

Bugs should be reported through rt.cpan.org. See
L<https://rt.cpan.org/Public/Dist/Display.html?Name=DateTime-Event-Easter>.

Or you can try to submit a pull request to
L<https://github.com/jforget/DateTime-Event-Easter>.

=head2 AUTHOR

Rick Measham <rickm@cpan.org>

Co-maintainer Jean Forget <jforget@cpan.org>

=head2 CREDITS

Much help from the DateTime mailing list, especially from:

B<Eugene van der Pijll> - who pointed out flaws causing errors on
gregorian years with no eastern easter (like 35000) and who came up with
a patch to make the module accept any calendar's DateTime object

B<Dave Rolsky> - who picked nits, designed DateTime itself and leads the project

B<Martin Hasch> - who pointed out the posibility of memory leak with an early beta

B<Joe Orost> and B<Andreas König> - for RT tickets about the POD documentation

B<Frank Wiegand> and B<Slaven Rezić> - for patches fixing the POD problems

=head2 COPYRIGHT

© Copyright 2003, 2004, 2015, 2019 Rick Measham and Jean Forget. All
rights reserved. This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself: GNU
Public License version 1 or later and Perl Artistic License.

The full text of the license can be found in the F<LICENSE> file
included with this module or at
L<https://dev.perl.org/licenses/artistic.html>
and L<https://www.gnu.org/licenses/gpl-1.0.html>.

Here is the summary of GPL:

This program is  free software; you can redistribute  it and/or modify
it under the  terms of the GNU General Public  License as published by
the Free  Software Foundation; either  version 1, or (at  your option)
any later version.

This program  is distributed in the  hope that it will  be useful, but
WITHOUT   ANY  WARRANTY;   without  even   the  implied   warranty  of
MERCHANTABILITY  or FITNESS  FOR A  PARTICULAR PURPOSE.   See  the GNU
General Public License for more details.

You  should have received  a copy  of the  GNU General  Public License
along with this program; if not, see <https://www.gnu.org/licenses/> or
write to the Free Software Foundation, Inc., L<https://fsf.org>.

=head2 SEE ALSO

L<DateTime>, L<DateTime::Calendar::Julian>, perl(1)

L<https://metacpan.org/search?q=easter> which gives L<Date::Easter>, L<Date::Calc> and L<Date::Pcalc>

L<https://github.com/houseabsolute/DateTime.pm/wiki>
