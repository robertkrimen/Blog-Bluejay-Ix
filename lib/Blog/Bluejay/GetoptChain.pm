package Blog::Bluejay::GetoptChain;

use strict;
use warnings;

use Getopt::Chain;
use Document::TriPart::Cabinet::UUID;
use Term::Prompt;
local $Term::Prompt::MULTILINE_INDENT = undef;
use File::Find();

our $PRINT = sub { print @_ };

sub blog_bluejay_class { return $ENV{BLOG_BLUEJAY} || 'Blog::Bluejay' }

######
# Do #
######

sub prompt_yn ($$) {
    return prompt Y => shift, '', shift;
}

sub folder_title {

    return unless @_;

    my $folder;
    if (($folder = $_[0]) =~ s/^\.//) {
        shift @_;
    }
    else {
        $folder = "Unfiled";
    }

    return unless @_;

    my $title = join " ", @_;

    return ($folder, $title);
}

#######
# Run #
#######

use Getopt::Chain::Declare;

context 'Blog::Bluejay::GetoptChain::Context';
require Blog::Bluejay::GetoptChain::Context;

start [qw/ home=s /], sub {
    my $ctx = shift;

    if (defined ( my $home = $ctx->option( 'home' ) ) ) {
        $ctx->stash(
            bluejay_home => $home,
        );
    }

    $ctx->error_no_command if $ctx->last;
};

on 'setup *' => undef, sub {
    my $ctx = shift;

    my ($home, $yes);

    if ( @_ ) {
        $home = Path::Class::dir( shift );
        $ctx->bluejay->home( $home );
    }
    elsif ( $home = $ctx->bluejay->home ) {
    }
    else {
        $home = $ctx->bluejay->home( Blog::Bluejay::FindHomeDir->cwd );
    }
    $home = $home->absolute;

    if ( -e $ctx->bluejay->file( 'assets/.protect' ) ) {
        $ctx->print( <<_END_ );
Don't overwrite your work, fool!
_END_
        return
    }

    if (-d $home) {
        $ctx->print( <<_END_ );
\"$home\" already exists and is a directory, do you want to setup anyway?
_END_
        if ( prompt_yn 'Is this okay? Y/n', 'Y' ) {
            $yes = 1;
        }
        else {
            $ctx->print( <<_END_ );
Aborting deploy
_END_
            exit -1;
        }
    }
    elsif (-f $home) {
        $ctx->print( <<_END_ );
\"$home\" already exists and is a file, cannot continue setup

Aborting deploy
_END_
        exit -1;
    }

    unless ($yes) {
        $ctx->print( <<_END_ );
I will setup in \"$home\"
_END_
        $yes = prompt_yn 'Is this okay? Y/n', 'Y';
    }

    unless ($yes) {
        $ctx->print( <<_END_ );
Aborting deploy
_END_
        exit -1;
    }

    $ctx->bluejay->assets->deploy;

    $ctx->print( "\n" );
    $home = readlink $home if -l $home;
    File::Find::find( { no_chdir => 1, wanted => sub {
    
        return if $_ eq $home;
        my $size;
        $size = -s _ if -f $_;

        $ctx->print( "\t", substr $_, 1 + length $home );
        $ctx->print( " $size" ) if defined $size;
        $ctx->print( "\n" );

    } }, $home );
    $ctx->print( "\n" );

    $ctx->print( <<_END_ );

To control your blog, you can either setup the following script:

    #!/bin/sh
    # $0 --home "$home" \$*
    # Take out the leading comment on the previous line

... or use the following alias:

    # alias "my-blog"="$0 --home \\"$home\\""

_END_
};

on 'update' => undef, sub {
    my $ctx = shift;

    $ctx->bluejay->update;

};

rewrite qr/^post-edit$/ => sub { 'edit' };
on 'edit *' => undef, sub {
    my $ctx = shift;

    $ctx->error_no_post_criteria unless @_;

    my ($post, $search, $count) = $ctx->find_post( @_ );

    if ($post) {
#        $post->document->read;
        $post->edit;
    }
    else {
        $ctx->error_too_many_posts( $search ) if $count > 1;
        return unless my ($folder, $title) = folder_title @_;
        if (prompt_yn "Post \"$title\" not found. Do you want to start it? y/N", 'Y') {
            my $post = $ctx->create_post( $title );
        }
    }
};

__PACKAGE__;

__END__

