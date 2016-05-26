package PearlBee;

# ABSTRACT: PearlBee Blog platform
use Dancer2 0.163000;
use Dancer2::Plugin::DBIC;

# configuration has to be set at compile-time
# because the module that uses it (D2::P::Auth::PearlBee)
# is also loaded at compile-time right after
# this will be fixed in a future version of Dancer2
# (the new plugin system and all that)
BEGIN {
    use RBAC::Tiny;
    set rbac => RBAC::Tiny->new( roles => config()->{'permissions'} || {} );

    our $is_static = config->{static} || '';

    # some defaults
    setting( posts_on_page => 5 ) if !config->{posts_on_page};
    setting( pages_per_set => 7 ) if !config->{pages_per_set};
}

# has to be *after* the configuration is set above
use Dancer2::Plugin::Auth::PearlBee;

# load all components
use PearlBee::Posts;
use PearlBee::Users;
use PearlBee::Authors;
use PearlBee::Categories;
use PearlBee::Tags;
use if !$PearlBee::is_static, 'PearlBee::Dashboard';
use PearlBee::Comments;

hook before => sub {
    my $settings = resultset('Setting')->first;
    set multiuser => $settings->multiuser;
    set blog_name => $settings->blog_name;
    set app_url   => config->{'app_url'}; # FIXME why oh why?

    if ( my $id = session->read('user_id') ) {
        var user => resultset('User')->from_session($id);
    }

    if ( request->dispatch_path =~ /^(.*)\.html$/ ) { forward $1; }
};

# main page
get '/' => sub {
    forward '/posts';
};

1;
