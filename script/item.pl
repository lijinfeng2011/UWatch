#!/home/s/ops/perl/bin/perl
use strict;
use warnings;

use YAML::XS;
use LWP::UserAgent;

use NS::Util::OptConf;

=head1 SYNOPSIS

 $0 [--add item] 
 $0 [--del item] 
 $0 [--list] 
 $0 [--mesg item] 
 $0 [--count item] 
    
=cut

my $option = NS::Util::OptConf->load();
my %o = $option->get( qw( add=s del=s list mesg=s count=s ) )->dump();

map{ print cont( $_, $o{$_} ) if $o{$_}; }qw( add del mesg count );
print cont( "list" ) if $o{list} || ! %o;

sub cont
{
    my $ua = LWP::UserAgent->new( );
    $ua->agent('Mozilla/9 [en] (Centos; Linux)');
    $ua->timeout( 10 );
    $ua->default_header ( 'Cache-control' => 'no-cache', 'Pragma' => 'no-cache' );
    my $res = $ua->get( sprintf "http://127.0.0.1:9999/item/%s", join '/', @_ );
    $res->is_success ? $res->content : undef;
}