on 'reset' => undef, sub {
    my $ctx = shift;

    die "Already connected to database\n" if $ctx->bluejay->{schema};

    $ctx->bluejay->schema_file->remove;

    $ctx->bluejay->dir( 'assets/document' )->recurse(callback => sub {
        my $file = shift;
        return unless -d $file;
        return unless $file->dir_list(-1) =~ m/^($Document::TriPart::Cabinet::UUID::re)$/;
        my $uuid = $1;
        warn "$uuid => $file\n";
        my $document = $ctx->bluejay->cabinet->load( $uuid );
        $document->save;
    });

    $ctx->list_posts;
};

on 'status' => undef, sub {
    my $ctx = shift;

    my ($problem);
    $ctx->print( "home = ", bluejay->home);
    $ctx->print( " (guessed)") if $ctx->bluejay->guessed_home;
    $ctx->print( " ($problem)") if defined ($problem = $ctx->bluejay->status->check_home); 
    $ctx->print( "\n" );
};

on [ [qw/ list posts/ ] ] => sub {
    my $ctx = shift;
    $ctx->list_posts;
};

require Blog::Bluejay::GetoptChain::catalyst;
require Blog::Bluejay::GetoptChain::help;

on qr/.*/ => undef, sub {
    my $ctx = shift;
    $ctx->error_unknown_command;
};

no Getopt::Chain::Declare;


#sub run {

#    Getopt::Chain->process(

#        commands => {

#            DEFAULT => sub {
#                my $context = shift;
#                local @_ = $context->remaining_arguments;

#                if (defined (my $command = $context->command)) {
#                    print <<_END_;
#    Unknown command: $command
#_END_
#                }

#                print <<_END_;
#    Usage: $0 <command>

#        new
#        edit <criteria> ...
#        list 
#        assets <key>

#_END_
#                do_list unless @_;
#            },

#            new => {
#                options => [qw/link=s/],

#                run => sub {
#                    my $context = shift;

#                    my ($folder, $title) = folder_title @_ or abort "Missing a title";

#                    if (my $post = do_new $folder, $title) {
#                    }
#                },
#            },

#            edit => sub {
#                my $context = shift;
#                local @_ = $context->remaining_arguments; # TODO Should pass in remaining arguments

#                return do_list unless @_;

#                my ($post, $search, $count) = find @_;

#                if ($post) {
#                    $post->edit;
#                }
#                else {
#                    return do_choose $search if $count > 1;
#                    return unless my ($folder, $title) = folder_title @_;
#                    if (prompt y => "Post \"$title\" not found. Do you want to start it?", undef, 'N') {
#                        my $post = new $folder, $title;
#                    }
#                }
#            },

#            assets => sub {
#                my $context = shift;
#                local @_ = $context->remaining_arguments;

#                return unless my $post = do_find @_;

#                my $assets_dir = $post->assets_dir;

#                if (-d $assets_dir) {
#                    print "$assets_dir already exists\n";
#                }
#                else {
#                    $assets_dir->mkpath;
#                }
#            },

#            link => sub {
#                my $context = shift;
#                local @_ = $context->remaining_arguments;

#                return do_list unless @_;

#                my $criteria = shift;

#                return unless my $post = find $criteria;

#                $post->link(@_);
#            },

#            'link-all' => sub {
#                my $context = shift;
#                local @_ = $context->remaining_arguments;

#                return do_list unless @_;

#                my @posts = $cabinet->model->search(post => {});
#                for (@posts) {
#                    $_->link(@_);
#                }
#            },

#            list => sub {
#                my $context = shift;
#                local @_ = $context->remaining_arguments;

#                my $search;
#                (undef, $search) = find @_ if $_;

#                do_list $search;
#            },

#            retitle => sub {
#                my $context = shift;
#                local @_ = $context->remaining_arguments;
#            },
#            
#        },
#    );

#}

no warnings 'void';

__PACKAGE__;

__END__

#            rescan => sub {
#                my $context = shift;
#                
#                my $dir = $bluejay->kit->home_dir->subdir( qw/assets journal/ );
#                $dir->recurse(callback => sub {
#                    my $file = shift;
#                    return unless -d $file;
#                    return unless $file->dir_list(-1) =~ m/^($Document::TriPart::UUID::re)$/;
#                    my $uuid = $1;
#                    warn "$uuid => $file\n";
#                    my $document = $journal->cabinet->load( $uuid );
#                    $journal->commit( $document );
#                });
#            },

#            trash => sub {
#                my $context = shift;
#                local @_ = $context->remaining_arguments;

#                return unless my $post = find @_;

#                my $title = $post->title;
#                if (prompt y => "Are you sure you want to trash \"$title\"?", undef, 'N') {
#                    $cabinet->trash_post($post);
#                }
            },

1;

