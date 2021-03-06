package Blog::Bluejay::Schema;

use strict;
use warnings;

use base qw/DBIx::Class::Schema Class::Accessor::Fast/;
our $schema = __PACKAGE__;

__PACKAGE__->mk_accessors(qw/ bluejay /);
__PACKAGE__->load_namespaces;

package Blog::Bluejay::Schema::Result::Post;

use strict;
use warnings;

use base qw/DBIx::Class/;

use JSON;

__PACKAGE__->load_components(qw/ InflateColumn::DateTime PK::Auto Core /);
__PACKAGE__->table( 'post' );
__PACKAGE__->add_columns(
    qw/ id uuid luid /,
    qw/ title description excerpt status file /,
    qw/ creation modification /,
);
#__PACKAGE__->add_columns(creation => { data_type => 'datetime' }, modification => { data_type => 'datetime' });
__PACKAGE__->set_primary_key( 'id' );
__PACKAGE__->add_unique_constraint( uuid => [qw/ uuid /]);

$schema->register_class(substr(__PACKAGE__, 10 + length $schema) => __PACKAGE__);

1;
