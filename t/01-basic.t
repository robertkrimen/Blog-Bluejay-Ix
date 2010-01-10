#!/usr/bin/env perl

use strict;
use warnings;

use Test::Most;

plan qw/no_plan/;

use Blog::Bluejay;
use Blog::Bluejay::FindHomeDir;

use Path::Class;
use File::Temp qw/ tempdir /;

use Carp::Always;

is( Blog::Bluejay::FindHomeDir->find( 't/assets/home1' ),
        dir( 't/assets/home1' )->absolute );

is( Blog::Bluejay::FindHomeDir->find( 't/assets/home2/a/b/c' ),
        dir( 't/assets/home2/a' )->absolute );

{
    my $run_dir = tempdir;
    my $bluejay = Blog::Bluejay->new( home => 't/assets/home3/' ); 
    $bluejay->path_mapper->map( '/run' => $run_dir );

    is( $bluejay->dir( 'run/apple' ), dir( $run_dir, 'apple' ) );
    is( $bluejay->dir( '/apple' ), dir( 't/assets/home3/apple' ) );

    $bluejay->update;

    my $post = $bluejay->model( 'Post' )->search({
        uuid => '39fc2078-8774-4978-a9f7-f0da1851f26c' })->first;
    ok( $post );
    is( $post->title, 'Apple' );
}
