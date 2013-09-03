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

{
$ENV{JUICECALC_BASE} = '48,pg,.5,vg,.5';
my $base = qx{$^X -Ilib -MApp::JuiceCalc -e 'print App::JuiceCalc->instance->base'};
is $base, '48,pg,.5,vg,.5', 'base set correct ENV base';
my $mg = qx{$^X -Ilib -MApp::JuiceCalc -e 'print App::JuiceCalc->instance->base_mg'};
my $pg = qx{$^X -Ilib -MApp::JuiceCalc -e 'print App::JuiceCalc->instance->base_carrier->{pg}'};
my $vg = qx{$^X -Ilib -MApp::JuiceCalc -e 'print App::JuiceCalc->instance->base_carrier->{vg}'};
is $mg, 48, 'got 48 mg base from ENV base';
ok $pg == .5, 'got 50 PG from ENV base';
ok $vg == .5, 'got 50 VG from ENV base';
delete $ENV{JUICECALC_BASE};
}

pass;
done_testing;
