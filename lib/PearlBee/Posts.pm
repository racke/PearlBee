package PearlBee::Posts;

# ABSTRCT: Posts-related paths
use Dancer2 appname => 'PearlBee';
use Dancer2::Plugin::DBIC;

use PearlBee::Helpers::Util qw<map_posts>;
use PearlBee::Helpers::Pagination qw<get_total_pages get_previous_next_link>;
use PearlBee::Helpers::Captcha;

prefix '/posts' => sub {
    get '' => sub {
        my $nr_of_rows = config->{'posts_on_page'};
        my $page = query_parameters->{'page'} || 1; # for paging
        my @posts = resultset('Post')->search(
            { status => 'published' },
            {
                order_by => { -desc => "created_date" },
                rows     => $nr_of_rows,
                page     => $page
            }
        );
        my $nr_of_posts
            = resultset('Post')->search( { status => 'published' } )->count;
        my @tags       = resultset('View::PublishedTags')->all();
        my @categories = resultset('View::PublishedCategories')
            ->search( { name => { '!=' => 'Uncategorized' } } );
        my @recent = resultset('Post')->search( { status => 'published' },
            { order_by => { -desc => "created_date" }, rows => 3 } );
        my @popular
            = resultset('View::PopularPosts')->search( {}, { rows => 3 } );

        # extract demo posts info
        my @mapped_posts = map_posts(@posts);

        # Calculate the next and previous page link
        my $total_pages = get_total_pages( $nr_of_posts, $nr_of_rows );
        my ( $previous_link, $next_link )
            = get_previous_next_link( $page, $total_pages );

        template 'index' => {
            posts         => \@mapped_posts,
            recent        => \@recent,
            popular       => \@popular,
            tags          => \@tags,
            categories    => \@categories,
            page          => $page,
            total_pages   => $total_pages,
            previous_link => $previous_link,
            next_link     => $next_link
        };
    };

    get '/:slug' => sub {
        my $slug       = route_parameters->{'slug'};
        my $post       = resultset('Post')->find( { slug => $slug } );
        my $settings   = resultset('Setting')->first;
        my @tags       = resultset('View::PublishedTags')->all();
        my @categories = resultset('View::PublishedCategories')
            ->search( { name => { '!=' => 'Uncategorized' } } );
        my @recent = resultset('Post')->search( { status => 'published' },
            { order_by => { -desc => "created_date" }, rows => 3 } );
        my @popular
            = resultset('View::PopularPosts')->search( {}, { rows => 3 } );

        PearlBee::Helpers::Captcha::new_captcha_code();

        template post => {
            post       => $post,
            recent     => \@recent,
            popular    => \@popular,
            categories => \@categories,
            setting    => $settings,
            tags       => \@tags,
        };
    };
};

1;
