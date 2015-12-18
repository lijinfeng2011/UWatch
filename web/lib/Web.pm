package Web;
use Dancer ':syntax';

use Data::Dumper;
use JSON;
use POSIX;
use FindBin qw( $RealBin );
use LWP::UserAgent;
use Digest::MD5;

use File::Basename;
use Alarm;
use URI::Escape;

our $VERSION = '0.1';
our %loginList;

hook 'before' => sub {
    if (request->user_agent =~ /iphone|android/i) { session 'view' => 'mobile'; } 
    else { session 'view' => 'desktop'; }

    if (!session('mobile_user')&& request->path_info=~m{^/glance|^/subscribe|^/mesgDetail|^/profile}){
        if (session('view') eq 'desktop') { template 'homepage_desktop.tt', {}; } 
        else { template 'homepage.tt', {}; }
    }
};

################# Route ####################
get '/' => sub {
    if ( session('mobile_user') ) { renderGlance(); } 
    else {
        if ( session('view') eq 'desktop' ) { template 'homepage_desktop.tt', {}; } 
        else { template 'homepage.tt', {}; }
    }
};

get '/homepage' => sub {
    my %param = %{request->params};

    # Access via with token;
    if ( $param{token} ) {
        my $user = Alarm::GetUserViaToken($param{token});
        if ( $user && $user ne 'error' ) {
            session 'mobile_user' => $user;
            renderGlance();
        }
    } elsif ( session('mobile_user') ) {
        renderGlance();
    } elsif ( session('view') eq 'desktop' ) {
        template 'homepage_desktop.tt', { status => $param{error} };
    } else {
        template 'homepage.tt', { status => $param{error} };
    }
};

get '/login' => sub { template 'login.tt'; };

get '/logout' => sub {
    session->destroy;

    if (request->user_agent =~ /iphone|android/i) { 
        session 'view' => 'mobile'; 
        template 'homepage.tt', {}; 
    } else { 
        session 'view' => 'desktop'; 
        template 'homepage_desktop.tt', {};
    }
};

post '/checkin' => sub {
    my %param = %{request->params};
    my ( $user, $pwd ) = @param{ qw( lname lpwd ) };

    my $token = Digest::MD5->new->add( time % 13 )->hexdigest;

    if ( ( not $loginList{$user} ) || ( time - $loginList{$user} > 3 ) ) {
        $loginList{$user} = time;

        unless ( session('mobile_user') ) {
            my $response = Alarm::Login( $user, $pwd );

            if ( not $response ) {
                session 'mobile_user' => $user;
                renderGlance();
            } else {
                template '/homepage', { status => $response, token => $token };
            }
        }
    } else {
        $loginList{$user} = time;
        template '/homepage', { token => $token };
    }
};

get '/glance' => sub { renderGlance(); };

any ['get', 'post'] => '/subscribe' => sub {
    my $response = Alarm::GetAllAlarmItem();
    return template 'subscribe.tt', { user => session('mobile_user'), error => 1 } unless $response;

    my $groupMap = { name => [] }; my $countMap = {};
    
    if ( my $fname = request->params->{fname} ) {
        map {
            $response->{$_} = {} if exists $response->{$_};
        } split('-', $fname);
    } 
    map {
        my $group = $_; 
        push @{$groupMap->{name}}, $group;
        $groupMap->{$group} = [] unless exists $groupMap->{$group};
        map {
            push @{$groupMap->{$group}}, 
                { name => $_, 
                  alias => Encode::decode_utf8(uri_unescape($response->{$group}->{$_}))
                };
        } sort keys %{$response->{$group}};

        $countMap->{$_} = scalar keys %{$response->{$group}};
    } @{$response->{name}};

    template 'subscribe.tt', { user => session('mobile_user'), groupMap => $groupMap, countMap => $countMap };
};

get '/subSetting' => sub {
    my $allBiz = Alarm::GetAllBiz();
    template 'subSetting.tt', { Biz => $allBiz }; 
};

get '/mesgDetail' => sub {
    my %param = %{request->params};
    my $message;
    if ( $param{type} eq 'old' ) {
        $message = Alarm::GetMessageDetail( session('mobile_user'), $param{id}, 'curr', 'tail', 100 );
    } else {
        $message = Alarm::GetMessageDetail( session('mobile_user'), $param{id}, 'curr', 'head', 100 );
    }

    $param{id} =~ s/</&lt;/g; $param{id} =~ s/>/&gt;/g;
    $param{id} =~ s/[(|)|=]//g;


    if (session('view') eq 'desktop') {
        template 'mesgDetail_desktop.tt', { mesgs => $message, count => scalar @$message, hermes => $param{id}, oldview => $param{type} eq 'old' ? 1 : 0 };
    } else {
        template 'mesgDetail.tt', { mesgs => $message, count => scalar @$message, hermes => $param{id}, oldview => $param{type} eq 'old' ? 1 : 0 };
    }
};

get '/profile' => sub {
    my $users      = Alarm::GetAllUsers(); my @followUsers = ();
    my $follower   = Alarm::GetFollowUsers( session('mobile_user') );
    my $notifyInfo = Alarm::GetNotifyInfo( session('mobile_user') );

    map {
        my $user = $_; 
        $user->{followed} = 1 if grep {$user->{name} eq $_} @$follower;
        push @followUsers, $user; 
    } grep { $_->{name} ne session('mobile_user') } @$users;

    my $profileItems = Alarm::GetProfile( session('mobile_user') );
    my %options = ( user => session('mobile_user'), followUsers => \@followUsers );

    if ( scalar @$profileItems == 4 ) {
        $options{phone}    = $profileItems->[0];
        $options{address}  = $profileItems->[1];
        $options{oncaller} = Encode::decode_utf8(uri_unescape($profileItems->[2]));
        $options{refTime}  = $profileItems->[3];
    }

    $options{stopAlarm}  = $notifyInfo->{stopAlarm} eq 'off' ? 1 : 0;
    $options{fullFormat} = $notifyInfo->{fullFormat} eq 'on' ? 1 : 0;

    map {
        if ( $_ =~ m/^(.+?)-(.+)/ ) {
            $options{$1} = $2 unless exists $options{$1};
        }
    } split ( /:/,
      Encode::decode_utf8(uri_unescape($notifyInfo->{repMethod})));

    template 'profile.tt', \%options;
};

