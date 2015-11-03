package Alarm;

use strict;
use warnings;
use Web;

use Data::Dumper;
use Carp;
use LWP::UserAgent;

my $server = 'http://127.0.0.1:9999';
my $userAgent = LWP::UserAgent->new();
$userAgent->timeout( 10 );
my @allItems = ();
my @subItems = ();

sub Login {
    my ( $user, $pwd, $response ) = @_;
    my $url = sprintf ( "%s/user/auth/%s/%s", $server, $user, $pwd );

    eval { $response = $userAgent->get( $url ) };
    if ($@) { return 1; }

    if    ( not $response->is_success )  { return 1; } 
    elsif ( $response->content eq 'ok')  { return 0; }
    else  { return 2; }
}


sub GetAllUsers {
    my $url = sprintf( "%s/user/list", $server );
    my ( $response, $content, @users );
   
    eval { $response = $userAgent->get( $url ) };
    return if $@;
  
    $content = $response->content if $response->is_success;
    my @tmp = sort split ( '\n', $content ) if $content;

    map { push @users, { name => $_, followed => 0 }; } @tmp;

    return \@users;
}


sub GetAllItems {
    my $url = sprintf ( "%s/item/list", $server ); 
    my ( $response, $items ); @allItems = ();

    eval { $response = $userAgent->get( $url ) };
    unless ( $@ ) { 
        $items = $response->content if $response->is_success;
        @allItems = sort split ( '\n', $items ) if $items;
    }
}


sub GetSubItems {
    my ( $user,  $response, $items ) = @_; @subItems = ();
    my $url = sprintf ( "%s/relate/list4user/%s", $server, $user );

    eval { $response = $userAgent->get( $url ) };
    unless ( $@ ) { 
        $items = $response->content if $response->is_success;
        @subItems = sort split ( '\n', $items ) if $items;
    }
}


sub GetAllAlarmItem {
    GetAllItems();
    return undef if $#allItems == -1;

    my %groupMap = ( 
        name  => ['safe', 'so', 'other'],
        other => {},
        so    => {}, 
        safe  => {}
    );

    foreach my $item ( @allItems ) {
        my @sp = split ( '_', $item );
        next unless scalar @sp > 1;

        my @hms = split ( '\.', $item );       
        next unless scalar @hms > 1;

        if ( $sp[0] =~ m/(^so$|^safe$)/ ) { $groupMap{$sp[0]}->{$hms[0]} = 1; } 
        else { $groupMap{other}->{$hms[0]} = 1; } 
    }

    return \%groupMap;
}


