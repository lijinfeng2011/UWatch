#!/home/s/ops/perl/bin/perl
use strict;
use warnings;

use YAML::XS;
use LWP::UserAgent;

use NS::Util::OptConf;

=head1 SYNOPSIS

 $0 [--add owner:follower] 
 $0 [--del owner:follower] 
 $0 [--update owner:follower] 
 $0 [--del4user owner] 
 $0 [--list4user owner] 
 $0 [--list] 
    
=cut

my $option = NS::Util::OptConf->load();
my %o = $option->get( qw( add=s del=s update=s del4user=s list4user=s list ) )->dump();

for ( qw( add del update ) )
{
    next unless $o{$_};
    my @a = split /:/, $o{$_};
    next unless @a == 2;
    cont( $_, @a );
}

map{ print cont( $_, $o{$_} ) if $o{$_}; }qw( del4user list4user );
print cont( "list" ) if $o{list} || ! %o;

sub cont
{
    my $ua = LWP::UserAgent->new( );
    $ua->agent('Mozilla/9 [en] (Centos; Linux)');
    $ua->timeout( 10 );
    $ua->default_header ( 'Cache-control' => 'no-cache', 'Pragma' => 'no-cache' );
    my $res = $ua->get( sprintf "http://127.0.0.1:9999/follow/%s", join '/', @_ );
    $res->is_success ? $res->content : undef;
}
