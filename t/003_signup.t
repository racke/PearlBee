use PearlBee::Test;
use PearlBee::Helpers::Captcha;
use Email::Template;

my $EmailSuccessful = 1;

{
    no warnings 'redefine';
    no strict 'refs';

    # The alternative would be trying to mess with the current code in the
    # session, which is even uglier...
    *PearlBee::Helpers::Captcha::check_captcha_code = sub { $_[0] eq 'zxcvb' };

    # The alternative would be using Email::Sender and using the Test transport
    # We will do that eventually :D
    *Email::Template::send = sub { return $EmailSuccessful };
}

subtest 'successful insert' => sub {
    my $mech = mech;

    db->resultset('User')->search({ email => 'johndoe@gmail.com' })->delete;

    $mech->get_ok('/sign-up', 'Sign-up returns a page');
    $mech->submit_form_ok({
        with_fields => {
            username   => 'johndoe',
            email      => 'johndoe@gmail.com',
            first_name => 'John',
            last_name  => 'Doe',
            secret     => 'zxcvb',
        },
    }, 'Was able to submit form');

    # If we weren't able to test the successful case, then the tests ensuring we
    # couldn't insert will be useless, so we bail out.
    ok(my $row = db->resultset('User')->search({ email => 'johndoe@gmail.com' })->first, 'found row in the database')
      or BAIL_OUT 'Insert is not working, the rest of the tests are irrelevant';

    my %expected = (
        email      => 'johndoe@gmail.com',
        first_name => 'John',
        last_name  => 'Doe',
        role       => 'author',
        status     => 'pending',
        username   => 'johndoe',
    );

    is( $row->$_, $expected{$_}, "New user's $_ has the expected value" ) for keys %expected;

    $mech->content_like(qr/The user was created and it is waiting for admin approval/, 'the user is presented with the expected message');

    db->resultset('User')->search({ email => 'johndoe@gmail.com' })->delete;
};

subtest 'successful insert, failed e-mail' => sub {
    my $mech = mech;

    $EmailSuccessful = 0;

    db->resultset('User')->search({ email => 'johndoe@gmail.com' })->delete;

    $mech->get_ok('/sign-up', 'Sign-up returns a page');
    $mech->submit_form_ok({
        with_fields => {
            username   => 'johndoe',
            email      => 'johndoe@gmail.com',
            first_name => 'John',
            last_name  => 'Doe',
            secret     => 'zxcvb',
        },
    }, 'Was able to submit form');

    ok(my $row = db->resultset('User')->search({ email => 'johndoe@gmail.com' })->first, 'found row in the database');

    my %expected = (
        email      => 'johndoe@gmail.com',
        first_name => 'John',
        last_name  => 'Doe',
        role       => 'author',
        status     => 'pending',
        username   => 'johndoe',
    );

    is( $row->$_, $expected{$_}, "New user's $_ has the expected value" ) for keys %expected;

    $mech->content_like(qr/Could not send the email/, 'the user is presented with the expected message');

    db->resultset('User')->search({ email => 'johndoe@gmail.com' })->delete;
};


subtest 'wrong captcha code' => sub {
    my $mech = mech;

    db->resultset('User')->search({ email => 'johndoe@gmail.com' })->delete;

    $mech->get_ok('/sign-up', 'Sign-up returns a page');
    $mech->submit_form_ok({
        with_fields => {
            username   => 'johndoe',
            email      => 'johndoe@gmail.com',
            first_name => 'John',
            last_name  => 'Doe',
            secret     => '00000',
        },
    }, 'Was able to submit form');

    ok(! defined db->resultset('User')->search({ email => 'johndoe@gmail.com' })->first, 'row was not found in the database');

    $mech->content_like(qr/Invalid secret code/, 'the user is presented with the expected message');

    db->resultset('User')->search({ email => 'johndoe@gmail.com' })->delete;
};

