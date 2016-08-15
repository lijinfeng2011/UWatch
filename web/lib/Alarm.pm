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
use Digest::MD5;
use String::MkPasswd qw(mkpasswd );

use NS::Util::OptConf;
use NS::Hermes;
use NS::Util::Sudo;
use NS::Hermes::Range;
use Dancer ':syntax';

my $server = 'http://127.0.0.1:9999';
my $imgUA = LWP::UserAgent->new();
$imgUA->timeout(10);

my %allAlias = ();
my %allLevel = ();
my @subItems = ();
my $g_config;

my $range_db;

sub uaget
{
    my ( $uri, $timeout ) = @_;
    $timeout ||= 30;
    my $ua = LWP::UserAgent->new();
    $ua->timeout( $timeout );
    my $res = $ua->get( $server.$uri );
    info sprintf "[UWatchApi] [%d] $server$uri\n", $res->status_line if $ENV{NS_DEBUG};
    return $res;
}

sub Login {
    my ( $user, $pwd, $response ) = @_;
    my $uri = sprintf ( "/user/auth/%s/%s", $user, $pwd );

    eval { $response = uaget( $uri ) };
    if ($@) { return 1; }

    if    ( not $response->is_success )  { return 1; } 
    elsif ( $response->content eq 'ok')  { return 0; }
    else  { return 2; }
}

sub HasUser {
    my $user = shift;
#    print Dumper($user);
    my $resp = uaget( "/user/list" );
    return 1 unless $resp->is_success;

    my %user = map{ $_ => 1 } split /\n/, $resp->content;
    return $user{$user} ? 1 : 0;
}

sub Mkpass {
    my $pass = mkpasswd(
        -length => 13, -minnum => 4, -minlower => 4,
        -minupper => 2, -minspecial => 0
    );
    return ( $pass, Digest::MD5->new->add($pass)->hexdigest );
}

sub AddUser {
    my ( $user, $pwd ) = @_;
    my $response = uaget( "/user/add/$user/$pwd" , 30);

    return $response->is_success ? 0 : 1;
}

sub GetAllUsers {
    my ( $response, $content, @users );
    eval { $response = uaget( '/user/list' ) };
    return if $@;
  
    $content = $response->content if $response->is_success;
    my @tmp = sort split ( '\n', $content ) if $content;

    map { push @users, { name => $_, followed => 0 }; } @tmp;

    return \@users;
}

sub GetNoAlarm {
    my $response = uaget( '/user/list' );
    my $content = $response->content if $response->is_success;
    my @tmp = split ( '\n', $content ) if $content;

    my %userList;
    map { $userList{$_} = 0 unless exists $userList{$_}; } @tmp;
    
    $response = uaget( '/method/list' );
    $content = $response->content if $response->is_success;
    @tmp = split ( '\n', $content ) if $content;
    
    map { 
        my @utmp = split(':', $_);
        $userList{$utmp[0]} = 1 if exists $userList{$utmp[0]}; 
    } @tmp;

    my @res;
    map { push @res, $_ if $userList{$_} == 0; } keys %userList;
}

sub GetItemInfos {
    my ( $response, %count );
    eval { $response = uaget( '/alias/list' ) };
    return if $@ || not $response->is_success;
    my $items = $response->content; %allAlias = ();
    foreach my $key ( split ( '\n', $items ) ) {
        if ( $key =~ m/^(\w+):(.+)$/ ) {
            $allAlias{$1} = $2;
        }
    }

    eval { $response = uaget( '/notifylevel/list' ) };
    return if $@ || not $response->is_success;

    $items = $response->content; %allLevel = ();
    foreach my $key ( split ( '\n', $items ) ) {
        if ( $key =~ m/^(.+):(.+)$/ ) {
            $allLevel{$1} = $2;
        }
    }
}

sub GetPrefixItems {
    my $response;
    eval { $response = uaget( '/item/listprefix' ) };
    return if $@ || not $response->is_success;

    my @itemPrefix = sort split('\n', $response->content);
    return \@itemPrefix;
}

sub GetSuffixItems {
    my $uri = sprintf ( "/item/listsuffix/%s", shift ); 
    my $response;

    eval { $response = uaget( $uri ) };
    return if $@ || not $response->is_success;

    my @itemSuffix = sort split('\n', $response->content);
    return \@itemSuffix;
}

sub GetSubItems {
    my ( $user,  $response, $items ) = @_; @subItems = ();
    my $uri = sprintf ( "/relate/list4user/%s", $user );

    eval { $response = uaget( $uri ) };
    unless ( $@ ) { 
        $items = $response->content if $response->is_success;
        return unless $items;

        @subItems = sort split('\n', $items);
      #  @subItems = grep { /^myself_/ } sort split('\n', $items);
    }
}

