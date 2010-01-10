package Blog::Bluejay;

use warnings;
use strict;

=head1 NAME

Blog::Bluejay - 

=head1 VERSION

Version 0.001

=cut

our $VERSION = '0.001';

use Any::Moose;
use Blog::Bluejay::Carp;

use Path::Class();
use Class::Inspector;
use Scalar::Util qw/weaken/;

has home => qw/reader _home lazy_build 1/;
sub _build_home {
    my $self = shift;

    return $ENV{BLOG_BLUEJAY_HOME} if defined $ENV{BLOG_BLUEJAY_HOME};

    require Blog::Bluejay::FindHomeDir;
    my $home = Blog::Bluejay::FindHomeDir->find( ref $self );
    $self->guessed_home( 1 );
    return $home;
}

# TODO Invalid if called before ->home
has guessed_home => qw/is rw isa Bool default 0/;

sub home_exists {
    my $self = shift;
    return -e $self->home;
}

sub home {
    return shift->home_dir( @_ );
}

sub home_dir {
    my $self = shift;
    if ( @_ ) {
        $self->path_mapper->base( shift );
    }
    return $self->path_mapper->dir( '/' );
}

has path_mapper => qw/is ro lazy_build 1/, handles => [qw/ dir file /];
sub _build_path_mapper {
    require Path::Mapper;
    my $self = shift;
    return Path::Mapper->new( base => $self->_home );
}

has schema_file => qw/is ro lazy_build 1/;
sub _build_schema_file {
    my $self = shift;
    return $self->file( 'run/bluejay.sqlite' );
}

has deploy => qw/is ro lazy_build 1/;
sub _build_deploy {
    require DBIx::SQLite::Deploy;
    my $self = shift;
    my $deploy;
    $deploy = DBIx::SQLite::Deploy->deploy( $self->schema_file, <<_END_,
[% PRIMARY_KEY = "INTEGER PRIMARY KEY AUTOINCREMENT" %]
[% KEY = "INTEGER" %]

id INTEGER PRIMARY KEY AUTOINCREMENT,
insert_dtime DATE NOT NULL DEFAULT current_timestamp,

[% CLEAR %]
--
CREATE TABLE post (

    id                  [% PRIMARY_KEY %],
    uuid                TEXT NOT NULL,
    luid                TEXT NULL,
    creation            DATE NOT NULL,
    modification        DATE,
    header              TEXT NULL,

    title               TEXT,
    description         TEXT,
    excerpt             TEXT,
    status              TEXT,

    file                TEXT,

    UNIQUE (uuid),
    UNIQUE (luid)
);
_END_
    );
};

has schema => qw/is ro lazy_build 1/;
sub _build_schema {
    require Blog::Bluejay::Schema;
    my $self = shift;
    my $schema = Blog::Bluejay::Schema->connect( $self->deploy->information );
    $schema->bluejay($self);
    weaken $schema->{bluejay};
    return $schema;
}

has modeler => qw/is ro lazy_build 1/;
sub _build_modeler {
    require Blog::Bluejay::Model;
    my $self = shift;
    my $model = Blog::Bluejay::Modeler->new( bluejay => $self, schema => $self->schema, namespace => '+Blog::Bluejay::Model' );
    return $model;
};

sub model {
    my $self = shift;
    return $self->modeler->model( @_ );
}

has assets => qw/is ro lazy_build 1/;
sub _build_assets {
    require Blog::Bluejay::Assets;
    my $self = shift;
    # TODO Implement overwrite option
    return Blog::Bluejay::Assets->new( base => $self->home );
}

has tt => qw/is ro lazy_build 1/;
sub _build_tt {
    require Template;
    my $self = shift;
    return Template->new({
        INCLUDE_PATH => [ $self->dir( 'assets/document' ) ],
    });
}

sub posts {
    my $self = shift;
    return $self->model( 'Post' )->search( @_ );
}

use Blog::Bluejay::Model;
use File::Find;
sub update {
    my $self = shift;

    my @posts;
    find({ no_chdir => 1, wanted => sub {

        return unless -f;
        return unless m/\.post$/;

        my $post = substr $_, 1 + length $self->home_dir.'';
        push @posts, $post;
    
    } }, $self->home_dir.'' );

    for my $file ( @posts ) {
        my $document = Blog::Bluejay::Model::Document->new;
        $document->_tp->read( $self->file( $file ) );

        $self->model( 'Post' )->update_or_create( {
            uuid => $document->uuid,
            creation => $document->creation,
            modification => $document->modification,
            title => $document->header->{title},
# TODO description, excerpt
            status => $document->header->{status},
            file => $file,
        } );
    }
}

sub load_tp {
    my $self = shift;
    my $file = shift;

    return Document::TriPart->new( file => $self->file( $file ) );
}

sub create_post {
    my $self = shift;

}

=head1 AUTHOR

Robert Krimen, C<< <rkrimen at cpan.org> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-blog-bluejay at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Blog-Bluejay>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Blog::Bluejay


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Blog-Bluejay>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Blog-Bluejay>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Blog-Bluejay>

=item * Search CPAN

L<http://search.cpan.org/dist/Blog-Bluejay/>

=back


=head1 ACKNOWLEDGEMENTS


=head1 COPYRIGHT & LICENSE

Copyright 2009 Robert Krimen.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.


=cut

1; # End of Blog::Bluejay
