package Admin::Follow;

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
    my $item = $ua->get( "$server/follow/list" );
    return () unless $item->is_success;

    map{ [ split /:/, $_ ] } sort split /\n/,$item->content;
}

sub add { $ua->get( sprintf "$server/follow/add/%s/%s", @_ ); }
sub del { $ua->get( sprintf "$server/follow/del/%s/%s", @_ ); }

1;
