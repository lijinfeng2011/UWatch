package Web;
use Dancer ':syntax';

use Data::Dumper;
use Dancer::Plugin::Ajax;
use JSON;
use POSIX;
use FindBin qw( $RealBin );
use LWP::UserAgent;
use Digest::MD5;
use Cwd;
use File::Basename;
use Ctrl;
use URI::Escape;

our $VERSION = '0.1';
our %loginList;

$|++;

set environment => 'production';

hook 'before' => sub {
    if ( request->user_agent && request->user_agent =~ /iphone|android/i) { session 'view' => 'mobile'; } 
    else { session 'view' => 'desktop'; }

    if (!session('mobile_user') && request->path_info =~ m{^/glance|^/subscribe|^/mesgDetail|^/profile|^verified}) {
         redirect '/homepage';
    }
};

get '/ext/nsso/login' => sub{
    my $sid = params->{sid};

    return redirect config->{sso}{'ref'}.config->{'web_addr'}.request->env->{REQUEST_URI} unless $sid;

    my ( $ua, $re, $info ) = LWP::UserAgent->new( ssl_opts => { verify_hostname => 0 });
    $ua->timeout( 6 );

    $re = $ua->get( config->{sso}{'sid'}.$sid );

    eval{ $info = decode_json $re->decoded_content };

    return redirect config->{sso}{'ref'}.config->{'web_addr'}.request->env->{REQUEST_URI}
        unless $re && $re->is_success && $info && $info->{user};

    session user => $info->{user};
    session mobile_user => $info->{user};

    redirect "/otherLogin";
};

################# Route ####################
get '/' => sub {
    my %param = %{request->params};
    my %env = %{request->env};

    my $lxErr = session('lx_error');
    my $view = session('view') eq 'desktop' ? 'homepage_desktop.tt' : 'homepage.tt';

    return renderGlance() if session('mobile_user');

    my $isInternal = $env{'HTTP_X_REAL_IP'} && $env{'HTTP_X_REAL_IP'} =~ m/^10\./;

    if ( $lxErr ) {
        session 'lx_error' => '0';
        template $view, { status => $lxErr, internal => $isInternal };
    } else {
        template $view, { internal => $isInternal }; 
    }
};

get '/calendar' => sub {
    template 'external/calendar.tt';
};

get '/homepage' => sub {
    my %param = %{request->params};
    my %env = %{request->env};

    my $isInternal = $env{'HTTP_X_REAL_IP'} && $env{'HTTP_X_REAL_IP'} =~ m/^10\./;

    # Access via with token;
    if ( $param{token} ) {
        my $user = Ctrl::GetUserViaToken($param{token});
        if ( $user && $user ne 'error' ) {
            session 'mobile_user' => $user;
            renderGlance();
        }
    } elsif ( session('mobile_user') ) {
        renderGlance();
    } elsif ( session('view') eq 'desktop' ) {
        template 'homepage_desktop.tt', { status => $param{error}, internal => $isInternal };
    } else {
        template 'homepage.tt', { status => $param{error} };
    }
};

get '/login' => sub { 
    template 'login.tt', +{ web_addr => config->{'web_addr'}, sso => config->{'sso'} }; 
};

get '/otherLogin' => sub {
    unless ( Ctrl::HasUser( session('mobile_user') ) ) {
        my ( $pass, $md5 ) = Ctrl::Mkpass();
        Ctrl::AddUser(session('mobile_user'), $md5); 
    }

    session 'login_type' => 'other';
    renderGlance(); 
};

get '/logout' => sub {
    my %env = %{request->env};
    
    session->destroy;

    my $isInternal = $env{'HTTP_X_REAL_IP'} && $env{'HTTP_X_REAL_IP'} =~ m/^10\./;

    if (request->user_agent =~ /iphone|android/i) { 
        session 'view' => 'mobile'; 
        return template 'homepage.tt'; 
    } else { 
        session 'view' => 'desktop'; 
        template 'homepage_desktop.tt', { internal => $isInternal };
    }
};

