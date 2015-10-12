#!/home/s/ops/perl/bin/perl
use strict;
use warnings;

use YAML::XS;
use LWP::UserAgent;

use NS::Util::OptConf;

=head1 SYNOPSIS

 $0 [--add user:passwd] 
 $0 [--del user] 
 $0 [--list] 
 $0 [--mesg user:item] 
 $0 [--getinfo user] 
 $0 [--setinfo user:info] 
 $0 [--getindex user:item] 
 $0 [--setindex user:item:id] 
 $0 [--auth user:pass] 
    
=cut

my $option = NS::Util::OptConf->load();
my %o = $option->get( 
    qw( add=s del=s list mesg=s getinfo=s setinfo=s getindex=s setindex=s auth=s debug)
)->dump();

for ( qw( add mesg setinfo getindex setindex auth ) )
{
    next unless $o{$_};
    my @a = split /:/, $o{$_};
    print cont( $_, @a );
}

map{ print cont( $_, $o{$_} ) if $o{$_} }qw( del getinfo );
print cont( "list" ) if $o{list} || ! %o;

sub cont
{
    my $ua = LWP::UserAgent->new( );
    $ua->agent('Mozilla/9 [en] (Centos; Linux)');
    $ua->timeout( 10 );
    $ua->default_header ( 'Cache-control' => 'no-cache', 'Pragma' => 'no-cache' );
    my $url = sprintf "http://127.0.0.1:9999/user/%s", join '/', @_;
    print "debug:$url\n" if $o{debug};
    my $res = $ua->get( $url );
    $res->is_success ? $res->content : undef;
}
