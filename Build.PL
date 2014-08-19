use Module::Build;
my $class = Module::Build->subclass(code => <<'EOF');
sub process_yp_files {
    my $self = shift;
    `yapp -o blib/lib/ShellParser.pm lib/ShellParser.yp`;
}
EOF
my $build = $class->new
(
    module_name => 'ShellParser',
    license => 'gpl',
    dist_version_from => 'lib/ShellParser.yp',
    requires => {
        'perl'        => '5.10.0',
        'Parse::Yapp' => '',
    },
);
$build->add_build_element('yp');
$build->create_build_script;
