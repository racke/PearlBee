package PearlBee::Helpers::Util;

use Data::GUID;
use String::Dirify;
use String::Util 'trim';

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK
    = qw/generate_crypted_filename generate_new_slug_name string_to_slug map_posts/;

=head

Generate a unique filename using GUID

=cut

sub generate_crypted_filename {
    my $guid     = Data::GUID->new;
    my $filename = $guid->as_string;

    return $filename;
}

=head

Generate a new slug name based on existing slug names

=cut

sub generate_new_slug_name {
    my ( $original_slug, $similar_slugs ) = @_;

    # Extract only the slugs that matter: the slugs with this pattern: $original_slug-number
    my @slugs_of_interest
        = grep { $_ =~ /^${original_slug}-\d*$/ } @{$similar_slugs};

    my $max_number = 0;
    foreach (@slugs_of_interest) {
        my @parts = split( '-', $_ );
        my $number = $parts[-1]; # Get the number at the end of the slugs

        $max_number
            = ( $max_number < $number )
            ? $number
            : $max_number; # Find the biggest one
    }

    my $new_slug_name
        = $original_slug . '-' . ++$max_number; # Generate the new slug name

    return $new_slug_name;
}

=head

Generate a valid slug kind name

=cut

sub string_to_slug {
    my ($string) = @_;

    my $slug = String::Dirify->dirify( trim($string), '-' );

    return $slug;
}

=head

Generate a valid slug kind name

=cut

sub map_posts {
    my (@posts) = @_;

    # map info (utf8 compliance)
    my @mapped_posts = ();
    foreach my $post (@posts) {
        my $el;
        map {
            $el->{$_} = eval { $post->$_ }
            } (
            'title',        'content',
            'id',           'slug',
            'description',  'cover',
            'created_date', 'status',
            'user_id',      'nr_of_comments',
            'uri',          'edit_uri',
            );

        # extract a sample from the content (first words)
        my $chunk        = 600;
        my $post_content = $el->{content};

=aaa
        $el->{content} = substr($post_content, 0, $chunk);
        $el->{content} =~ s/([,\s\.])*[^,\s\.]*$/ /is; # make sure we do not split inside of a word
        $el->{content} =~ s/\W*$//is; # make sure we do not split inside of a word
        
        $el->{content} .= ' ...';
=cut

        # get post author
        $el->{user}->{username} = $post->user->username;
        $el->{user}->{id}       = $post->user->id;

        # add post categories
        foreach my $category ( $post->post_categories ) {
            my $details;
            $details->{category}->{name} = $category->category->name;
            $details->{category}->{slug} = $category->category->slug;
            push( @{ $el->{post_categories} }, $details );
        }

        push( @mapped_posts, $el );
    }

    return @mapped_posts;
}

1;
