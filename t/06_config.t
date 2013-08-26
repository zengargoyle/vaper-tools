use strict;
use warnings;

use Test::More;

use App::JuiceCalc;

subtest instance_file => sub {
my $i = App::JuiceCalc->instance;
is $i->base_mg, 100, 'got our 100 mg base';
$i->set_from_file( 't/test_data/test1.conf' );
is $i->base_mg, 48, 'got our 48 mg base';
};

subtest instance_persist => sub {
my $i = App::JuiceCalc->instance;
is $i->base_mg, 48, 'got our 48 mg base';
};

subtest instance_env => sub {
my $mg;
$mg = qx{$^X -Ilib -MApp::JuiceCalc -e 'print App::JuiceCalc->instance->base_mg'};
is $mg, 100, 'got default 100 mg base';
$ENV{JUICECALC_BASE_MG} = 48;
$mg = qx{$^X -Ilib -MApp::JuiceCalc -e 'print App::JuiceCalc->instance->base_mg'};
is $mg, 48, 'got 48 mg base from ENV';
delete $ENV{JUICECALC_BASE_MG};
$mg = qx{$^X -Ilib -MApp::JuiceCalc -e 'print App::JuiceCalc->instance->base_mg'};
is $mg, 100, 'back to 100 mg base';
$ENV{APP_JUICECALC_BASE_MG} = 48;
$mg = qx{$^X -Ilib -MApp::JuiceCalc -e 'print App::JuiceCalc->instance->base_mg'};
is $mg, 48, 'got 48 mg base from ENV long version';
delete $ENV{APP_JUICECALC_BASE_MG};
};

pass;
done_testing;
