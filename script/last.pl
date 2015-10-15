#!/home/s/ops/perl/bin/perl
use strict;
use warnings;

use YAML::XS;
use LWP::UserAgent;

use NS::Util::OptConf;

=head1 SYNOPSIS

 $0 [--list] 
    
=cut

my $option = NS::Util::OptConf->load();
my %o = $option->get( qw( list ) )->dump();

print cont( "list" ) if $o{list} || ! %o;

sub cont
{
    my $ua = LWP::UserAgent->new( );
    $ua->agent('Mozilla/9 [en] (Centos; Linux)');
    $ua->timeout( 10 );
    $ua->default_header ( 'Cache-control' => 'no-cache', 'Pragma' => 'no-cache' );
    my $res = $ua->get( sprintf "http://127.0.0.1:9999/last/%s", join '/', @_ );
    $res->is_success ? $res->content : undef;
}