############### Ajax ####################
any ['get', 'post'] => '/ajaxBookSubscribe' => sub {
    return to_json({ response => 'No Content' }) unless session('mobile_user');    

    my %param = %{request->params};
    my $response = Alarm::BookSubscribeItems( \%param, session('mobile_user') );
    to_json({ response => $response });
};

any ['get', 'post'] => '/ajaxGetMessageGroup' => sub {
    return to_json({ response => 'No Content' }) unless session('mobile_user');    

    my $type = request->params->{type};
    my $message = Alarm::GetMessageGroup(session('mobile_user'));

    if ( request->params->{type} eq 'self' ) {
        to_json({ mesgGrp => $message->[0] });
    } else {
        to_json({ mesgGrp => $message->[1] });
    }
};

any ['get', 'post'] => '/ajaxGetSubDetail' => sub {
    return to_json({ response => 'No Content' }) unless session('mobile_user');    

    my %param = %{request->params};
    my $items = Alarm::GetSubscribeDetail( $param{group}, session('mobile_user') );
    to_json({ subDetail => $items });
};

any ['get', 'post'] => '/ajaxSetProfile' => sub {
    return to_json({ response => 'No Content' }) unless session('mobile_user');

    my %param = %{request->params};
    my $response = Alarm::SetProfile( \%param, session('mobile_user') );
    to_json({ response => $response });
};

any ['get', 'post'] => '/ajaxChangePWD' => sub {
    return to_json({ response => 'No Content' }) unless session('mobile_user');

    my %param = %{request->params};
    my $response = Alarm::ChangePWD( session('mobile_user'), $param{old}, $param{new} );
    to_json({ response => $response });
};

any ['get', 'post'] => '/ajaxGetMessage' => sub {
    return to_json({ response => 'No Content' }) unless session('mobile_user');

    my %param = %{request->params}; my $response;

    if ( $param{type} eq 'new' ) {
        $response = Alarm::GetMessageDetail(session('mobile_user'), $param{id}, 'curr', 'head', 'all');
    }
    elsif ( $param{type} eq 'old' ) {
        $response = Alarm::GetMessageDetail(session('mobile_user'), $param{id}, $param{pos}, 'tail', 100);
    }
    
    to_json({ response => $response });
};

any ['get', 'post'] => '/ajaxSetFilterMessage' => sub {
    return to_json({ response => 'No Content' }) unless session('mobile_user');

    my %param = %{request->params};
    my $response = Alarm::SetFilterMessage( session('mobile_user'), $param{name}, $param{node} );
    to_json({ response => $response });
};

any ['get', 'post'] => '/ajaxDelFilterMessage' => sub {
    return to_json({ response => 'No Content' }) unless session('mobile_user');

    my %param = %{request->params};
    my $response = Alarm::DelFilterMessage( session('mobile_user'), $param{name}, $param{node} );
    to_json({ response => $response });
};

any ['get', 'post'] => '/ajaxSetAlarm' => sub {
    return to_json({ response => 'No Content' }) unless session('mobile_user');

    my %param = %{request->params};
    my $response = Alarm::SetNotifyInfo( session('mobile_user'), 'Alarm', $param{value} );
    to_json({ response => $response });
};

any ['get', 'post'] => '/ajaxSetFormat' => sub {
    return to_json({ response => 'No Content' }) unless session('mobile_user');

    my %param = %{request->params};
    my $response = Alarm::SetNotifyInfo( session('mobile_user'), 'Format', $param{value} );
    to_json({ response => $response });
};

any ['get', 'post'] => '/ajaxSetMethod' => sub {
    return to_json({ response => 'No Content' }) unless session('mobile_user');

    my %param = %{request->params};
    my $response = Alarm::SetNotifyInfo( session('mobile_user'), 'Method', $param{value} );
    to_json({ response => $response });
};

any ['get', 'post'] => '/ajaxTriggerTest' => sub {
    return to_json({ response => 'No Content' }) unless session('mobile_user');

    my $response = Alarm::TriggerNotifyTest(session('mobile_user'));
    to_json({ response => $response });
};

any ['get', 'post'] => '/ajaxGetRecords' => sub {
    return to_json({ response => 'No Content' }) unless session('mobile_user');

    my $response = Alarm::GetRecords( request->params->{hermes} );
    to_json({ response => $response });
};

any ['get', 'post'] => '/ajaxGetTasks' => sub {
    my $response = Alarm::GetTasks(request->params->{s}, request->params->{e});
    to_json( {response => $response} );
};

any ['get', 'post'] => '/ajaxGetFilterItems' => sub {
    my $response = Alarm::GetFilterItems(session('mobile_user'));
    to_json( {response => $response} );
};

############## Functions ################
sub renderGlance {
    my $mesgGroup = Alarm::GetMessageGroup(session('mobile_user'));

    template 'glance.tt', { 
        user => session('mobile_user'),
        selfMesgGroup => $mesgGroup->[0], 
        oncallMesgGroup => $mesgGroup->[1],
        isOncall => $mesgGroup->[2]
    };
};


true;

