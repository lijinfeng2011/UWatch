package Alarm;

use strict;
use warnings;
use Web;

use Data::Dumper;
use YAML::XS;
use Carp;
use LWP::UserAgent;
use MIME::Base64;
use URI::Escape;
use Cwd;
use FindBin qw/$Bin/;

my $server = 'http://127.0.0.1:9999';
my $userAgent = LWP::UserAgent->new();
$userAgent->timeout( 10 );
my @allItems = ();
my %allAlias = ();
my %allLevel = ();
my @subItems = ();
my $g_config;

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

sub GetNoAlarm {
    my $url = sprintf ( "%s/user/list", $server );
    my $response = $userAgent->get( $url );
    my $content = $response->content if $response->is_success;
    my @tmp = split ( '\n', $content ) if $content;

    my %userList;
    map { $userList{$_} = 0 unless exists $userList{$_}; } @tmp;
    
    $url = sprintf ( "%s/method/list", $server );
    $response = $userAgent->get( $url );
    $content = $response->content if $response->is_success;
    @tmp = split ( '\n', $content ) if $content;
    
    map { 
        my @utmp = split(':', $_);
        $userList{$utmp[0]} = 1 if exists $userList{$utmp[0]}; 
    } @tmp;

    my @res;
    map { push @res, $_ if $userList{$_} == 0; } keys %userList;

    print Dumper(\@res);
}

sub GetAllItems {
    my $url = sprintf ( "%s/item/list", $server ); 
    my ( $response, $items, %count );

    eval { $response = $userAgent->get( $url ) };
    return if $@ || not $response->is_success;

    $items = $response->content;
    @allItems = sort split( '\n', $items );

    $url = sprintf ( "%s/alias/list", $server );
    eval { $response = $userAgent->get( $url ) };
    return if $@ || not $response->is_success;

    $items = $response->content; %allAlias = ();
    foreach my $key ( split ( '\n', $items ) ) {
        if ( $key =~ m/^(\w+):(.+)$/ ) {
            $allAlias{$1} = $2;
        }
    }

    $url = sprintf ( "%s/notifylevel/list", $server );
    eval { $response = $userAgent->get( $url ) };
    return if $@ || not $response->is_success;

    $items = $response->content; %allLevel = ();
    foreach my $key ( split ( '\n', $items ) ) {
        if ( $key =~ m/^(.+):(.+)$/ ) {
            $allLevel{$1} = $2;
        }
    }
}

sub GetSubItems {
    my ( $user,  $response, $items ) = @_; @subItems = ();
    my $url = sprintf ( "%s/relate/list4user/%s", $server, $user );

    eval { $response = $userAgent->get( $url ) };
    unless ( $@ ) { 
        $items = $response->content if $response->is_success;
        return unless $items;

        @subItems = sort split('\n', $items);
      #  @subItems = grep { /^myself_/ } sort split('\n', $items);
    }
}

sub GetAllBiz {
    $g_config = eval { YAML::XS::LoadFile("$Bin/../lib/config.yml") } unless $g_config;
    return $g_config->{'watch_config'}->{'subscribe_sort'}->{alias};
}

sub GetAllAlarmItem {
    GetAllItems();
    return undef if $#allItems == -1;

    $g_config = eval { YAML::XS::LoadFile("$Bin/../lib/config.yml") } unless $g_config;
    my %groupMap = ( rule => {} );
    my ($index, $reg, %result) = (0, 0);
    $groupMap{alias} = $result{name} = $g_config->{'watch_config'}->{'subscribe_sort'}->{alias};
    $groupMap{prefix} = $g_config->{'watch_config'}->{'subscribe_sort'}->{prefix};

    map { $groupMap{rule}->{$_} = $index++; } @{$groupMap{prefix}};

    foreach my $item (@allItems) {
       my ($hms, $alm, $ismached) = split ('\.', $item);
       next unless $hms && $alm;

       my $ahms = $allAlias{$hms} ? $allAlias{$hms} : ' %E6%9A%82%E6%97%A0%E5%A4%87%E6%B3%A8';

       foreach ( @{$groupMap{prefix}} ) {
           $reg = sprintf("^%s", $_);
           if ( $hms =~ m/$reg/ ) {
              $ismached = 1;
              my $id = $groupMap{rule}->{$_};
              $result{$groupMap{alias}->[$id]} = {} unless exists $result{$groupMap{alias}->[$id]};
              $result{$groupMap{alias}->[$id]}->{$hms} = $ahms;
              last;
           }
       } 
       unless ( $ismached ) {
           $result{$groupMap{alias}->[-1]} = {} unless exists $result{$groupMap{alias}->[-1]};
           $result{$groupMap{alias}->[-1]}->{$hms} = $ahms; 
       }
    }

    return \%result;
}

