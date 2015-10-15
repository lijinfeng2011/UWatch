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

our $VERSION = '0.1';

our %loginList;

hook 'before' => sub {
    if ( !session('mobile_user') && request->path_info =~ m{^/glance|^/subscribe|^/mesgDetail|^/profile} ) {
        redirect '/homepage';
    }
};

get '/' => sub {
    redirect '/homepage';
};

get '/homepage' => sub {
    my %param = %{request->params};
 
    if ( session('mobile_user') ) {
        redirect 'glance';
    } else {
        template 'homepage.tt', { status => $param{error} };
    }
};

get '/login' => sub {
    template 'login.tt';
};

any ['get', 'post'] => '/logout' => sub {
    session->destroy;
    redirect '/homepage';
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
                my $mesgGroup = Alarm::GetMessageGroup( $user );
                template 'glance.tt', { user => session('mobile_user'), mesgGroup => $mesgGroup };
            } else {
                template '/homepage', { status => $response, token => $token };
            }
        }
    } else {
        $loginList{$user} = time;
        template '/homepage', { token => $token };
    }
};

get '/glance' => sub {
    my $mesgGroup = Alarm::GetMessageGroup( session('mobile_user') );
    template 'glance.tt', { user => session('mobile_user'), mesgGroup => $mesgGroup };
};

get '/subscribe' => sub {
    my %param = %{request->params};

    my $response = Alarm::GetAllAlarmItem();
    return template 'subscribe.tt', { user => session('mobile_user'), error => 1 } unless $response;

    my $groupMap = { name => [] }; my $countMap = {};
        
    map {
        my $group = $_; 
        push @{$groupMap->{name}}, $group;
        $groupMap->{$group} = [] unless exists $groupMap->{$group};
        map { push @{$groupMap->{$group}}, $_ } sort keys %{$response->{$group}};

        $countMap->{$_} = scalar keys %{$response->{$group}};
    } @{$response->{name}};

    return template 'subscribe.tt', { user => session('mobile_user'), groupMap => $groupMap, countMap => $countMap };
};

get '/mesgDetail' => sub {
    my %param = %{request->params};
    my $message = Alarm::GetMessageDetail( $param{id}, session('mobile_user') );
    template 'mesgDetail.tt', { mesgs => $message, count => scalar @$message, hermes => $param{id} };
};

get '/profile' => sub {
    my $users = Alarm::GetAllUsers(); my @followUsers = ();
    my $follower = Alarm::GetFollowUsers( session('mobile_user') );

    map {
        my $user = $_; 
        $user->{followed} = 1 if grep {$user->{name} eq $_} @$follower;
        push @followUsers, $user; 
    } grep { $_->{name} ne session('mobile_user') } @$users;

    my $profileItems = Alarm::GetProfile( session('mobile_user') );
    my %options = ( user => session('mobile_user'), followUsers => \@followUsers );

    if ( scalar @$profileItems == 4 ) {
        $options{phone} = $profileItems->[0];
        $options{address} = $profileItems->[1];
        $options{oncaller} = $profileItems->[2];
        $options{refTime} = $profileItems->[3];
    }

    template 'profile.tt', \%options;
};


any ['get', 'post'] => '/ajaxBookSubscribe' => sub {
    return to_json({ response => 'No Content' }) unless session('mobile_user');    

    my %param = %{request->params};
    my $response = Alarm::BookSubscribeItems( \%param, session('mobile_user') );
    to_json({ response => $response });
};

any ['get', 'post'] => '/ajaxGetMessageGroup' => sub {
    return to_json({ response => 'No Content' }) unless session('mobile_user');    

    my $mesges = Alarm::GetMessageGroup( session('mobile_user') );
    to_json({ mesgGrp => $mesges });
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


true;

