package Admin::Item;

use strict;
use warnings;

use Data::Dumper;
use Carp;
use LWP::UserAgent;
use Digest::MD5;

my $server = 'http://127.0.0.1:9999';
my $ua = LWP::UserAgent->new();
$ua->timeout( 10 );

sub list
{
    my $item = $ua->get( "$server/item/list" );
    return () unless $item->is_success;

    return sort split /\n/,$item->content;
}

sub add { $ua->get( sprintf "$server/item/add/%s", shift ); }
sub del { $ua->get( sprintf "$server/item/del/%s", shift ); }

1;
