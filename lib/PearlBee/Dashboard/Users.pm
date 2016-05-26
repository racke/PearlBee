package PearlBee::Dashboard::Users;
use Dancer2 appname => 'PearlBee';
use Dancer2::Plugin::DBIC;
use Dancer2::Plugin::Auth::PearlBee;

use PearlBee::Helpers::Pagination qw<
    get_total_pages
    get_previous_next_link
    generate_pagination_numbering
>;

use String::Random qw<random_string>;

use DateTime;
use URI::Escape;
use Email::Template;

sub change_user_state {
    my ( $id, $state ) = @_;
    my $user = resultset('User')->find($id);

    # FIXME: these methods check if the user is authorized
    #        we should put this action elsewhere
    eval {
        $user->$state();
        1;
    } or do {

        # FIXME: don't just report the error, show the user as well
        #        GH#9
        my $error = $@ || 'Zombie error';
        error $error;
    };

    return config->{'app_url'} . '/dashboard/users';
}

prefix '/dashboard/users' => sub {
    get '/?' => needs_permission view_user => sub {
        my $page       = query_parameters->{'page'} || 1;
        my $status     = query_parameters->{'status'};
        my $nr_of_rows = config->{posts_on_page};

        my $search_parameters = {};

        # this is very confusing, but basically:
        # - if we have a status, use that
        # - if we don't AND it's not multiuser, get non-pending only
        # (conclusion: multiuser allows seeing pending users)
        if ($status) {
            $search_parameters->{'status'} = $status;
        } elsif ( !config->{'multiuser'} ) {
            $search_parameters->{'status'} = { '!=' => 'pending' };
        }

        my $search_options = {
            order_by => { -desc => 'register_date' },
            rows     => $nr_of_rows,
            page     => $page,
        };

        my @users = resultset('User')
            ->search( $search_parameters, $search_options );
        my $count = resultset('View::Count::StatusUser')->first;

        my ( $all, $activated, $deactivated, $suspended, $pending )
            = $count->get_all_status_counts;

        # we also want to change the count of total users
        # and if it's not multiuser, we remove pending users from the count
        if ( !config->{'multiuser'} ) {
            my $num_pending_users
                = resultset('User')->search( { status => 'pending' }, )
                ->count;

            $all -= $num_pending_users;
        }

        # FIXME: temporary override of $all because "ugh"
        #        Uses the View::Count::StatusPost
        #        which doesn't allow specifying an optional post status
        #        why have two methods instead of a method with a parameter?
        $status and $all = $count->get_status_count($status);

        my $action_url = '/dashboard/users?status=' . uri_escape($status);

        # Calculate the next and previous page link
        my $total_pages = get_total_pages( $all, $nr_of_rows );
        my ( $previous_link, $next_link )
            = get_previous_next_link( $page, $total_pages, $action_url );

        # Generating the pagination navigation
        my $total_users    = $all;
        my $posts_per_page = $nr_of_rows;
        my $current_page   = $page;
        my $pages_per_set  = config->{pages_per_set};
        my $pagination
            = generate_pagination_numbering( $total_users, $posts_per_page,
            $current_page, $pages_per_set );

        template '/admin/users/list' => {
            users         => \@users,
            all           => $all,
            activated     => $activated,
            deactivated   => $deactivated,
            suspended     => $suspended,
            pending       => $pending,
            page          => $page,
            next_link     => $next_link,
            previous_link => $previous_link,
            action_url    => $action_url,
            pages         => $pagination->pages_in_set
        } => { layout => 'admin' };
    };

    foreach my $state (qw<activate deactivate suspend>) {
        get "/$state/:id" => needs_permission update_user => sub {
            my $new_url
                = change_user_state( route_parameters->{'id'}, $state, );

            redirect $new_url;
        };
    }

    # approve pending users (FIXME: rename to "approve"?)
    get '/allow/:id' => needs_permission allow_user => sub {
        my $user_id = route_parameters->{'id'};
        my $user    = resultset('User')->find($user_id)
            or redirect config->{'app_url'} . '/dashboard/users';

        eval {
            my $password = random_string('Ccc!cCn');
            $user->update( { password => $password } );
            $user->allow();

            Email::Template->send(
                config->{'email_templates'} . 'welcome.tt',
                {
                    From    => config->{'default_email_sender'},
                    To      => $user->email,
                    Subject => config->{'welcome_email_subject'},

                    tt_vars => {
                        role       => $user->role,
                        username   => $user->username,
                        password   => $password,
                        first_name => $user->first_name,
                        app_url    => config->{'app_url'},
                        blog_name  => config->{'blog_name'},
                        signature  => config->{'email_signature'},
                        allowed    => 1,
                    },
                }
            ) or error 'Could not send the email'; # FIXME GH#9
            1;
        } or do {

            # FIXME: ugh GH#9
            my $error = $@ || 'Zombie error';
            error $error;
        };

        redirect config->{'app_url'} . '/dashboard/users';
    };

    get '/add' => sub {
        template 'admin/users/add', {}, { layout => 'admin' };
    };

    post '/add' => sub {
        eval {
            # Set the proper timezone
            my $dt       = DateTime->now;
            my $settings = resultset('Setting')->first;
            $dt->set_time_zone( $settings->timezone );

            my $password   = random_string('Ccc!cCn');
            my $params     = body_parameters;
            my $username   = $params->{'username'};
            my $email      = $params->{'email'};
            my $first_name = $params->{'first_name'};
            my $last_name  = $params->{'last_name'};
            my $role       = $params->{'role'};

            resultset('User')->create(
                {
                    username      => $username,
                    password      => $password,
                    first_name    => $first_name,
                    last_name     => $last_name,
                    register_date => join( ' ', $dt->ymd, $dt->hms ),
                    role          => $role,
                    email         => $email,
                }
            );

            Email::Template->send(
                config->{'email_templates'} . 'welcome.tt',
                {
                    From    => config->{'default_email_sender'},
                    To      => $email,
                    Subject => config->{'welcome_email_subject'},

                    tt_vars => {
                        role       => $role,
                        username   => $username,
                        password   => $password,
                        first_name => $first_name,
                        app_url    => config->{'app_url'},
                        blog_name  => config->{'blog_name'},
                        signature  => config->{'email_signature'},
                    },
                }
            ) or error "Could not send the email";

            1;
        } or do {
            my $error = $@ || 'Zombie error';
            error $error; # FIXME GH#9
            return template 'admin/users/add' => { warning =>
                    'Something went wrong. Please contact the administrator.'
            } => { layout => 'admin' };
        };

        template 'admin/users/add' => { success =>
                'The user was added succesfully and will be activated after he logs in.'
        } => { layout => 'admin' };
    };
};

1;
