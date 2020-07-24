#!/bin/perl6

my $homedir=%*ENV{'HOME'};

my @subdirs = ("ee", "math", "eng");

my ($srcbase, $dtbase, $ddbase, $menubase) = ("/read/", 
                                              "/.local/share/applications/mylibrary/",
                                              "/.local/share/desktop-directories/mylibrary/",
                                              "/.config/menus/").map: $homedir ~ * ~ "placeholder";

class Menu
{
    has $.parent is rw;
    has Menu @.subs is rw;
    has IO @.files is rw;
    has IO $.dir is rw;
    has Str $.relpath is rw;
    has Bool $!is_setup = False;
    has Str $.xml is rw;

    submethod BUILD (:$parent, 
                     :@subs = Array[Menu].new, 
                     :@files = Array[IO].new, 
                     :$dir, 
                     :$relpath = $dir.absolute.substr($srcbase.chars), 
                     :$is_setup,
                     :$xml) {
        $!parent := $parent;
        @!subs   := @subs;
        @!files  := @files;
        $!dir    := $dir;
        $!relpath := $relpath;
        $!is_setup = False;
        $!xml    = "";
    }
    
    method setup {
        return if $!is_setup++;
        with $.parent { .setup; .subs.append(self) };
        my %directory =
            Name => $.dir.basename,
            Type => "Directory",
            Encoding => "UTF-8",
            Icon => "folder",
            Comment => "Documentation Directory";
        
        (my $dddir = $ddbase ~ $.relpath).IO.mkdir;
        ($dtbase ~ $.relpath).IO.mkdir;
        
        my $dtfile = ($dddir ~ '/' ~ $.dir.basename  ~ ".directory").IO;
        with $dtfile { 
            if !.e { .spurt("[Desktop Entry]\n" ~ do for %directory.kv -> $k,$v { $k ~ '=' ~ $v ~ "\n"}.join) }
        }
        return self;
    }
    
}

sub visit_file (IO:D $file, $parent_menu)
{
    $parent_menu.setup;
    
    my %desktop = 
        Name => $file.basename,
        GenericName => "File link",
        URL => "file://" ~ $file.absolute,
        Type => "Link";
    
    %desktop<Icon> = do given $file.extension {
        when "pdf" {'evince'}
        when "txt" {'gedit'}
        when "url" {'applications-internet'}
        when "png" {'gnome-mime-application-magicpoint'}
				when 'odt' {'application/vnd.oasis.opendocument.text'}
				when 'ods' {'application/vnd.oasis.opendocument.spreadsheet'}
				when 'odg' {'application/vnd.oasis.opendocument.graphics'}
				when 'html' {'text/html'}
				when 'xhtml' { 'application/xhtml+xml' }
        default { return }
    }
    
    if $file.extension ~~ 'url' && $file.slurp() ~~ /URL\=(.*)\n/ {
        %desktop<GenericName> = "URL Resource";
        %desktop<URL> = $/[0];
    }
    
    $parent_menu.files.append: $file;
    
    my $newfile = $dtbase ~ S/\..*$/.desktop/ with ($parent_menu.relpath ~ '/' ~ $file.basename);
    $newfile.IO.spurt("[Desktop Entry]\n" ~ do for %desktop.kv -> $k,$v { $k ~ '=' ~ $v ~ "\n"}.join)
}


sub visit_dir (IO:D $dir, :$parent_menu=Nil)
{
    my %contents := $dir.dir.classify({ .d });
    return if not Bool(%contents);
    
    my $my_menu = Menu.new( dir => $dir, parent => $parent_menu );
    
    for %contents.sort>>.kv -> ($b,$v) {
        if $b {
            $v.map( -> $d { visit_dir($d, :parent_menu($my_menu))}).eager
        } else {
            $v.map( -> $d { visit_file($d, $my_menu)}).eager
        }
    }
    
    $my_menu.xml = qq [
        <Menu>
            <Name>{ $my_menu.dir.basename }</Name>
            <Directory>{ $my_menu.dir.basename }.directory</Directory>
            <AppDir>{ $dtbase ~ $my_menu.relpath }</AppDir>
            <DirectoryDir>{ $ddbase ~ $my_menu.relpath }</DirectoryDir>
            
            <Include>
            {
               do for $my_menu.files -> $file { "<Filename>" ~ (S/\.\S+$/.desktop/ with $file.basename) ~ "</Filename>\n" }
            }
            </Include>
            {
               do for $my_menu.subs -> $sm { $sm.xml }
            }
        </Menu>
    ];
    
    return $my_menu;
}

for @subdirs -> $dir 
{
		($srcbase, $dtbase, $ddbase, $menubase) = ("/read/", 
                                              "/.local/share/applications/mylibrary/",
                                              "/.local/share/desktop-directories/mylibrary/",
																							 "/.config/menus/").map: $homedir ~ * ~ $dir;
		
		$menubase = $homedir ~ "/.config/menus/" ~ $dir;
		($dtbase, $ddbase, $menubase).map( { run 'rm', '-rf', $_ } ).eager;
		my $topmenu = visit_dir($srcbase.IO);
		
		$menubase.IO.mkdir;
		my $menuxml = qq { <!DOCTYPE Menu PUBLIC "-//freedesktop//DTD Menu 1.0//EN
    "http://www.freedesktop.org/standards/menu-spec/1.0/menu.dtd"> } ~ $topmenu.xml;
		($menubase ~  '/' ~ $dir ~ '.menu').IO.spurt: $menuxml;

}




