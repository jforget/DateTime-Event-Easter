#     Test script for DateTime::Event::Easter
#     Copyright (C) 2003, 2004, 2015, Rick Measham and Jean Forget
#
#     This program is distributed under the same terms as Perl 5.16.3:
#     GNU Public License version 1 or later and Perl Artistic License
#
#     You can find the text of the licenses in the F<LICENSE> file or at
#     L<http://www.perlfoundation.org/artistic_license_1_0>
#     and L<http://www.gnu.org/licenses/gpl-1.0.html>.
#
#     Here is the summary of GPL:
#
#     This program is free software; you can redistribute it and/or modify
#     it under the terms of the GNU General Public License as published by
#     the Free Software Foundation; either version 1, or (at your option)
#     any later version.
#
#     This program is distributed in the hope that it will be useful,
#     but WITHOUT ANY WARRANTY; without even the implied warranty of
#     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#     GNU General Public License for more details.
#
#     You should have received a copy of the GNU General Public License
#     along with this program; if not, write to the Free Software Foundation,
#     Inc., <http://www.fsf.org/>.
#
use strict;

use Test::More tests => 5;

use DateTime::Event::Easter qw/easter/;

my $post_easter_2003 = DateTime->new(
	year  => 2003,
	month => 8,
	day   => 28,
);

my $event_easter_sunday = DateTime::Event::Easter->new(day=>'easter sunday');
is( $event_easter_sunday->previous($post_easter_2003)->ymd, 
	'2003-04-20', 
	"Day: Easter Sunday is correct",
);

my $event_black_saturday = DateTime::Event::Easter->new(day=>'black saturday');
is( $event_black_saturday->previous($post_easter_2003)->ymd, 
	'2003-04-19', 
	"Day: Black Saturday is correct",
);

my $event_good_friday = DateTime::Event::Easter->new(day=>'good friday');
is( $event_good_friday->previous($post_easter_2003)->ymd, 
	'2003-04-18', 
	"Day: Good Friday is correct",
);

my $event_maundy_thursday = DateTime::Event::Easter->new(day=>'maundy thursday');
is( $event_maundy_thursday->previous($post_easter_2003)->ymd, 
	'2003-04-17', 
	"Day: Maundy Thursday is correct",
);

my $event_pentecost = DateTime::Event::Easter->new(day=>49);
is( $event_pentecost->previous($post_easter_2003)->ymd, 
	'2003-06-08', 
	"Day: +49 is correct",
);


