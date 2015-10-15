package Auth;

use Dancer qw( session );

use strict;
use warnings;
use Web;

use Carp;

sub setUserSession
{
    my %param = @_;
    
    session user => $param{user};
}


1;