subtest 'e-mail already in use' => sub {
    my $mech = mech;

    db->resultset('User')->search({ username => 'johndoe' })->delete;
    db->resultset('User')->search({ username => 'johndoe2' })->delete;

    $mech->get_ok('/sign-up', 'Sign-up returns a page');
    $mech->submit_form_ok({
        with_fields => {
            username   => 'johndoe',
            email      => 'johndoe@gmail.com',
            first_name => 'John',
            last_name  => 'Doe',
            secret     => 'zxcvb',
        },
    }, 'Was able to submit form');

    $mech->get_ok('/sign-up', 'Sign-up returns a page the second time');
    $mech->submit_form_ok({
        with_fields => {
            username   => 'johndoe2',
            email      => 'johndoe@gmail.com',
            first_name => 'John',
            last_name  => 'Doe',
            secret     => 'zxcvb',
        },
    }, 'Submit the form a second time');

    ok(! defined db->resultset('User')->search({ username => 'johndoe2' })->first, 'row was not found in the database');

    $mech->content_like(qr/Email address already in use/, 'the user is presented with the expected message');

    db->resultset('User')->search({ username => 'johndoe' })->delete;
    db->resultset('User')->search({ username => 'johndoe2' })->delete;
};

subtest 'username already in use' => sub {
    my $mech = mech;

    db->resultset('User')->search({ email => 'johndoe@gmail.com' })->delete;
    db->resultset('User')->search({ email => 'johndoe2@gmail.com' })->delete;

    $mech->get_ok('/sign-up', 'Sign-up returns a page');
    $mech->submit_form_ok({
        with_fields => {
            username   => 'johndoe',
            email      => 'johndoe@gmail.com',
            first_name => 'John',
            last_name  => 'Doe',
            secret     => 'zxcvb',
        },
    }, 'Was able to submit form');

    $mech->get_ok('/sign-up', 'Sign-up returns a page the second time');
    $mech->submit_form_ok({
        with_fields => {
            username   => 'johndoe',
            email      => 'johndoe2@gmail.com',
            first_name => 'John',
            last_name  => 'Doe',
            secret     => 'zxcvb',
        },
    }, 'Submit the form a second time');

    ok(! defined db->resultset('User')->search({ email => 'johndoe2@gmail.com' })->first, 'row was not found in the database');

    $mech->content_like(qr/Username already in use/, 'the user is presented with the expected message');

    db->resultset('User')->search({ email => 'johndoe@gmail.com' })->delete;
    db->resultset('User')->search({ email => 'johndoe2@gmail.com' })->delete;
};

subtest 'username empty' => sub {
    my $mech = mech;

    db->resultset('User')->search({ email => 'johndoe@gmail.com' })->delete;

    $mech->get_ok('/sign-up', 'Sign-up returns a page');
    $mech->submit_form_ok({
        with_fields => {
            username   => '',
            email      => 'johndoe@gmail.com',
            first_name => 'John',
            last_name  => 'Doe',
            secret     => 'zxcvb',
        },
    }, 'Was able to submit form');

    ok(! defined db->resultset('User')->search({ email => 'johndoe@gmail.com' })->first, 'row was not found in the database');

    $mech->content_like(qr/Please provide an username/, 'the user is presented with the expected message');

    db->resultset('User')->search({ email => 'johndoe@gmail.com' })->delete;
};

subtest 'email empty' => sub {
    my $mech = mech;

    db->resultset('User')->search({ username => 'johndoe' })->delete;

    $mech->get_ok('/sign-up', 'Sign-up returns a page');
    $mech->submit_form_ok({
        with_fields => {
            username   => 'johndoe',
            email      => '',
            first_name => 'John',
            last_name  => 'Doe',
            secret     => 'zxcvb',
        },
    }, 'Was able to submit form');

    ok(! defined db->resultset('User')->search({ username => 'johndoe' })->first, 'row was not found in the database');

    $mech->content_like(qr/Please provide an email/, 'the user is presented with the expected message');

    db->resultset('User')->search({ username => 'johndoe' })->delete;
};

done_testing;