package Admin;
use Dancer ':syntax';

use LWP::UserAgent;
use Digest::MD5;

use Admin::Auth;
use Admin::User;
use Admin::Item;
use Admin::Follow;

our $VERSION = '0.1';

hook 'before' => sub { 
    redirect '/admin/login'
        if request->path_info !~ /^\/admin\/login/ && ! session('admin');
};

get '/' => sub { redirect '/admin/index'; };

any ['get', 'post'] =>  '/admin/login' => sub {
    my %param = %{request->params};
    my ( $usr, $pwd ) = @param{ qw( lusr lpwd ) };
    if( $usr && $pwd &&  Admin::Auth::check( $usr, $pwd ) )
    {  
        session 'user' => $usr;
        session 'admin' => $usr;
        redirect '/admin/index';
    }
    template 'admin/login.tt';
};

any ['get', 'post'] =>  '/admin/login-md5' => sub {
    my %param = %{request->params};
    my ( $usr, $pwd ) = @param{ qw( lusr lpwd ) };
    if( $usr && $pwd &&  Admin::Auth::check_md5( $usr, $pwd ) )
    {  
        session 'user' => $usr;
        session 'mobile_user' => $usr;
        redirect '/';
    }
    template 'admin/login.tt';
};

any ['get', 'post'] => '/admin/logout' => sub {
    session->destroy;
    redirect '/admin/login';
};

any ['get', 'post'] =>  '/admin/index' => sub {
    redirect '/admin/user';
};

any ['get', 'post'] =>  '/admin/user' => sub {
    redirect '/admin/user-info';
};

any ['get', 'post'] =>  '/admin/user-info' => sub {
    my %param = %{request->params};
    my @info = @param{qw(name phone email notify interval)};
    Admin::User::info_set( $info[0], join ':', map{$info[$_] ||''}1..4 ) if $info[0];

    my $user =  session( 'user' );

    my ( $adduser, $addpass, $deluser ) = @param{qw(adduser addpass deluser )};
    Admin::User::adduser( $adduser, $addpass ) if $adduser && $addpass;
    Admin::User::deluser( $deluser ) if $deluser;

    my ( $chuser, $chpass ) = @param{qw(chuser chpass)};
    Admin::User::chpasswd( $chuser, $chpass ) if $chuser && $chpass;

    my @info = Admin::User::info_list();

    my ( $u, $s ) = @param{qw(u s)};
    Admin::User::notify_set( $u, $s ) if $u && $s;
    my %user = Admin::User::notify_list();
    map{ push @$_, $user{$_->[0]} }@info;
    
    template 'admin/user-info.tt', +{ user => $user, info => \@info };
};

any ['get', 'post'] =>  '/admin/item' => sub {
    redirect '/admin/item-info';
};

any ['get', 'post'] =>  '/admin/item-info' => sub {
    my %param = %{request->params};
    my $user =  session( 'user' );

    my ( $additem, $delitem ) = @param{qw(additem delitem )};
    Admin::Item::add( $additem ) if $additem;
    Admin::Item::del( $delitem ) if $delitem;
    my @info = Admin::Item::list();

    template 'admin/item-info.tt', +{ user => $user, info => \@info };
};

any ['get', 'post'] =>  '/admin/follow' => sub {
    redirect '/admin/follow-info';
};

any ['get', 'post'] =>  '/admin/follow-info' => sub {
    my %param = %{request->params};
    my $user =  session( 'user' );

    my ( $addowner, $addfollower, $delowner, $delfollower ) 
        = @param{qw( addowner addfollower delowner delfollower )};
    Admin::Follow::add( $addowner, $addfollower ) if $addowner && $addfollower;
    Admin::Follow::del( $delowner, $delfollower ) if $delowner && $delfollower;
    my @info = Admin::Follow::list();

    template 'admin/follow-info.tt', +{ user => $user, info => \@info };
};

true;