sub _initConf {
    NS::Util::Sudo->sudo();
    $range_db = NS::Hermes->new( NS::Util::OptConf->load()->dump( 'range') )->db;
}

sub GetBizbyNodes {
    _initConf() unless $range_db;
    my @result;
    my @cluster = $range_db->select('name', node => [1, shift]);
    for my $clu ( @cluster ) {
        my ($name) = @$clu;
        push @result, $name;
    }

    return \@result;
}

sub GetNodesbyHermes {
    _initConf() unless $range_db;
    my %room;
    my @nodes = $range_db->select('attr,node,info', name => [1, shift]);
    map {
        $room{$_->[0]} = [] unless exists $room{$_->[0]};
        push @{$room{$_->[0]}}, sprintf("%s (%s)", $_->[1], $_->[2]);
    } @nodes; 

    return \%room; 
}

sub GetNodeDetail {
    my ( $node, $hermes, %list ) = ( shift );
    _initConf() unless $range_db;

    my @cluster = $range_db->select('name', node => [1, $node]);
    for my $cluster ( @cluster ) {
        my ( $name ) = @$cluster;
        $hermes .= ' | ' if $hermes;
        $hermes .= $name;
    }

    my ($oncaller, @mArray, $response);
    eval { $response = uaget( '/cronos/get/now/cronos_base' ) };
    unless ( $@ ) { 
        my $items = $response->content if $response->is_success;
        my @subItems = split('\n', $items) if $items;
        map { $oncaller = $_; $oncaller =~ s/^u1://; } grep{ /^u1:/ } @subItems;
    }

    if ( $oncaller ) {
        eval { $response = uaget( "/method/get/$oncaller" ) };
        unless ( $@ ) { 
            my $items = $response->content if $response->is_success;
            map {
               if ( /^(.+?)-(.+)/ ) {
                   push @mArray, '蓝信: '.  $2 if $1 eq 'blue';
                   push @mArray, '短信: '.  $2 if $1 eq 'sms';
                   push @mArray, 'QAlarm: '.$2 if $1 eq 'qalarm';
               } 
            }split(':', $items);
        }
         
    }

    $list{node} = $node;
    $list{hermes} = $hermes;
    $list{oncaller} = $oncaller.'('.join('|', @mArray).')';
     

    return \%list;
}
sub GetAllBiz {
    $g_config = eval { YAML::XS::LoadFile("$Bin/../lib/config.yml") } unless $g_config;
    return $g_config->{'watch_config'}->{'subscribe_sort'}->{alias};
}

sub GetAllAlarmItem {
    GetItemInfos();
    return undef unless %allAlias;

    $g_config = eval { YAML::XS::LoadFile("$Bin/../lib/config.yml") } unless $g_config;
    my %groupMap = ( rule => {} );
    my ($index, $reg, %result) = (0, 0);
    $groupMap{alias} = $result{name} = $g_config->{'watch_config'}->{'subscribe_sort'}->{alias};
    $groupMap{prefix} = $g_config->{'watch_config'}->{'subscribe_sort'}->{prefix};

    map { $groupMap{rule}->{$_} = $index++; } @{$groupMap{prefix}};

    my $items = GetPrefixItems();

    foreach my $item ( @$items ) {
       my $ismached = 0;
       my $ahms = $allAlias{$item} ? $allAlias{$item} : ' %E6%9A%82%E6%97%A0%E5%A4%87%E6%B3%A8';

       foreach ( @{$groupMap{prefix}} ) {
           $reg = sprintf("^%s", $_);
           if ( $item =~ m/$reg/ ) {
              $ismached = 1;
              my $id = $groupMap{rule}->{$_};
              $result{$groupMap{alias}->[$id]} = {} unless exists $result{$groupMap{alias}->[$id]};
              $result{$groupMap{alias}->[$id]}->{$item} = $ahms;
              last;
           }
       } 
       unless ( $ismached ) {
           $result{$groupMap{alias}->[-1]} = {} unless exists $result{$groupMap{alias}->[-1]};
           $result{$groupMap{alias}->[-1]}->{$item} = $ahms; 
       }
    }

    return \%result;
}

sub GetSubscribeDetail {
    my ( $subPrefix, $user, @items, @selfBooked ) = @_;

    GetItemInfos() unless %allAlias;
    return unless %allAlias;

    GetSubItems( $user ); 

    my $suffixItems = GetSuffixItems($subPrefix);

    foreach my $item ( @$suffixItems ) { 
       @selfBooked = grep { /^myself_/ } @subItems;
      
       my %detail = ( name => $item, booked => 0, level => 2 );
       my $reg = join('.', $subPrefix, $item);

       $detail{booked} = 1 if grep (/:$reg:/, @selfBooked);
       $detail{level} = $allLevel{$reg} if $allLevel{$reg};
       $detail{alias} = $allAlias{$item} ? Encode::decode_utf8(uri_unescape($allAlias{$item})) : '';

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
           eval { $response = uaget( "/relate/add/$query/$user" ) }; if ($@) { return 1; } 
           unless ( $response->is_success && $response->content eq 'ok' )  { return 1; }  

           $query = join( '.', $hermes, $item );
           $index = 0;
        }
    }

    if ( $query ) {
         eval { $response = uaget( "/relate/add/$query/$user" ) }; if ($@) { return 1; }
         unless ( $response->is_success && $response->content eq 'ok' )  { return 1; }
    }

    $index = 0; $query = '';
    foreach my $item (@delItem) {
        if ( ++$index < 10 ) {
            $query .= ':' if $query;
            $query .= join( '.', $hermes, $item );
        } else {
           eval { $response = uaget( "/relate/del/$query/$user" ) }; if ($@) { return 1; } 
           unless ( $response->is_success && $response->content eq 'ok' )  { return 1; }

           $query = join( '.', $hermes, $item );
           $index = 0;
        }
    }

    if ( $query ) {
         eval { $response = uaget( "/relate/del/$query/$user" ) }; if ($@) { return 1; }
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

    my $uri = sprintf ("/user/mesg/%s/%s/%s/%s/%s", $user, $group, $pos, $type, $limit);

    eval { $response = uaget( $uri ) };
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

    eval { $response = uaget( "/user/setinfo/$user/$arguments" ) }; if ($@) { return 1; }
    unless ( $response->is_success && $response->content eq 'ok' )  { return 1; }

    if ( $param->{follower} ) {
        eval { $response = uaget( "/follow/update/$user/$param->{follower}" ) }; if ($@) { return 1; }
        unless ( $response->is_success && $response->content eq 'ok' )  { return 1; }
    } else {
        eval { $response = uaget( "/follow/del4user/$user" ) }; if ($@) { return 1; }
        unless ( $response->is_success && $response->content eq 'ok' )  { return 1; }
    }

    return 0;
}

sub GetProfile {
    my ( $response, $items, @items );
    my $uri = sprintf( "/user/getinfo/%s", shift ); 
    
    eval { $response = uaget( $uri ) };
    unless ( $@ ) { 
        $items = $response->content if $response->is_success;
        chomp( $items ) if $items;
        @items = split ( ':', $items ) if $items;
    }

    return \@items;
}

sub GetFollowUsers {
    my ( $response, $items ); my @items = [];
    my $uri = sprintf( "/follow/list4user/%s", shift ); 
    
    eval { $response = uaget( $uri ) };
    unless ( $@ ) { 
        $items = $response->content if $response->is_success;
        chomp( $items ) if $items;
        @items = split ( '\n', $items ) if $items;
    }

    return \@items;
}

sub ChangePWD {
    my ( $user, $old, $new, $type, $uri, $response ) = @_;

    if ( $type eq 'other' ) {
        eval { $response = uaget( "/user/changepwd/$user/$new" ) }; if ($@) { return 1; }
        return 1 unless $response->is_success;
        my $content = $response->content; chomp( $content );
        return 1 if $content eq 'set failed';
        return 0 if $content eq 'success';
    } else {
        $uri = sprintf ( "/user/changepwd/%s/%s/%s", $user, $old, $new );
        return 1 if length( $new ) < 6 || $new !~ m/[a-zA-Z]/ || $new !~ m/[0-9]/; 

        # 0: success.
        # 1: network error.
        # 2: auth error.
        eval { $response = uaget( $uri ) }; if ($@) { return 1; }
        return 1 unless $response->is_success;
  
        my $content = $response->content; chomp( $content );

        return 1 if $content eq 'set failed';
        return 2 if $content eq 'auth failed';
        return 0 if $content eq 'success';
    }
}

sub SetFilterMessage {
    my ( $user, $name, $node, $time, $response ) = @_;
    my $uri = sprintf ( "/filter/add/%s/%s/%s", $user, $name, $node );
    $uri = sprintf("/filter/add/%s/%s/%s/%s", $user, $time, $name, $node) if $time;

    eval { $response = uaget( $uri ) }; if ($@) { return 1; }
    return 1 unless $response->is_success;

    my $content = $response->content; chomp( $content ); 
    return 0 if $content eq 'ok';

    return 1;
}

sub GetNodes {
    my ( $hms, @nodes ) = @_;

    eval{ @nodes = NS::Hermes::Range->new()->load($hms)->list() };
    return 1 if $@;

    return 2 if scalar @nodes > 20;

    map {
        my $key = $_;
        return 3 if $key =~ /^\.|\.$/;
        $key =~ s/\.//g;
        return 3 unless length($key) > 4;
    } @nodes;

    return join(':', @nodes); 
}

sub SetFilterMessageGrp {
    my ( $user, $name, $hms, $time, $response ) = @_;

    my ( @nodes, $uri );
    eval { @nodes = NS::Hermes::Range->new()->load($hms)->list() };
    if ( $@ ) { return 1 }; 

    return 2 if scalar @nodes > 20;

    map {
          my $key = $_; 
          return 3 if $key =~ /^\.|\.$/;
          $key =~ s/\.//g;
          return 3 unless length($key) > 4;
    } @nodes;

    my $node = join(':', @nodes);

    $uri = sprintf ( "/filter/add/%s/%s/%s", $user, $name, $node );
    $uri = sprintf("/filter/add/%s/%s/%s/%s", $user, $time, $name, $node) if $time;

    eval { $response = uaget( $uri ) }; 
    if ($@) { return 1; }
    return 1 unless $response->is_success;

    my $content = $response->content; chomp( $content ); 
    return 0 if $content eq 'ok';

    return 1;
}

sub DelFilterMessage {
    my ( $user, $name, $node, $response ) = @_;

    eval { $response = uaget( "/filter/del/$name/$node" ) }; 
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
    my ( $user, $type, $uri, $response ) = @_;
    $uri = sprintf( "/notify/getstat/%s", $user ) if $type eq 'Alarm';
    $uri = sprintf( "/detail/getstat/%s", $user ) if $type eq 'Format';
    $uri = sprintf( "/method/get/%s",     $user ) if $type eq 'Method';

    eval { $response = uaget( $uri ) }; if ($@) { return 'error'; }

    return 'error' unless $response->is_success;

    my $content = $response->content; chomp( $content );
    return $content;
}

sub TriggerNotifyTest {
    my $uri = sprintf( "/notify/test/%s", shift );

    my $response;
    eval { $response = uaget( $uri ) }; if ($@) { return 1; }
    return 1 unless $response->is_success;

    my $content = $response->content; chomp( $content );

    return 0 if $content eq 'ok';

    return 1;
}

sub SetNotifyInfo {
    my ( $user, $type, $stat, $response, $uri ) = @_;
    if ( $type eq 'Alarm' ) {
        $uri = sprintf( "/notify/setstat/%s/%s", $user, $stat );
    } elsif ( $type eq 'Format' ) {
        $uri = sprintf( "/detail/setstat/%s/%s", $user, $stat );
    } elsif ( $type eq 'Method' ) {
        $uri = sprintf( "/method/add/%s/%s", $user, $stat );
    }

    eval { $response = uaget( $uri ) }; if ($@) { return 1; }
    return 1 unless $response->is_success;

    my $content = $response->content; chomp( $content );

    return 0 if $content eq 'ok';

    return 1;
}

sub GetUserViaToken {
    my $uri = sprintf( "/token/search/%s", shift ); 
    my $response;

    eval { $response = uaget( $uri ) };
    return 'error' if $@ || not $response->is_success;

    my $content = $response->content; chomp( $content );
    return $content;
}

sub GetRecords {
    my $uri = sprintf("/item/count/%s", shift);
    my $response;

    eval { $response = uaget( $uri ) };
    return '' if $@ || not $response->is_success;

    my $content = $response->content; chomp( $content );
    return $content;
}

sub GetGraph {
    my ($type, $name, $small, $width, $height) = @_;
    my $url = sprintf("http://rrd.nices.net:9922/stats/rrdGraph?type=%s&name=%s&small=%s&width=%s&height=%s", $type, $name, $small, $width, $height);
    my $res = $imgUA->get($url);
    
    return $res->content;
}

sub GetFilterItems {
    my ($self, $response, %f_items, @sp) = @_;

    eval { $response = uaget( "/filter/table" ) };
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
    my $uri = sprintf("/filter/list4user/%s", shift);
    my ($response,  %f_items, @sp);

    eval { $response = uaget( $uri ) };
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

    eval { $response = uaget( "/cronos/period/$start/$end" ) };
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
