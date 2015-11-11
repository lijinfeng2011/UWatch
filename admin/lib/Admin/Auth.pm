package Admin::Auth;

use strict;
use warnings;

use Data::Dumper;
use Carp;
use LWP::UserAgent;

my $server = 'http://127.0.0.1:9999';
my $ua = LWP::UserAgent->new();
$ua->timeout( 10 );

our %tt;

sub check
{
    my ( $usr, $pwd ) = @_;
    $tt{$usr} ||= 0;
    return 0 if $tt{$usr} + 3 > time;
    my $re = $ua->get( 
        sprintf ( "%s/user/auth/%s/%s", $server, $usr, Digest::MD5->new->add( $pwd )->hexdigest )
    );
    return 0 unless $re->is_success && $re->content eq 'ok';

    my $admin = $ua->get( 
        sprintf ( "%s/admin/get/%s", $server, $usr ) 
    );
    return ( $admin->is_success && $admin->content eq $usr ) ? 1 : 0;
}

sub check_md5
{
    my ( $usr, $pwd ) = @_;
    $tt{$usr} ||= 0;
    return 0 if $tt{$usr} + 3 > time;
    my $re = $ua->get( 
        sprintf ( "%s/user/auth/%s/%s", $server, $usr, $pwd )
    );
    return ( $re->is_success && $re->content eq 'ok' ) ? 1 : 0;
}

1;
