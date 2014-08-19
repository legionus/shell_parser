use Module::Build;
my $build = Module::Build->new
(
    module_name => 'ShellParser',
    license => 'gpl3',
    requires => {
        'perl'        => '5.10.0',
        'Parse::Yapp' => '',
    },
);
$build->create_build_script;
