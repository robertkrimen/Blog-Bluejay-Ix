use inc::Module::Install;

name     'Blog-Bluejay';
all_from 'lib/Blog/Bluejay.pm';
author   q{Robert Krimen <rkrimen@cpan.org>};
license  'perl';

build_requires 'Test::More';

auto_install;

WriteAll;

