package Blog::Bluejay::FindHomeDir;

use strict;
use warnings;

use Cwd();
use Path::Class;

sub cwd {
    return dir( Cwd::cwd() )->absolute->cleanup;
}

sub find {
    my $self = shift;
    my $dir = shift;

    $dir = Cwd::cwd() unless defined $dir && length $dir;
    $dir = dir( $dir )->absolute->cleanup;

    my $root_dir = dir( '/' );

    do {
        return $dir if -f $dir->file( 'bluejay' );
        $dir = $dir->parent;
    } while ( $dir ne $root_dir );

    return undef;
}

1;
