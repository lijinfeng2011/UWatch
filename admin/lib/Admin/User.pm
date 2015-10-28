package Admin::User;

use strict;
use warnings;

use Data::Dumper;
use Carp;
use LWP::UserAgent;
use Digest::MD5;

my $server = 'http://127.0.0.1:9999';
my $ua = LWP::UserAgent->new();
$ua->timeout( 10 );

sub notify_list
{
    my $user = $ua->get( "$server/user/list" );
    my $notify = $ua->get( "$server/notify/liststat" );
    return () unless $user->is_success && $notify->is_success;

    my %user = map{ $_ => 1 }split /\n/,$user->content;
    map{ 
        my ( $u, $s) = split /:/, $_, 2;
        if( $u && $s )
        {
          $user{$u} = $s eq "off" ? 0 : 1;
        }

    }split /\n/,$notify->content;
    return %user;
}

sub notify_set
{
    $ua->get( sprintf "$server/notify/setstat/%s/%s",@_ );
}

sub info_list
{
    my $info = $ua->get( "$server/user/listtable" );
    return [] unless $info->is_success;

    my @info = map{ my @i = split /:/, $_; map{ $i[$_]||='' }0..5; \@i }split /\n/,$info->content;
    return @info;
}

sub info_set
{
    $ua->get( sprintf "$server/user/setinfo/%s/%s",@_ );
}

sub adduser
{
    my ($user,$pass) = @_;
    return unless length $pass >= 6 && $pass =~ /[a-zA-Z]/ && $pass =~ /\d+/;
    $ua->get( sprintf "$server/user/add/%s/%s", $user, Digest::MD5->new->add( $pass )->hexdigest );
}

sub chpasswd
{
    my ($user,$pass) = @_;
    return unless length $pass >= 6 && $pass =~ /[a-zA-Z]/ && $pass =~ /\d+/;
    $ua->get( sprintf "$server/user/changepwd/%s/%s", $user, Digest::MD5->new->add( $pass )->hexdigest );
}

sub deluser
{
    $ua->get( sprintf "$server/user/del/%s", shift );
}


1;