post '/checkin' => sub {
    my %param = %{request->params};
    my ( $user, $pwd, $code ) = @param{ qw( lname lpwd code ) };

    my $token = Digest::MD5->new->add( time % 13 )->hexdigest;

    # 没有code = 暴力破解;
    return template "login_mesg.tt", { status => 101 } unless $code;

    # r参数无效 = 已过期;
    return template 'login_mesg.tt', { status => 102 } unless session('captcha_time');

    my $ped = time - session('captcha_time');
    return template 'login_mesg.tt', { status => 102 } if $ped > 30;

    # 验证码错误;
    return template 'login_mesg.tt', { status => 103 } unless lc(session('captcha')) eq lc($code);

    if ( ( not $loginList{$user} ) || ( time - $loginList{$user} > 3 ) ) {
        $loginList{$user} = time;

        unless ( session('mobile_user') ) {
            my $response = Ctrl::Login( $user, $pwd );

            return template 'login_mesg.tt', { status => $response } if $response;
            
            session 'mobile_user' => $user;
            session 'login_type' => 'normal';
            renderGlance();
        }
    } else {
        $loginList{$user} = time;
        template 'login_mesg.tt', { status => 104 };
    }
};

get '/getCaptcha' => sub {
    my ( $code, @code );
    map { push @code, $_ } ('0'..'9');
    map { push @code, $_ } ('a'..'z');
    map { push @code, $_ } ('A'..'Z');
    map { $code = $code . $code[rand(61)] } (1 .. 4);

    session 'captcha' => $code;
    session 'captcha_time' => time;

    my $path = ( $0 =~ m{^/} ) ? dirname($0) : dirname( getcwd(). "/$0" );
    
    header('Content-Type' => 'image/png');
    my $php = config->{php_path} || 'php';
    return `$php $path/../lib/captcha.php $code`;
};

get '/glance' => sub { renderGlance(); };

