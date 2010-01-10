package Blog::Bluejay::Model;

use strict;
use warnings;

package Blog::Bluejay::Modeler;

use Moose;

extends qw/DBICx::Modeler/;

with qw/Blog::Bluejay::Component/;

package Blog::Bluejay::Modeler::Model;

use Moose::Role;

has bluejay => qw/is ro lazy_build 1/;
sub _build_bluejay {
    return shift->_model__modeler->bluejay; # Doing this sort of access in the model is horribly ugly
}

package Blog::Bluejay::Model::Post;

use DBICx::Modeler::Model;

with qw/Blog::Bluejay::Modeler::Model/;

use DateTimeX::Easy qw/datetime/;
use Path::Resource;

has uri => qw/is ro lazy_build 1/;
sub _build_uri {
    my $self = shift;
    return $self->bluejay->uri->child( qw/ journal /, join '-', lc $self->safe_title, $self->uuid );
}

has safe_title => qw/is ro lazy_build 1 isa Str/;
sub _build_safe_title {
    my $self = shift;
    my $title = $self->title;
    $title =~ s/[^A-Za-z0-9]+/-/g;
    $title =~ s/^-+//g;
    $title =~ s/-+$//g;
    return $title;
}

has document => qw/is ro lazy_build 1/;
sub _build_document {
    my $self = shift;
#    return $self->bluejay->cabinet->load( $self->uuid );
    return $self->bluejay->load_tp( $self->file );
}

sub edit {
    my $self = shift;

    my $document = $self->document;
    $document->edit;
    $self->update({ 
#        creation => $document->creation,
#        modification => $document->modification,
        title => $document->header->{title},
        status => $document->header->{status},
        file => $document->file,
    } );
}

has assets_dir => qw/is ro lazy_build 1/;
sub _build_assets_dir {
    my $self = shift;
    return $self->bluejay->cabinet->storage->assets_dir( $self->uuid );
}

has creation => qw/is ro lazy_build 1/;
sub _build_creation {
    my $self = shift;
    return datetime( $self->_model__column_creation );
}

has local_creation => qw/is ro lazy_build 1/;
sub _build_local_creation {
    my $self = shift;
    return $self->creation->set_time_zone( 'local' );
}

has body => qw/is ro lazy_build 1/;
sub _build_body {
    my $self = shift;
    return $self->bluejay->inflate( 'Model::Post::Body', post => $self );
}

sub asset_rsc {
    my $self = shift;
    return Path::Resource->new( uri => $self->uri->child( 'assets' ), dir => $self->assets_dir )->child( @_ );
}

sub asset {
    my $self = shift;
    my $rsc = $self->asset_rsc( @_ );
    return $self->bluejay->inflate( 'Model::Post::Asset', post => $self, rsc => $rsc );
}

package Blog::Bluejay::Model::Post::Asset;

use Moose;

has post => qw/is ro required 1/;
has rsc => qw/is ro required 1/;

sub file {
    return shift->rsc->file;
}

sub exists {
    return -e shift->file;
}

has render => qw/is ro lazy_build 1/;
sub _build_render {
    my $self = shift;
    return $self->post->bluejay->render_post_asset( $self );
}

package Blog::Bluejay::Model::Post::Body;

use Moose;

has post => qw/is ro required 1/;

sub raw {
    my $self = shift;
    return $self->post->document->body;
}

has render => qw/is ro lazy_build 1/;
sub _build_render {
    my $self = shift;
    return $self->post->bluejay->render_post_body( $self );
}

package Blog::Bluejay::Model::PostDocument;

use Any::Moose;

use Blog::Bluejay::UUID;
use Document::TriPart;

sub _datetime {
    return DateTime->now->set_time_zone( 'UTC' )->strftime( '%F %T %z' );
}

has bluejay => qw/is ro required 1 isa Blog::Bluejay/;

has file => qw/is ro required 1/;

has _tp => qw/is ro isa Document::TriPart lazy_build 1/, handles => [qw/ preamble header body /];
sub _build__tp {
    return Document::TriPart->new;
}

sub uuid {
    return shift->header->{uuid};
}

sub creation {
    return shift->header->{creation};
}

sub modification {
    return shift->header->{modification};
}

sub edit {
    my $self = shift;

    my $file = $self->file;

    unless( -s $file ) {
        # Initialize $file
        $self->header->{uuid} = Blog::Bluejay::UUID->make;
        $self->header->{creation} = _datetime;
        $self->_tp->write;
    }

    $self->_tp->edit;


#    $self->header->{uuid} = $self->uuid;
#    my $new;
#    unless ( $self->creation ) {
#        $new = 1;
#        # Creation should be from file mtime if missing
#        $self->creation( _datetime );
#    }

#    # FIXME
#    $self->_tp->edit;

#    # Assert we have a valid uuid
#    # Is the uuid different?

#    $self->modification( _datetime ) unless $new;

#    my $uuid = $self->header->{uuid};
#    $self->{uuid} = Document::TriPart::Cabinet::UUID->normalize( $uuid );

#    # FIXME
##    $self->save;
}

1;