sub GetSubscribeDetail {
    my ( $subID, $user, @items, @selfBooked ) = @_;

    GetAllItems() if ( $#allItems == -1 );
    return if $#allItems == -1;

    GetSubItems( $user ); 

    foreach my $item ( grep { $_ =~ m/(^$subID\.)/ } @allItems ) { 
       my @sp = split( '\.', $item, 2 );
       next if scalar @sp < 1;

       @selfBooked = grep { /^myself_/ } @subItems;
      
       my %detail = ( name => $sp[1], booked => 0, level => 2 );
       $detail{booked} = 1 if grep (/:$item:/, @selfBooked);
      
       my $key = join('.', $subID, $sp[1]);
       $detail{level} = $allLevel{$key} if $allLevel{$key};

       $detail{alias} = $allAlias{$sp[1]}?Encode::decode_utf8(uri_unescape($allAlias{$sp[1]})):'';

       push @items, \%detail;
    } 

    return \@items;
}

sub BookSubscribeItems {
    my ( $param, $user ) = @_;
    my ( $url, $response, @addItem, @delItem );

    my $AlmMethod = _getNotifyInfo( $user, 'Method');

    # 0->OK; 1->Error; 2->No Method; 3->OK&OpenAlm;
    return 2 if $AlmMethod eq 'error';

    my $hermes = delete $param->{hermesID};

    while ( my ( $item, $value ) = each ( %$param ) ) { 
        push @addItem, $item if $value == 1; 
        push @delItem, $item if $value == 0;
    }

    my $index = 0; my $query;
    foreach my $item (@addItem) {
        if ( ++$index < 10 ) {
            $query .= ':' if $query;
            $query .= join( '.', $hermes, $item );
        } else {
           $url = sprintf ( "%s/relate/add/%s/%s", $server, $query, $user );
           eval { $response = $userAgent->get( $url ) }; if ($@) { return 1; } 
           unless ( $response->is_success && $response->content eq 'ok' )  { return 1; }  

           $query = join( '.', $hermes, $item );
           $index = 0;
        }
    }

    if ( $query ) {
         $url = sprintf ( "%s/relate/add/%s/%s", $server, $query, $user );
         eval { $response = $userAgent->get( $url ) }; if ($@) { return 1; }
         unless ( $response->is_success && $response->content eq 'ok' )  { return 1; }
    }

    $index = 0; $query = '';
    foreach my $item (@delItem) {
        if ( ++$index < 10 ) {
            $query .= ':' if $query;
            $query .= join( '.', $hermes, $item );
        } else {
           $url = sprintf ( "%s/relate/del/%s/%s", $server, $query, $user );
           eval { $response = $userAgent->get( $url ) }; if ($@) { return 1; } 
           unless ( $response->is_success && $response->content eq 'ok' )  { return 1; }

           $query = join( '.', $hermes, $item );
           $index = 0;
        }
    }

    if ( $query ) {
         $url = sprintf ( "%s/relate/del/%s/%s", $server, $query, $user );
         eval { $response = $userAgent->get( $url ) }; if ($@) { return 1; }
         unless ( $response->is_success && $response->content eq 'ok' )  { return 1; }
    }

    my $isOpenAlm = _getNotifyInfo( $user, 'Alarm' ) || 'on';
    return 0 if $isOpenAlm eq 'on';
    return 3;
}

sub GetMessageGroup {
    my ( $user, $oncall, @selfMesgGrp, @oncallMesgGrp, @result ) = @_;

    GetSubItems( $user );

    foreach my $msg ( @subItems ) { 
        my @sp = split ( ':', $msg);
        next unless scalar @sp == 3;

        if ( $sp[0] =~ /^myself_/ ) {
            if ( $sp[2]>999 ) {
                unshift @selfMesgGrp, { name => $sp[1], count => '999+' };
            } elsif ( $sp[2]>0 ) {
                unshift @selfMesgGrp, { name => $sp[1], count => $sp[2] };
            } else {
                push @selfMesgGrp, { name => $sp[1], count => '' };
            }
        } elsif ( $sp[0] =~ /^oncall_(.+)_(.+)_(.+)$/ ) {
            my $level = '常规'; $oncall = 1;
            $level = '一级值班' if $1 eq 'u1';
            $level = '二级值班' if $1 eq 'u2';
            $level = '三级值班' if $1 eq 'u3';
            my $newBiz = Encode::decode_utf8(uri_unescape(sprintf("%s: %s业务", $level, $3)));
            if ( $sp[2]>999 ) {
                unshift @oncallMesgGrp, { name => $sp[1], count => '999+', biz => $newBiz };
            } elsif ( $sp[2]>0 ) {
                unshift @oncallMesgGrp, { name => $sp[1], count => $sp[2], biz => $newBiz };
            } else {
                push @oncallMesgGrp, { name => $sp[1], count => '', biz => $newBiz };
            }
        }
    }

    push @result, ( \@selfMesgGrp, \@oncallMesgGrp, $oncall );

    return \@result;
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

sub DelFilterMessage {
    my ( $user, $name, $node, $response ) = @_;
    my $url = sprintf ( "%s/filter/del/%s/%s", $server, $name, $node );

    eval { $response = $userAgent->get( $url ) }; 
    return 1 if $@ || not  $response->is_success;

    my $content = $response->content; chomp( $content ); 
    return 0 if $content eq 'ok';

    return 1;
}

sub GetNotifyInfo {
    my $user = shift;
    my $stopAlarm  =  _getNotifyInfo( $user, 'Alarm' );
    my $fullFormat =  _getNotifyInfo( $user, 'Format');
    my $repMethod  =  _getNotifyInfo( $user, 'Method');

    return {
        stopAlarm  => $stopAlarm,
        fullFormat => $fullFormat,
        repMethod  => $repMethod
    };
}

sub _getNotifyInfo {
    my ( $user, $type, $url, $response ) = @_;
    $url = sprintf( "%s/notify/getstat/%s", $server, $user ) if $type eq 'Alarm';
    $url = sprintf( "%s/detail/getstat/%s", $server, $user ) if $type eq 'Format';
    $url = sprintf( "%s/method/get/%s",     $server, $user ) if $type eq 'Method';

    eval { $response = $userAgent->get( $url ) }; if ($@) { return 'error'; }

    return 'error' unless $response->is_success;

    my $content = $response->content; chomp( $content );
    return $content;
}

sub TriggerNotifyTest {
    my $url = sprintf( "%s/notify/test/%s", $server, shift );

    my $response;
    eval { $response = $userAgent->get( $url ) }; if ($@) { return 1; }
    return 1 unless $response->is_success;

    my $content = $response->content; chomp( $content );

    return 0 if $content eq 'ok';

    return 1;
}

sub SetNotifyInfo {
    my ( $user, $type, $stat, $response, $url ) = @_;
    if ( $type eq 'Alarm' ) {
        $url = sprintf( "%s/notify/setstat/%s/%s", $server, $user, $stat );
    } elsif ( $type eq 'Format' ) {
        $url = sprintf( "%s/detail/setstat/%s/%s", $server, $user, $stat );
    } elsif ( $type eq 'Method' ) {
        $url = sprintf( "%s/method/add/%s/%s", $server, $user, $stat );
    }

    eval { $response = $userAgent->get( $url ) }; if ($@) { return 1; }
    return 1 unless $response->is_success;

    my $content = $response->content; chomp( $content );

    return 0 if $content eq 'ok';

    return 1;
}

sub GetUserViaToken {
    my $url = sprintf( "%s/token/search/%s", $server, shift ); my $response;

    eval { $response = $userAgent->get( $url ) };
    return 'error' if $@ || not $response->is_success;

    my $content = $response->content; chomp( $content );
    return $content;
}

sub GetRecords {
    my $url = sprintf("%s/item/count/%s", $server, shift);
    my $response;

    eval { $response = $userAgent->get( $url ) };
    return '' if $@ || not $response->is_success;

    my $content = $response->content; chomp( $content );
    return $content;
}

sub GetFilterItems {
    my $url = sprintf("%s/filter/table", $server);
    my ($self, $response, %f_items, @sp) = @_;

    eval { $response = $userAgent->get( $url ) };
    return '' if $@ || not $response->is_success;

    my $content = $response->content; chomp( $content );
    return undef unless $content;

    foreach my $item ( split('\n', $content) ) {
        @sp = split(':', $item);
        $f_items{$sp[0]} = [] unless exists $f_items{$sp[0]};
        my $isDup = 0;
        map { $isDup = 1 if $sp[1] eq $_; } @{$f_items{$sp[0]}};

        unless ( $isDup ) {
            unshift @{$f_items{$sp[0]}}, join(':', $sp[1], $sp[2], '1') if $self eq $sp[2];
            push @{$f_items{$sp[0]}}, join(':', $sp[1], $sp[2], '0') unless $self eq $sp[2];
        }
    }

    return \%f_items;
}

sub GetFilterItems1 {
    my $url = sprintf("%s/filter/list4user/%s", $server, shift);
    my ($response,  %f_items, @sp);

    eval { $response = $userAgent->get( $url ) };
    return '' if $@ || not $response->is_success;

    my $content = $response->content; chomp( $content );
    return undef unless $content;

    foreach my $item ( split('\n', $content) ) {
        @sp = split(':', $item);
        $f_items{$sp[0]} = [] unless exists $f_items{$sp[0]};
        my $isDup = 0;
        map { $isDup = 1 if $sp[1] eq $_; } @{$f_items{$sp[0]}};
        push @{$f_items{$sp[0]}}, $sp[1] unless $isDup;
    }

    return \%f_items;
}

sub GetTasks {
    my ($start, $end, $response) = @_;
    my $url = sprintf("%s/cronos/period/%s/%s",$server,$start,$end);

    eval { $response = $userAgent->get( $url ) };
    return [] if $@ || not $response->is_success;

    my $content = $response->content; chomp( $content );
    my @tasks = split ( '\n', $content ) if $content;  

    my (@pArray, @cArray, @newTask, @time, $newTask, $last);
    foreach my $task (@tasks) {
        @cArray = split(':', $task);
        next unless scalar(@cArray);
  
        unless( scalar(@pArray) ) {
            @pArray = @cArray; $last = 1; 
            @time = localtime($pArray[1]);
            next;
        }

        if ($pArray[0] eq $cArray[0] && $pArray[2] eq $cArray[2]) {
            $last++;
        } else {
            if ($pArray[0] eq 'cronos_search') { $pArray[0] = 'S'; }
            elsif ($pArray[0] eq 'cronos_base') {$pArray[0] = 'B'; }
 
            $newTask = join(':', $pArray[0], $pArray[2], $time[3], $time[2], $last);
            push @newTask, $newTask;
            @pArray = @cArray;
            @time = localtime( $cArray[1] );
            $last = 1;
        }
    }

    if ($pArray[0] eq 'cronos_search') { $pArray[0] = 'S'; }
    elsif ($pArray[0] eq 'cronos_base') {$pArray[0] = 'B'; }
    $newTask = join(':', $pArray[0],$pArray[2],$time[3],$time[2],$last);
    push @newTask, $newTask;

    return \@newTask;
}

1;
