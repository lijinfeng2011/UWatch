package Client;
use strict;
use warnings;

use Carp;

use IO::Socket;
use IO::Select;
use Time::HiRes qw/time/;

use constant TIMEOUT => 30;


sub new
{
    my ( $class, %this ) = @_;

    confess "undef server.\n" unless $this{server};
   
    $this{sock} = my $sock = IO::Socket::INET->new(
        Blocking => 0, Timeout => TIMEOUT,
        Proto => 'tcp', Type => SOCK_STREAM,
        PeerAddr => $this{server},
    );

    die "socket:[addr:$this{server}] $!\n" unless $sock;
    return bless \%this, ref $class || $class;
}

sub get
{
    my $this = shift;
    my $sock = $this->{sock};

    $sock->send( shift ) if @_;
#    $sock->shutdown( 1 );

    my $select = IO::Select->new();
    $select->add( $sock );

sleep 1;
    my $buffer = '';
    while( 1 )
    {
     #   die "read from socker timeout\n" 
      next  unless my @ready = $select->can_read( 5 );

        my $fh = shift @ready;
        my $tmp = <$fh>;
        if( $tmp ) { $buffer .= $tmp; }
        else
        {   
            $select->remove( $fh );
            close( $fh );
            last;
        }
        
    }
    eval { $sock->shutdown( 2 ) };

    $buffer =~ s/#\+END\+#$// ? $buffer : die "syntax err:$buffer\n";
}

sub indatamodle
{
    my $this = shift;
    my $sock = $this->{sock};

    my $select = IO::Select->new();
    $select->add( $sock );

    $sock->send( 'data' );

    map{
        my ( $fh ) = $select->can_read( 0.1 );
        if( $fh && ( my $mesg = <$fh> ) )
        {
            return $this if $mesg =~ /modle/;
        }
    }0 .. 9;

    die "indatamodle fail.\n";
}

sub send
{
    my $this = shift;
    my $sock = $this->{sock};
    map{ $sock->send( $_ ) }@_;
}

1;