any '/subscribe' => sub {
    my $response = Ctrl::GetAllAlarmItem();
    my $allBiz = Ctrl::GetAllBiz();

    return template 'subscribe.tt', { user => session('mobile_user'), error => 1, Biz => $allBiz } unless $response;

    my $groupMap = { name => [] }; my $countMap = {};
    
    if ( my $fname = request->params->{fname} ) {
        map {
            $response->{$_} = {} if exists $response->{$_};
        } split('-', $fname);
    } 

    if ( my $fbiz = request->params->{fbiz} ) {
        my @fbizArray = split(':', $fbiz);
        while ( my ($key, $value) = each ( %$response ) ) {
            next unless ref ( $value ) eq 'HASH';
            my $section = {};
            foreach my $biz ( @fbizArray ) {
                $section->{$biz} = $value->{$biz} if exists $value->{$biz};
            }
            $response->{$key} = $section;            
        } 
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

    template 'subscribe.tt', { user => session('mobile_user'), groupMap => $groupMap, countMap => $countMap, Biz => $allBiz };
};

get '/advancedSetting' => sub {
    my $allBiz = Ctrl::GetAllBiz();
    template 'advancedSetting.tt', { Biz => $allBiz }; 
};

get '/mesgDetail' => sub {
    my %param = %{request->params};
    my $message;
 
    eval {
        if ( $param{type} eq 'old' ) {
            $message = Ctrl::GetMessageDetail( session('mobile_user'), $param{id}, 'curr', 'tail', 100 );
        } else {
            $message = Ctrl::GetMessageDetail( session('mobile_user'), $param{id}, 'curr', 'head', 100 );
        }
    };

    return if @_;

    # XSS Attack
    validParams( \%param );

    if (session('view') eq 'desktop') {
        template 'mesgDetail_desktop.tt', { mesgs => $message, count => scalar @$message, hermes => $param{id}, oldview => $param{type} eq 'old' ? 1 : 0 };
    } else {
        template 'mesgDetail.tt', { mesgs => $message, count => scalar @$message, hermes => $param{id}, oldview => $param{type} eq 'old' ? 1 : 0 };
    }
};

get '/profile' => sub {
    my $users      = Ctrl::GetAllUsers(); my @followUsers = ();
    my $follower   = Ctrl::GetFollowUsers( session('mobile_user') );
    my $notifyInfo = Ctrl::GetNotifyInfo( session('mobile_user') );

    map {
        my $user = $_; 
        $user->{followed} = 1 if grep {$user->{name} eq $_} @$follower;
        push @followUsers, $user; 
    } grep { $_->{name} ne session('mobile_user') } @$users;

    my $profileItems = Ctrl::GetProfile( session('mobile_user') );
    my %options = ( user => session('mobile_user'), followUsers => \@followUsers );

    if ( scalar @$profileItems == 4 ) {
        $options{phone}    = $profileItems->[0];
        $options{address}  = $profileItems->[1];
        $options{oncaller} = Encode::decode_utf8(uri_unescape($profileItems->[2]));
        $options{refTime}  = $profileItems->[3];
    }

    $options{stopAlarm}  = $notifyInfo->{stopAlarm} eq 'off' ? 1 : 0;
    $options{fullFormat} = $notifyInfo->{fullFormat} eq 'on' ? 1 : 0;
    $options{skipOldPwd} = (session('login_type') && session('login_type') eq 'other') ? 1 : 0;

    map {
        if ( $_ =~ m/^(.+?)-(.+)/ ) {
            $options{$1} = $2 unless exists $options{$1};
        }
    } split ( /:/,
      Encode::decode_utf8(uri_unescape($notifyInfo->{repMethod})));

    template 'profile.tt', \%options;
};

############### Ajax ####################
ajax '/ajaxBookSubscribe' => sub {
    # CSRF Attack
    return unless validRequest();

    my %param = %{request->params};
    my $response = Ctrl::BookSubscribeItems( \%param, session('mobile_user') );
    to_json({ response => $response });
};

ajax '/ajaxGetMessageGroup' => sub {
    return unless validRequest();

    my $type = request->params->{type};
    my $message = Ctrl::GetMessageGroup(session('mobile_user'));

    if ( request->params->{type} eq 'self' ) {
        to_json({ mesgGrp => $message->[0] });
    } else {
        to_json({ mesgGrp => $message->[1] });
    }
};

ajax '/ajaxGetSubDetail' => sub {
    return unless validRequest();

    my %param = %{request->params};
    my $items = Ctrl::GetSubscribeDetail( $param{group}, session('mobile_user') );
    to_json({ subDetail => $items });
};

ajax '/ajaxSetProfile' => sub {
    return unless validRequest();

    my %param = %{request->params};

    # XSS Attack
    validParams( \%param );

    my $response = Ctrl::SetProfile( \%param, session('mobile_user') );
    to_json({ response => $response });
};

ajax '/ajaxChangePWD' => sub {
    return unless validRequest();

    my %param = %{request->params};
    my $resp = Ctrl::ChangePWD(session('mobile_user'), $param{old}, $param{new}, session('login_type'));
    to_json({ response => $resp });
};

ajax '/ajaxGetMessage' => sub {
    return unless validRequest();

    my %param = %{request->params}; my $response;

    if ( $param{type} eq 'new' ) {
        $response = Ctrl::GetMessageDetail(session('mobile_user'), $param{id}, 'curr', 'head', 'all');
    }
    elsif ( $param{type} eq 'old' ) {
        $response = Ctrl::GetMessageDetail(session('mobile_user'), $param{id}, $param{pos}, 'tail', 100);
    }
    
    to_json({ response => $response });
};

ajax '/ajaxSetFilterMessage' => sub {
    return unless validRequest();

    my %param = %{request->params};

    my $response = Ctrl::SetFilterMessage( session('mobile_user'), $param{name}, $param{node}, $param{time} );
    to_json({ response => $response });
};

ajax '/ajaxSetFilterMessageGrp' => sub {
    return unless validRequest();

    my %param = %{request->params};

    my $response = Ctrl::SetFilterMessageGrp( session('mobile_user'), $param{name}, $param{hms}, $param{time} );

    to_json({ response => $response });
};

ajax '/ajaxGetNodes' => sub {
    return unless validRequest();

    my %param = %{request->params};

    my $nodes = Ctrl::GetNodes( $param{hms} );

    to_json({ nodes => $nodes, name => $param{name}, time => $param{time}, hermes => $param{hms} });
};

ajax '/ajaxDelFilterMessage' => sub {
    return unless validRequest();

    my %param = %{request->params};
    my $response = Ctrl::DelFilterMessage( session('mobile_user'), $param{name}, $param{node} );
    to_json({ response => $response });
};

ajax '/ajaxSetAlarm' => sub {
    return unless validRequest();

    my %param = %{request->params};
    my $response = Ctrl::SetNotifyInfo( session('mobile_user'), 'Alarm', $param{value} );
    to_json({ response => $response });
};

ajax '/ajaxSetFormat' => sub {
    return unless validRequest();

    my %param = %{request->params};
    my $response = Ctrl::SetNotifyInfo( session('mobile_user'), 'Format', $param{value} );
    to_json({ response => $response });
};

ajax '/ajaxSetMethod' => sub {
    return unless validRequest();

    my %param = %{request->params};

    # XSS Attack
    validParams( \%param );

    my $response = Ctrl::SetNotifyInfo( session('mobile_user'), 'Method', $param{value} );
    to_json({ response => $response });
};

ajax '/ajaxTriggerTest' => sub {
    return unless validRequest();

    my $response = Ctrl::TriggerNotifyTest(session('mobile_user'));
    to_json({ response => $response });
};

ajax '/ajaxGetRecords' => sub {
    return unless validRequest();

    my $response = Ctrl::GetRecords( request->params->{hermes} );
    to_json({ response => $response });
};

ajax '/ajaxGetTasks' => sub {
    my ($start, $end) = ( request->params->{s}, request->params->{e} );
    return to_json({ response => 'No Content'}) unless $start =~ /^\d+$/ && $end =~ /^\d+$/;
    my $response = Ctrl::GetTasks( $start, $end );
    to_json( {response => $response} );
};

ajax '/ajaxGetFilterItems' => sub {
    my $response = Ctrl::GetFilterItems(session('mobile_user'));
    to_json( {response => $response} );
};

ajax '/ajaxGetNodeDetail' => sub {
    return unless validRequest();

    my $response = Ctrl::GetNodeDetail(request->params->{node});
    content_type 'application/json';
    to_json( { detail => $response } );
};

ajax '/ajaxGetBizByNode' => sub {
    return unless validRequest();

    my $response = Ctrl::GetBizbyNodes(request->params->{node});
    to_json( { bizList => $response } );
};

ajax '/ajaxGetNodesByHermes' => sub {
    return unless validRequest();

    my $response = Ctrl::GetNodesbyHermes(request->params->{hermes});
    to_json( { nodesList => $response } );
};

any '/getGraph' => sub {
    my %param = %{request->params};
    my ($type, $name, $small) = ($param{type}, $param{name}, $param{small});
    my ($height, $width) = (600, 800);
    ($height, $width) = (120, 300) if $small; 

    header('Content-Type' => 'image/png');
    return Ctrl::GetGraph( $type, $name, $small, $width, $height );
};

############## Functions ################
sub renderGlance {
    my $mesgGroup = Ctrl::GetMessageGroup(session('mobile_user'));

    template 'glance.tt', { 
        user => session('mobile_user'),
        selfMesgGroup => $mesgGroup->[0], 
        oncallMesgGroup => $mesgGroup->[1],
        isOncall => $mesgGroup->[2]
    };
};

# CSRF Attack;
sub validRequest {
    my $web_addr = config->{web_addr};
    return request->referer && request->referer =~ m{^$web_addr} && session('mobile_user');
};

# XSS Attack;
sub validParams {
    my $params = shift;

    foreach my $k (keys %{$params} )  {
        $params->{$k} =~ s/</&lt;/g; 
        $params->{$k} =~ s/>/&gt;/g;
        $params->{$k} =~ s/[|=]//g;
    }
};


true;

