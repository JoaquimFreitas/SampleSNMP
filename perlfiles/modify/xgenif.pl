#!/usr/bin/perl -w
# xgenif.pl -- generting interface table spec

use strict;

my $cfg_skip_oid_prefix = '1.3.6.1.2.1';

my $file = shift;

$file = 'IF-MIB-tree' if ( ! defined($file) || ! -f $file ); 
if ( ! -f $file ) {
    print "Error file $file\n";
    die "Error file $file\n";
}

my @lines = ();

my $rc = 0;
my $fh = undef;

$rc = open($fh, "<", $file);
if ( ! $rc ) {
    print "Error open file $file\n";
    die "Error open file $file\n";
    exit 0;
}
@lines = <$fh>;
close($fh);

#printf "OK read %d lines\n", scalar(@lines);

    sub parseblock {
        my $startline = shift;
        my $startlevel = shift;
        my $prefix = shift;

        my $blkref = [];
        my $parsedlines = 0;
        my $lastname = "";
        for ( my $i = $startline; $i <= $#lines; $i++) {
            my $theline = $lines[$i];
            chomp($theline);
            if ( $theline =~ m/^OK compile file \w+.*$/ ) {
                $parsedlines ++;
            } elsif ( $theline =~ m/^\s*\|\s*$/ ) {
                $parsedlines ++;
            } elsif ( $theline =~ m/^(\w+\S*)\s*$/ && $startlevel == 0 ) {
                $prefix = $1;
                $parsedlines ++;
            } elsif ( $theline !~ m/^\s*\+(\d+)--\s+P(\S*)\s(\s*.*)$/ ) {
                last;
            } else {
                my ($lvl, $perm, $an) = ($1, $2, $3);
                #printf("  theline %d %s\n", $lvl, $theline);
                #printf("\n  theline %d %s\n", $lvl, $an);
                if ( $lvl < $startlevel ) {
                    last;
                }
                if ( $lvl > $startlevel ) {
                    my ($result, $nl) = parseblock( $i, $lvl, 
                                                    $prefix.".".$lastname);
                    push @{$blkref}, ["blk", $i, $lvl, $perm, $result];
                    $i += $nl -1;
                    $parsedlines += $nl;
                    next;
                }
                my @elements = split(/\s+/, $an);
                if ( scalar(@elements) <= 0 ) {
                    print "Error at line $i\n";
                    die "Error at line $i\n";
                }
                my $foundperm=8;
                if ( $perm eq "---" ) { $foundperm = 0; }
                if ( $perm eq "--w" ) { $foundperm = 2; } #invalid
                if ( $perm eq "-r-" ) { $foundperm = 1; }
                if ( $perm eq "-rw" ) { $foundperm = 3; }
                if ( $perm eq "c--" ) { $foundperm = 4; }
                if ( $perm eq "c-w" ) { $foundperm = 6; } #invalid
                if ( $perm eq "cr-" ) { $foundperm = 5; }
                if ( $perm eq "crw" ) { $foundperm = 7; }
                my ($foundtype, $foundname, $foundoid) = ("", "", "");
                my $strsize=0;
                my ($tablerange, $tableindex) = ("", "");
                my ($enumdef, $intrange) = ("", "");
                for (my $k=0; $k<= $#elements; $k++) {
                    #printf("        ==%s==\n", $elements[$k]);
                    my $e = $elements[$k];
                    next if ( $e =~ m/^\s*$/ ); #empty line
                    if ( $e =~ m/^\s*T(\w+)\s*$/ ) { $foundtype = $1; }
                    if ( $e =~ m/^\s*N(\w+)(\(\d+\))*\s*$/ ) { $foundname = $1; }
                    if ( $e =~ m/^\s*AOid\[([\.\d]+)\]\s*$/ ) {$foundoid = $1;}
                    if ( $e =~ m/^\s*AStringSize\[((\d+\-\d+)|(\w+))\]\s*$/ ) { 
                        $strsize = $1; 
                    }
                    if ( $e =~ m/^\s*ATableRange\[([\w\-,]+)\]\s*$/ ) { 
                        $tablerange = $1; 
                    }
                    if ( $e =~ m/^\s*ATableIndex\[([\w,]+)\]\s*$/ ) { 
                        $tableindex = $1; 
                    }
                    if ( $e =~ m/^\s*AEnum\[([\w\;\:]+)\]\s*$/ ) { 
                        $enumdef = $1; 
                    }
                    if ( $e =~ 
                          m/^\s*AIntRange\[(([\d\-]+\-[\d\-]+)|\w+)\]\s*$/ ) { 
                        $intrange = $1; 
                    }
                    if ( $foundoid ) { $foundoid =~ s/$cfg_skip_oid_prefix//; }
                }
                #printf("        ==%s==%s==%s==%s==\n", $foundtype, $foundname, 
                #       $foundoid, $strsize);
                if ( $foundtype && $foundname && $foundoid ) {
                    #printf("                     tno tnos\n");
                    if ( $strsize ) {
                        push @{$blkref}, 
                            ["tnos", $i, $lvl, $foundperm, 
                             $foundtype, $prefix.".".$foundname, 
                                                        $foundoid, $strsize];
                    } elsif ( length($enumdef) > 0 ) {
                        push @{$blkref}, 
                            ["tnoe", $i, $lvl, $foundperm, 
                             $foundtype, $prefix.".".$foundname, 
                                                        $foundoid, $enumdef];
                    } elsif ( length($intrange) > 0 ) {
                        push @{$blkref}, 
                            ["tnor", $i, $lvl, $foundperm, 
                             $foundtype, $prefix.".".$foundname, 
                                                        $foundoid, $intrange];
                    } else {
                        push @{$blkref}, 
                            ["tno", $i, $lvl, $foundperm, 
                             $foundtype, $prefix.".".$foundname, 
                                                                $foundoid];
                    }
                } elsif ($foundname && $foundoid && $tablerange) {
                    #printf("                     nor\n");
                    my @list = split(/,/, $tablerange);
                    if ( scalar(@list) ) { 
                        push @{$blkref}, ["nor", $i, $lvl, $foundperm, 
                                          $prefix.".".$foundname, $foundoid, 
                             "".scalar(@list)." ".$tablerange." ".$tableindex];
                    } else {
                        push @{$blkref}, ["norx", $i, $lvl, $foundperm, 
                                          $prefix.".".$foundname, $foundoid, 
                                             "x ".$tablerange." ".$tableindex];
                    }
                } elsif ($foundname && $foundoid) {
                    #printf("                     n\n");
                    push @{$blkref}, ["nao", $i, $lvl, $foundperm, 
                                      $prefix.".".$foundname, $foundoid];
                } elsif ($foundname) {
                    #printf("                     n\n");
                    push @{$blkref}, ["name", $i, $lvl, $foundperm, 
                                      $prefix.".".$foundname];
                }
                $lastname = $foundname if ( $foundname );
                $parsedlines ++;
            }
        }
        return ($blkref, $parsedlines);
    }

my $currentline = 0;
my $currLevel = 0;
my $currentPrefix = "";

my ($ret, $rel) = parseblock($currentline, $currLevel, $currentPrefix);

if ( $rel < scalar @lines ) { printf("\n\n lines consumed %d\n\n", $rel); }

    sub showelems {
            my @elm = @_;
            if ( $#elm < 0 ) {
                printf(" Error: Undefined elements\n");
                die " Error: Undefined elements\n";
            }
            if ( $elm[0] eq "name" ) {
                printf(" name %3d %3d %3s %-8s %s\n",$elm[1]+1,$elm[2],$elm[3],"", $elm[4]);
            } elsif ( $elm[0] eq 'nao' ) {
                printf(" nao %3d %3d %3s %-8s %-66s %-11s\n", 
                            $elm[1]+1, $elm[2], $elm[3],"", $elm[4], $elm[5]);
            } elsif ( $elm[0] eq 'nor' ) {
                printf(" nor %3d %3d %3s %-8s %-66s %-11s %s\n", 
                            $elm[1]+1, $elm[2], $elm[3],"", $elm[4], $elm[5], $elm[6]);
            } elsif ( $elm[0] eq 'norx' ) {
                printf(" norx %3d %3d %3s %-8s %-66s %-11s %s\n", 
                            $elm[1]+1, $elm[2], $elm[3],"", $elm[4], $elm[5], $elm[6]);
            } elsif ( $elm[0] eq 'tno' ) {
                printf(" tno  %3d %3d %3s %-8s %-66s %-11s\n", 
                                $elm[1]+1, $elm[2], $elm[3], $elm[4], $elm[5], $elm[6]);
            } elsif ( $elm[0] eq 'tnos' ) {
                printf(" tnos %3d %3d %3s %-8s %-66s %-11s %s\n", 
                       $elm[1]+1, $elm[2], $elm[3], $elm[4], $elm[5], $elm[6], $elm[7]);
            } elsif ( $elm[0] eq 'tnoe' ) {
                printf(" tnoe %3d %3d %3s %-8s %-66s %-11s %s\n", 
                       $elm[1]+1, $elm[2], $elm[3], $elm[4], $elm[5], $elm[6], $elm[7]);
            } elsif ( $elm[0] eq 'tnor' ) {
                printf(" tnor %3d %3d %3s %-8s %-66s %-11s %s\n", 
                       $elm[1]+1, $elm[2], $elm[3], $elm[4], $elm[5], $elm[6], $elm[7]);
            } else {
                printf(" Error: Unknown element : %s\n", $elm[0]);
                die " Error: Unknown element\n";
            }
    }
    sub walktree {
        my $dat = shift;
        my $retref = shift;
        my @blk = @{$dat};
        my $showwalk = 0;
        for ( my $i=0; $i <= $#blk; $i++ ) {
            my @elm = @{$blk[$i]};
            if ( $elm[0] eq "name" || $elm[0] eq 'nao' || $elm[0] eq 'nor' || 
                 $elm[0] eq 'norx' || $elm[0] eq 'tno' || 
                 $elm[0] eq 'tnos' || $elm[0] eq 'tnoe' || $elm[0] eq 'tnor'  ) {
                push @{$retref}, $blk[$i];
                showelems(@elm) if ( $showwalk );
            } elsif ( $elm[0] eq 'blk' ) {
                #printf(" --blk  %3d %3d %3s \n", $elm[1]+1, $elm[2], $elm[3]);
                walktree($elm[4], $retref);
            } else {
                printf(" Error: Unknown element : %s\n", $elm[0]);
                die " Error: Unknown element\n";
            }
        }
    }

my $flat = [];
walktree($ret, $flat);

    sub walkflat {
        my $dat = shift;
        my $retref = shift;
        my @blk = @{$dat};
        my $showwalk = 1;
        for ( my $i=0; $i <= $#blk; $i++ ) {
            my @elm = @{$blk[$i]};
            push @{$retref}, $blk[$i];
            if ( $elm[0] eq "name" || $elm[0] eq 'nao' || $elm[0] eq 'nor' || 
                 $elm[0] eq 'norx' || $elm[0] eq 'tno' || 
                 $elm[0] eq 'tnos' || $elm[0] eq 'tnoe' || $elm[0] eq 'tnor' ) {
                showelems(@elm) if ( $showwalk );
            } else {
                printf(" Error: Unknown element : %s\n", $elm[0]);
                die " Error: Unknown element\n";
            }
        }
    }

if ( 0 ) { #walk through flat, clone into flat2, then print the sizes of them
  printf("\n");
  printf("#if (0) /* dump intermediate list */\n");
  my $flat2 = [];
  walkflat($flat, $flat2);
  printf " sizes %d %d\n\n", scalar(@{$flat}), scalar(@{$flat2});
  printf("#endif /* dump intermediate list */\n");
  printf("\n");
}

    sub decodeoid {
        my $str = shift;
        my @ret = ();
        if ( $str =~ m/^\s*\.(\d+)\s*$/ ) {
            @ret = ($1, 0, 0, 0);
        } elsif ( $str =~ m/^\s*\.(\d+)\.(\d+)\s*$/ ) {
            @ret = ($1, $2, 0, 0);
        } elsif ( $str =~ m/^\s*\.(\d+)\.(\d+)\.(\d+)\s*$/ ) {
            @ret = ($1, $2, $3, 0);
        } elsif ( $str =~ m/^\s*\.(\d+)\.(\d+)\.(\d+)\.(\d+)\s*$/ ) {
            @ret = ($1, $2, $3, $4);
        } else {
            @ret = (0, 0, 0, 0);
        }
        return @ret;
    }
    sub decodetableoid {
        my $str = shift;
        my @ret = ();
        if ( $str =~ m/^\s*\.(\d+)\.(\d+)\.(\d+)\s*$/ ) {
            @ret = ($1, $3, 0, 0);
        } elsif ( $str =~ m/^\s*\.(\d+)\.(\d+)\.(\d+)\.(\d+)\s*$/ ) {
            @ret = ($1, $2, $4, 0);
        } elsif ( $str =~ m/^\s*\.(\d+)\.(\d+)\.(\d+)\.(\d+)\.(\d+)\s*$/ ) {
            @ret = ($1, $2, $3, $5);
        } else {
            @ret = (0, 0, 0, 0);
        }
        return @ret;
    }
    sub decodename {
        my $str = shift;
        my $ret = "known_name";
        if ( $str =~ m/.*\.(\w+)\s*$/ ) {
            $ret = $1;
        }
        return $ret;
    }
    sub decodedim {
        my $str = shift;
        my $ret = "known_dim";
        if ( $str =~ m/.*\s*(\d\d\d\d)\-(\d\d\d\d)\s*$/ ) {
            my ($lo, $hi) = ($1, $2);
            if ( $lo == 0 && $hi > 0 ) {
                $ret = $hi;
            }
        }
        return $ret;
    }
    sub isvalidoid {
        my @oid = @_;
        if ( $oid[0] != 0 || $oid[1] != 0 || $oid[2] != 0 || $oid[3] != 0  ) {
            return 1;
        }
        return 0;
    }

    sub walkflathostdev {
        my $kwrd = shift;
        my $dat = shift;
        my @blk = @{$dat};
        my $showwalk = 0;
        my $showelem = 0;
        my $state = 0;
        my $levelbase = 0;

        my $fh = undef;
        my $ofile = "hostdevspec.h";
        my $rc = open($fh, ">", $ofile);
        if ( ! $rc ) {
            print "Error open file $ofile\n";
            die "Error open file $ofile\n";
        }
        print $fh "/*\n * hostdevspec.h\n */\n\n";

        for ( my $i=0; $i <= $#blk; $i++ ) {
            my @elm = @{$blk[$i]};
            if ( $elm[0] eq "name" || $elm[0] eq 'nao' || $elm[0] eq 'nor' || 
                 $elm[0] eq 'norx' || $elm[0] eq 'tno' || 
                 $elm[0] eq 'tnos' || $elm[0] eq 'tnoe' || $elm[0] eq 'tnor'){
                showelems(@elm) if ( $showwalk );
              # tno 78 0 1 Int8 interfaces.ifNumber  .2.1       
                if ( $state == 0 &&   # look for name interfaces.ifNumber
                     $elm[0] eq "tno" && $elm[5] =~ m/^\s*$kwrd\.\w+.*$/ ) {
                    $state = 1;
                }
                if ( $state == 1 &&   # look for name interfaces.ifNumber
                     $elm[0] eq "tno" && $elm[5] =~ m/^.*\.ifNumber\s*$/ ) {

                    my $fh2 = undef;
                    my $ofile2 = "hostdevmacro.h";
                    my $rc2 = open($fh2, ">", $ofile2);
                    if ( ! $rc2 ) {
                        print "Error open file $ofile2\n";
                        die "Error open file $ofile2\n";
                    }
                    print $fh2 sprintf("/*\n * hostdevmacro.h\n */\n");
                    print $fh2 sprintf("#define HOST_PREFIX_OID (%s)\n", 
                                                        $cfg_skip_oid_prefix);
                    print $fh2 sprintf("#define HOSTDEV_IFN_OID (%s)\n", 
                                                                     $elm[6]);
                    close $fh2;

                    $state = 6;
                    $levelbase = $elm[2];
                }
                if ( $state == 6 && 
                          $elm[2] >= $levelbase &&
                          defined($elm[5]) && 
                          $elm[5] =~ m/^\s*$kwrd\.\w+.*$/ ) {
                    my @oid = (0, 0, 0, 0);
                    my ($typ, $nam, $dim) = 
                              ("unknown_type", "unknown_name", "unknown_dim");
                    my $dimtype = "unknown_dim";
                    my $perm = 0;
                    if ( $elm[0] eq 'tno' ) {
                         printf(" %40s host dev tno  %s  %s  %s\n", "", 
                                $elm[4], $elm[6], $elm[5]) if ($showelem);
                         $typ = $elm[4];
                         @oid = decodeoid( $elm[6] );
                         $nam = decodename( $elm[5] );
                         $perm = $elm[3];
                    } elsif ( $elm[0] eq 'tnos' ) {
                         printf(" %40s host dev tnos %s  %s  %s\n", "", 
                                $elm[4], $elm[6], $elm[5]) if ($showelem);
                         $typ = $elm[4];
                         @oid = decodeoid( $elm[6] );
                         $nam = decodename( $elm[5] );
                         $dim = decodedim( $elm[7] ); $dimtype = "strsize";
                         $perm = $elm[3];
                    } elsif ( $elm[0] eq 'tnoe' ) {
                         printf(" %40s host dev tnoe %s  %s  %s\n", "", 
                                $elm[4], $elm[6], $elm[5]) if ($showelem);
                         $typ = $elm[4];
                         @oid = decodeoid( $elm[6] );
                         $nam = decodename( $elm[5] );
                         $dim = $elm[7]; $dimtype = "enum";
                         $perm = $elm[3];
                    } elsif ( $elm[0] eq 'tnor' ) {
                         printf(" %40s host dev tnor %s  %s  %s\n", "", 
                                $elm[4], $elm[6], $elm[5]) if ($showelem);
                         $typ = $elm[4];
                         @oid = decodeoid( $elm[6] );
                         $nam = decodename( $elm[5] );
                         $dim = $elm[7]; $dimtype = "intrange";
                         $perm = $elm[3];
                    } else {
                        $state = 9;
                    }
                    if ( isvalidoid(@oid) ) {
                        print $fh sprintf(
                            " %s %d, %d, %d, %d, %d, %s, %s, %s, \"%s\" %s\n",
                                "host_dev_def(", 
                                $perm, $oid[0], $oid[1], $oid[2], $oid[3], 
                                $typ, $nam, $dimtype, $dim, ")");
                    }
                } elsif ( $state == 6 ) {
                        $state = 9;
                } elsif ( $state == 9 ) {
                    last;
                }
            } else {
                printf(" Error: Unknown element : %s\n", $elm[0]);
                die " Error: Unknown element\n";
            }
        }
        close $fh;
    }

    sub walkflathostif {
        my $kwrd = shift;
        my $dat = shift;
        my @blk = @{$dat};
        my $showwalk = 0;
        my $showelem = 0;
        my $state = 0;
        my $levelbase = 0;

        my $fh = undef;
        my $ofile = "hostifspec.h";
        my $rc = open($fh, ">", $ofile);
        if ( ! $rc ) {
            print "Error open file $ofile\n";
            die "Error open file $ofile\n";
        }
        print $fh "/*\n * hostifspec.h\n */\n\n";

        for ( my $i=0; $i <= $#blk; $i++ ) {
            my @elm = @{$blk[$i]};
            if ( $elm[0] eq "name" || $elm[0] eq 'nao' || $elm[0] eq 'nor' || 
                 $elm[0] eq 'norx' || $elm[0] eq 'tno' || 
                 $elm[0] eq 'tnos' || $elm[0] eq 'tnoe' || $elm[0] eq 'tnor'){
                showelems(@elm) if ( $showwalk );
                if ( $state == 0 &&   # look for name $kwrd
                    $elm[0] eq "nao" && $elm[4] =~ m/^\s*$kwrd\.ifTable\s*$/){
                    $state = 2;
                #} elsif ( $state == 1 &&   # look for ifTable
                #          $elm[0] eq "name" && 
                #          $elm[4] =~ m'.*\.ifTable\s*$' ) {
                #    $state = 2;
                } elsif ( $state == 2 &&   # look for ifEntry
                          $elm[0] eq "nor" && 
                          $elm[4] =~ m/^\s*$kwrd\..*ifEntry\s*$/ ) {

                    my $fh2 = undef;
                    my $ofile2 = "hostifmacro.h";
                    my $rc2 = open($fh2, ">", $ofile2);
                    if ( ! $rc2 ) {
                        print "Error open file $ofile2\n";
                        die "Error open file $ofile2\n";
                    }
                    print $fh2 sprintf("/*\n * hostifmacro.h\n */\n");
                    print $fh2 sprintf("#define HOSTDEV_IFTABLE_OID (%s)\n", 
                                                                     $elm[5]);
                    close $fh2;

                    $state = 6;
                    $levelbase = $elm[2];
                } elsif ( $state == 6 && 
                          $elm[2] >= $levelbase && 
                          $elm[5] =~ m/^\s*$kwrd\.\w+.*$/ ) {
                    my @oid = (0, 0, 0, 0);
                    my ($typ, $nam, $dim) = 
                                ("unknown_type", "known_name", "unknown_dim");
                    my $dimtype = "unknown_dim";
                    my $perm = 0;
                    if ( $elm[0] eq 'tno' ) {
                         printf(" %40s host if tno  %s  %s  %s\n", "", 
                                $elm[4], $elm[6], $elm[5]) if ($showelem);
                         $typ = $elm[4];
                         @oid = decodetableoid( $elm[6] );
                         $nam = decodename( $elm[5] );
                         $perm = $elm[3];
                    } elsif ( $elm[0] eq 'tnos' ) {
                         printf(" %40s host if tnos %s  %s  %s\n", "", 
                                $elm[4], $elm[6], $elm[5]) if ($showelem);
                         $typ = $elm[4];
                         @oid = decodetableoid( $elm[6] );
                         $nam = decodename( $elm[5] );
                         $dim = decodedim( $elm[7] ); $dimtype = "strsize";
                         $perm = $elm[3];
                    } elsif ( $elm[0] eq 'tnoe' ) {
                         printf(" %40s host if tnoe %s  %s  %s\n", "", 
                                $elm[4], $elm[6], $elm[5]) if ($showelem);
                         $typ = $elm[4];
                         @oid = decodetableoid( $elm[6] );
                         $nam = decodename( $elm[5] );
                         $dim = $elm[7]; $dimtype = "enum";
                         $perm = $elm[3];
                    } elsif ( $elm[0] eq 'tnor' ) {
                         printf(" %40s host if tnor %s  %s  %s\n", "", 
                                $elm[4], $elm[6], $elm[5]) if ($showelem);
                         $typ = $elm[4];
                         @oid = decodetableoid( $elm[6] );
                         $nam = decodename( $elm[5] );
                         $dim = $elm[7]; $dimtype = "intrange";
                         $perm = $elm[3];
                    } else {
                        $state = 9;
                    }
                    if ( isvalidoid(@oid) ) {
                        print $fh sprintf(
                            " %s %d, %d, %d, %d, %d, %s, %s, %s, \"%s\" %s\n",
                                " host_if_def(", 
                                $perm, $oid[0], $oid[1], $oid[2], $oid[3], 
                                $typ, $nam, $dimtype, $dim, ")");
                    }
                } elsif ( $state == 6 ) {
                        $state = 9;
                } elsif ( $state == 9 ) {
                    last;
                }
            } else {
                printf(" Error: Unknown element : %s\n", $elm[0]);
                die " Error: Unknown element\n";
            }
        }
        close $fh;
    }

printf("host dev group:\n");
walkflathostdev('interfaces', $flat);

printf("host if group:\n");
walkflathostif('interfaces', $flat);

exit 0;

__END__

##########################################################################

host if dev spec:
 nao  75   2   8          ifMIB.ifConformance.ifCompliances.ifCompliance2                    .31.2.2.2  
 tno   78   0   1 Int8     interfaces.ifNumber                                                .2.1       
 nao  79   0   0          interfaces.ifTable                                                 .2.2       
 nor  81   1   0          interfaces.ifTable.ifEntry                                         .2.2.1      1 norange ifIndex
 tno   83   2   1 Int32    interfaces.ifTable.ifEntry.ifIndex                                 .2.2.1.1   
 tnos  84   2   1 String   interfaces.ifTable.ifEntry.ifDescr                                 .2.2.1.2    0000-0255

host if table spec:
 nao  79   0   0          interfaces.ifTable                                                 .2.2       
 nor  81   1   0          interfaces.ifTable.ifEntry                                         .2.2.1      1 norange ifIndex
 tno   83   2   1 Int32    interfaces.ifTable.ifEntry.ifIndex                                 .2.2.1.1   
 tnos  84   2   1 String   interfaces.ifTable.ifEntry.ifDescr                                 .2.2.1.2    0000-0255

