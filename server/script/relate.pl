#!/home/s/ops/perl/bin/perl
use strict;
use warnings;

use YAML::XS;
use LWP::UserAgent;

use NS::Util::OptConf;

=head1 SYNOPSIS

 $0 [--add item:user] 
 $0 [--del item:user] 
 $0 [--list4user user] 
 $0 [--list] 
    
=cut

my $option = NS::Util::OptConf->load();
my %o = $option->get( qw( add=s del=s list list4user=s ) )->dump();

for ( qw( add del ) )
{
    next unless $o{$_};
    my @a = split /:/, $o{$_};
    next unless @a == 2;
    cont( $_, @a );
}

print cont( "list4user", $o{list4user} ) if $o{list4user};
print cont( "list" ) if $o{list} || ! %o;

sub cont
{
    my $ua = LWP::UserAgent->new( );
    $ua->agent('Mozilla/9 [en] (Centos; Linux)');
    $ua->timeout( 10 );
    $ua->default_header ( 'Cache-control' => 'no-cache', 'Pragma' => 'no-cache' );
    my $res = $ua->get( sprintf "http://127.0.0.1:9999/relate/%s", join '/', @_ );
    $res->is_success ? $res->content : undef;
}