sub GetSubscribeDetail {
    my ( $subID, $user, @items ) = @_;

    GetAllItems() if ( $#allItems == -1 );
    return if $#allItems == -1;

    GetSubItems( $user ); 

    foreach my $item ( grep { $_ =~ m/(^$subID)/ } @allItems ) { 
       my @sp = split( '\.', $item, 2 );
       next if scalar @sp < 1;
      
       my %detail = ( name => $sp[1], booked => 0 );
       $detail{booked} = 1 if grep (/:$item:/, @subItems);
       
       push @items, \%detail;
    } 

    return \@items;
}


sub BookSubscribeItems {
    my ( $param, $user ) = @_;

    my $hermes = delete $param->{hermesID};

    my ( $addQuery, $deleteQuery, $response );

    while ( my ( $item, $value ) = each ( %$param ) ) {
        if ( $value == 1 ) {
            $addQuery .= ':' if $addQuery;
            $addQuery .= join( '.', $hermes, $item );
        } 
        if ( $value == 0) {
            $deleteQuery .= ':' if $deleteQuery;
            $deleteQuery .= join( '.', $hermes, $item );
        }  
    }

    if ( $addQuery ) {
         my $url = sprintf ( "%s/relate/add/%s/%s", $server, $addQuery, $user );
         eval { $response = $userAgent->get( $url ) }; if ($@) { return 1; }
         unless ( $response->is_success && $response->content eq 'ok' )  { return 1; }
    }

    if ( $deleteQuery ) {
        my $url = sprintf ( "%s/relate/del/%s/%s", $server, $deleteQuery, $user );
        eval { $response = $userAgent->get( $url ) }; if ($@) { return 1; } 
        unless ( $response->is_success && $response->content eq 'ok' )  { return 1; }
    }

    return 0;
}


sub GetMessageGroup {
    my ( $user, @mesgGroup ) = @_;

    GetSubItems( $user );

    foreach my $msg ( @subItems ) { 
        my @sp = split ( ':', $msg);
        next unless scalar @sp == 3;

        if ( $sp[2] > 999 ) {
            push @mesgGroup, { name => $sp[1], count => '999+' };
        } else {
            push @mesgGroup, { name => $sp[1], count => $sp[2] };
        }
    }

    return \@mesgGroup;   
}


sub GetMessageDetail {
    my ( $user, $group, $pos, $type, $limit, $response, @mesgDetail ) = @_;

    my $url = sprintf ("%s/user/mesg/%s/%s/%s/%s/%s", $server, $user, $group, $pos, $type, $limit);

    eval { $response = $userAgent->get( $url ) };
    unless ( $@ ) { 
        my $items = $response->content if $response->is_success;
        my @tmp = split ( '\n', $items ) if $items;

        my ( $idx, $msg, $node );
        foreach my $tmp ( @tmp ) {
            if ( $tmp =~ m/^\*(\d+)\*(.+)$/ ) {
                $idx = $1; 
                $msg = $2;
                $msg =~ m/ ([\w\._@-]+)#/;                
                push @mesgDetail, { idx => $idx, content => $msg, node => $1 };
            }
        } 
    }

    return \@mesgDetail;
}


sub SetProfile {
    my ( $param, $user, $response ) = @_;
    my @param = ( $param->{phone}, $param->{address}, $param->{oncaller}, $param->{refTime} );

    my $arguments = join( ':',  @param );
    my $url = sprintf ( "%s/user/setinfo/%s/%s", $server, $user, $arguments );

    eval { $response = $userAgent->get( $url ) }; if ($@) { return 1; }
    unless ( $response->is_success && $response->content eq 'ok' )  { return 1; }

    if ( $param->{follower} ) {
        $url = sprintf ( "%s/follow/update/%s/%s", $server, $user, $param->{follower} );
        eval { $response = $userAgent->get( $url ) }; if ($@) { return 1; }
        unless ( $response->is_success && $response->content eq 'ok' )  { return 1; }
    } else {
        $url = sprintf ( "%s/follow/del4user/%s", $server, $user );
        eval { $response = $userAgent->get( $url ) }; if ($@) { return 1; }
        unless ( $response->is_success && $response->content eq 'ok' )  { return 1; }
    }

    return 0;
}


sub GetProfile {
    my ( $response, $items, @items );
    my $url = sprintf( "%s/user/getinfo/%s", $server, shift ); 
    
    eval { $response = $userAgent->get( $url ) };
    unless ( $@ ) { 
        $items = $response->content if $response->is_success;
        chomp( $items ) if $items;
        @items = split ( ':', $items ) if $items;
    }

    return \@items;
}


sub GetFollowUsers {
    my ( $response, $items ); my @items = [];
    my $url = sprintf( "%s/follow/list4user/%s", $server, shift ); 
    
    eval { $response = $userAgent->get( $url ) };
    unless ( $@ ) { 
        $items = $response->content if $response->is_success;
        chomp( $items ) if $items;
        @items = split ( '\n', $items ) if $items;
    }

    return \@items;
}


sub ChangePWD {
    my ( $user, $old, $new, $response ) = @_;     
    my $url = sprintf ( "%s/user/changepwd/%s/%s/%s", $server, $user, $old, $new );
    
    return 1 if length( $new ) < 6 || $new !~ m/[a-zA-Z]/ || $new !~ m/[0-9]/; 

    # 0: success.
    # 1: network error.
    # 2: auth error.
    eval { $response = $userAgent->get( $url ) }; if ($@) { return 1; }
    
    return 1 unless $response->is_success;
  
    my $content = $response->content; chomp( $content );

    return 1 if $content eq 'set failed';

    return 2 if $content eq 'auth failed';

    return 0 if $content eq 'success';
}


sub SetFilterMessage {
    my ( $user, $name, $node, $response ) = @_;
    my $url = sprintf ( "%s/filter/add/%s/%s/%s", $server, $user, $name, $node );

    eval { $response = $userAgent->get( $url ) }; if ($@) { return 1; }
    return 1 unless $response->is_success;

    my $content = $response->content; chomp( $content ); 
    return 0 if $content eq 'ok';

    return 1;
}


sub GetNotifyInfo {
    my ( $user, $type, $url, $response ) = @_;
    $url = sprintf( "%s/notify/getstat/%s", $server, $user ) if $type eq 'Alarm';
    $url = sprintf( "%s/detail/getstat/%s", $server, $user ) if $type eq 'Format';

    eval { $response = $userAgent->get( $url ) }; if ($@) { return 'error'; }

    return 'error' unless $response->is_success;

    my $content = $response->content; chomp( $content );
    return $content;
}


sub SetNotifyInfo {
    my ( $user, $type, $stat, $response, $url ) = @_;
    if ( $type eq 'Alarm' ) {
        $url = sprintf( "%s/notify/setstat/%s/%s", $server, $user, $stat );
    } elsif ( $type eq 'Format' ) {
        $url = sprintf( "%s/detail/setstat/%s/%s", $server, $user, $stat );
    }

    eval { $response = $userAgent->get( $url ) }; if ($@) { return 1; }
    return 1 unless $response->is_success;

    my $content = $response->content; chomp( $content );

    return 0 if $content eq 'ok';

    return 1;
}

sub GetUserViaToken {
    my $url = sprintf ( "%s/token/search/%s", $server, shift ); my $response;

    eval { $response = $userAgent->get( $url ) }; if( $@ ) { return 'error'; }
    return 'error' unless $response->is_success;

    my $content = $response->content; chomp( $content );

    return $content;
}

1;
