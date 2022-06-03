#!/usr/bin/env vmd
#
#  script:	gui.tcl
#  author:	Marc Siggel (marc.siggel@yahoo.de), Pieter J. in 't Veld
#  date:	May-September 2017
#  purpose:	EMC Setup GUI for creation of EMC setup scripts with VMD
#
#  Copyright (c) 2004-2019 Marc Siggel and Pieter J. in 't Veld
#  Distributed under GNU Public License as stated in LICENSE file in EMC root
#  directory
#
#  notes:
#    20170929	First release
#    20170930	Reorganization
#    20210801	Adaptation to EMC Setup v4.1
#

package require Thread

#==============================================================================
# Package export
#==============================================================================

package provide emc_gui 1.5.1


#==============================================================================
# Global namespace for gui; required for use in vmd
#==============================================================================

namespace eval ::EMC::gui {
  namespace export emc_gui
  package require Tk 8.5

  # general

  variable version "1.5.1"
  variable date "16 August 2021"
  variable authors "Marc Siggel, Eduard Schreiner, and Pieter J. in 't Veld"

  # window variable

  variable w

  # interrupt

  variable interrupt
  set interrupt(id) -1

  # Source all files to the ::EMC::gui namespace

  # source infotext.tcl	# for definition of infobox texts; currently internal
  
  # lists that define position of options within the gui
  # populated from the data in optionlist
  # relevant proc: 
  
  variable basicemcoptionslist {}
  variable advancedemcoptionslist {}
  variable basiclammpslist {}
  variable advancedlammpslist {}
  variable runoptions { \
    ncores queue_analyze queue_build queue_run replace time_analyze \
    time_build time_run host}
  variable dpdoptionslist {}
  variable writealloptions

  # define where options go in final build script

  variable MainOptionList {}
  variable TemplateOptionList {}
  variable fflist {}
  variable ffdefault
  set ffdefault(field) charmm
  set ffdefault(type) charmm

  # stores all loop variables in a list of lists
  # each loopvariable has one list
  # {option_name arg1 arg2 arg3 [...]}

  variable LoopList {}
  
  # defines designated position of the cluster and group definitions

  variable WriteClusterToTemplate "false"
  variable WriteGroupsToTemplate "true"
  variable UsePolymers "false"
  
  # lists that store what's displayed in the treeviews of groups,clusters etc.
  # necessary for saving and loading stuff to treeviews

  variable smgrouplist {}
  variable polgrouplist {}
  variable tvdefchemistrylist {}

  # don't need these next ones

  variable monomergrouplist {} 
  variable tvsurfgrouplist {}
  variable triallist {}
  #variable garbagelist {}

  # variables for generating and storing all information for generating the
  # connection matrices and writing the group definitions in the end

  ## Data Syntax polymernames:

  ## Data Syntax polymerarray: 

  variable polymernames {}
  variable polymerarray

  # lists which are called by the final build procs to write out the groups

  variable ClusterList {}
  variable GroupList {}
  variable PolymerItem {}
  
  # array for all options available in emc
  # the keys of the array correspond to the input list and are also stored
  # like this in the other option lists; these values are adapted according to
  # the users input (the gui manipulates the entries)

  ## Data Syntax options($optionname)

  variable options
  variable trials
  variable stages

  set options(filename) "setup"

  # This manages the variables and stuff associated with surfaces aka.
  # verbatim, type of input and possible variables for emc type inputs where
  # the ITEM VARIABLE section has to be placed into the file
  
  variable surfoptions
  variable polymertype ""
  variable polymername ""
  variable monomeramount ""
  
  # initialize gui

  # name of the option list which is first first loaded from the input file
  # default values are stored here and are static to allow the program to
  # restore default settings if necessary

  ## Data Syntax:

  variable optionlist {}
  variable pairconcentration "true"

  # array stores the concentrations of the individual 

  variable concarray
  variable editedpolymerentryswitch -1
  variable fieldlist {}
  variable ensemble
  
  variable fffilelist
  variable ffbrowse

  variable EMC_ROOTDIR
  variable fatalexit 0
  variable statusmessage "Status: Ready"
  variable progress "-"

  variable conclbl
  variable listindex

  variable bgcolor [ttk::style lookup TFrame -background]
  variable formatstr {%-16s%-16s}
  variable formatstrtriple {%-16s%-16s%-16s}
  variable formatitem {%-8s%-8s}

  variable window_size 900x750
  variable window_height 110
  variable window_xdelta 0

  variable currentdirlist {}
  variable processes
  variable currentpath

  # styles

  variable style_accept \u2713
  variable style_cancel \u2715
  variable down_point \u25BC
  variable right_point \u25B6
  variable left_arrow \u2190
  variable up_arrow \u2191
  variable right_arrow \u2192
  variable down_arrow \u2193
  variable frame_padding 5
  variable pad_x 0
  variable pad_y "10 0"

  # used for saving the text from the manual in the gui to display in the help
  # windows

  variable helpentries

  variable header_setup ""
}


#==============================================================================
# Miscellaneous button response functions (used in tabs)
#==============================================================================

proc date {} {
  return [clock format [clock seconds] -format "%a %b %d %H:%M:%S %Z %Y"]
}


proc interrupt {ms body} {
  if {$::EMC::gui::interrupt(id) != -1} {
    after cancel $::EMC::gui::interrupt(id);
    set ::EMC::gui::interrupt(id) -1;
  }
  if {"$ms" != "cancel"} {
    eval $body
    set ::EMC::gui::interrupt(id) [after $ms [info level 0]]
  }
}


proc fmkdir {dir} {
  if {[file exists $dir]} {
    if {![file isdirectory $dir]} {
      puts "Warning) removing file '[pwd]/$dir'"
      file delete $dir
      file mkdir $dir
    }
  } else {
    file mkdir $dir
  }
}


proc ffind {root masks} {
  set files {}
 
  if {[llength $masks] == 0} { return }
  foreach file [glob -nocomplain -type d -directory $root -- *] {
    if {[lindex [file split $file] end] != "src"} {
      set files [concat $files [ffind $file $masks]]
    }
  }
  foreach mask $masks {
    foreach file [glob -nocomplain -type f -directory $root -- $mask] {
      if {[file rootname [lindex [file split $file] end]] != "template"} {
	set files [concat $files $file]
      }
    }
  }
  return $files
}


proc emc {} {
  return [eval ::EMC::gui::emc_gui]
}


proc emcsm {} {
  return [eval ::EMC::gui::emc_add_sm]
}


proc emcpoly {} {
  return [eval ::EMC::gui::emc_add_poly]
}


proc emcsurf {} {
  return [eval ::EMC::gui::emc_add_surf]
}


proc polyedit {} {
  return [eval ::EMC::gui::editpolymer]
}


proc emctrial {} {
  return [eval ::EMC::gui::emc_add_trial]
}


proc emcpolconnect {} {
  return [eval ::EMC::gui::PolymerConnectivity]
}


#==============================================================================
# Window functions
#==============================================================================
  
proc text_banner {} {
  puts "
Info) -------------------------------------------------------------------------
Info)			    WELCOME TO THE EMC SETUP GUI
Info) -------------------------------------------------------------------------
Info) EMC GUI developed by
Info)   $::EMC::gui::authors
Info)   Version $::EMC::gui::version, $::EMC::gui::date
Info)
Info) EMC developed by
Info)   Pieter J. in 't Veld
Info)
Info) Please include this reference in published work using EMC:
Info)   P.J. in 't Veld and G.C.Rutledge, Macromolecules 2003, 36, 7358
Info) -------------------------------------------------------------------------"
}


proc set_esh_header {} {
  set ::EMC::gui::header_setup "#!/usr/bin/env emc_setup.pl
#
#  Script:	$::EMC::gui::options(filename)
#  Author:	EMC GUI v$::EMC::gui::version, $::EMC::gui::date
#  Date:	[date]
#  Purpose:	Input script for EMC Setup
#
#  Notes:
#    - Automatically generated by EMC GUI
#    - GUI developed by $::EMC::gui::authors
#    - Please include this reference in published work using EMC:
#
#      P.J in 't Veld and G.C. Rutledge, Macromolecules 2003, 36, 7358
#
"
}


proc set_style {} {
  set themeList [ttk::style theme names]
  if { [lsearch -exact $themeList "aqua"] != -1 } {
    
    # MacOS style

    ttk::style theme use aqua
    set placeHolderPadX 18
    set ::EMC::gui::window_xdelta 35
    set ::EMC::gui::window_height 140
    set ::EMC::gui::window_size 1025x625

  } elseif { [lsearch -exact $themeList "clam"] != -1 } {

    # Clam style

    ttk::style theme use clam

  } elseif { [lsearch -exact $themeList "classic"] != -1 } {

    # Classic style

    ttk::style theme use classic

  } else {

    # Default style

    ttk::style theme use default

  }
}


#==============================================================================
# GUI Window Startup - Central Function
#==============================================================================

proc ::EMC::gui::emc_gui {} \
{
  set_style
  text_banner

  # Window variable (used to initialize screen)

  variable w

  # initialize gui command
  # populates all lists and options from the input file or emc
 
  set ::EMC::gui::fatalexit 0
  ::EMC::gui::initialize
  set_esh_header

  if {$::EMC::gui::fatalexit == 1} { return }

  # setup of the initial window w

  if { [winfo exists .emc] } {
    wm deiconify .emc
    return
  }
  set w [toplevel .emc]

  main_window
  tab_general
  tab_force_field
  tab_chemistry
  tab_emc_options
  tab_lammps_options
  tab_analysis_options
  tab_check_run
  tab_results_summary
}


#==============================================================================
# Main Window
#==============================================================================

proc main_window {} {
  set w $::EMC::gui::w

  wm title $w "EMC: Monte Carlo Simulations - GUI"
  grid columnconfigure $w 0 -weight 1
  grid rowconfigure $w 0 -weight 1

  # fundamental geometry of main window

  wm geometry $w $::EMC::gui::window_size
  wm resizable $w 0 0

  ttk::frame $w.hlf
  grid $w.hlf -column 0 -row 0 -sticky nsew
  grid columnconfigure $w.hlf 0 -weight 1
  grid rowconfigure $w.hlf 2 -weight 1

  # insert toplevel commands which are at the top:
  # add a menu bar
  # add the fixed commands at the toplevel

  ttk::frame $w.hlf.mainmenu
  set FileMenu [ttk::menubutton $w.hlf.mainmenu.filemenu \
    -text "Main Menu" -menu $w.hlf.mainmenu.filemenu.save -width 9]
  set FileMenuSave [menu $w.hlf.mainmenu.filemenu.save -tearoff no]
  $FileMenuSave add command -label "New Session" \
    -command {
      set answer [tk_messageBox \
	-message "Clearing whole session, which cannot be undone.\nProceed?" \
	-icon warning -type yesno -parent .emc]
      switch -- $answer {
	yes {::EMC::gui::ClearAllandRestoreDefaults}
	no {return}
      }
     }
  $FileMenuSave add command -label "Save Session" \
    -command "::EMC::gui::save_settings"
  $FileMenuSave add command -label "Load Session" \
    -command "::EMC::gui::load_settings"
  $FileMenuSave add command -label "Populate Options from Script" \
    -command "::EMC::gui::ReadEshOptions"
  $FileMenuSave add command -label "Restore Options to Defaults" \
    -command {
      set answer [tk_messageBox \
	-message "Resetting to defaults, which cannot be undone.\nProceed?" \
	-icon warning -type yesno -parent .emc]
      switch -- $answer {
	yes {::EMC::gui::SetDefaultOptions}
	no {return}
      }
    }

  grid $w.hlf.mainmenu -row 0 -column 0 -sticky nsew
  grid rowconfigure $w.hlf 0 -minsize 30
  grid $FileMenu -row 0 -column 0 -sticky nw

  # generate notebook here

  ttk::notebook $w.hlf.nb
  grid $w.hlf.nb -column 0 -row 1 -sticky nsew

  # everything in footer below the notebook aka disclaimer are lister here
  # potentially put run script here

  ttk::frame $w.hlf.footer
  set footer $w.hlf.footer
  grid $w.hlf.footer -column 0 -row 2 -sticky nsew -padx 15 -pady "0 5"
  

  ttk::separator $footer.sep1 -orient horizontal
  ttk::label $footer.disclaimer \
    -text "Version $::EMC::gui::version, $::EMC::gui::date - Developed by $::EMC::gui::authors"

  grid columnconfigure $footer 0 -weight 1
  grid $footer.sep1 -column 0 -row 0 -sticky nwe -pady 10 -columnspan 1
  grid $footer.disclaimer -column 0 -row 1
  grid rowconfigure $w.hlf 1 -weight 1
  grid rowconfigure $w.hlf 2 -minsize 45 -weight 1
}


#==============================================================================
# General Tab
#==============================================================================

proc tab_general {} {
  set w $::EMC::gui::w

  ttk::frame $w.hlf.nb.permanentsettings
  $w.hlf.nb add $w.hlf.nb.permanentsettings -text "General"
  grid columnconfigure $w.hlf.nb.permanentsettings 0 -weight 1
  set permanent $w.hlf.nb.permanentsettings

  ttk::label $permanent.lbl1 \
    -text "General Settings" -anchor w -font TkHeadingFont
  grid $permanent.lbl1 \
    -column 0 -row 0 -sticky nsew -pady {5 5} -padx {5 0}
  ttk::label $permanent.projectnamelbl \
    -text "Project File Name:" -anchor e
  ttk::entry $permanent.projectname \
    -textvariable ::EMC::gui::options(filename)
  ttk::button $permanent.filepathbrowse \
    -text "Browse" \
    -command {
      set types {
		{{Esh Files} {.esh}}
		{{All Files} *}
		}
      set tempfile [ \
	tk_getSaveFile \
	  -parent .emc \
	  -title "Select Project File Name" \
	  -filetypes $types \
	  -initialdir $::EMC::gui::options(directory)]
      if {$tempfile != ""} {
	set ::EMC::gui::options(filename) $tempfile
      } else {
	return
      }
    }
  ttk::label $permanent.projectdirlbl \
    -text "Project Directory:" -anchor e
  ttk::entry $permanent.projectdir \
    -textvariable ::EMC::gui::options(directory)
  ttk::button $permanent.projectdirbrowse \
    -text "Browse" \
    -command {
      set tempfile [ \
	tk_chooseDirectory \
	  -parent .emc \
	  -title "Select Project Dir" \
	  -initialdir $::EMC::gui::options(directory)]
      if {$tempfile != ""} {
	set ::EMC::gui::options(directory) $tempfile
	cd $tempfile
      } else {
	return
      }
    }

  ttk::label $permanent.ensemblelbl -text "Ensemble" -anchor e
  ttk::radiobutton $permanent.ensemblenvt \
    -text NVT -value "NVT" \
    -variable ::EMC::gui::ensemble \
    -command {
      .emc.hlf.nb.permanentsettings.pressure configure -state disable
      .emc.hlf.nb.permanentsettings.temperature configure -state normal
      set ::EMC::gui::options(pressure) false
    }
    set path "$permanent.ensemblenvt"
    set help "type of ensemble which should be used for EMC and LAMMPS"
    ::EMC::gui::balloon $path $help

  ttk::radiobutton $permanent.ensemblenpt \
    -text NPT -value "NPT" \
    -variable ::EMC::gui::ensemble \
    -command {
      .emc.hlf.nb.permanentsettings.temperature configure -state normal
      .emc.hlf.nb.permanentsettings.pressure configure -state normal
      set ::EMC::gui::options(pressure) 1
    }
  set ::EMC::gui::ensemble "NVT"
  
  set path "$permanent.ensemblenpt"
  set help "type of ensemble which should be used for EMC and LAMMPS"
  ::EMC::gui::balloon $path $help  
  
  ttk::label $permanent.fractionlbl \
    -text "Composition Calculation:" -anchor e
  ttk::radiobutton $permanent.molfraction \
    -text "Mol Fraction" -value mol \
    -variable ::EMC::gui::options(fraction) \
    -command {
      set ::EMC::gui::conclbl "Mol Fraction:"
      set ::EMC::gui::options(mol) "true"
      set ::EMC::gui::options(mass) "false"
      set ::EMC::gui::options(volume) "false"
      set ::EMC::gui::options(number) "false"
      .emc.hlf.nb.permanentsettings.ntotal configure -state normal
    }
  ttk::radiobutton $permanent.massfraction \
    -text "Mass Fraction" -value mass  \
    -variable ::EMC::gui::options(fraction) \
    -command {
      set ::EMC::gui::conclbl "Mass Fraction:"
      set ::EMC::gui::options(mol) "false"
      set ::EMC::gui::options(mass) "true"
      set ::EMC::gui::options(volume) "false"
      set ::EMC::gui::options(number) "false"
      .emc.hlf.nb.permanentsettings.ntotal configure -state normal
    }
  ttk::radiobutton $permanent.volfraction \
    -text "Volume Fraction" -value vol \
    -variable ::EMC::gui::options(fraction) \
    -command {
      set ::EMC::gui::conclbl "Volume Fraction:"
      set ::EMC::gui::options(mol) "false"
      set ::EMC::gui::options(mass) "false"
      set ::EMC::gui::options(volume) "true"
      set ::EMC::gui::options(number) "false"
      .emc.hlf.nb.permanentsettings.ntotal configure -state normal
    }
  ttk::radiobutton $permanent.molcount \
    -text "Number of Molecules" -value count \
    -variable ::EMC::gui::options(fraction) \
    -command {
      set ::EMC::gui::conclbl "Number of Molecules:"
      set ::EMC::gui::options(mol) "false"
      set ::EMC::gui::options(mass) "false"
      set ::EMC::gui::options(volume) "false"
      set ::EMC::gui::options(number) "true"
      .emc.hlf.nb.permanentsettings.ntotal configure -state disable
    }

  set ::EMC::gui::options(fraction) mol
  ttk::label $permanent.temperaturelbl \
    -text "Temperature:" -anchor e
  ttk::entry $permanent.temperature \
    -textvariable ::EMC::gui::options(temperature)
  set path "$permanent.temperature"
  set help [lindex $::EMC::gui::optionlist \
    [lsearch -index 0 $::EMC::gui::optionlist "temperature"]  1] 
  ::EMC::gui::balloon $path $help

  ttk::label $permanent.pressurelbl \
    -text "Pressure:" -anchor e
  ttk::entry $permanent.pressure \
    -textvariable ::EMC::gui::options(pressure)
  set path "$permanent.pressure"
  set help [lindex $::EMC::gui::optionlist \
    [lsearch -index 0 $::EMC::gui::optionlist "pressure"]  1] 
  ::EMC::gui::balloon $path $help

  ttk::label $permanent.densitylbl \
    -text "Density:" -anchor e
  ttk::entry $permanent.density \
    -textvariable ::EMC::gui::options(density)
  set path "$permanent.density"
  set help [lindex $::EMC::gui::optionlist \
    [lsearch -index 0 $::EMC::gui::optionlist "density"]  1] 
  ::EMC::gui::balloon $path $help

  ttk::label $permanent.ntotallbl \
    -text "Number of Atoms:" -anchor e
  ttk::entry $permanent.ntotal \
    -textvariable ::EMC::gui::options(ntotal)
  set path "$permanent.ntotal"
  set help [lindex $::EMC::gui::optionlist \
    [lsearch -index 0 $::EMC::gui::optionlist "ntotal"]  1] 
  ::EMC::gui::balloon $path $help

  ttk::label $permanent.shapelbl \
    -text "Shape:" -anchor e
  ttk::entry $permanent.shape \
    -textvariable ::EMC::gui::options(shape)
  set path "$permanent.shape"
  set help [lindex $::EMC::gui::optionlist \
    [lsearch -index 0 $::EMC::gui::optionlist "shape"]  1] 
  ::EMC::gui::balloon $path $help

  ttk::label $permanent.copieslbl \
    -text "Copies:" -anchor e
  ttk::entry $permanent.copies \
    -textvariable ::EMC::gui::options(multicopies)
  $permanent.copies configure \
    -validate key -validatecommand {string is int %P}

  ttk::label $permanent.stagenamelbl \
    -text "Stage Name:" -anchor e
  ttk::entry $permanent.stagename \
    -textvariable ::EMC::gui::stages(defaultstage)
  
  ttk::label $permanent.trialnamelbl \
    -text "Trial Name" -anchor e
  ttk::entry $permanent.trialname \
    -textvariable ::EMC::gui::trials(defaulttrial)

  ttk::label $permanent.projectvarnamelbl \
    -text "Project Name" -anchor e
  ttk::entry $permanent.projectvarname \
    -textvariable ::EMC::gui::options(project)

  set path "$permanent.projectvarname"
  set help "Name of the project files. If not specified esh file name will be used"
  ::EMC::gui::balloon $path $help
  
  ttk::label $permanent.sampleplbl \
    -text "LAMMPS Sampling Options:" -anchor e
  ttk::checkbutton $permanent.samplep \
    -text "Sample Pressure" -variable ::EMC::gui::options(sample,p) \
    -onvalue true -offvalue false
  ttk::checkbutton $permanent.samplev \
    -text "Sample Volume" -variable ::EMC::gui::options(sample,v) \
    -onvalue true -offvalue false
  ttk::checkbutton $permanent.samplee \
    -text "Sample Energy" -variable ::EMC::gui::options(sample,e) \
    -onvalue true -offvalue false

  ttk::label $permanent.profilelbl \
    -text "LAMMPS Profile options:" -anchor e
  ttk::checkbutton $permanent.profilep \
    -text "Pressure Profile" -variable ::EMC::gui::options(profile,pressure) \
    -onvalue true -offvalue false
  ttk::checkbutton $permanent.profiled \
    -text "Density Profile" -variable ::EMC::gui::options(profile,density) \
    -onvalue true -offvalue false
  

  set path "$permanent.samplep"
  set help [lindex $::EMC::gui::optionlist \
    [lsearch -index 0 $::EMC::gui::optionlist "sample"]  1] 
  ::EMC::gui::balloon $path $help
  set path "$permanent.samplev"
  set help [lindex $::EMC::gui::optionlist \
    [lsearch -index 0 $::EMC::gui::optionlist "sample"]  1] 
  ::EMC::gui::balloon $path $help
  set path "$permanent.samplee"
  set help [lindex $::EMC::gui::optionlist \
    [lsearch -index 0 $::EMC::gui::optionlist "sample"]  1] 
  ::EMC::gui::balloon $path $help

  # Grid Definitions of permanent options on the top
  
  set row 1

  grid $permanent.projectdirlbl \
    -column 0 -row $row -padx {5 5} -pady {5 5}	-sticky nsew
  grid $permanent.projectdir \
    -column 1 -row $row -padx {5 5} -pady {5 5} -sticky nsew -columnspan 4
  grid $permanent.projectdirbrowse \
    -column 5 -row $row -padx {5 5} -pady {5 5} -sticky nsew
  set row [expr $row+1]

  grid $permanent.projectnamelbl \
    -column 0 -row $row -padx {5 5} -pady {5 5} -sticky nsew
  grid $permanent.projectname \
    -column 1 -row $row -padx {5 5} -pady {5 5} -sticky nsew -columnspan 4
  grid $permanent.filepathbrowse \
    -column 5 -row $row -padx {5 5} -pady {5 5} -sticky nsew
  set row [expr $row+1]

  grid $permanent.stagenamelbl \
    -column 0 -row $row -padx {5 5} -pady {5 5} -sticky nsew
  grid $permanent.stagename \
    -column 1 -row $row -padx {5 5} -pady {5 5} -sticky nsew
  grid $permanent.trialnamelbl \
    -column 2 -row $row -padx {5 5} -pady {5 5} -sticky nsew
  grid $permanent.trialname \
    -column 3 -row $row -padx {5 5} -pady {5 5} -sticky nsew
  set row [expr $row+1]

  grid $permanent.copieslbl \
    -column 0 -row $row -padx {5 5} -pady {5 5} -sticky nsew
  grid $permanent.copies \
    -column 1 -row $row -padx {5 5} -pady {5 5} -sticky nsew
  grid $permanent.projectvarnamelbl \
    -column 2 -row $row -padx {5 5} -pady {5 5} -sticky nsew
  grid $permanent.projectvarname \
    -column 3 -row $row -padx {5 5} -pady {5 5} -sticky nsew
  set row [expr $row+1]

  grid $permanent.densitylbl \
    -column 0 -row $row -padx {5 5} -pady {5 5} -sticky nsew
  grid $permanent.density \
    -column 1 -row $row -padx {5 5} -pady {5 5} -sticky nsew
  grid $permanent.shapelbl \
    -column 2 -row $row -padx {5 5} -pady {5 5} -sticky nsew
  grid $permanent.shape \
    -column 3 -row $row -padx {5 5} -pady {5 5} -sticky nsew
  set row [expr $row+1]

  grid $permanent.ensemblelbl \
    -column 0 -row $row -padx {5 5} -pady {5 5} -sticky nsew
  grid $permanent.ensemblenvt \
    -column 1 -row $row -padx {5 5} -pady {5 5} -sticky nsew
  grid $permanent.ensemblenpt \
    -column 3 -row $row -padx {5 5} -pady {5 5} -sticky nsew
  set row [expr $row+1]

  grid $permanent.temperaturelbl \
    -column 0 -row $row -padx {5 5} -pady {5 5} -sticky nsew
  grid $permanent.temperature \
    -column 1 -row $row -padx {5 5} -pady {5 5} -sticky nsew
  grid $permanent.pressurelbl \
    -column 2 -row $row -padx {5 5} -pady {5 5} -sticky nsew
  grid $permanent.pressure \
    -column 3 -row $row -padx {5 5} -pady {5 5} -sticky nsew
  .emc.hlf.nb.permanentsettings.pressure configure -state disable
  set row [expr $row+1]


  grid $permanent.ntotallbl \
    -column 0 -row $row -padx {5 5} -pady {5 5} -sticky nsew
  grid $permanent.ntotal \
    -column 1 -row $row -padx {5 5} -pady {5 5} -sticky nsew
  set row [expr $row+1]

  grid $permanent.fractionlbl \
    -column 0 -row $row -padx {5 5} -pady {5 5} -sticky nsew
  grid $permanent.molfraction \
    -column 1 -row $row -padx {5 5} -pady {5 5} -sticky nsew
  grid $permanent.massfraction \
    -column 2 -row $row -padx {5 5} -pady {5 5} -sticky nsew
  grid $permanent.volfraction \
    -column 3 -row $row -padx {5 5} -pady {5 5} -sticky nsew
  grid $permanent.molcount \
    -column 4 -row $row -padx {5 5} -pady {5 5} -sticky nsew 
  set row [expr $row+1]

  grid $permanent.sampleplbl \
    -column 0 -row $row -padx {5 5} -pady {5 5} -sticky nsew
  grid $permanent.samplep \
    -column 1 -row $row -padx {5 5} -pady {5 5} -sticky nsew
  grid $permanent.samplev \
    -column 2 -row $row -padx {5 5} -pady {5 5} -sticky nsew
  grid $permanent.samplee \
    -column 3 -row $row -padx {5 5} -pady {5 5} -sticky nsew
  set row [expr $row+1]

  grid $permanent.profilelbl \
    -column 0 -row $row -padx {5 5} -pady {5 5} -sticky nsew
  grid $permanent.profiled \
    -column 1 -row $row -padx {5 5} -pady {5 5} -sticky nsew
  grid $permanent.profilep \
    -column 2 -row $row -padx {5 5} -pady {5 5} -sticky nsew
  set row [expr $row+1]

  grid columnconfigure $permanent {0} -weight 1 -uniform rt1

  grid columnconfigure $w.hlf.mainmenu 1 -weight 1 
  ::EMC::gui::createInfoButton $w.hlf.mainmenu 0 1
  bind $w.hlf.mainmenu.info <Button-1> {
    set val [::EMC::gui::MainMenuInfo]
    set ::EMC::gui::link [lindex $val 1]
    ::EMC::gui::infoWindow info [lindex $val 0] [lindex $val 2]
  }

  grid columnconfigure $permanent 1 -weight 1 
  ::EMC::gui::createInfoButton $permanent 0 5
  bind $permanent.info <Button-1> {
    set val [::EMC::gui::FixedMenuInfo]
    set ::EMC::gui::link [lindex $val 1]
    ::EMC::gui::infoWindow info [lindex $val 0] [lindex $val 2]
  }
}


#==============================================================================
# Force Field Tab
#==============================================================================

proc tab_force_field {} {
  set w $::EMC::gui::w

  ttk::frame $w.hlf.nb.ffsettings -width 500 -height 250
  $w.hlf.nb add $w.hlf.nb.ffsettings -text "Force Field"
  grid columnconfigure $w.hlf.nb.ffsettings 0 -weight 1

  set ffsettings $w.hlf.nb.ffsettings

  ttk::frame $ffsettings.basic
  ttk::label $ffsettings.basic.lbl1 \
    -text "Standard Options" -font TkHeadingFont

  # important basic Settings hard code in here
  # advanced settings are not implemented in the prototype

  ttk::labelframe $ffsettings.advanced \
    -labelanchor nw -padding $::EMC::gui::frame_padding
  ttk::label $ffsettings.advanced.lblwidget \
    -text "$::EMC::gui::down_point Advanced Options" \
    -anchor w -font TkDefaultFont
  $ffsettings.advanced configure \
    -labelwidget $ffsettings.advanced.lblwidget
  ttk::label $ffsettings.advancedPlaceHolder \
    -text "$::EMC::gui::right_point Advanced Options" \
    -anchor w -font TkDefaultFont

  bind $ffsettings.advanced.lblwidget <Button-1> {
    grid remove .emc.hlf.nb.ffsettings.advanced
    grid .emc.hlf.nb.ffsettings.advancedPlaceHolder
    ::EMC::gui::ResizeToActiveTab
  }
  bind $ffsettings.advancedPlaceHolder <Button-1> {
    grid remove .emc.hlf.nb.ffsettings.advancedPlaceHolder
    grid .emc.hlf.nb.ffsettings.advanced
    ::EMC::gui::ResizeToActiveTab
  }
  
  ttk::frame $ffsettings.browserframe

  ttk::label $ffsettings.browserframe.forcefieldlbl \
    -text "Force Field:" -anchor w -font TkHeadingFont
  ttk::combobox $ffsettings.browserframe.forcefield \
    -textvariable ::EMC::gui::options(field) -state readonly \
    -values $::EMC::gui::fflist

  # sets default and calls the same functions as if the selection in
  # the drop down were changed

  set ::EMC::gui::options(field) $::EMC::gui::ffdefault(field)

  bind $ffsettings.browserframe.forcefield <<ComboboxSelected>> {
    ::EMC::gui::ReloadOptionsFromEmcforForceField $::EMC::gui::options(field)
    ::EMC::gui::EnableFieldOptions .emc.hlf.nb.ffsettings $::EMC::gui::options(field)
    ::EMC::gui::GetUpdateParameterList
    if {[info exists ::EMC::gui::options(field,custom)] == 1} {
      unset ::EMC::gui::options(field,custom)
    }
    tk_messageBox \
      -title "Forcefield Changed" \
      -icon info -type ok -parent .emc \
      -message "By changing the force field some options may no longer be valid.  Please check your options." 
  }

  ttk::label $ffsettings.browserframe.title \
    -text "Available Files:" -font TkHeadingFont
  ttk::treeview $ffsettings.browserframe.tv \
    -selectmode browse -yscrollcommand " $ffsettings.browserframe.scroll set"
  $ffsettings.browserframe.tv \
    configure -column {Name path} -display {Name} -show {headings} -height 5
  $ffsettings.browserframe.tv \
    heading Name -text "Name"
  $ffsettings.browserframe.tv \
    column Name -width 250 -stretch 1 -anchor center
  ttk::scrollbar $ffsettings.browserframe.scroll \
    -orient vertical -command " $ffsettings.browserframe.tv yview"

  ttk::label $ffsettings.browserframe.title2 \
    -text "Used Files:" -font TkHeadingFont
  ttk::treeview $ffsettings.browserframe.tv2 \
    -selectmode browse -yscrollcommand "$ffsettings.browserframe.scroll2 set"
  $ffsettings.browserframe.tv2 \
    configure -column {Name path} -display {Name} -show {headings} -height 5
  $ffsettings.browserframe.tv2 \
    heading Name -text "Name"
  $ffsettings.browserframe.tv2 \
    column Name -width 250 -stretch 1 -anchor center
  ttk::scrollbar $ffsettings.browserframe.scroll2 \
    -orient vertical -command "$ffsettings.browserframe.tv yview"

  ttk::button $ffsettings.browserframe.addright \
    -text "Add FF $::EMC::gui::right_arrow" \
    -command {
      set comparedirectory [join [lrange [split [lindex [.emc.hlf.nb.ffsettings.browserframe.tv item [.emc.hlf.nb.ffsettings.browserframe.tv selection] -values] 1] "/"] 0 end-1] "/"]
      set mismatch 0
      foreach field $::EMC::gui::fffilelist {
	if {$comparedirectory != [ \
	    join [lrange [split [lindex $field 1] "/"] 0 end-1] "/"]} {
	  set mismatch 1
	}
      }
      if {$mismatch == 1} {
	tk_messageBox \
	  -type ok -icon error \
	  -title "Field Directory Error" -parent .emc \
	  -message "Force field files must all be in the same directory."
	return 
      }
      ::EMC::gui::AddForceFieldButton
      set ::EMC::gui::options(field,custom) 1
    }

  ttk::button $ffsettings.browserframe.removeleft \
    -text "Remove FF $::EMC::gui::left_arrow" \
    -command {
      ::EMC::gui::RemoveForceFieldButton
      set ::EMC::gui::options(field,custom) 1
    }

  ttk::button $ffsettings.browserframe.addbutton -text "Add File" \
    -command {
      set types { {{All Files} *} }
      set tempfile [tk_getOpenFile -title "Import Group File" -filetypes $types -parent .emc]
      if {$tempfile ne ""} {
	set comparedirectory [join [lrange [split $tempfile "/"] 0 end-1] "/"]
	set mismatch 0
	foreach field $::EMC::gui::fffilelist {
	  if {$comparedirectory != [ \
	      join [lrange [split [lindex $field 1] "/"] 0 end-1] "/"]} {
	    set mismatch 1
	  }
	}
	if {$mismatch == 1} {
	  tk_messageBox -type ok \
	    -icon error -title "Field Directory Error" -parent .emc \
	    -message "Force field files must all be in the same directory!"
	  return 
	}
	set name [lindex [split $tempfile "/"] end]
	.emc.hlf.nb.ffsettings.browserframe.tv2 insert {} end -values [ \
	  list "$name" "$tempfile"]
	lappend ::EMC::gui::fffilelist "$name $tempfile"
	set ::EMC::gui::options(field,custom) 1
      }
    }

  ttk::button $ffsettings.browserframe.removebutton -text "Remove File" \
    -command {
      if {[.emc.hlf.nb.ffsettings.browserframe.tv selection] == ""} {
	return
      } else {
	.emc.hlf.nb.ffsettings.browserframe.tv2 delete [ \
	  .emc.hlf.nb.ffsettings.browserframe.tv2 selection]
	set ::EMC::gui::fffilelist [ \
	  lreplace $::EMC::gui::fffilelist [ \
	    lsearch -index 0 $::EMC::gui::fffilelist [ \
	      lindex [ \
		.emc.hlf.nb.ffsettings.browserframe.tv item [ \
		  .emc.hlf.nb.ffsettings.browserframe.tv selection] \
	       	-values] 0]] [ \
	    lsearch -index 0 $::EMC::gui::fffilelist [ \
	      lindex [ \
		.emc.hlf.nb.ffsettings.browserframe.tv item [ \
		  .emc.hlf.nb.ffsettings.browserframe.tv selection] \
		-values] 0]]]
	set ::EMC::gui::options(field,custom) 1
      }
    }
  ttk::button $ffsettings.browserframe.moveup -text "Move Up" \
    -command {
      set currentID [.emc.hlf.nb.ffsettings.browserframe.tv2 selection]
      if {[set previousID [.emc.hlf.nb.ffsettings.browserframe.tv2 prev $currentID]] ne ""} {
	set previousIndex [.emc.hlf.nb.ffsettings.browserframe.tv2 index $previousID]
	.emc.hlf.nb.ffsettings.browserframe.tv2 move $currentID {} $previousIndex
	unset previousIndex
      }
      unset currentID previousID
      set ::EMC::gui::options(field,custom) 1
    }
  ttk::button $ffsettings.browserframe.movedown -text "Move Down" \
    -command {
      set currentID [.emc.hlf.nb.ffsettings.browserframe.tv2 selection]
      if {[set previousID [.emc.hlf.nb.ffsettings.browserframe.tv2 next $currentID]] ne ""} {
	set previousIndex [.emc.hlf.nb.ffsettings.browserframe.tv2 index $previousID]
	.emc.hlf.nb.ffsettings.browserframe.tv2 move $currentID {} $previousIndex
	unset previousIndex
      }
      unset currentID previousID
      set ::EMC::gui::options(field,custom) 1
    }

  grid $ffsettings.browserframe \
    -column 0 -row 0 -sticky nsew -padx {0 0} -pady {5 5}

  grid $ffsettings.browserframe.forcefieldlbl \
    -column 0 -row 0 -sticky w -padx {5 5} -pady {5 5}
  grid $ffsettings.browserframe.forcefield \
    -column 1 -row 0 -sticky w -padx {5 5} -pady {5 5}

  grid $ffsettings.browserframe.title \
    -column 0 -row 1 -sticky nsew -padx {5 5} -pady {5 5} -columnspan 2
  grid $ffsettings.browserframe.tv \
    -column 0 -row 2 -sticky nsew -padx {5 0} -pady {0 5} -rowspan 4 -columnspan 2
  grid $ffsettings.browserframe.scroll \
    -column 2 -row 2 -sticky nsew -padx {0 0} -pady {0 5} -rowspan 4
  grid $ffsettings.browserframe.addright \
    -column 3  -row 3 -sticky nsew -padx {5 5} -pady {5 5}
  grid $ffsettings.browserframe.removeleft \
    -column 3  -row 4 -sticky nsew -padx {5 5} -pady {5 5}
  grid $ffsettings.browserframe.title2 \
    -column 4  -row 1 -sticky nsew -padx {5 5} -pady {5 5}
  grid $ffsettings.browserframe.tv2 \
    -column 4 -row 2  -sticky nsew -padx {5 0} -pady {0 5} -rowspan 4
  grid $ffsettings.browserframe.scroll2 \
    -column 5 -row 2 -sticky nsew -padx {0 0} -pady {0 5} -rowspan 4

  grid $ffsettings.browserframe.addbutton \
    -column 6 -row 5 -sticky nsew -padx {5 0} -pady {0 5}
  grid $ffsettings.browserframe.moveup  \
    -column 6 -row 3 -sticky nsew -padx {5 0} -pady {0 5}
  grid $ffsettings.browserframe.movedown \
    -column 6 -row 4 -sticky nsew -padx {5 0} -pady {0 5}

  grid columnconfigure \
    $ffsettings.browserframe {0 1} -weight 1 -uniform rt1

  grid $ffsettings.basic \
    -column 0 -row 1 -sticky nsew
  grid columnconfigure \
    $w.hlf.nb.ffsettings.basic {0 1 2 4 5 6} -weight 1 -uniform rt1
  grid $ffsettings.basic.lbl1 \
    -column 0 -row 0 -sticky nsew
  grid $ffsettings.advanced \
    -column 0 -row 2 -sticky nsew \
    -padx $::EMC::gui::pad_x -pady $::EMC::gui::pad_y
  grid remove $ffsettings.advanced
  grid columnconfigure \
    $w.hlf.nb.ffsettings.advanced {0 1 2 4 5 6} -weight 1 -uniform rt1
  grid $ffsettings.advancedPlaceHolder \
    -column 0 -row 2 -sticky nswe \
    -padx $::EMC::gui::pad_x -pady $::EMC::gui::pad_y

  ::EMC::gui::MakeGuiOptionsSection \
    .emc.hlf.nb.ffsettings.basic field standard

  ::EMC::gui::MakeGuiOptionsSection \
    .emc.hlf.nb.ffsettings.advanced field advanced

  ::EMC::gui::createInfoButton $w.hlf.nb.ffsettings.basic 0 6
  bind $w.hlf.nb.ffsettings.basic.info <Button-1> {
    set val [::EMC::gui::selectInfo]
    set ::EMC::gui::link [lindex $val 1]
    ::EMC::gui::infoWindow info [lindex $val 0] [lindex $val 2]
  }
  ::EMC::gui::GetUpdateParameterList
}


#==============================================================================
# Chemistry Tab
#==============================================================================

proc tab_chemistry {} {
  set w $::EMC::gui::w

  ttk::frame $w.hlf.nb.chemistry
  $w.hlf.nb add $w.hlf.nb.chemistry -text "Chemistry"
  grid columnconfigure $w.hlf.nb.chemistry 0 -weight 1
  set wchem $w.hlf.nb.chemistry
   
  # Add Chemistry stuff here
  ttk::frame $wchem.definechemistry
  #ttk::labelframe $wchem.additional -text "Additional Parameters"
  ttk::separator $wchem.sep -orient horizontal
  ttk::frame $wchem.trials

  ttk::label $wchem.definechemistry.title \
    -text "Defined Chemistry" -font TkHeadingFont
  ttk::button $wchem.definechemistry.addsm \
    -text "Add Small Molecule" -width 17 \
    -command {
      if {[winfo exists .emcsm]} {
	raise .emcsm
	return
      }
      emcsm
    }
  ttk::button $wchem.definechemistry.addpoly -text "Add Polymer"  -width 17 \
    -command {
      if {[winfo exists .emcpoly]} {
	raise .emcpoly
	return
      }
      emcpoly
    }
  ttk::button $wchem.definechemistry.addsurf -text "Add Surface" -width 17 \
    -command {
      if {[winfo exists .emcsurf]} {
	raise .emcsurf
	return
      }
      emcsurf
    }
  ttk::button $wchem.definechemistry.addprotein -text "Add Protein" -width 17 \
    -command {
      puts "Warning) Open protein window - This feature does not exists yet"
    }
  ttk::button $wchem.definechemistry.deleteitem -text "Delete Item" -width 17 \
    -command {
      if {$::EMC::gui::temptype == "polymer"} {
	::EMC::gui::DeletePolymerItem $::EMC::gui::tempname
	set ::EMC::gui::tvdefchemistrylist [ \
	  lreplace $::EMC::gui::tvdefchemistrylist [ \
	    lsearch -index 0 \
	      $::EMC::gui::tvdefchemistrylist $::EMC::gui::tempname] [ \
	    lsearch -index 0 \
	      $::EMC::gui::tvdefchemistrylist $::EMC::gui::tempname]]
	.emc.hlf.nb.chemistry.definechemistry.tv delete [ \
	  .emc.hlf.nb.chemistry.definechemistry.tv selection]
      } elseif {$::EMC::gui::temptype == "small_molecule"} {
	set ::EMC::gui::tvdefchemistrylist [ \
	  lreplace $::EMC::gui::tvdefchemistrylist [ \
	    lsearch -index 0 \
	      $::EMC::gui::tvdefchemistrylist $::EMC::gui::tempname] [ \
	    lsearch -index 0 \
	      $::EMC::gui::tvdefchemistrylist $::EMC::gui::tempname]]
	.emc.hlf.nb.chemistry.definechemistry.tv delete [ \
	  .emc.hlf.nb.chemistry.definechemistry.tv selection]
      } elseif {$::EMC::gui::temptype == "surface"} {
# 	::EMC::gui::DeleteSurfaceItem
	set ::EMC::gui::tvdefchemistrylist [ \
	  lreplace $::EMC::gui::tvdefchemistrylist [ \
	    lsearch -index 0 \
	      $::EMC::gui::tvdefchemistrylist $::EMC::gui::tempname] [ \
	    lsearch -index 0 \
	      $::EMC::gui::tvdefchemistrylist $::EMC::gui::tempname]]
	.emc.hlf.nb.chemistry.definechemistry.tv delete [ \
	  .emc.hlf.nb.chemistry.definechemistry.tv selection]
	array unset ::EMC::gui::surfoptions
      }
    }
  ttk::button $wchem.definechemistry.clearall -text "Clear All" \
    -command {
      .emc.hlf.nb.chemistry.definechemistry.tv delete [ \
	.emc.hlf.nb.chemistry.definechemistry.tv children {}]
      set ::EMC::gui::tvdefchemistrylist {}
      set ::EMC::gui::ClusterList {}
      set ::EMC::gui::PolymerItem {}
      set ::EMC::gui::GroupList {}
    }

  ttk::separator \
    $wchem.definechemistry.sep1 -orient horizontal

  ttk::treeview \
    $wchem.definechemistry.tv -selectmode browse \
    -yscrollcommand "$wchem.definechemistry.scroll set"
  $wchem.definechemistry.tv configure \
    -column {name type polymerization conc phase} \
    -display {name type conc phase} -show {headings} -height 5
  $wchem.definechemistry.tv heading name \
    -text "Name"
  $wchem.definechemistry.tv heading type \
    -text "Type"
  $wchem.definechemistry.tv heading conc \
    -text "Amount"
  $wchem.definechemistry.tv heading phase \
    -text "Phase"
  $wchem.definechemistry.tv column name \
    -width 175 -stretch 1 -anchor center
  $wchem.definechemistry.tv column type \
    -width 175 -stretch 1 -anchor center
  $wchem.definechemistry.tv column conc \
    -width 150 -stretch 1 -anchor center
  $wchem.definechemistry.tv column phase \
    -width 100 -stretch 1 -anchor center
  ttk::scrollbar $wchem.definechemistry.scroll \
    -orient vertical -command "$wchem.definechemistry.tv yview"
  
  ttk::button $wchem.definechemistry.apply \
    -text "$::EMC::gui::style_accept Apply" \
    -command {
      if {[string length $::EMC::gui::tempconcentration] == 0 || \
	  [string length $::EMC::gui::tempphase] == 0} { return }
      .emc.hlf.nb.chemistry.definechemistry.tv item [ \
	.emc.hlf.nb.chemistry.definechemistry.tv selection] \
	-values [list \
	  $::EMC::gui::tempname \
	  $EMC::gui::temptype \
	  $EMC::gui::temppolymer \
	  $::EMC::gui::tempconcentration \
	  $::EMC::gui::tempphase]
      set ::EMC::gui::tvdefchemistrylist [ \
	lreplace $::EMC::gui::tvdefchemistrylist [ \
	  lsearch -index 0 \
	    $::EMC::gui::tvdefchemistrylist $::EMC::gui::tempname] [ \
	  lsearch -index 0 \
	    $::EMC::gui::tvdefchemistrylist $::EMC::gui::tempname]]
      lappend ::EMC::gui::tvdefchemistrylist \
	"$::EMC::gui::tempname $EMC::gui::temptype $EMC::gui::temppolymer $::EMC::gui::tempconcentration $::EMC::gui::tempphase"
    }

  ttk::label $wchem.definechemistry.addconclbl \
    -textvariable ::EMC::gui::conclbl -anchor w
  ttk::entry $wchem.definechemistry.addconcentry \
    -textvariable ::EMC::gui::tempconcentration -width 1
  ttk::label $wchem.definechemistry.addphaselbl \
    -text "Change Phase:" -anchor w
  ttk::entry $wchem.definechemistry.addphaseentry \
    -textvariable ::EMC::gui::tempphase -width 1 -validate key \
    -validatecommand {string is int %P}

  bind $wchem.definechemistry.tv <<TreeviewSelect>> {
    set editdata [ \
      .emc.hlf.nb.chemistry.definechemistry.tv item [ \
      .emc.hlf.nb.chemistry.definechemistry.tv selection] -values]
    set ::EMC::gui::tempconcentration [lindex $editdata 3]
    set ::EMC::gui::tempphase [lindex $editdata 4]
    set ::EMC::gui::tempname [lindex $editdata 0]
    set ::EMC::gui::temptype [lindex $editdata 1]
    set ::EMC::gui::temppolymer [lindex $editdata 2]
    if {$::EMC::gui::temptype == "surface"} {
      .emc.hlf.nb.chemistry.definechemistry.addphaseentry \
	configure -state disable
      .emc.hlf.nb.chemistry.definechemistry.addconcentry \
	configure -state disable
    } else {
      .emc.hlf.nb.chemistry.definechemistry.addphaseentry \
	configure -state normal
      .emc.hlf.nb.chemistry.definechemistry.addconcentry \
	configure -state normal
    }
  }
  
  # all trial buttons and tv start here

  ttk::label $wchem.trials.titlelbl \
    -text "Multiple Trial Sampling" -font TkHeadingFont
  set ::EMC::gui::trials(use) "false"
  ttk::checkbutton $wchem.trials.usecheckbox \
    -text "Use Trials" -variable ::EMC::gui::trials(use) \
    -onvalue true -offvalue false \
    -command {::EMC::gui::AddRemoveTrial}
   
  ttk::treeview $wchem.trials.tv \
    -selectmode browse -yscrollcommand "$wchem.trials.scroll set"
  $wchem.trials.tv configure \
    -column {name smiles trial} -display {name smiles trial} \
    -show {headings} -height 5
  $wchem.trials.tv heading name \
    -text "Name"
  $wchem.trials.tv heading smiles \
    -text "Smiles"
  $wchem.trials.tv heading trial \
    -text "Trial Name"
  $wchem.trials.tv column name \
    -width 200 -stretch 1 -anchor center
  $wchem.trials.tv column smiles \
    -width 200 -stretch 1 -anchor center
  $wchem.trials.tv column trial \
    -width 200 -stretch 1 -anchor center
  ttk::scrollbar $wchem.trials.scroll \
    -orient vertical -command "$wchem.trials.tv yview"
  
  ttk::button $wchem.trials.addtrial \
    -text "Add $::EMC::gui::style_accept" -width 17 \
    -command { emctrial }

  ttk::button $wchem.trials.removetrial \
    -text "Remove" -width 17 \
    -command {
      set trialposition [ \
	lsearch -index 0 $::EMC::gui::LoopList "trial"]
      unset ::EMC::gui::trials( \
	[lindex [ \
	  .emc.hlf.nb.chemistry.trials.tv item [ \
	    .emc.hlf.nb.chemistry.trials.tv selection] -values] 2],molname)
      set ::EMC::gui::triallist [ \
	lreplace $::EMC::gui::triallist [ \
	  lsearch -index 0 $::EMC::gui::triallist [ \
	    lindex [ \
	      .emc.hlf.nb.chemistry.trials.tv item [ \
		.emc.hlf.nb.chemistry.trials.tv selection] -values] 2]] [ \
	  lsearch -index 0 $::EMC::gui::triallist [ \
	    lindex [ \
	      .emc.hlf.nb.chemistry.trials.tv item [ \
		.emc.hlf.nb.chemistry.trials.tv selection] -values] 2]]]
      .emc.hlf.nb.chemistry.trials.tv delete [ \
	.emc.hlf.nb.chemistry.trials.tv selection]
    }
  
  grid $wchem.definechemistry \
    -column 0  -row 0  -sticky nsew -pady 5
  grid columnconfigure \
    $wchem.definechemistry 0 -weight 1 -minsize 175
  grid columnconfigure \
    $wchem.definechemistry 1 -weight 1 -minsize 175
  grid columnconfigure \
    $wchem.definechemistry 2 -weight 1 -minsize 150
  grid columnconfigure \
    $wchem.definechemistry 3 -weight 1 -minsize 100

  grid $wchem.sep  \
    -column 0 -row 1 -sticky nsew -padx {0 0} -pady {5 5}
  grid $wchem.trials \
    -column 0  -row 2  -sticky nsew -pady 5

  grid columnconfigure \
    $wchem.trials 0 -weight 0 -minsize 200
  grid columnconfigure \
    $wchem.trials 1 -weight 0 -minsize 200
  grid columnconfigure \
    $wchem.trials 2 -weight 0 -minsize 200

  grid $wchem.definechemistry.title \
    -column 0 -row 0 -sticky nsew -padx {0 0} -pady {0 0}
  grid $wchem.definechemistry.tv \
    -column 0 -row 1 -sticky nsew -padx {0 0} -pady {0 5} \
    -columnspan 4 -rowspan 4 
  grid $wchem.definechemistry.scroll \
    -column 4 -row 1 -sticky nsew -padx {0 5} -pady {0 5} -rowspan 4
  grid $wchem.definechemistry.addsm \
    -column 5 -row 1 -sticky nsew -padx {0 5} -pady {0 5}
  grid $wchem.definechemistry.addpoly \
    -column 6 -row 1 -sticky nsew -padx {0 5} -pady {0 5}
  grid $wchem.definechemistry.addsurf \
    -column 5 -row 2 -sticky nsew -padx {0 5} -pady {0 5}
  grid $wchem.definechemistry.addprotein \
    -column 6 -row 2 -sticky nsew -padx {0 5} -pady {0 5}
  grid $wchem.definechemistry.sep1 \
    -column 5 -row 3 -sticky nsew -padx {0 5} -pady {5 5} -columnspan 2
  grid $wchem.definechemistry.deleteitem \
    -column 5 -row 4 -sticky nsew -padx {0 5} -pady {0 5}

  grid $wchem.definechemistry.apply \
    -column 5 -row 6 -sticky nsew -padx {0 5} -pady {0 5}
  grid $wchem.definechemistry.addconclbl \
    -column 2 -row 5 -sticky nsew -padx {0 0} -pady {0 5}
  grid $wchem.definechemistry.addconcentry \
    -column 2 -row 6 -sticky nsew -padx {5 5} -pady {0 5}
  grid $wchem.definechemistry.addphaselbl \
    -column 3 -row 5 -sticky nsew -padx {0 0} -pady {0 5}
  grid $wchem.definechemistry.addphaseentry \
    -column 3 -row 6 -sticky nsew -padx {5 5} -pady {0 5}

  grid $wchem.trials.titlelbl \
    -column 0 -row 0 -sticky nsew -padx {0 0} -pady {0 0}   
  grid $wchem.trials.usecheckbox \
    -column 1 -row 0 -sticky nsew -padx {0 0} -pady {0 0}
  grid $wchem.trials.tv \
    -column 0 -row 1 -sticky nsew -padx {0 0} -pady {0 0} \
    -columnspan 3 -rowspan 4
  grid $wchem.trials.scroll \
    -column 3 -row 1 -sticky nsew -padx {0 5} -pady {0 0} -rowspan 4
  grid $wchem.trials.addtrial \
    -column 4 -row 2 -sticky nsew -padx {0 5} -pady {0 5}
  grid $wchem.trials.removetrial \
    -column 4 -row 3 -sticky nsew -padx {0 5} -pady {0 5}
  
  $wchem.trials.removetrial configure -state disable
  $wchem.trials.addtrial	configure -state disable

  ::EMC::gui::createInfoButton $wchem.definechemistry 0 6
  bind $wchem.definechemistry.info <Button-1> {
    set val [::EMC::gui::DefineChemistryInfo]
    set ::EMC::gui::link [lindex $val 1]
    ::EMC::gui::infoWindow info [lindex $val 0] [lindex $val 2]
  }
  grid columnconfigure $wchem.trials 6 -weight 1
  ::EMC::gui::createInfoButton $wchem.trials 0 6
  bind $wchem.trials.info <Button-1> {
    set val [::EMC::gui::selectInfo]
    set ::EMC::gui::link [lindex $val 1]
    ::EMC::gui::infoWindow info [lindex $val 0] [lindex $val 2]
  }
}


#==============================================================================
# EMC Option Tab
#==============================================================================

proc tab_emc_options {} {
  set w $::EMC::gui::w

  ttk::frame $w.hlf.nb.emcsettings
  $w.hlf.nb add $w.hlf.nb.emcsettings -text "EMC Options"
  grid columnconfigure $w.hlf.nb.emcsettings 0 -weight 1

  set wemc $w.hlf.nb.emcsettings

  ttk::frame $wemc.basic
  ttk::label $wemc.basic.lbl1 -text "Standard Options" -font TkHeadingFont
  
  ttk::labelframe $wemc.advanced \
    -labelanchor nw -padding $::EMC::gui::frame_padding
  ttk::label $wemc.advanced.lblwidget \
    -text "$::EMC::gui::down_point Advanced Options" \
    -anchor w -font TkDefaultFont
  $wemc.advanced configure \
    -labelwidget $wemc.advanced.lblwidget
  ttk::label $wemc.advancedPlaceHolder \
    -text "$::EMC::gui::right_point Advanced Options" \
    -anchor w -font TkDefaultFont

  bind $wemc.advanced.lblwidget <Button-1> {
    grid remove .emc.hlf.nb.emcsettings.advanced
    grid .emc.hlf.nb.emcsettings.advancedPlaceHolder
    ::EMC::gui::ResizeToActiveTab
  }
  bind $wemc.advancedPlaceHolder <Button-1> {
    grid remove .emc.hlf.nb.emcsettings.advancedPlaceHolder
    grid .emc.hlf.nb.emcsettings.advanced
    ::EMC::gui::ResizeToActiveTab
  }

  ::EMC::gui::MakeGuiOptionsSection \
    .emc.hlf.nb.emcsettings.basic emc standard
  ::EMC::gui::MakeGuiOptionsSection \
    .emc.hlf.nb.emcsettings.advanced emc advanced

  grid $wemc.basic \
    -column 0 -row 0 -sticky nsew
  grid columnconfigure \
    $w.hlf.nb.emcsettings.basic {0 1 2 4 5 6} -weight 1  -uniform rt1
  grid $wemc.basic.lbl1 \
    -column 0 -row 0 -sticky nsew
  grid $wemc.advanced \
    -column 0 -row 1 -sticky nsew \
    -padx $::EMC::gui::pad_x -pady $::EMC::gui::pad_y
  grid columnconfigure \
    $w.hlf.nb.emcsettings.advanced {0 1 2 4 5 6} -weight 1 -uniform rt1
  grid rowconfigure \
    $wemc.advanced {1 2 3 4 5 6 7} -weight 1
  grid remove \
    $wemc.advanced
  grid $wemc.advancedPlaceHolder \
    -column 0 -row 1 -sticky nswe \
    -padx $::EMC::gui::pad_x -pady $::EMC::gui::pad_y

  ::EMC::gui::createInfoButton $w.hlf.nb.emcsettings.basic 0 6
  bind $w.hlf.nb.emcsettings.basic.info <Button-1> {
    set val [::EMC::gui::EMCOptionsInfo]
    set ::EMC::gui::link [lindex $val 1]
    ::EMC::gui::infoWindow info [lindex $val 0] [lindex $val 2]
  }
}


#==============================================================================
# LAMMPS Options Tab
#==============================================================================

proc tab_lammps_options {} {
  set w $::EMC::gui::w

  ttk::frame $w.hlf.nb.lammpssettings -width 500 -height 250
  $w.hlf.nb add $w.hlf.nb.lammpssettings -text "LAMMPS Options"
  grid columnconfigure $w.hlf.nb.lammpssettings 0 -weight 1


  set wlammps $w.hlf.nb.lammpssettings

  ttk::frame $wlammps.basic
  ttk::label $wlammps.basic.lbl1 -text "Standard Options" -font TkHeadingFont

  ttk::labelframe $wlammps.advanced \
    -labelanchor nw -padding $::EMC::gui::frame_padding
  ttk::label $wlammps.advanced.lblwidget \
    -text "$::EMC::gui::down_point Advanced Options" \
    -anchor w -font TkDefaultFont
  $wlammps.advanced configure \
    -labelwidget $wlammps.advanced.lblwidget
  ttk::label $wlammps.advancedPlaceHolder \
    -text "$::EMC::gui::right_point Advanced Options" \
    -anchor w -font TkDefaultFont

  bind $wlammps.advanced.lblwidget <Button-1> {
    grid remove .emc.hlf.nb.lammpssettings.advanced
    grid .emc.hlf.nb.lammpssettings.advancedPlaceHolder
    ::EMC::gui::ResizeToActiveTab
  }
  bind $wlammps.advancedPlaceHolder <Button-1> {
    grid remove .emc.hlf.nb.lammpssettings.advancedPlaceHolder
    grid .emc.hlf.nb.lammpssettings.advanced
    ::EMC::gui::ResizeToActiveTab
  }

  grid $wlammps.basic \
    -column 0 -row 0 -sticky nsew
  grid columnconfigure \
    $w.hlf.nb.lammpssettings.basic {0 1 2 4 5 6} -weight 1  -uniform rt1
  grid $wlammps.basic.lbl1 \
    -column 0 -row 0 -sticky nsew
  grid $wlammps.advanced \
    -column 0 -row 1 -sticky nsew \
    -padx $::EMC::gui::pad_x -pady $::EMC::gui::pad_y
  grid remove $wlammps.advanced
  grid $wlammps.advancedPlaceHolder \
    -column 0 -row 1 -sticky nswe \
    -padx $::EMC::gui::pad_x -pady $::EMC::gui::pad_y
  grid columnconfigure \
    $w.hlf.nb.lammpssettings.advanced {0 1 2 4 5 6} -weight 1  -uniform rt1

  ::EMC::gui::MakeGuiOptionsSection \
    .emc.hlf.nb.lammpssettings.basic lammps standard
  ::EMC::gui::MakeGuiOptionsSection \
    .emc.hlf.nb.lammpssettings.advanced lammps advanced
  
  ::EMC::gui::createInfoButton $w.hlf.nb.lammpssettings.basic 0 6
  bind $w.hlf.nb.lammpssettings.basic.info <Button-1> {
    set val [::EMC::gui::LammpsOptionsInfo]
    set ::EMC::gui::link [lindex $val 1]
    ::EMC::gui::infoWindow info [lindex $val 0] [lindex $val 2]
  }
}


#==============================================================================
# Analysis Options Tab
#==============================================================================

proc tab_analysis_options {} {
  set w $::EMC::gui::w

  ttk::frame $w.hlf.nb.analysissettings -width 500 -height 250
  $w.hlf.nb add $w.hlf.nb.analysissettings -text "Analysis Options"
  grid columnconfigure $w.hlf.nb.analysissettings 0 -weight 1

  set wanalysis $w.hlf.nb.analysissettings

  ttk::frame $wanalysis.basic
  ttk::label $wanalysis.basic.lbl1 -text "Standard Options" -font TkHeadingFont

  grid $wanalysis.basic \
    -column 0 -row 0 -sticky nsew
  grid $wanalysis.basic.lbl1 \
    -column 0 -row 0 -sticky nsew
  grid columnconfigure \
    $w.hlf.nb.analysissettings.basic {0 1 2 4 5 6} -weight 1  -uniform rt1

  ::EMC::gui::MakeGuiOptionsSection \
    .emc.hlf.nb.analysissettings.basic analysis standard

  ::EMC::gui::createInfoButton $w.hlf.nb.analysissettings.basic 0 6
  bind $w.hlf.nb.analysissettings.basic.info <Button-1> {
    set val [::EMC::gui::AnalysisOptionsInfo]
    set ::EMC::gui::link [lindex $val 1]
    ::EMC::gui::infoWindow info [lindex $val 0] [lindex $val 2]
  }
}


#==============================================================================
# Check/Run Tab
#==============================================================================

proc tab_check_run {} {
  set w $::EMC::gui::w

  ttk::frame $w.hlf.nb.run -width 500 -height 250
  $w.hlf.nb add $w.hlf.nb.run -text "Check/Run"
  grid columnconfigure $w.hlf.nb.run 0 -weight 1

  set wrun $w.hlf.nb.run
  ttk::frame $wrun.options
  ttk::label $wrun.options.lbl -text "Run Options" -font TkHeadingFont

  grid $wrun.options \
    -column 0 -row 0 -sticky nsew
  grid columnconfigure \
    $w.hlf.nb.run.options {0 1 2 4 5 6} -weight 1
  grid $wrun.options.lbl \
    -column 0 -row 0
  
  ttk::frame $wrun.runframe
  ttk::separator $wrun.centerseparator -orient horizontal

  grid $wrun.centerseparator \
    -column 0 -row 1 -sticky nsew -pady {20 30} -padx {20 20}
  grid $wrun.runframe \
    -column 0 -row 2 -sticky nsew

  set runlist {}
  set windowpath ".emc.hlf.nb.run.options"
  foreach item $::EMC::gui::runoptions {
    lappend runlist [lsearch -index 0 $::EMC::gui::optionlist "$item"]
  }
  set i 1
  set j 0
  foreach listindex $runlist {
    if {[lindex $::EMC::gui::optionlist $listindex 3] == "boolean"} {
      ttk::label \
	$windowpath.[lindex $::EMC::gui::optionlist $listindex 0]lbl \
	-text "[lindex $::EMC::gui::optionlist $listindex 0]:" \
	-anchor e
      ttk::checkbutton \
	$windowpath.[lindex $::EMC::gui::optionlist $listindex 0]box \
	-text "On/Off" \
        -variable ::EMC::gui::options([lindex $::EMC::gui::optionlist $listindex 0]) -offvalue false -onvalue true
      grid \
	$windowpath.[lindex $::EMC::gui::optionlist $listindex 0]lbl \
	-column [expr {$j + 0}] -row $i -sticky nsew -padx {5 5} -pady {0 5}
      grid \
	$windowpath.[lindex $::EMC::gui::optionlist $listindex 0]box \
	-column [expr {$j + 1}] -row $i -sticky nsew -padx {0 0} -pady {0 5}
      if {$j == 4} {
	incr i 
      }
    } elseif {[lindex $::EMC::gui::optionlist $listindex 3] in {"integer" "real" "string" "list"}} {
      ttk::label $windowpath.[lindex $::EMC::gui::optionlist $listindex 0]lbl \
	-text "[lindex $::EMC::gui::optionlist $listindex 0]:" -anchor e
      ttk::entry $windowpath.[lindex $::EMC::gui::optionlist $listindex 0]box \
	-textvariable ::EMC::gui::options([lindex $::EMC::gui::optionlist $listindex 0])
      grid $windowpath.[lindex $::EMC::gui::optionlist $listindex 0]lbl \
	-column [expr {$j + 0}] -row $i -sticky nsew -padx {5 5} -pady {0 5}
      grid $windowpath.[lindex $::EMC::gui::optionlist $listindex 0]box \
	-column [expr {$j + 1}] -row $i -sticky nsew -padx {0 0} -pady {0 5}
      switch -exact [lindex $::EMC::gui::optionlist $listindex 3] {
	"list" {
	  ttk::label \
	    $windowpath.[lindex $::EMC::gui::optionlist $listindex 0]descriptor \
	      -text "(List Format: arg,arg,arg,\[...\])" -justify left
	  grid \
	    $windowpath.[lindex $::EMC::gui::optionlist $listindex 0]descriptor \
	    -column [expr {$j + 2}] -row $i -padx {5 5} -pady {0 5} -sticky w
	}
	"string" {
	  ttk::label \
	    $windowpath.[lindex $::EMC::gui::optionlist $listindex 0]descriptor \
	    -text "(String)" -justify left
	  grid \
	    $windowpath.[lindex $::EMC::gui::optionlist $listindex 0]descriptor \
	    -column [expr {$j + 2}] -row $i -padx {5 5} -pady {0 5} -sticky w
	}
	"real" {
	  $windowpath.[lindex $::EMC::gui::optionlist $listindex 0]box \
	    configure -validate key -validatecommand {string is double %P}
	  ttk::label \
	    $windowpath.[lindex $::EMC::gui::optionlist $listindex 0]descriptor \
	    -text "(Real)" -justify left
	  grid \
	    $windowpath.[lindex $::EMC::gui::optionlist $listindex 0]descriptor \
	    -column [expr {$j + 2}] -row $i -padx {5 5} -pady {0 5}  -sticky w
	}
	"integer" {
	  $windowpath.[lindex $::EMC::gui::optionlist $listindex 0]box \
	    configure -validate key -validatecommand {string is int %P}
	  ttk::label \
	    $windowpath.[lindex $::EMC::gui::optionlist $listindex 0]descriptor \
	    -text "(Integer)" -justify left
	  grid \
	    $windowpath.[lindex $::EMC::gui::optionlist $listindex 0]descriptor \
	    -column [expr {$j + 2}] -row $i -padx {5 5} -pady {0 5}  -sticky w
	}
      }
      if {$j == 4} {
	incr i 
      }
    } elseif {[ \
	lindex $::EMC::gui::optionlist $listindex 3] == "option" || \
	[string first "," "[lindex $::EMC::gui::optionlist $listindex 7]"] != -1} {
	set valuelist "[ \
	  lindex $::EMC::gui::optionlist $listindex 2] [ \
	  split [lindex $::EMC::gui::optionlist $listindex 7] ","]"
	ttk::label \
	  $windowpath.[lindex $::EMC::gui::optionlist $listindex 0]lbl \
	  -text "[lindex $::EMC::gui::optionlist $listindex 0]:" -anchor e
	ttk::combobox \
	  $windowpath.[lindex $::EMC::gui::optionlist $listindex 0]box \
	  -textvariable ::EMC::gui::options( \
	    [lindex $::EMC::gui::optionlist $listindex 0]) \
	  -state readonly -values $valuelist
	grid \
	  $windowpath.[lindex $::EMC::gui::optionlist $listindex 0]lbl \
	  -column [expr {$j + 0}] -row $i -sticky nsew -padx {5 5} -pady {0 5}
	grid \
	  $windowpath.[lindex $::EMC::gui::optionlist $listindex 0]box \
	  -column [expr {$j + 1}] -row $i -sticky nsew -padx {0 0} -pady {0 5}
      if {$j == 4} {
	incr i 
      }
    } else {
      continue
    }
    if {$j == 0} {
      set j 4
    } elseif {$j == 4} {
      set j 0
    }
    set path "$windowpath.[lindex $::EMC::gui::optionlist $listindex 0]box"
    set help [lindex $::EMC::gui::optionlist $listindex 1] 
    ::EMC::gui::balloon $path $help

  }
  ttk::separator $wrun.options.centerseparator -orient vertical
  grid $wrun.options.centerseparator \
    -column 3 -row 1 -rowspan [ \
      llength [ \
	grid slaves $windowpath -column 1] \
      ] -sticky nsew -padx {30 30} -pady {5 5}
  unset windowpath

  ttk::button $wrun.runframe.checkbutton \
    -text "Check Status" \
    -command {
      ::EMC::gui::GetHostVarFromRoot
      if {$::EMC::gui::options(filename) != ""} {
	::EMC::gui::AppendFileNamePath
      }
      if {[::EMC::gui::CheckAllEntryValidity] != 0} {
	set ::EMC::gui::statusmessage "Status: Error"
      } else {
	set ::EMC::gui::statusmessage "Status: Ready"
      }
    }
  ttk::label $wrun.runframe.writealloptionslbl \
    -text "Write Default Options:"
  ttk::checkbutton $wrun.runframe.writealloptions \
    -text "Yes/No" -offvalue false -onvalue true \
    -variable ::EMC::gui::writealloptions

  ttk::button $wrun.runframe.runbutton \
    -text "Write EMC Script" \
    -command {
      if {[::EMC::gui::CheckAllEntryValidity] != 0} { return }
      ::EMC::gui::RunWriteEmcScript
    }

  ttk::label $wrun.runframe.status \
    -textvariable ::EMC::gui::statusmessage -anchor center -font TkCaptionFont
  
  ttk::button $wrun.runframe.testrunbutton \
    -text "Test Run Build" \
    -command {
      ::EMC::gui::MakeAndCheckTempDirectory
    }
  ttk::button $wrun.runframe.realrun \
    -text "Run Build" \
    -command {
      ::EMC::gui::RunEmcBuild
      ::EMC::gui::PopulateTvItemsStatusRun .emc.hlf.nb.results.tv true
    }

  grid columnconfigure \
    $wrun.runframe {0 1 2} -weight 1
  grid columnconfigure \
    $wrun.runframe 1 -minsize 250
  grid $wrun.runframe.checkbutton \
    -column 0 -row 0 -sticky nsew -padx {20 5} -pady {0 20}
  grid $wrun.runframe.runbutton \
    -column 0 -row 1 -sticky nsew -padx {20 5} -pady {0 20}
  grid $wrun.runframe.testrunbutton \
    -column 2 -row 0 -sticky nsew -padx {5 20} -pady {0 20}
  grid $wrun.runframe.realrun \
    -column 2 -row 1 -sticky nsew -padx {5 20} -pady {0 20}
 
  $wrun.runframe.realrun configure -state disable
  grid $wrun.runframe.status \
    -column 1 -row 0 -sticky nsew -padx {5 5} -pady {0 5} -rowspan 2
  
  ::EMC::gui::createInfoButton $w.hlf.nb.run.options 0 6
  bind $w.hlf.nb.run.options.info <Button-1> {
    set val [::EMC::gui::CheckRunInfo]
    set ::EMC::gui::link [lindex $val 1]
    ::EMC::gui::infoWindow info [lindex $val 0] [lindex $val 2]
  }
}


#==============================================================================
# Results/Summary Tab
#==============================================================================

proc tab_results_summary {} {
  set w $::EMC::gui::w

  ttk::frame $w.hlf.nb.results -width 500 -height 250
  $w.hlf.nb add $w.hlf.nb.results -text "Results/Summary"
  grid columnconfigure $w.hlf.nb.results 0 -weight 1

  set wresults $w.hlf.nb.results
  ttk::label $wresults.lbl \
    -text "Systems:" -font TkHeadingFont
  ttk::treeview $wresults.tv \
    -selectmode browse -yscrollcommand "$wresults.scroll set"
  $wresults.tv configure -column {Name Queue Status Visualization actualpath} -display {Name Queue Status Visualization} -show {headings} -height 5
  $wresults.tv heading Name -text "Name"
  $wresults.tv heading Queue -text "Queue"
  $wresults.tv heading Status -text "Status"
  $wresults.tv heading Visualization -text "Mol ID"
  $wresults.tv column Name -width 250 -stretch 1 -anchor center
  $wresults.tv column Queue -width 200 -stretch 1 -anchor center
  $wresults.tv column Status -width 150 -stretch 1 -anchor center
  $wresults.tv column Visualization -width 150 -stretch 1 -anchor center
  ttk::scrollbar $wresults.scroll -orient vertical -command "$wresults.tv yview"
 
  ttk::button $wresults.updatestatus \
    -text "Update Status" \
    -command { ::EMC::gui::CheckRunStatusClusterBuild .emc.hlf.nb.results.tv }
  ttk::button $wresults.loadvizstate \
    -text "Load Viz State" \
    -command { ::EMC::gui::LoadVisualizationState .emc.hlf.nb.results.tv }
  ttk::button $wresults.removevizstate \
    -text "Remove Viz State" \
    -command { ::EMC::gui::DeleteVisualizationState .emc.hlf.nb.results.tv }
  ttk::button $wresults.clearvizstates \
    -text "Clear All Viz States" \
    -command { ::EMC::gui::ClearAllEmcRepresentations .emc.hlf.nb.results.tv }
  ttk::button $wresults.loadeshfilepaths \
    -text "Load Esh Paths" \
    -command {
      if {[::EMC::gui::GetPathsFromEshFile] == 1} {
	::EMC::gui::PopulateTvItemsStatusRun .emc.hlf.nb.results.tv false
      }
    } 
  ttk::button $wresults.deletefromlist \
    -text "Delete Entry" \
    -command {::EMC::gui::DeleteVizFromTreeview .emc.hlf.nb.results.tv}

  # necessary to allow editing of the entries which already exist in the
  # treeview; variables are otherwise not automatically put into the treeview

  bind $wresults.tv <<TreeviewSelect>> {
    set temppath [.emc.hlf.nb.results.tv item [.emc.hlf.nb.results.tv selection] -values]
    set ::EMC::gui::currentpath [lindex $temppath 4]
    set ::EMC::gui::currentstatus [lindex $temppath 2]
    set ::EMC::gui::currentmolid [lindex $temppath 3]
    set mollist [molinfo list]
    foreach tvitem [.emc.hlf.nb.results.tv children {}] {
      if {[\
	  lsearch $mollist [ \
	    lindex [.emc.hlf.nb.results.tv item $tvitem -values] 3]] == -1 && \
	  $::EMC::gui::currentmolid != -1} {
	set ::EMC::gui::processes($::EMC::gui::currentpath,molid) -1
	set ::EMC::gui::currentmolid -1
	.emc.hlf.nb.results.tv item $tvitem \
	-values [list \
	  $::EMC::gui::processes($::EMC::gui::currentpath,sysinfo) \
	  $::EMC::gui::processes($::EMC::gui::currentpath,queue) \
	  $::EMC::gui::processes($::EMC::gui::currentpath,build) \
	  $::EMC::gui::processes($::EMC::gui::currentpath,molid) \
	  $::EMC::gui::currentpath] 
      }
    }
    foreach tvitem [.emc.hlf.nb.results.tv children {}] {
      if { \
	[lindex [.emc.hlf.nb.results.tv item $tvitem -values] 3] != -1 && \
	[lindex [.emc.hlf.nb.results.tv item $tvitem -values] 4] != $::EMC::gui::currentpath} {
	mol off [lindex [.emc.hlf.nb.results.tv item $tvitem -values] 3]
      } elseif { \
	[lindex [.emc.hlf.nb.results.tv item $tvitem -values] 3] != -1 && \
	[lindex [.emc.hlf.nb.results.tv item $tvitem -values] 4] == $::EMC::gui::currentpath} {
	mol on [lindex [.emc.hlf.nb.results.tv item $tvitem -values] 3]
      }
    }
  }

  grid columnconfigure \
    $wresults 0 -weight 1 -minsize 250
  grid columnconfigure \
    $wresults 1 -weight 1 -minsize 200
  grid columnconfigure \
    $wresults 2 -weight 1 -minsize 150
  grid columnconfigure \
    $wresults 3 -weight 1 -minsize 150

  grid $wresults.lbl \
    -column 0 -row 0 -sticky nsew -padx {0 5} -pady {0 5}
  grid $wresults.tv \
    -column 0 -row 1 -sticky nsew -padx {0 0} -pady {0 5} \
    -columnspan 4 -rowspan 4 
  grid $wresults.scroll \
    -column 4 -row 1 -sticky nsew -padx {0 5} -pady {0 5} \
    -rowspan 4 
  grid $wresults.updatestatus \
    -column 5 -row 1 -sticky nsew -padx {0 5} -pady {0 5}
  grid $wresults.loadvizstate \
    -column 5 -row 2 -sticky nsew -padx {0 5} -pady {0 5}
  grid $wresults.removevizstate \
    -column 5 -row 3 -sticky nsew -padx {0 5} -pady {0 5}
  grid $wresults.clearvizstates \
    -column 5 -row 4 -sticky nsew -padx {0 5} -pady {0 5}
  grid $wresults.loadeshfilepaths \
    -column 5 -row 5 -sticky nsew -padx {0 5} -pady {0 5}
  grid $wresults.deletefromlist \
    -column 5 -row 6 -sticky nsew -padx {0 5} -pady {0 5}
  
  ::EMC::gui::createInfoButton $w.hlf.nb.results 0 5
  bind $w.hlf.nb.results.info <Button-1> {
    set val [::EMC::gui::ResultsSummaryInfo]
    set ::EMC::gui::link [lindex $val 1]
    ::EMC::gui::infoWindow info [lindex $val 0] [lindex $val 2]
  }

  bind .emc.hlf.nb <<NotebookTabChanged>> { ::EMC::gui::ResizeToActiveTab}
  ::EMC::gui::EnableFieldOptions .emc.hlf.nb.ffsettings general
}


#==============================================================================
# Small molecule build window is opened when this proc is called
#==============================================================================

proc ::EMC::gui::emc_add_sm {} \
{
  variable wsm

  if { [winfo exists .emcsm] } {
    wm deiconify .emcsm
    return
  }
  set wsm [toplevel .emcsm]
  wm title $wsm "EMC: Add Single Molecule"
  grid columnconfigure $wsm 0 -weight 1
  grid rowconfigure $wsm 0 -weight 1

  wm geometry $wsm [expr {585 + $::EMC::gui::window_xdelta}]x250
  wm resizable $wsm 0 0

  ttk::frame $wsm.hlf

  grid $wsm.hlf -column 0 -row 0 -sticky nsew
  grid columnconfigure $wsm.hlf 0 -weight 1
  grid rowconfigure $wsm.hlf 0 -weight 1


  ttk::label $wsm.hlf.editentry \
    -text "Edit Entry:" -anchor sw
  ttk::label $wsm.hlf.tvtitle \
    -text "List of Available Groups:" -font TkHeadingFont -anchor w
  ttk::entry $wsm.hlf.molname \
    -textvariable ::EMC::gui::smmolname -width 20
  ttk::entry $wsm.hlf.smilesdef \
    -textvariable ::EMC::gui::smsmiles -width 20
  ttk::button $wsm.hlf.addtomainwindow \
    -text "Add Molecule to System" \
    -command {
      if {[string length $::EMC::gui::smmolname] == 0 || \
	  [string length $::EMC::gui::smsmiles] == 0 } { return }
      if {[string first \* $::EMC::gui::smsmiles] != -1} {
	tk_messageBox -type ok -icon error \
	  -title "SMILES Warning" -parent .emcsm \
	  -message "Connector (*) was found in SMILES String. Monomers for polymers may only be defined in the Polymer Builder"
	return
      }
      foreach tvitem [.emc.hlf.nb.chemistry.definechemistry.tv children {}] {
	if {[lindex [ \
	    .emc.hlf.nb.chemistry.definechemistry.tv item $tvitem -values] 0 \
	  ] == $::EMC::gui::smmolname} {
	  tk_messageBox -type ok -icon error \
	    -title "Warning Duplicate" -parent .emcsm \
	    -message "The groupname: $::EMC::gui::smmolname exists already. Duplicates are not allowed!"
	  return
	} elseif {[lindex [ \
	    .emc.hlf.nb.chemistry.definechemistry.tv item $tvitem -values] 2 \
	  ] == $::EMC::gui::smmolname} {
	  tk_messageBox -type ok -icon error \
	    -title "Warning Duplicate" -parent .emcsm\
	    -message "The  SMILES string: $::EMC::gui::smsmiles  already exists"
	  return
	}
      }
 
      .emc.hlf.nb.chemistry.definechemistry.tv insert {} end -values [ \
	list $::EMC::gui::smmolname small_molecule $::EMC::gui::smsmiles 1 1]
      lappend ::EMC::gui::tvdefchemistrylist \
	"$::EMC::gui::smmolname small_molecule $::EMC::gui::smsmiles 1 1"
  
      if {[lsearch -index 0 \
	    $::EMC::gui::smgrouplist "$::EMC::gui::smmolname"] == -1 && 
	  [lsearch -index 1 \
	    $::EMC::gui::smgrouplist "$::EMC::gui::smsmiles"]  == -1 } {
	lappend ::EMC::gui::smgrouplist [ \
	  list $::EMC::gui::smmolname $::EMC::gui::smsmiles]
      	.emcsm.hlf.tv insert {} end -values [ \
	  list $::EMC::gui::smmolname $::EMC::gui::smsmiles]
      }
      set ::EMC::gui::smsmiles ""
      set ::EMC::gui::smmolname ""
    }

  ttk::button $wsm.hlf.importfile -text "Import File" \
      -command {::EMC::gui::ImportFile small_molecule .emcsm}

  ttk::button $wsm.hlf.savetofile -text "Save File" \
    -command {
	::EMC::gui::SaveGrouptable .emcsm.hlf.tv
    }
 
  ttk::button $wsm.hlf.addtolist  \
    -text "Add Entry" \
    -command {
      if {[string length $::EMC::gui::smmolname] == 0 || \
	  [string length $::EMC::gui::smsmiles] == 0 } { return }
      if {[string first \* $::EMC::gui::smsmiles] != -1} {
	tk_messageBox -type ok -icon error \
	  -title "SMILES Warning" -parent .emcsm \
	  -message "Connector (*) was found in SMILES String. Monomers for polymers may only be defined in the Polymer Builder"
	return
      }
      if {[string first "-" $::EMC::gui::smmolname] != -1} {
	tk_messageBox -type ok -icon error \
	  -title "Name Warning" -parent .emcsm \
	  -message "Dash(-) is not allowed in group names!"
	return
      }
      foreach tvitem [.emcsm.hlf.tv children {}] {
	if {[lindex [.emcsm.hlf.tv item $tvitem -values] 0] == 
	    $::EMC::gui::smmolname} {
	  set answer [ \
	    tk_messageBox \
	      -message "Are you sure you want to a duplicate name entry?" \
	      -icon question -type yesno -parent .emcsm]
	  switch -- $answer {
	    yes {continue}
	    no {return}
	  }
	} elseif {[lindex [.emcsm.hlf.tv item $tvitem -values] 1] == \
		  $::EMC::gui::smsmiles} {
	  set answer [ \
	    tk_messageBox \
	      -message "Are you sure you want to a duplicate SMILES entry?" \
	      -icon question -type yesno -parent .emcsm]
	  switch -- $answer {
	    yes {continue}
	    no {return}
	  }
	}
      }
      .emcsm.hlf.tv insert {} end -values [ \
	list $::EMC::gui::smmolname $::EMC::gui::smsmiles]
      lappend ::EMC::gui::smgrouplist \
	"$::EMC::gui::smmolname $::EMC::gui::smsmiles"
      set ::EMC::gui::smmolname ""
      set ::EMC::gui::smsmiles ""
    } 

  ttk::button $wsm.hlf.applychanges  \
    -text "Edit Entry" \
    -command {
      if {[string length $::EMC::gui::smmolname] == 0 || \
	  [string length $::EMC::gui::smsmiles] == 0 } { return }
      if {[string first \* $::EMC::gui::smsmiles] != -1} {
	tk_messageBox -type ok -icon error \
	  -title "SMILES Warning" -parent .emcsm \
	  -message "Connector (*) was found in SMILES String. Monomers for polymers may only be defined in the Polymer Builder"
	return
      }
      foreach tvitem [.emcsm.hlf.tv children {}] {
	if {$tvitem == [.emcsm.hlf.tv selection]} { continue }
	if {[lindex [.emcsm.hlf.tv item $tvitem -values] 0] == \
	    $::EMC::gui::smmolname} {
	  set answer [ \
	    tk_messageBox \
	      -message "Are you sure you want to add this duplicate Name entry?" \
	      -icon question -type yesno -parent .emcsm]
	  switch -- $answer {
	    yes {continue}
	    no {return}
	  }
	} elseif {[lindex [.emcsm.hlf.tv item $tvitem -values] 1] == \
		  $::EMC::gui::smsmiles} {
	  set answer [ \
	    tk_messageBox \
	      -message "Are you sure you want add this duplicate SMILES entry?" \
	      -icon question -type yesno -parent .emcsm]
	  switch -- $answer {
	    yes {continue}
	    no {return}
	  }
	}
      }
      set ::EMC::gui::smgrouplist [ \
	lreplace $::EMC::gui::smgrouplist [ \
	  lsearch -index 0 $::EMC::gui::smgrouplist [ \
	    lindex [.emcsm.hlf.tv item [.emcsm.hlf.tv selection] -values] 0]] [ \
	  lsearch -index 0 $::EMC::gui::smgrouplist [ \
	    lindex [.emcsm.hlf.tv item [.emcsm.hlf.tv selection] -values] 0]]]
      .emcsm.hlf.tv item [ \
	.emcsm.hlf.tv selection] -values [ \
	  list $::EMC::gui::smmolname $::EMC::gui::smsmiles]
      lappend ::EMC::gui::smgrouplist \
	"$::EMC::gui::smmolname $::EMC::gui::smsmiles"
      set ::EMC::gui::smmolname ""
      set ::EMC::gui::smsmiles ""
    } 
  
  ttk::button $wsm.hlf.deleteentry  -text "Delete Entry" \
    -command {
      .emcsm.hlf.tv delete [.emcsm.hlf.tv selection]
      set ::EMC::gui::smgrouplist [ \
	lreplace $::EMC::gui::smgrouplist [ \
	  lsearch -index 0 $::EMC::gui::smgrouplist [ \
	    lindex [.emcsm.hlf.tv item [.emcsm.hlf.tv selection] -values] 0]] [ \
	  lsearch -index 0 $::EMC::gui::smgrouplist [ \
	    lindex [.emcsm.hlf.tv item [.emcsm.hlf.tv selection] -values] 0]]]
    } 

  ttk::button $wsm.hlf.clearall -text "Clear All" \
    -command {
      set answer [ \
	tk_messageBox \
	  -message "Are you sure you want to delete all entries?" \
	  -icon question -type yesno -parent .emcsm]
      switch -- $answer {
	yes { 
	  .emcsm.hlf.tv delete [.emcsm.hlf.tv children {}]
	  set ::EMC::gui::smgrouplist {}  
	}
	no { return }
      }
    }

  ttk::separator $wsm.hlf.sep1 -orient horizontal

  ttk::button $wsm.hlf.moveup -text "Move Up $::EMC::gui::up_arrow" \
    -command {
      set currentID [.emcsm.hlf.tv selection]
      if {[set previousID [.emcsm.hlf.tv prev $currentID]] ne ""} {
	set previousIndex [.emcsm.hlf.tv index $previousID]
	.emcsm.hlf.tv move $currentID {} $previousIndex
	unset previousIndex
      }
      unset currentID previousID
   } 

  ttk::button $wsm.hlf.movedown -text "Move Down $::EMC::gui::down_arrow" \
    -command {
      set currentID [.emcsm.hlf.tv selection]
      if {[set previousID [.emcsm.hlf.tv next $currentID]] ne ""} {
	set previousIndex [.emcsm.hlf.tv index $previousID]
	.emcsm.hlf.tv move $currentID {} $previousIndex
	unset previousIndex
      }
      unset currentID previousID
    } 

  ttk::treeview $wsm.hlf.tv \
    -selectmode browse -yscrollcommand "$wsm.hlf.scroll set"
  $wsm.hlf.tv configure \
    -column {Name SMILES} -display {Name SMILES} -show {headings} -height 5
  $wsm.hlf.tv heading Name \
    -text "Name"
  $wsm.hlf.tv heading SMILES \
    -text "SMILES"
  $wsm.hlf.tv column Name \
    -width 150 -stretch 0 -anchor center
  $wsm.hlf.tv column SMILES \
    -width 200 -stretch 0 -anchor center
  ttk::scrollbar $wsm.hlf.scroll \
    -orient vertical -command "$wsm.hlf.tv yview"
  
  # necessary to allow editing of the entries which already exist in the
  # treeview; variables are otherwise not automatically put into the treeview

  bind $wsm.hlf.tv <<TreeviewSelect>> {
    set tempsm [.emcsm.hlf.tv item [.emcsm.hlf.tv selection] -values]
    set ::EMC::gui::smmolname [lindex $tempsm 0]
    set ::EMC::gui::smsmiles [lindex $tempsm 1]
  }

  ::EMC::gui::createInfoButton $wsm.hlf 0 4
  bind $wsm.hlf.info <Button-1> {
    set val [::EMC::gui::SmallMoleculeInfo]
    set ::EMC::gui::link [lindex $val 1]
    ::EMC::gui::infoWindow info [lindex $val 0] [lindex $val 2]
  }

  grid $wsm.hlf.tvtitle \
    -column 0 -row 0 -padx {5 0} -pady {5 5} -sticky nsew
  grid $wsm.hlf.tv \
    -column 0 -row 1 -padx {5 0} -pady 0 -sticky nsew -columnspan 2 -rowspan 3
  grid $wsm.hlf.scroll \
    -column 2 -row 1 -padx {0 5} -pady 0 -sticky nsew -rowspan 3
# grid $wsm.hlf.sep1 \
#   -column 2 -row 1 -padx 0 -pady 0 -sticky nsew
  grid $wsm.hlf.editentry \
    -column 0 -row 4 -padx {5 0} -pady {5 0} -sticky nsew
  grid $wsm.hlf.molname \
    -column 0 -row 5 -padx {5 0} -pady 0 -sticky nsew

  grid columnconfigure $wsm.hlf 0 -minsize 150 -weight 0
  grid columnconfigure $wsm.hlf 1 -minsize 200 -weight 0
 
  grid $wsm.hlf.smilesdef \
    -column 1 -row 5 -padx 0 -pady 0 -sticky nsew 
  grid $wsm.hlf.importfile \
    -column 3 -row 1 -padx {0 5} -pady {0 5} -sticky nsew
  grid $wsm.hlf.savetofile \
    -column 4 -row 1 -padx {0 5} -pady {0 5} -sticky nsew
  grid $wsm.hlf.addtolist \
    -column 3 -row 5 -padx {0 5} -pady 0 -sticky nsew
  grid $wsm.hlf.applychanges \
    -column 4 -row 5 -padx {0 5} -pady 0 -sticky nsew
  grid $wsm.hlf.deleteentry \
    -column 3 -row 2 -padx {0 5} -pady {0 5} -sticky nsew
  grid $wsm.hlf.clearall \
    -column 4 -row 2 -padx {0 5} -pady {0 5} -sticky nsew
  grid $wsm.hlf.moveup \
    -column 3 -row 3 -padx {0 5} -pady {0 5} -sticky nsew
  grid $wsm.hlf.movedown \
    -column 4 -row 3 -padx {0 5} -pady {0 5} -sticky nsew
  grid $wsm.hlf.sep1 \
    -column 3 -row 4 -padx {10 10} -pady {0 0} -sticky ew -columnspan 2 
  grid $wsm.hlf.addtomainwindow \
    -column 0 -row 6 -padx {5 0} -pady {5 5} -sticky nsew -columnspan 2
 
  if {[llength $::EMC::gui::smgrouplist] != 0} {
      foreach item $::EMC::gui::smgrouplist {
	.emcsm.hlf.tv insert {} end -values [ \
	  list [lindex $item 0] [lindex $item 1]]
      }
  }
  set ::EMC::gui::smmolname ""
  set ::EMC::gui::smsmiles ""
}


#==============================================================================
#
#==============================================================================

proc ::EMC::gui::emc_add_trial {} \
{
  variable wtrial

  if { [winfo exists .emctrial] } {
    wm deiconify .emctrial
    return
  }
  set wtrial [toplevel .emctrial]
  wm title $wtrial "EMC: Add Trial"
  grid columnconfigure $wtrial 0 -weight 1
  grid rowconfigure $wtrial 0 -weight 1

  wm geometry $wtrial 585x290
  wm resizable $wtrial 0 0

  ttk::frame $wtrial.hlf

  grid $wtrial.hlf -column 0 -row 0 -sticky nsew
  grid columnconfigure $wtrial.hlf 0 -weight 1
  grid rowconfigure $wtrial.hlf 0 -weight 1


  ttk::label $wtrial.hlf.editentry \
    -text "Edit Entry:" -anchor sw
  ttk::label $wtrial.hlf.tvtitle \
    -text "List of Available Groups:" -font TkHeadingFont -anchor w
  ttk::entry $wtrial.hlf.molname \
    -textvariable ::EMC::gui::trials(molname) -width 20
  ttk::entry $wtrial.hlf.smilesdef \
    -textvariable ::EMC::gui::trials(smiles) -width 20
  ttk::button $wtrial.hlf.addtomainwindow \
    -text "Add Trial To List" \
    -command {
      if {[string length $::EMC::gui::trials(molname)] == 0 || \
	  [string length $::EMC::gui::trials(smiles)] == 0 } { return }
      if {[string first \* $::EMC::gui::trials(smiles)] != -1} {
	tk_messageBox -type ok -icon error \
	  -title "SMILES Warning" -parent .emctrial \
	  -message "Connector (*) was found in SMILES String. Monomers for polymers may only be defined in the Polymer Builder"
	return
      }
      foreach tvitem [.emc.hlf.nb.chemistry.trials.tv children {}] {
	if {[lindex [ \
	      .emc.hlf.nb.chemistry.trials.tv item $tvitem -values] 0] == \
	    $::EMC::gui::trials(molname)} {
	  tk_messageBox -type ok -icon error \
	    -title "Warning Duplicate" -parent .emctrial \
	    -message "The groupname: $::EMC::gui::trials(molname) exists already. Duplicates are not allowed!"
	  return
	} elseif {[lindex [ \
	      .emc.hlf.nb.chemistry.trials.tv item $tvitem -values] 1] == \
	    $::EMC::gui::trials(smiles)} {
	  tk_messageBox -type ok -icon error \
	    -title "Warning Duplicate" -parent .emctrial\
	    -message "The  SMILES string: $::EMC::gui::trials(smiles) already exists"
	  return
	} elseif {[lindex [ \
	      .emc.hlf.nb.chemistry.trials.tv item $tvitem -values] 2] == \
	    $::EMC::gui::trials(name)} {
	  tk_messageBox -type ok -icon error \
	    -title "Warning Duplicate" -parent .emctrial\
	    -message "The Trial Name: $::EMC::gui::trials(name) already exists!\nDuplicates not allowed"
	  return
	}
      }

      .emc.hlf.nb.chemistry.trials.tv insert {} end -values [ \
	list \
	  $::EMC::gui::trials(molname) \
	  $::EMC::gui::trials(smiles) \
	  $::EMC::gui::trials(name)]
      lappend ::EMC::gui::triallist \
	"$::EMC::gui::trials(molname) $::EMC::gui::trials(smiles) $::EMC::gui::trials(name)"
      set ::EMC::gui::trials($::EMC::gui::trials(name),molname) \
	"$::EMC::gui::trials(molname)"

      if {[lsearch -index 0 $::EMC::gui::smgrouplist \
	    "$::EMC::gui::trials(molname)"] == -1 && \
	  [lsearch -index 1 $::EMC::gui::smgrouplist \
	    "$::EMC::gui::trials(smiles)"]  == -1 } {
	lappend ::EMC::gui::smgrouplist \
	  "$::EMC::gui::trials(molname) $::EMC::gui::trials(smiles)"
      	if {[winfo exists .emcsm]} {
	  .emcsm.hlf.tv insert {} end -values [ \
	    list \
	      $::EMC::gui::trials(molname) \
	      $::EMC::gui::trials(smiles)]
	}
	.emctrial.hlf.tv insert {} end -values [ \
	  list \
	    $::EMC::gui::trials(molname) \
	    $::EMC::gui::trials(smiles)]
      }
    }

  ttk::button $wtrial.hlf.importfile -text "Import File" \
    -command {
      set types {
	{{ESH Files} {.esh}}
	{{Text Files} {.txt}} 
	{{All Files} *}
      }
      set tempfile [tk_getOpenFile \
	-title "Import Group File" -filetypes $types -parent .emctrial ]
      if {$tempfile ne ""} {
      set garbagelist {}
      if {[string first ".esh" $tempfile] != -1} {
	set templist [::EMC::gui::ReadEshGroups $tempfile]
	foreach item $templist {
	    lappend ::EMC::gui::smgrouplist $item
	}
      } else {
	set templist [::EMC::gui::ReadTabular $tempfile]
	foreach item $templist {
	    lappend ::EMC::gui::smgrouplist $item
	}
      }
      foreach item $::EMC::gui::smgrouplist {
	if {[llength [split [lindex $item 1] "*"]] > 1} {
	  lappend garbagelist "[lindex $item 0] [lindex $item 1]\n"
	  set ::EMC::gui::smgrouplist [ \
	    lreplace $::EMC::gui::smgrouplist [ \
	      lsearch -index 0 $::EMC::gui::smgrouplist [ \
		lindex $item 0]] [ \
	      lsearch -index 0 $::EMC::gui::smgrouplist [ \
		lindex $item 0]]]
	} elseif {[llength $item] == 1} {
	  lappend garbagelist "[lindex $item 0] [lindex $item 1]\n"
	  set ::EMC::gui::smgrouplist [ \
	    lreplace $::EMC::gui::smgrouplist [ \
	      lsearch -index 0 $::EMC::gui::smgrouplist [ \
		lindex $item 0]] [ \
	      lsearch -index 0 $::EMC::gui::smgrouplist [ \
		lindex $item 0]]]
	} else {
	  .emctrial.hlf.tv insert {} end \
	    -values [list "[lindex $item 0]" "[lindex $item 1]"]
	}
      }
      if {[llength $garbagelist] > 1} {
	tk_messageBox -type ok -icon error \
	  -title "Import Warning" -parent .emctrial \
	  -message "The following Groups were not imported:\n$garbagelist"
      }
      unset garbagelist
      } else {
	return
      }
    }

  ttk::button $wtrial.hlf.savetofile -text "Save File" \
    -command { ::EMC::gui::SaveGrouptable .emctrial.hlf.tv }
 
  ttk::button $wtrial.hlf.addtolist \
    -text "Add Entry" \
    -command {
      if {[string length $::EMC::gui::trials(molname)] == 0 || \
	  [string length $::EMC::gui::trials(smiles)] == 0 } { return }
      if {[string first \* $::EMC::gui::trials(smiles)] != -1} {
	tk_messageBox -type ok -icon error \
	  -title "SMILES Warning" -parent .emctrial \
	  -message "Connector (*) was found in SMILES String. Monomers for polymers may only be defined in the Polymer Builder"
	return
      }
      if {[string first "-" $::EMC::gui::trials(molname)] != -1} {
	tk_messageBox -type ok -icon error \
	  -title "Name Warning" -parent .emctrial \
	  -message "Dash(-) is not allowed in group names!"
	return
      }
      foreach tvitem [.emctrial.hlf.tv children {}] {
	if {[lindex [.emctrial.hlf.tv item $tvitem -values] 0] == \
	    $::EMC::gui::trials(molname)} {
	  set answer [ \
	    tk_messageBox \
	      -message "Are you sure you want to a duplicate name entry?" \
	      -icon question -type yesno -parent .emctrial]
	  switch -- $answer {
	    yes { continue }
	    no { return }
	  }
	} elseif {[lindex [.emctrial.hlf.tv item $tvitem -values] 1] == \
		  $::EMC::gui::trials(smiles)} {
	  set answer [ \
	    tk_messageBox \
	      -message "Are you sure you want to a duplicate SMILES entry?" \
	      -icon question -type yesno -parent .emctrial]
	  switch -- $answer {
	    yes { continue }
	    no { return }
	  }
	}
      }
      .emctrial.hlf.tv insert {} end \
	-values [ \
	  list \
	    $::EMC::gui::trials(molname) \
	    $::EMC::gui::trials(smiles)]
      lappend ::EMC::gui::smgrouplist \
	"$::EMC::gui::trials(molname) $::EMC::gui::trials(smiles)"
    } 

  ttk::button $wtrial.hlf.applychanges \
    -text "Edit Entry" \
    -command {
      if {[string length $::EMC::gui::trials(molname)] == 0 || \
	[string length $::EMC::gui::trials(smiles)] == 0 } { return }
      if {[string first \* $::EMC::gui::trials(smiles)] != -1} {
	tk_messageBox -type ok -icon error \
	  -title "SMILES Warning" -parent .emctrial \
	  -message "Connector (*) was found in SMILES String. Monomers for polymers may only be defined in the Polymer Builder"
	return
      }
      foreach tvitem [.emctrial.hlf.tv children {}] {
	if {[lindex [.emctrial.hlf.tv item $tvitem -values] 0] == \
	    $::EMC::gui::trials(smiles)} {
	  set answer [ \
	    tk_messageBox \
	      -message "Are you sure you want to add this duplicate Name entry?" \
	      -icon question -type yesno -parent .emctrial]
	  switch -- $answer {
	    yes { continue }
	    no { return }
	  }
	} elseif {[lindex [.emctrial.hlf.tv item $tvitem -values] 1] == \
		  $::EMC::gui::trials(smiles)} {
	  set answer [ \
	    tk_messageBox \
	      -message "Are you sure you want add this duplicate SMILES entry?" \
	      -icon question -type yesno -parent .emctrial]
	  switch -- $answer {
	    yes { continue }
	    no { return }
	  }
	}
      }
      .emctrial.hlf.tv item [.emctrial.hlf.tv selection] \
	-values [ \
	  list \
	    $::EMC::gui::trials(molname) \
	    $::EMC::gui::trials(smiles)]
      set ::EMC::gui::smgrouplist [ \
	lreplace $::EMC::gui::smgrouplist [ \
	  lsearch -index 0 $::EMC::gui::smgrouplist [lindex $item 0]] [ \
	  lsearch -index 0 $::EMC::gui::smgrouplist [lindex $item 0]]]
      lappend ::EMC::gui::smgrouplist \
	"$::EMC::gui::trials(molname) $::EMC::gui::trials(smiles)"
    } 
  
  ttk::button $wtrial.hlf.deleteentry  -text "Delete Entry" \
    -command {
      .emctrial.hlf.tv delete [.emctrial.hlf.tv selection]
      set ::EMC::gui::smgrouplist [ \
	lreplace $::EMC::gui::smgrouplist [ \
	  lsearch -index 0 $::EMC::gui::smgrouplist [ \
	    lindex [.emcsm.hlf.tv item [.emcsm.hlf.tv selection] -values] 0]] [ \
	  lsearch -index 0 $::EMC::gui::smgrouplist [ \
	    lindex [.emcsm.hlf.tv item [.emcsm.hlf.tv selection] -values] 0]]]
     } 

  ttk::button $wtrial.hlf.clearall -text "Clear All" \
    -command {
      set answer [ \
	tk_messageBox \
	  -message "Are you sure you want to delete all entries?" \
	  -icon question -type yesno -parent .emctrial]
      switch -- $answer {
	yes {
	  .emctrial.hlf.tv delete [.emctrial.hlf.tv children {}]
	  set ::EMC::gui::smgrouplist {} 
	}
	no { return }
      }
    }

  ttk::separator $wtrial.hlf.sep1 -orient horizontal

  ttk::button $wtrial.hlf.moveup -text "Move Up $::EMC::gui::up_arrow" \
    -command {
      set currentID [.emctrial.hlf.tv selection]
      if {[set previousID [.emctrial.hlf.tv prev $currentID]] ne ""} {
	set previousIndex [.emctrial.hlf.tv index $previousID]
	.emctrial.hlf.tv move $currentID {} $previousIndex
	unset previousIndex
      }
      unset currentID previousID
    } 

  ttk::button $wtrial.hlf.movedown -text "Move Down $::EMC::gui::down_arrow" \
    -command {
      set currentID [.emctrial.hlf.tv selection]
      if {[set previousID [.emctrial.hlf.tv next $currentID]] ne ""} {
	set previousIndex [.emctrial.hlf.tv index $previousID]
	.emctrial.hlf.tv move $currentID {} $previousIndex
	unset previousIndex
      }
      unset currentID previousID
   } 

  ttk::label $wtrial.hlf.triallbl -text "Trial Name:" -anchor sw
  ttk::entry $wtrial.hlf.trialentry -textvariable ::EMC::gui::trials(name)


  ttk::treeview $wtrial.hlf.tv \
    -selectmode browse -yscrollcommand "$wtrial.hlf.scroll set"
  $wtrial.hlf.tv configure \
    -column {Name SMILES} -display {Name SMILES} -show {headings} -height 5
  $wtrial.hlf.tv heading Name \
    -text "Name"
  $wtrial.hlf.tv heading SMILES \
    -text "SMILES"
  $wtrial.hlf.tv column Name \
    -width 150 -stretch 0 -anchor center
  $wtrial.hlf.tv column SMILES \
    -width 200 -stretch 0 -anchor center
  ttk::scrollbar $wtrial.hlf.scroll \
    -orient vertical -command "$wtrial.hlf.tv yview"
  
  bind $wtrial.hlf.tv <<TreeviewSelect>> {
    set tempsm [.emctrial.hlf.tv item [.emctrial.hlf.tv selection] -values]
    set ::EMC::gui::trials(molname) [lindex $tempsm 0]
    set ::EMC::gui::trials(smiles) [lindex $tempsm 1]
  }

  ::EMC::gui::createInfoButton $wtrial.hlf 0 4
  bind $wtrial.hlf.info <Button-1> {
    set val [::EMC::gui::selectInfo]
    set ::EMC::gui::link [lindex $val 1]
    ::EMC::gui::infoWindow info [lindex $val 0] [lindex $val 2]
  }

  grid $wtrial.hlf.tvtitle \
    -column 0 -row 0 -padx {5 0} -pady {5 5} -sticky nsew
  grid $wtrial.hlf.tv \
    -column 0 -row 1 -padx {5 0} -pady 0 -sticky nsew -columnspan 2  -rowspan 3
  grid $wtrial.hlf.scroll \
    -column 2 -row 1 -padx {0 5} -pady 0 -sticky nsew -rowspan 3
  grid $wtrial.hlf.editentry \
    -column 0 -row 4 -padx {5 0} -pady {5 0} -sticky nsew
  grid $wtrial.hlf.molname \
    -column 0 -row 5 -padx {5 0} -pady 0 -sticky nsew

  grid columnconfigure $wtrial.hlf 0 -minsize 150 -weight 0
  grid columnconfigure $wtrial.hlf 1 -minsize 200 -weight 0

  grid $wtrial.hlf.smilesdef \
    -column 1 -row 5 -padx 0 -pady 0 -sticky nsew
  
  grid $wtrial.hlf.importfile \
    -column 3 -row 1 -padx {0 5} -pady {0 5} -sticky nsew
  grid $wtrial.hlf.savetofile \
    -column 4 -row 1 -padx {0 5} -pady {0 5} -sticky nsew
  grid $wtrial.hlf.addtolist \
    -column 3 -row 5 -padx {0 5} -pady 0 -sticky nsew
  grid $wtrial.hlf.applychanges \
    -column 4 -row 5 -padx {0 5} -pady 0 -sticky nsew
  grid $wtrial.hlf.deleteentry \
    -column 3 -row 2 -padx {0 5} -pady {0 5} -sticky nsew
  grid $wtrial.hlf.clearall \
    -column 4 -row 2 -padx {0 5} -pady {0 5} -sticky nsew
  grid $wtrial.hlf.moveup \
    -column 3 -row 3 -padx {0 5} -pady {0 5} -sticky nsew
  grid $wtrial.hlf.movedown \
    -column 4 -row 3 -padx {0 5} -pady {0 5} -sticky nsew
  grid $wtrial.hlf.sep1 \
    -column 3 -row 4 -padx {10 10} -pady {0 0} -sticky ew -columnspan 2 
  grid $wtrial.hlf.triallbl \
    -column 0 -row 6 -padx {5 0} -pady {0 5} -sticky nsew
  grid $wtrial.hlf.trialentry \
    -column 0 -row 7 -padx {5 0} -pady {0 5} -sticky nsew  -columnspan 2
  grid  $wtrial.hlf.addtomainwindow \
    -column 3 -row 7 -padx {0 5} -pady {0 5} -sticky nsew -columnspan 2
 
  if {[llength $::EMC::gui::smgrouplist] != 0} {
    foreach item $::EMC::gui::smgrouplist {
      .emctrial.hlf.tv insert {} end -values [ \
	list [lindex $item 0] [lindex $item 1]]
    }
  }
}


#==============================================================================
# Opens the polymer window when this proc is called
#==============================================================================

proc ::EMC::gui::emc_add_poly {} \
{
  variable wpoly

  if { [winfo exists .emcpoly] } {
    wm deiconify .emcpoly
    return
  }
  set wpoly [toplevel .emcpoly]
  wm title $wpoly "EMC: Add Polymers"
  grid columnconfigure $wpoly 0 -weight 1
  grid rowconfigure $wpoly 0 -weight 1

  wm geometry $wpoly [expr {615 + $::EMC::gui::window_xdelta}]x520
  
  ttk::frame $wpoly.hlf

  grid $wpoly.hlf -column 0 -row 0 -sticky nsew
  grid columnconfigure $wpoly.hlf 0 -weight 1
  grid rowconfigure $wpoly.hlf 0 -weight 1
  
  # builds the frame and treeview for the monomer groups
  
  ttk::frame $wpoly.hlf.groups 
  set grps $wpoly.hlf.groups 
  
  ttk::label $grps.lbl1 \
    -text "List of Available Monomers:" -font TkHeadingFont -anchor w
  ttk::label $grps.lbl2 \
    -text "Edit Entry:" -anchor nw
  ttk::treeview $grps.tv \
    -selectmode browse -yscrollcommand "$grps.scroll set"
  
  $grps.tv configure \
    -column {Name SMILES} -display {Name SMILES} -show {headings} -height 5
  $grps.tv heading Name \
    -text "Monomer Name"
  $grps.tv heading SMILES \
    -text "SMILES"
  $grps.tv column Name \
    -width 150 -stretch 1 -anchor center
  $grps.tv column SMILES \
    -width 200 -stretch 1 -anchor center
  ttk::scrollbar $grps.scroll \
    -orient vertical -command "$grps.tv yview"
  
  ttk::entry $grps.molname -textvariable ::EMC::gui::grpname
  ttk::entry $grps.smilesdef -textvariable ::EMC::gui::grpsmiles

  ttk::button $grps.addtolist \
    -text "Add Entry" \
    -command {
      if {[string length $::EMC::gui::grpname] == 0 || \
	  [string length $::EMC::gui::grpsmiles] == 0 } { return }
      if {[string first \* $::EMC::gui::grpsmiles] == -1} {
	tk_messageBox -type ok -icon error \
	  -title "SMILES Warning" -parent .emcpoly \
	  -message "No Connector (*) was found in SMILES String. Groups may only be defined in the Small Molecule Editor"
	return
      }
      if {[string first "**" $::EMC::gui::grpname] == 0} {
	tk_messageBox -type ok -icon error \
	  -title "Name Warning" -parent .emcpoly \
	  -message "(**) is not allowed at the beginning of a group definition!"
	return
      }
      if {[string first "-" $::EMC::gui::grpname] != -1} {
	tk_messageBox -type ok -icon error \
	  -title "Name Warning" -parent .emcpoly \
	  -message "Dash(-) is not allowed in group names!"
	return
      }
      foreach tvitem [.emcpoly.hlf.groups.tv children {}] {
	if {[lindex [.emcpoly.hlf.groups.tv item $tvitem -values] 0] == \
	    $::EMC::gui::grpname} {
	  set answer [ \
	    tk_messageBox \
	      -message "Are you sure you want to a duplicate name entry?" \
	      -icon question -type yesno -parent .emcpoly]
	  switch -- $answer {
	    yes { continue }
	    no { return }
	  }
	} elseif {[lindex [ \
	      .emcpoly.hlf.groups.tv item $tvitem -values] 1] == 
	    $::EMC::gui::grpsmiles} {
	  set answer [ \
	    tk_messageBox \
	      -message "Are you sure you want to a duplicate SMILES entry?" \
	      -icon question -type yesno -parent .emcpoly]
	  switch -- $answer {
	    yes { continue }
	    no { return }
	  }
	}
      }
      .emcpoly.hlf.groups.tv insert {} end -values [ \
	list \
	  $::EMC::gui::grpname \
	  $::EMC::gui::grpsmiles]
      lappend ::EMC::gui::polgrouplist \
	"$::EMC::gui::grpname $::EMC::gui::grpsmiles"
      set ::EMC::gui::grpname ""
      set ::EMC::gui::grpsmiles ""
   } 

  ttk::button $grps.editentry \
    -text "Edit Monomer" \
    -command {
      if {[string length $::EMC::gui::grpname] == 0 || \
	  [string length $::EMC::gui::grpsmiles] == 0 } { return }
      if {[string first \* $::EMC::gui::grpsmiles] == -1} {
	tk_messageBox -type ok -icon error \
	  -title "SMILES Warning" -parent .emcpoly\
	  -message " No Connector (*) was found in SMILES String.Groups may only be defined in the Small Molecule Editor"
	return
      }
      foreach tvitem [.emcpoly.hlf.groups.tv children {}] {
	if {$tvitem == [.emcpoly.hlf.groups.tv selection]} { continue }
	if {[lindex [ \
	      .emcpoly.hlf.groups.tv item $tvitem -values] 0] == \
	    $::EMC::gui::grpname &&
	    [lindex [ \
	      .emcpoly.hlf.groups.tv item $tvitem -values] 1] == \
	    $::EMC::gui::grpsmiles} {
	  return
	}
	if {[lindex [\
	      .emcpoly.hlf.groups.tv item $tvitem -values] 0] == \
	    $::EMC::gui::grpname} {
	  set answer [ \
	    tk_messageBox \
	      -message "Are you sure you want to add this duplicate Name entry?" \
	      -icon question -type yesno -parent .emcpoly]
	  switch -- $answer {
	    yes { continue }
	    no { return }
	  }
	} elseif {[lindex [ \
	      .emcpoly.hlf.groups.tv item $tvitem -values] 1] == \
	    $::EMC::gui::grpsmiles} {
	  set answer [ \
	    tk_messageBox \
	      -message "Are you sure you want add this duplicate SMILES entry?" \
	      -icon question -type yesno -parent .emcpoly]
	  switch -- $answer {
	    yes { continue }
	    no { return }
	  }
	}
      }

      set ::EMC::gui::polgrouplist [ \
	lreplace $::EMC::gui::polgrouplist [ \
	  lsearch -index 0 $::EMC::gui::polgrouplist [ \
	    lindex [.emcpoly.hlf.groups.tv item [ \
		.emcpoly.hlf.groups.tv selection] -values] 0]] [ \
	  lsearch -index 0 $::EMC::gui::polgrouplist [ \
	    lindex [.emcpoly.hlf.groups.tv item [ \
		.emcsm.hlf.tv selection] -values] 0]]]
      .emcpoly.hlf.groups.tv item [ \
	  .emcpoly.hlf.groups.tv selection] -values [ \
	list \
	  $::EMC::gui::grpname \
	  $::EMC::gui::grpsmiles]
      lappend ::EMC::gui::polgrouplist \
	"$::EMC::gui::grpname $::EMC::gui::grpsmiles"
      set ::EMC::gui::grpname ""
      set ::EMC::gui::grpsmiles ""
    }

  ttk::button $grps.deleteitem \
    -text "Delete" \
    -command {
      .emcpoly.hlf.groups.tv delete [.emcpoly.hlf.groups.tv selection]
      set ::EMC::gui::polgrouplist [ \
	lreplace $::EMC::gui::polgrouplist [ \
	  lsearch -index 0 $::EMC::gui::polgrouplist $::EMC::gui::grpname] [ \
	  lsearch -index 0 $::EMC::gui::polgrouplist $::EMC::gui::grpname]]
    }

  ttk::button $grps.clearlist \
    -text "Clear All" \
    -command {
      set answer [ \
	tk_messageBox \
	  -message "Are you sure you want to delete all entries?" \
	  -icon question -type yesno -parent .emcpoly]
      switch -- $answer {
	yes {
	  .emcpoly.hlf.groups.tv delete [.emcpoly.hlf.groups.tv children {}]
	  set ::EMC::gui::polgrouplist {}
	}
	no { return }
      }
    }

  ttk::button $grps.loadfile \
    -text "Import File" \
    -command { ::EMC::gui::ImportFile polymer .emcpoly }
  
  ttk::button $grps.savetofile \
    -text "Save File" \
    -command { ::EMC::gui::SaveGrouptable .emcpoly.hlf.groups.tv }

  ttk::button $grps.moveup \
    -text "Move Up $::EMC::gui::up_arrow" \
    -command {
      set currentID [.emcpoly.hlf.groups.tv selection]
      if {[set previousID [.emcpoly.hlf.groups.tv prev $currentID]] ne ""} {
	set previousIndex [.emcpoly.hlf.groups.tv index $previousID]
	.emcpoly.hlf.groups.tv move $currentID {} $previousIndex
	unset previousIndex
      }
      unset currentID previousID
    } 

  ttk::button $grps.movedown \
    -text "Move Down $::EMC::gui::down_arrow" \
    -command {
      set currentID [.emcpoly.hlf.groups.tv selection]
      if {[set previousID [.emcpoly.hlf.groups.tv next $currentID]] ne ""} {
	set previousIndex [.emcpoly.hlf.groups.tv index $previousID]
	.emcpoly.hlf.groups.tv move $currentID {} $previousIndex
	unset previousIndex
      }
      unset currentID previousID
    } 
  
  ttk::separator $grps.sepinteral1 -orient horizontal

  bind $grps.tv <<TreeviewSelect>> {
    set tempsm [ \
      .emcpoly.hlf.groups.tv item [.emcpoly.hlf.groups.tv selection] -values]
    set ::EMC::gui::grpname [lindex $tempsm 0]
    set ::EMC::gui::grpsmiles [lindex $tempsm 1]
  }

  ::EMC::gui::createInfoButton $wpoly.hlf.groups 0 4
  bind $wpoly.hlf.groups.info <Button-1> {
    set val [::EMC::gui::PolymerGroupInfo]
    set ::EMC::gui::link [lindex $val 1]
    ::EMC::gui::infoWindow info [lindex $val 0] [lindex $val 2]
  }
  
  #
  # DEFINE POLYMER SECTION
  #

  ttk::separator $wpoly.hlf.sep1 -orient horizontal

  ttk::frame $wpoly.hlf.polymer
  ttk::label $wpoly.hlf.polymer.lbl1 \
    -text "Define Polymers:" -font TkHeadingFont -anchor w
  set pol $wpoly.hlf.polymer
  #ttk::labelframe $pol.frame -text "Polymer Connectivity"
  
  #set TemporaryMonomerNames {Styrene MMA Ethylene}
  #set TemporarySmilesList {*cccc* *ccc* *ccc*}
  #set Linkerlist {2 2 2}
  #set monomerlist {mma styr ethyl}
  #set connectorcount {2 2 2}
 
  # polymer treeview for the individual polymers 
  
  ttk::treeview $pol.tv \
    -selectmode browse -yscrollcommand "$pol.scroll set"
  $pol.tv configure \
    -column {Name Monomers Type} -display {Name Monomers Type} \
    -show {headings} -height 5
  $pol.tv heading Name \
    -text "Polymer Name"
  $pol.tv heading Monomers \
    -text "Monomers"
  $pol.tv heading Type \
    -text "Type"
  $pol.tv column Name \
    -width 150 -stretch 1 -anchor center
  $pol.tv column Monomers \
    -width 250 -stretch 1 -anchor center
  $pol.tv column Type \
    -width 75 -stretch 1 -anchor center
  ttk::scrollbar $pol.scroll \
    -orient vertical -command "$pol.tv yview"
 
  ttk::button $pol.addnew \
    -text "New Polymer" \
    -command {
      if {[winfo exists .emceditpolymer]} { destroy .emceditpolymer }
      ::EMC::gui::editpolymer
    }

  ttk::button $pol.editpol \
    -text "Edit Polymer" \
    -command {
      if {[.emcpoly.hlf.polymer.tv selection] == ""} {
	return
      }
      if {[winfo exists .emceditpolymer]} {
	destroy .emceditpolymer
      }
      ::EMC::gui::editpolymer
      foreach polgroup [lindex [ \
	  .emcpoly.hlf.polymer.tv item [ \
	    .emcpoly.hlf.polymer.tv selection] -values] 1] {
	.emceditpolymer.hlf.tv2 insert {} end \
	  -values [ \
	    list \
	      [lindex $polgroup 0] \
	      [lindex $polgroup 1] \
	      [lindex $polgroup 2]]
      }
      set ::EMC::gui::polymername \
	"[lindex [.emcpoly.hlf.polymer.tv item [.emcpoly.hlf.polymer.tv selection] -values] 0]"
      set ::EMC::gui::polymertype \
	"[lindex [.emcpoly.hlf.polymer.tv item [.emcpoly.hlf.polymer.tv selection] -values] 2]"
      set ::EMC::gui::editedpolymerentryswitch \
	[lindex [.emcpoly.hlf.polymer.tv item [.emcpoly.hlf.polymer.tv selection] -values] 0]
    }

  ttk::button $pol.deletepol \
    -text "Delete" \
    -command {
      set ::EMC::gui::PolymerItem [ \
	lreplace $::EMC::gui::PolymerItem [ \
	  lsearch -index 0 $::EMC::gui::PolymerItem [ \
	    lindex [.emcpoly.hlf.polymer.tv item [ \
	      .emcpoly.hlf.polymer.tv selection] -values] 0]] [ \
	  lsearch -index 0 $::EMC::gui::PolymerItem [ \
	    lindex [.emcpoly.hlf.polymer.tv item [ \
	      .emcpoly.hlf.polymer.tv selection] -values] 0]]]
      .emcpoly.hlf.polymer.tv delete [.emcpoly.hlf.polymer.tv selection]
      if {[winfo exists .emcpolconnect] == 0 && \
	  [llength [.emcpoly.hlf.polymer.tv children {}]] != 0} { 
	emcpolconnect
      } elseif {[winfo exists .emcpolconnect] != 0 && \
		[llength [.emcpoly.hlf.polymer.tv children {}]] != 0} {
	destroy .emcpolconnect
	emcpolconnect
      } elseif {[winfo exists .emcpolconnect] != 0 && \
		[llength [.emcpoly.hlf.polymer.tv children {}]] == 0} {
	::EMC::gui::MakeUpdatedPolymerGrid \
	  .emcpoly.hlf.polymer.tv .emcpolconnect.hlf
	destroy .emcpolconnect
      } elseif {[winfo exists .emcpolconnect] == 0 && \
		[llength [.emcpoly.hlf.polymer.tv children {}]] == 0} {
	emcpolconnect
	destroy .emcpolconnect
      }
   }

  ttk::button $pol.clearlist -text "Clear All" \
    -command {
      if {[llength [.emcpoly.hlf.polymer.tv children {}]] == 0} {
	return
      }
      set answer [tk_messageBox -message "Are you sure you want to delete all entries?" -icon question -type yesno -parent .emcpoly]
      switch -- $answer {
	yes {.emcpoly.hlf.polymer.tv delete [.emcpoly.hlf.polymer.tv children {}]}
	no {return}
      }
      if {[winfo exists .emcpolconnect] != 0} {
	::EMC::gui::MakeUpdatedPolymerGrid .emcpoly.hlf.polymer.tv .emcpolconnect.hlf
	destroy .emcpolconnect
      }
    }
  
  ::EMC::gui::createInfoButton $wpoly.hlf.polymer 0 4
  bind $wpoly.hlf.polymer.info <Button-1> {
    set val [::EMC::gui::PolymerDefinitionInfo]
    set ::EMC::gui::link [lindex $val 1]
    ::EMC::gui::infoWindow info [lindex $val 0] [lindex $val 2]
   }

 
  ttk::button $pol.selgrid -text "Edit Connection" \
    -command {
      if {[llength [.emcpoly.hlf.polymer.tv children {}]] == 0} {
	return
      } else {
	emcpolconnect
      }
    }

  # in this frame $conn where the connectivity tables are generated dynamically
  # all frames, buttons, labels etc are generated for this in the 
  # MakePolymerUpdateGrid proc as subwindows of $conn

  ttk::separator $wpoly.hlf.sep2 -orient horizontal
  set conn $wpoly.hlf.connectivity
  
  ttk::button $wpoly.hlf.submit \
    -text "Update System Polymer Chemistry" \
    -command {
      foreach tvitem [.emcpoly.hlf.polymer.tv children {}] {
	if {[lsearch -index 0 $::EMC::gui::tvdefchemistrylist \
	    [lindex [.emcpoly.hlf.polymer.tv item $tvitem -values] 0]] == -1} {
	  .emc.hlf.nb.chemistry.definechemistry.tv insert {} end \
	    -values [ \
	      list \
		[lindex [.emcpoly.hlf.polymer.tv item $tvitem -values] 0] \
		polymer \
		[lindex [.emcpoly.hlf.polymer.tv item $tvitem -values] 2] 1 1]
	  lappend ::EMC::gui::tvdefchemistrylist \
	    "[lindex [.emcpoly.hlf.polymer.tv item $tvitem -values] 0] polymer [lindex [.emcpoly.hlf.polymer.tv item $tvitem -values] 2] 1 1"
	} elseif {[lsearch -index 0 $::EMC::gui::tvdefchemistrylist \
	    [lindex [.emcpoly.hlf.polymer.tv item $tvitem -values] 0]] != -1} {
	  continue
	}
      }

      foreach tvitem [.emc.hlf.nb.chemistry.definechemistry.tv children {}] {
	if {[lsearch -index 0 $::EMC::gui::PolymerItem \
	      [lindex [ \
		.emc.hlf.nb.chemistry.definechemistry.tv \
		  item $tvitem -values] 0]] == -1 && \
	    [lindex [ \
	      .emc.hlf.nb.chemistry.definechemistry.tv \
		item $tvitem -values] 1] == "polymer"} {
	  set ::EMC::gui::tvdefchemistrylist [ \
	    lreplace $::EMC::gui::tvdefchemistrylist [ \
	      lsearch -index 0 $::EMC::gui::tvdefchemistrylist [ \
		lindex [ \
		  .emc.hlf.nb.chemistry.definechemistry.tv \
		    item $tvitem -values] 0]] [ \
	      lsearch -index 0 $::EMC::gui::tvdefchemistrylist [ \
		lindex [ \
		  .emc.hlf.nb.chemistry.definechemistry.tv \
		    item $tvitem -values] 0]]]
	  .emc.hlf.nb.chemistry.definechemistry.tv delete $tvitem
	}
      }
      
      if {[winfo exists .emcpoly]} {
	destroy .emcpoly
      }
      if {[winfo exists .emcpolconnect]} {
	destroy .emcpolconnect
      }
      raise .emc
    }

  # grid all static gui objects in the window
  # change placements here
  
  grid $grps \
    -column 0 -row 0
  grid $grps.lbl1 \
    -column 0 -row 0 -sticky nsew -padx {0 0} -pady {0 0}
  grid $grps.tv  \
    -column 0 -row 1 -sticky nsew -padx {0 0} -pady {0 5} \
    -columnspan 2 -rowspan 3
  grid $grps.scroll \
    -column 2 -row 1 -sticky nsew -padx {0 5} -pady {0 5} -rowspan 3

  grid columnconfigure $grps 0 -minsize 150 -weight 0
  grid columnconfigure $grps 1 -minsize 200 -weight 0
  
  grid $grps.molname \
    -column 0 -row 5 -sticky nsew -padx {0 5} -pady {0 5}
  grid $grps.smilesdef \
    -column 1 -row 5 -sticky nsew -padx {0 5} -pady {0 5}
  grid $grps.editentry \
    -column 4 -row 5 -sticky nsew -padx {0 5} -pady {0 5}
  grid $grps.addtolist \
    -column 3 -row 5 -sticky nsew -padx {0 5} -pady {0 5}
  grid $grps.deleteitem \
    -column 3 -row 2 -sticky nsew -padx {0 5} -pady {0 5}
  grid $grps.clearlist \
    -column 4 -row 2 -sticky nsew -padx {0 5} -pady {0 5}
  grid $grps.loadfile \
    -column 3 -row 1 -sticky nsew -padx {0 5} -pady {0 5}
  grid $grps.savetofile \
    -column 4 -row 1 -sticky nsew -padx {0 5} -pady {0 5}
  grid $grps.moveup \
    -column 3 -row 3 -sticky nsew -padx {0 5} -pady {0 5}
  grid $grps.movedown \
    -column 4 -row 3 -sticky nsew -padx {0 5} -pady {0 5}
  grid $grps.lbl2 \
    -column 0 -row 4 -sticky nsew -padx {0 5} -pady {0 5}
  grid $grps.sepinteral1 \
    -column 3 -row 4 -sticky ew -padx {10 10} -pady {0 0} -columnspan 2

  grid $wpoly.hlf.sep1 \
    -column 0 -row 1 -sticky nsew -padx {5 5} -pady {5 5} -columnspan 5

  grid $pol \
    -column 0 -row 2 -padx {0 5} -pady {0 5}
  grid $pol.lbl1 \
    -column 0 -row 0 -sticky nsew
  grid $pol.tv \
    -column 0 -row 1 -sticky nsew -padx {0 0} -pady {0 5} \
     -columnspan 3 -rowspan 5

  grid columnconfigure $pol 0 -minsize 150 -weight 0
  grid columnconfigure $pol 1 -minsize 250 -weight 0
  grid columnconfigure $pol 2 -minsize 75 -weight 0
  
  grid $pol.scroll \
    -column 3 -row 1 -sticky nsew -padx {0 5} -pady {0 5} -rowspan 5
  grid $pol.addnew \
    -column 4 -row 1 -sticky nsew -padx {0 5} -pady {0 5}
  grid $pol.editpol \
    -column 4 -row 2 -sticky nsew -padx {0 5} -pady {0 5}
  grid $pol.deletepol \
    -column 4 -row 3 -sticky nsew -padx {0 5} -pady {0 5}
  grid $pol.clearlist \
    -column 4 -row 4 -sticky nsew -padx {0 5} -pady {0 5}
  grid $pol.selgrid \
    -column 4 -row 5 -sticky nsew -padx {0 5} -pady {0 5}
  grid $wpoly.hlf.sep2 \
    -column 0 -row 3 -sticky nsew -padx {5 5} -pady {5 5} -columnspan 5
  grid $wpoly.hlf.submit \
    -column 0 -row 4 -sticky nsew -padx {5 5} -pady {5 5}

  if {[llength $::EMC::gui::polgrouplist] != 0} {
    foreach item $::EMC::gui::polgrouplist {
      .emcpoly.hlf.groups.tv insert {} end \
	-values [list [lindex $item 0] [lindex $item 1]]
    }
  }
  if {[llength $::EMC::gui::PolymerItem] != 0} {
    foreach item $::EMC::gui::PolymerItem {
      .emcpoly.hlf.polymer.tv insert {} end \
	-values [list [lindex $item 0] [lindex $item 1] [lindex $item 2]]
    }
    if {[winfo exists .emcpolconnect] == 0} {
      emcpolconnect
    } elseif {[winfo exists .emcpolconnect] == 0} {
      ::EMC::gui::MakeUpdatedPolymerGrid \
	.emcpoly.hlf.polymer.tv .emcpolconnect.hlf
    }
  }

  set ::EMC::gui::grpname ""
  set ::EMC::gui::grpsmiles ""
}


#==============================================================================
# Opens the add surface window on click
#==============================================================================

proc ::EMC::gui::emc_add_surf {} \
{
  variable wsurf


  if { [winfo exists .emcsurf] } {
    wm deiconify .emcsurf
    return
  }
  set wsurf [toplevel .emcsurf]
  wm title $wsurf "EMC: Add Surface"
  grid columnconfigure $wsurf 0 -weight 1
  grid rowconfigure $wsurf 0 -weight 1

  wm geometry $wsurf [expr {355 + $::EMC::gui::window_xdelta}]x205
  wm resizable $wsurf 0 0
  
  ttk::frame $wsurf.hlf
  grid $wsurf.hlf -column 0 -row 0 -sticky nsew
  grid columnconfigure $wsurf.hlf 0 -weight 1
  grid rowconfigure $wsurf.hlf 0 -weight 1

  ttk::label $wsurf.hlf.title \
    -text "Define Surface" -font TkHeadingFont -anchor w

  ttk::label $wsurf.hlf.namelbl \
    -text "Surface Name:"
  ttk::entry $wsurf.hlf.nameentry \
    -textvariable ::EMC::gui::surfoptions(name)
  
  ttk::label $wsurf.hlf.importlbl \
    -text "Surface File:"
  ttk::entry $wsurf.hlf.importentry \
    -textvariable ::EMC::gui::surfoptions(filename)

  ttk::button $wsurf.hlf.importbutton \
    -text "Browse" \
    -command {
      set types {
	{{All Files} *}
	{{Text Files} {.txt}} 
      }
      set tempfile [ \
	tk_getOpenFile \
	  -parent .emcsurf -title "Select Surface file" -filetypes $types]
      if {$tempfile != ""} {
	set ::EMC::gui::surfoptions(filename) [lindex [split $tempfile "."] 0]
      } else {
	return
      }
    }

  ttk::frame $wsurf.hlf.type

  ttk::label $wsurf.hlf.filetypelbl \
    -text "File Type:"
  ttk::menubutton $wsurf.hlf.filetype \
    -direction below -menu  .emcsurf.hlf.filetype.menu \
    -textvariable ::EMC::gui::surfoptions(inputtype) -width 15
  menu $wsurf.hlf.filetype.menu -tearoff no

  $wsurf.hlf.filetype.menu add command \
    -label "EMC" \
    -command {
      set ::EMC::gui::surfoptions(inputtype) emc
      grid .emcsurf.hlf.type
    }
  $wsurf.hlf.filetype.menu add command \
    -label "Insight" \
    -command {
      set ::EMC::gui::surfoptions(inputtype) insight
      grid remove .emcsurf.hlf.type
     }

  ttk::label $wsurf.hlf.placementlbl \
    -text "Surface Position:"
  ttk::radiobutton $wsurf.hlf.placementbtn1 \
    -text "Box Edges" -value "verbatimtrue" \
    -variable ::EMC::gui::surfoptions(placement)
  ttk::radiobutton $wsurf.hlf.placementbtn2 \
    -text "Box Center" -value "verbatimfalse" \
    -variable ::EMC::gui::surfoptions(placement)

  ttk::button $wsurf.hlf.addtosystem \
    -text "Add To System" \
    -command {
      ::EMC::gui::CheckSurfaceInputfile
      if {[string length $::EMC::gui::surfoptions(name)] == 0 || 
	  [string length $::EMC::gui::surfoptions(filename)] == 0 } {
	tk_messageBox -type ok -icon error \
	  -title "Missing Entries" -parent .emcsurf \
	  -message "Please fill in all necessary options before adding the surface."
	return
      }
      foreach tvitem [.emc.hlf.nb.chemistry.definechemistry.tv children {}] {
	if {[lindex [ \
	      .emc.hlf.nb.chemistry.definechemistry.tv \
		item $tvitem -values] 0] == \
	    $::EMC::gui::surfoptions(name)} {
	  tk_messageBox -type ok -icon error \
	    -title "Warning Duplicate" -parent .emcsurf \
	    -message "The groupname: $::EMC::gui::surfoptions(name) exists already. Duplicates are not allowed!"
	  return
	} elseif {[lindex [ \
	      .emc.hlf.nb.chemistry.definechemistry.tv \
		item $tvitem -values] 1] == "surface"} {
	  tk_messageBox -type ok -icon error \
	    -title "Surface Warning" -parent .emcsurf \
	    -message "Only one surface may be defined in a system."
	  return
	}
      }
      .emc.hlf.nb.chemistry.definechemistry.tv insert {} end \
	-values [ \
	  list \
	    $::EMC::gui::surfoptions(name) \
	    "surface" \
	    $::EMC::gui::surfoptions(filename) \
	    "not_defined" \
	    "0"]
      lappend ::EMC::gui::tvdefchemistrylist \
	"$::EMC::gui::surfoptions(name) surface $::EMC::gui::surfoptions(filename) not_defined 0"
    }
  
  ::EMC::gui::createInfoButton $wsurf.hlf 0 2
  bind $wsurf.hlf.info <Button-1> {
    set val [::EMC::gui::SurfacesInfo]
    set ::EMC::gui::link [lindex $val 1]
    ::EMC::gui::infoWindow info [lindex $val 0] [lindex $val 2]
  }

  # grid the components
  
  grid $wsurf.hlf.title \
    -column 0 -row 0 -sticky nsew -padx {5 5} -pady {0 5} 

  grid $wsurf.hlf.namelbl \
    -column 0 -row 1 -sticky nsew -padx {5 5} -pady {0 5} 
  grid $wsurf.hlf.nameentry \
    -column 1 -row 1 -sticky nsew -padx {0 5} -pady {0 5} 
  
  grid $wsurf.hlf.importlbl \
    -column 0 -row 2 -sticky nsew -padx {5 5} -pady {0 5} 
  grid $wsurf.hlf.importentry \
    -column 1 -row 2 -sticky nsew -padx {0 5} -pady {0 5} 
  grid $wsurf.hlf.importbutton \
    -column 2 -row 2 -sticky nsew -padx {0 5} -pady {0 5} 

  grid $wsurf.hlf.filetypelbl \
    -column 0 -row 3 -sticky nsew -padx {5 5} -pady {0 5} 
  grid $wsurf.hlf.filetype \
    -column 1 -row 3 -sticky nsew -padx {0 5} -pady {0 5} 
  
  grid $wsurf.hlf.addtosystem \
    -column 0 -row 5 -sticky nsew -padx {5 5} -pady {5 5} -columnspan 3
}


#==============================================================================
# Opens the edit polymer window which pops up within the polymer manager window
#==============================================================================

proc ::EMC::gui::editpolymer {} \
{
  #Var to initialize screen
  variable editpol

  #initialize gui command
  #::EMC::gui::initialize

  if { [winfo exists .emceditpolymer] } {
    wm deiconify .emceditpolymer
    return
  }
  set editpol [toplevel .emceditpolymer]
  wm title $editpol "EMC: Edit Polymer"
  grid columnconfigure $editpol 0 -weight 1
  grid rowconfigure $editpol 0 -weight 1

  wm geometry $editpol 500x400
  wm resizable $editpol 0 0
  ttk::frame $editpol.hlf

  grid $editpol.hlf -column 0 -row 0 -sticky nsew
  grid columnconfigure $editpol.hlf 0 -weight 1
  grid rowconfigure $editpol.hlf 0 -weight 1
  
  ttk::label $editpol.hlf.lbl1 \
    -text "Polymer" -font TkHeadingFont -anchor nw
  ttk::treeview $editpol.hlf.tv1 \
    -selectmode browse -yscrollcommand "$editpol.hlf.scroll1 set"

  $editpol.hlf.tv1 configure \
    -column {Name SMILES} -display {Name SMILES} -show {headings} -height 5
  $editpol.hlf.tv1 heading Name \
    -text "Group Name"
  $editpol.hlf.tv1 heading SMILES \
    -text "SMILES"
  $editpol.hlf.tv1 column Name \
    -width 100 -stretch 1 -anchor center
  $editpol.hlf.tv1 column SMILES \
    -width 100 -stretch 1 -anchor center
  ttk::scrollbar $editpol.hlf.scroll1 \
    -orient vertical -command "$editpol.hlf.tv1 yview"

  
  ttk::label $editpol.hlf.amountlbl \
    -text "Amount:" -anchor w
  ttk::entry $editpol.hlf.amount \
    -textvariable ::EMC::gui::monomeramount
  
  set monomeramount 1
  
  ttk::button $editpol.hlf.addbutton \
    -text "Add Group $::EMC::gui::down_arrow" \
    -command {
      if {$::EMC::gui::monomeramount == ""} {
	return
      } elseif {[regexp {[[:alpha:]]} $::EMC::gui::monomeramount] == 1} {
	return
      } elseif {[.emceditpolymer.hlf.tv1 selection] == ""} {
	return
      }
      .emceditpolymer.hlf.tv2 insert {} end -values \
	"[lindex [.emceditpolymer.hlf.tv1 item [.emceditpolymer.hlf.tv1 selection] -values] 0] [lindex [.emceditpolymer.hlf.tv1 item [.emceditpolymer.hlf.tv1 selection] -values] 1] $::EMC::gui::monomeramount"
    }
  
  ttk::button  $editpol.hlf.removebutton \
    -text "Remove Group $::EMC::gui::up_arrow" \
    -command {
      .emceditpolymer.hlf.tv2 delete [.emceditpolymer.hlf.tv2 selection]
    }

  ttk::treeview $editpol.hlf.tv2 \
    -selectmode browse -yscrollcommand "$editpol.hlf.scroll2 set"

  $editpol.hlf.tv2 configure \
    -column {Name SMILES Amount} -display {Name SMILES Amount} \
    -show {headings} -height 5
  $editpol.hlf.tv2 heading Name \
    -text "Group Name"
  $editpol.hlf.tv2 heading SMILES \
    -text "SMILES"
  $editpol.hlf.tv2 heading Amount \
    -text "Amount"
  $editpol.hlf.tv2 column Name \
    -width 100 -stretch 1 -anchor center
  $editpol.hlf.tv2 column SMILES \
    -width 100 -stretch 1 -anchor center
  $editpol.hlf.tv2 column Amount \
    -width 100 -stretch 1 -anchor center
  
  ttk::scrollbar $editpol.hlf.scroll2 \
    -orient vertical -command "$editpol.hlf.tv2 yview"
 
  ttk::label $editpol.hlf.addnamelbl \
    -text "Add Name:" -anchor w
  ttk::entry $editpol.hlf.addname \
    -textvariable ::EMC::gui::polymername
  ttk::label $editpol.hlf.addpolymertypelbl \
    -text "Polymer Type" -anchor w
  ttk::combobox $editpol.hlf.addpolymertype \
    -textvariable ::EMC::gui::polymertype -state readonly \
    -values {alternate block random} 
    
  ttk::button  $editpol.hlf.close \
    -text "Add and Close" \
    -command {
      if {$::EMC::gui::polymername == ""} {
	tk_messageBox -type ok -icon error \
	  -title "Polymer Name Missing" -parent .emceditpolymer \
	  -message "No polymer name defined!"
	return
      }
      if {[lsearch -index 0 \
	    $::EMC::gui::PolymerItem $::EMC::gui::polymername] != -1 && 
	  $::EMC::gui::editedpolymerentryswitch == -1} {
	tk_messageBox -type ok -icon error \
	  -title "Name Exists" -parent .emceditpolymer \
	  -message "The polymer name you chose has been previously defined."
	return
      }
      if {$::EMC::gui::polymertype == ""} {
	tk_messageBox -type ok -icon error \
	  -title "Polymer Type Missing" -parent .emceditpolymer \
	  -message "No Polymer Type Defined"
	return
      }
      if {[llength [.emceditpolymer.hlf.tv2 children {}]] == 0} {
	return
      }
      if {[::EMC::gui::CheckPolymerTerminators] == 1} {
	tk_messageBox -type ok -icon error \
	  -title "Missing Terminator" -parent .emceditpolymer \
	  -message "Only One terminator group was defined."
	return
      }

      set grouplist {}
      foreach tvitem [.emceditpolymer.hlf.tv2 children {}] {
	lappend grouplist "[.emceditpolymer.hlf.tv2 item $tvitem -values]"
      }
      if {$::EMC::gui::editedpolymerentryswitch != -1} {
	.emcpoly.hlf.polymer.tv item [.emcpoly.hlf.polymer.tv selection] \
	  -values [ \
	    list \
	      "$::EMC::gui::polymername" \
	      "$grouplist" \
	      "$::EMC::gui::polymertype"]
	set ::EMC::gui::PolymerItem [ \
	  lreplace $::EMC::gui::PolymerItem [ \
	    lsearch -index 0 \
	      $::EMC::gui::PolymerItem \
	      $::EMC::gui::editedpolymerentryswitch] [ \
	    lsearch -index 0 \
	      $::EMC::gui::PolymerItem $::EMC::gui::editedpolymerentryswitch]]
	lappend ::EMC::gui::PolymerItem [ \
	  list \
	    $::EMC::gui::polymername \
	    $grouplist \
	    $::EMC::gui::polymertype]
      } elseif {$::EMC::gui::editedpolymerentryswitch == -1} {
	.emcpoly.hlf.polymer.tv insert {} end \
	  -values [ \
	    list \
	      "$::EMC::gui::polymername" \
	      "$grouplist" \
	      "$::EMC::gui::polymertype"]
	if { [lsearch -index 0 \
	      $::EMC::gui::polymernames $::EMC::gui::polymername] == -1} {
	  lappend ::EMC::gui::PolymerItem [ \
	    list \
	      $::EMC::gui::polymername \
	      $grouplist \
	      $::EMC::gui::polymertype]
	}
      }

      # add command for updating the polymer selector grid
      
      if {[winfo exists .emceditpolymer]} {
	destroy .emceditpolymer
      }
      set ::EMC::gui::editedpolymerentryswitch -1
      set ::EMC::gui::polymername ""
      set ::EMC::gui::polymertype ""

      # make updated polymer grid
      
      if {[winfo exists .emcpolconnect] == 0} {
	emcpolconnect
      } elseif {[winfo exists .emcpolconnect]} {
	destroy .emcpolconnect
	emcpolconnect
      }
    }
 
  grid $editpol.hlf.tv1 \
    -column 0 -row 0 -sticky nsew -padx {0 0} -pady {0 0} \
    -columnspan 5 -rowspan 5
  grid $editpol.hlf.scroll1 \
    -column 5 -row 0 -sticky nsew -padx {0 0} -pady {0 0} -rowspan 5

  grid $editpol.hlf.amountlbl \
    -column 0 -row 6 -sticky nsew -padx {0 5} -pady {5 5}
  grid $editpol.hlf.amount \
    -column 1 -row 6 -sticky nsew -padx {0 5} -pady {5 5}
  grid $editpol.hlf.addbutton \
    -column 2 -row 6 -sticky nsew -padx {0 5} -pady {5 5}
  grid $editpol.hlf.removebutton \
    -column 3 -row 6 -sticky nsew -padx {0 0} -pady {5 5}
  
  grid $editpol.hlf.tv2 \
    -column 0 -row 7 -sticky nsew -padx {0 0} -pady {0 0} \
    -columnspan 5 -rowspan 5
  grid $editpol.hlf.scroll2 \
    -column 5 -row 7 -sticky nsew -padx {0 0} -pady {0 0} -rowspan 5
  
  grid $editpol.hlf.addnamelbl \
    -column 0 -row 12 -sticky nsew -padx {0 5} -pady {5 5}
  grid $editpol.hlf.addname \
    -column 1 -row 12 -sticky nsew -padx {0 0} -pady {5 5}
  grid $editpol.hlf.addpolymertypelbl \
    -column 0 -row 13 -sticky nsew -padx {0 5} -pady {5 5}
  grid $editpol.hlf.addpolymertype \
    -column 1 -row 13 -sticky nsew -padx {0 0} -pady {5 5}

  grid $editpol.hlf.close \
    -column 0 -row 14 -sticky nsew -padx {5 5} -pady {5 5} -columnspan 6

  # load available groups from the polymer group window
  
  foreach tvitem [.emcpoly.hlf.groups.tv children {}] {
    .emceditpolymer.hlf.tv1 insert {} end \
      -values [.emcpoly.hlf.groups.tv item $tvitem -values]
  }
}


#==============================================================================
# Polymer connectivity window
#==============================================================================

proc ::EMC::gui::PolymerConnectivity {} {
  variable polconnect

  if { [winfo exists .emcpolconnect] } {
    wm deiconify .emcpolconnect
    raise .emcpolconnect
    return
  }
  set polconn [toplevel .emcpolconnect]
  wm title $polconn "EMC: Polymer Connectivity"
  grid columnconfigure $polconn 0 -weight 1
  grid rowconfigure $polconn 0 -weight 1

  ttk::frame $polconn.hlf

  grid $polconn.hlf -column 0 -row 0 -sticky nsew
  grid columnconfigure $polconn.hlf 0 -weight 1
  grid rowconfigure $polconn.hlf 0 -weight 1

  ::EMC::gui::MakeUpdatedPolymerGrid .emcpoly.hlf.polymer.tv .emcpolconnect.hlf

  ttk::menubutton $polconn.hlf.masterselection \
    -direction below -menu $polconn.hlf.masterselection.menu \
    -text "Linkage"
  menu $polconn.hlf.masterselection.menu -tearoff no
  $polconn.hlf.masterselection.menu add command \
    -label "Head-Tail" \
    -command { ::EMC::gui::PolymerSelectionSchemeHeadTail }
  $polconn.hlf.masterselection.menu add command \
    -label "All" \
    -command { ::EMC::gui::PolymerSelectionAllNone 1 }
  $polconn.hlf.masterselection.menu add command \
    -label "None" \
    -command { ::EMC::gui::PolymerSelectionAllNone 0 }

  grid $polconn.hlf.masterselection -column 0 -row 0
}


#==============================================================================
# Functions controlling backend from here on
#==============================================================================

#==============================================================================
# Called when opening the window
# Sets inital options, rootdirectory (internally)
#==============================================================================

proc ::EMC::gui::ImportOptions {} \
{
  set ::EMC::gui::optionlist {}
  set import [ \
    exec $::EMC::gui::EMC_ROOTDIR/scripts/emc_setup.pl \
      -field_type=$::EMC::gui::ffdefault(type) -options_tcl]
  eval "array set importoptions $import"
  unset import
  foreach option [lsort [array names importoptions]] {
    set value [string map {", " ","} $importoptions($option)]
    lappend ::EMC::gui::optionlist "$option $value"
  }
  array unset importoptions
  
  ::EMC::gui::SetDefaultOptions
}


proc ::EMC::gui::initialize {} \
{
  ::EMC::gui::GetEMCRootDir
  ::EMC::gui::ImportOptions
  ::EMC::gui::GetForceFieldNames
  
  set ::EMC::gui::helpentries [ \
    ::EMC::gui::ReadOptionText \
    $::EMC::gui::EMC_ROOTDIR/vmd/packages/options.dat]
  
  set ::EMC::gui::writealloptions "false"

  set ::EMC::gui::options(directory) [pwd]
  set ::EMC::gui::options(filename) "setup.esh"
  set ::EMC::gui::options(sample,p) "false"
  set ::EMC::gui::options(sample,v) "false"
  set ::EMC::gui::options(sample,e) "false"
  set ::EMC::gui::options(profile,pressure) "false"
  set ::EMC::gui::options(profile,density) "false"

  set ::EMC::gui::options(replace) "true"
  set ::EMC::gui::conclbl "Change Mol Fraction:"
  set ::EMC::gui::ensemble "NVT"
  set ::EMC::gui::trials(defaulttrial) "00"
  set ::EMC::gui::stages(defaultstage) "00"
  set ::EMC::gui::options(multicopies) "1"
  foreach {key value} [array get ::EMC::gui::options *,usr] {
    unset ::EMC::gui::options($key)
  }
  set ::EMC::gui::currentdirlist {}
}


#==============================================================================
# Saves all options and lists as commands to a text file which can be sourced
# in emc to adapt all variables
#==============================================================================

proc ::EMC::gui::save_settings {} \
{
  set tempfilename [tk_getSaveFile -defaultextension ".tcl" -filetypes {{tcl {.tcl}} {all {*}}} -parent .emc]
  if {$tempfilename != ""} {
    set f [open $tempfilename "w"]
    set data ""
    append data "# THIS IS AN EMC GUI STATE FILE - THIS IS NOT AN EMC INPUT FILE \n"
    append data "OPTIONS\n"
    foreach {key value} [array get ::EMC::gui::options] {
      set value [string map {", " ","} $value]
      append data "$key $value\n"
    }
    append data "END\n"

    append data "POLYMERNAMES\n"
    foreach item $::EMC::gui::polymernames {
	append data "$item\n"
    }
    append data "END\n"

    append data "POLYMERARRAY\n"
    foreach {key value} [array get ::EMC::gui::polymerarray] {
      append data "$key $value\n"
    }
    append data "END\n"

    append data "CURRENTDIRLIST\n"
    foreach {key value} [array get ::EMC::gui::processes] {
      append data "$key {$value}\n"
    }
    append data "END\n"

    append data "SYSTEMS\n"
    foreach tvitem [.emc.hlf.nb.results.tv children {}] {
      append data "[.emc.hlf.nb.results.tv item $tvitem -values]\n"
    }
    append data "END\n"

    append data "LOOPLIST\n"
    foreach item $::EMC::gui::LoopList {
	append data "$item\n"
    }
    append data "END\n"
  
    append data "POLYMERITEM\n"
    foreach item $::EMC::gui::PolymerItem {
	append data "$item\n"
    }
    append data "END\n"

    append data "GROUPLIST\n"
    foreach item $::EMC::gui::GroupList {
      append data "$item\n"
    }
    append data "END\n"

    append data "CLUSTERLIST\n"
    foreach item $::EMC::gui::ClusterList {
      append data "$item\n"
    }
    append data "END\n"

    append data "SMGROUPLIST\n"
    foreach item $::EMC::gui::smgrouplist {
      append data "$item\n"
    }
    append data "END\n"
    
    append data "POLGROUPLIST \n"
    foreach item $::EMC::gui::polgrouplist {
      append data "$item\n"
    }
    append data "END\n"

   append data "TVDEFCHEMISTRY\n"
   foreach item $::EMC::gui::tvdefchemistrylist {
      append data "\"[lindex $item 0]\" \"[lindex $item 1]\" \"[lindex $item 2]\" \"[lindex $item 3]\" \"[lindex $item 4]\"\n"
    }
   append data "END\n"

   append data "TRIALLIST\n"
   foreach item $::EMC::gui::triallist {
      append data "$item\n"
    }
   append data "END\n"

   append data "TRIALS\n"
    foreach {key value} [array get ::EMC::gui::trials] {
      append data "$key {$value}\n"
    }
   append data "END\n"

   append data "STAGES\n"
    foreach {key value} [array get ::EMC::gui::stages] {
      append data "$key {$value}\n"
    }
    append data "END\n"

   append data "FFBROWSE\n"
   foreach item $::EMC::gui::ffbrowse {
      append data "$item\n"
    }
   append data "END\n"
   
   append data "FFFILELIST\n"
   foreach item $::EMC::gui::fffilelist {
      append data "$item\n"
    }
   append data "END\n"
    ##############
    puts $f $data
    close $f
  } elseif {$tempfilename == ""} {
    return
  }
  puts "Info) Session saved to '$tempfilename'"
}


#==============================================================================
# Sources the tcl file which was generated by the save command file; contains
# commands meaning this only opens the designated file
#==============================================================================

proc ::EMC::gui::load_settings {} \
{
  set identifier 0
  set tempfilename [ \
    tk_getOpenFile \
      -defaultextension ".tcl" \
      -filetypes {{tcl {.tcl}} {all {*}}} -parent .emc]

  if {$tempfilename == ""} { return }

  # reset field

  set ::EMC::gui::ffbrowse {}
  set ::EMC::gui::fffilelist {}
  .emc.hlf.nb.ffsettings.browserframe.tv \
    delete [.emc.hlf.nb.ffsettings.browserframe.tv children {}]
  .emc.hlf.nb.ffsettings.browserframe.tv2 \
    delete [.emc.hlf.nb.ffsettings.browserframe.tv2 children {}]

  # get settings

  set f [open $tempfilename "r"]
  while {[gets $f line] > -1} {
    if {[string first \# $line] != -1} {
      continue
    } 
    if {[string first "END" $line] != -1} {
      set identifier 0
      continue
    }
    foreach keyword { \
	OPTIONS POLYMERNAMES POLYMERARRAY LOOPLIST POLYMERITEM GROUPLIST \
	CLUSTERLIST SMGROUPLIST POLGROUPLIST TVDEFCHEMISTRY TRIALLIST \
	CURRENTDIRLIST SYSTEMS STAGES TRIALS FFFILELIST FFBROWSE} {
      if {[string first "$keyword" $line] != -1} {
	set identifier $keyword
	break
      }
    }
    #puts "[LINE [info frame]]: $line"
    if {[llength $line] < 2} {
      continue
    }
    switch $identifier {
      "OPTIONS" {
	set option [lindex $line 0]
	set value [lindex $line 1]
	set ::EMC::gui::options($option) $value
      }
      "POLYMERARRAY" {
	set ::EMC::gui::polymerarray([lindex $line 0]) [lindex $line 1]
      }
      "CURRENTDIRLIST" {
	set ::EMC::gui::processes([lindex $line 0]) [lindex $line 1]
      }
      "STAGES" {
	set ::EMC::gui::stages([lindex $line 0]) [lindex $line 1]
      }
      "TRIALS" {
	set ::EMC::gui::trials([lindex $line 0]) [lindex $line 1]
      }
      "SYSTEMS" {
	if {[info exists ::EMC::gui::options(directory)]} {
	  cd $::EMC::gui::options(directory)
	} else {
	  set $::EMC::gui::options(directory) [pwd]
	}
	if {[lindex $line 3] != -1 && [file exists [lindex $line 4]] != -1} {
	  cd [lindex $line 4]
	  set shfilename [lindex [split $::EMC::gui::options(filename) "."] 0]
	  source ./$shfilename.vmd
	  cd $::EMC::gui::options(directory)
	  set currentmolid [molinfo top]
	  mol rename $currentmolid [lindex $line 4]
	  set ::EMC::gui::processes([lindex $line 4],molid) $currentmolid
	}
	.emc.hlf.nb.results.tv insert {} end \
	  -values [ \
	    list \
	      "[lindex $line 0]" \
	      "[lindex $line 1]" \
	      "[lindex $line 2]" \
	      "$::EMC::gui::processes([lindex $line 4],molid)" \
	      "[lindex $line 4]"]
      }
      "LOOPLIST" {
	puts "no"}
      "POLYMERNAMES" {
	lappend ::EMC::gui::polymernames $line	
      }
      "POLYMERITEM" {
	if {[lsearch -index 0 \
	      $::EMC::gui::PolymerItem [lindex $line 0]] == -1 && 
	    [lsearch -index 1 \
	      $::EMC::gui::PolymerItem [lindex $line 1]] == -1} {
	  lappend ::EMC::gui::PolymerItem $line
	  if {[winfo exists .emcpoly] == 1} {
	    .emcpoly.hlf.groups.tv insert {} end \
	      -values [ \
		list \
		  "[lindex $line 0]" \
		  "[lindex $line 1]"]
	    ::EMC::gui::MakeUpdatedPolymerGrid \
	      .emcpoly.hlf.polymer.tv .emcpolconnect.hlf
	  }
	}
      }
      "GROUPLIST" {
	lappend ::EMC::gui::GroupList $line}
      "CLUSTERLIST" {
	lappend ::EMC::gui::ClusterList $line}
      "SMGROUPLIST" {
	if {[lsearch -index 0 \
	      $::EMC::gui::smgrouplist [lindex $line 0]] == -1 && 
	    [lsearch -index 1 \
	      $::EMC::gui::smgrouplist [lindex $line 1]] == -1} {
	  lappend ::EMC::gui::smgrouplist $line
	  if {[winfo exists .emcsm] == 1} {
	    .emcsm.hlf.tv insert {} end \
	      -values [ \
		list \
		  "[lindex $line 0]" \
		  "[lindex $line 1]"]
	  }
	}
      }
      "POLGROUPLIST" {
	if {[lsearch -index 0 \
	      $::EMC::gui::polgrouplist [lindex $line 0]] == -1 && 
	    [lsearch -index 1 \
	      $::EMC::gui::polgrouplist [lindex $line 1]] == -1} {
	  lappend ::EMC::gui::polgrouplist $line
	  if {[winfo exists .emcpoly] == 1} {
	    .emcpoly.hlf.groups.tv insert {} end \
	      -values [ \
		list \
		  "[lindex $line 0]" \
		  "[lindex $line 1]"]
	  }
	}
      }
      "TVDEFCHEMISTRY" {
	if {[lsearch -index 0 \
	      $::EMC::gui::tvdefchemistrylist [lindex $line 0]] == -1 && 
	    [lsearch -index 1 \
	      $::EMC::gui::tvdefchemistrylist [lindex $line 2]] == -1} {
	  lappend ::EMC::gui::tvdefchemistrylist $line
	  if {[winfo exists .emc] == 1} {
	    .emc.hlf.nb.chemistry.definechemistry.tv insert {} end \
	      -values [ \
		list \
		  "[lindex $line 0]" \
		  "[lindex $line 1]" \
		  "[lindex $line 2]" \
		  "[lindex $line 3]" \
		  "[lindex $line 4]"]
	  }
	}
      }
      "TRIALLIST" {
	if {[lsearch -index 0 \
	      $::EMC::gui::triallist [lindex $line 0]] == -1 && \
	    [lsearch -index 1 \
	      $::EMC::gui::triallist [lindex $line 2]] == -1} {
	  lappend ::EMC::gui::triallist $line
	  if {[winfo exists .emc] == 1} {
	    .emc.hlf.nb.chemistry.trials.tv insert {} end \
	      -values [ \
		list \
		  "[lindex $line 0]" \
		  "[lindex $line 1]" \
		  "[lindex $line 2]"]
	      }
	  }
      }
      "FFBROWSE" {
	if {[lsearch -index 0 \
	      $::EMC::gui::ffbrowse [lindex $line 0]] == -1 && \
	    [lsearch -index 1 \
	      $::EMC::gui::ffbrowse [lindex $line 1]] == -1} {
	  lappend ::EMC::gui::ffbrowse $line
	  if {[winfo exists .emc] == 1} {
	    .emc.hlf.nb.ffsettings.browserframe.tv insert {} end \
	      -values [ \
		list \
		  "[lindex $line 0]" \
		  "[lindex $line 1]"]
	  }
	}
      }
      "FFFILELIST" {
	if {[lsearch -index 0 \
	      $::EMC::gui::fffilelist [lindex $line 0]] == -1 && \
	    [lsearch -index 1 \
	      $::EMC::gui::fffilelist [lindex $line 1]] == -1} {
	  lappend ::EMC::gui::fffilelist $line
	  if {[winfo exists .emc] == 1} {
	    .emc.hlf.nb.ffsettings.browserframe.tv2 insert {} end \
	      -values [ \
		list \
		  "[lindex $line 0]" \
		  "[lindex $line 1]"]
	  }
	}
      }
      "0" {
	continue
      }
    }
    continue
  }
  close $f
  puts "Info) Session loaded from '$tempfilename'"

  ::EMC::gui::AddRemoveTrial
  ::EMC::gui::EnableFieldOptions \
    .emc.hlf.nb.ffsettings $::EMC::gui::options(field)

  if {$::EMC::gui::options(fraction) == "count"} {
    set ::EMC::gui::conclbl "Number of Molecules:"
    .emc.hlf.nb.permanentsettings.ntotal configure -state disable
  } elseif {$::EMC::gui::options(fraction) == "mol"} {
    set ::EMC::gui::conclbl "Mol Fraction:"
    .emc.hlf.nb.permanentsettings.ntotal configure -state normal
  } elseif {$::EMC::gui::options(fraction) == "mass"} {
    set ::EMC::gui::conclbl "Mass Fraction:"
    .emc.hlf.nb.permanentsettings.ntotal configure -state normal
  } elseif {$::EMC::gui::options(fraction) == "vol"} {
    set ::EMC::gui::conclbl "Volumen Fraction:"
    .emc.hlf.nb.permanentsettings.ntotal configure -state normal
  }
}


#==============================================================================
# Loads all the settings from the option list which has all defaults statically
# stored within; optionlist must never be changed!
#==============================================================================

proc ::EMC::gui::SetDefaultOptions {} \
{
#  puts "[LINE [info frame]]: Set default options"
  foreach option $::EMC::gui::optionlist {
    set ::EMC::gui::options([lindex $option 0]) [lindex $option 2]
  }
  set ::EMC::gui::options(replace) "true"
  set ::EMC::gui::options(field) $::EMC::gui::ffdefault(field)
  set ::EMC::gui::options(pressure) "false"
  set ::EMC::gui::options(ncores) "1"
}


#==============================================================================
#
#==============================================================================

proc ::EMC::gui::ClearAllandRestoreDefaults {} \
{
  set ::EMC::gui::statusmessage "Status: Ready"
  
  ::EMC::gui::SetDefaultOptions
  
  set ::EMC::gui::trials(use) "false"

  .emc.hlf.nb.chemistry.definechemistry.tv delete [ \
    .emc.hlf.nb.chemistry.definechemistry.tv children {}]
  .emc.hlf.nb.chemistry.trials.tv delete [ \
    .emc.hlf.nb.chemistry.trials.tv children {}]
  if {[winfo exists .emcpoly]} {
    .emcpoly.hlf.groups.tv delete [ \
      .emcpoly.hlf.groups.tv children {}]
    .emcpoly.hlf.polymer.tv delete [ \
      .emcpoly.hlf.polymer.tv children {}]
  }
  if {[winfo exists .emcsm]} {
    .emcsm.hlf.tv delete [.emcsm.hlf.tv children {}]
  }
  if {[winfo exists .emceditpolymer]} {
    .emceditpolymer.hlf.tv1 delete [ \
      .emceditpolymer.hlf.tv1 children {}]
    .emceditpolymer.hlf.tv2 delete [ \
      .emceditpolymer.hlf.tv2 children {}]
  }

  set ::EMC::gui::LoopList {}
  set ::EMC::gui::polymernames {}
  set ::EMC::gui::MainOptionList {}
  set ::EMC::gui::TemplateOptionList {}
  set ::EMC::gui::GroupList {}
  set ::EMC::gui::smgrouplist {}
  set ::EMC::gui::tvdefchemistrylist {}
  set ::EMC::gui::polgrouplist {}
  set ::EMC::gui::PolymerItem {}
  set ::EMC::gui::triallist {}
  
  foreach {key value} [array get ::EMC:gui::polymerarray] {
    unset ::EMC::gui::polymerarray($key) 
  }
  array unset ::EMC::gui::polymerarray
  if {[winfo exists .emcpoly]} {
    ::EMC::gui::MakeUpdatedPolymerGrid
  }
  foreach {key value} [array get ::EMC::gui::surfoptions] {
    unset ::EMC::gui::surfoptions($key)
  }
  array unset ::EMC::gui::surfoptions
  
  ::EMC::gui::ClearAllEmcRepresentations .emc.hlf.nb.results.tv
  .emc.hlf.nb.results.tv delete [.emc.hlf.nb.results.tv children {}]
  
  array unset ::EMC::gui::trials
  array unset ::EMC::gui::stages
  array unset ::EMC::gui::processes
  
  set ::EMC::gui::trials(use) "true"
  set ::EMC::gui::stages(defaultstage) "00"
  set ::EMC::gui::trials(defaulttrial) "00"
  
  cd $::EMC::gui::options(directory)
  
  set ::EMC::gui::options(fraction) "mol"
  set ::EMC::gui::conclbl "Mol Fraction:"

  ::EMC::gui::ReloadOptionsFromEmcforForceField \
    $::EMC::gui::options(field)
  ::EMC::gui::EnableFieldOptions \
    .emc.hlf.nb.ffsettings $::EMC::gui::options(field)
  ::EMC::gui::GetUpdateParameterList
  ::EMC::gui::initialize
}


#==============================================================================
# Reformats the window size when changing tab or unfolding the advanced tabs
#==============================================================================

proc ::EMC::gui::ResizeToActiveTab {args} \
{
  # change the window size to match the active notebook tab
  # need to force gridder to update

  update idletask  

  # uncomment line below to resize width as well
  #set dimW [winfo reqwidth [.fftk_gui.hlf.nb select]]

  # line below does not resize width, as all tabs are designed with gracefull
  # extension of width
  # note +/- for offset can be +- (multimonitor setup), so the expression needs
  # to allow for BOTH symbols;
  # hend "[+-]+"

  regexp {([0-9]+)x[0-9]+[\+\-]+[0-9]+[\+\-]+[0-9]+} [ \
    wm geometry .emc] all dimW

  # manually set dimw to 750
  #set dimW 700

  set dimH [winfo reqheight [.emc.hlf.nb select]]
  #set dimW [expr {$dimW + 44}]
  set dimH [expr {$dimH + $::EMC::gui::window_height}]

  wm geometry .emc [format "%ix%i" $dimW $dimH]
  
  # note: 44 and 47 take care of additional padding between nb tab and window
  # edges

  update idletasks
}


#==============================================================================
# Main proc to make all window options in the connectivity manager and setup
# all necessary variables
#==============================================================================

proc ::EMC::gui::MakeUpdatedPolymerGrid {treeviewpath windowpath} \
{
  # preprocessing and resetting of everything: deletes the current frames and
  # boxes prior to loading the new ones
  
  foreach w [winfo children $windowpath] {
    destroy $w
  }
  if {[llength [$treeviewpath children {}]] < 1} {
    return
  }
  # sets the reference array to allow the proc to retain existing clicked
  # buttons incase new polymers are addded
  # temporary local storage in oldpairs()

  set ::EMC::gui::polymernames {}
  if { [array exists ::EMC::gui::polymerarray] } {
    foreach {key value} [array get ::EMC::gui::polymerarray] {
      set oldpairs($key) $value
      unset ::EMC::gui::polymerarray($key)
    }
    array unset ::EMC::gui::polymerarray
  }

  # 1. from the treeview the grounames and groupsmiles are stored individually
  #    in local lists
  # 2. nested 4x loop checks existing entries or generates new ones in the
  #    polymerarry
  # general syntax: 
  # 	polymerarray(group1,group2,connectorofgroup1,connectorofgroup2)
  # 	either 0 or 1 depending on whether the checkbox is on or off

  foreach tvitem [$treeviewpath children {}] {
    set tvpolymer {}
    set tvpolymersmiles {} 
    foreach grouptvitem [lindex [$treeviewpath item $tvitem -values] 1] {
      lappend tvpolymer [lindex $grouptvitem 0]
      lappend tvpolymersmiles [lindex $grouptvitem 1]
    }
    for {set i 0} {$i < [llength $tvpolymer]} {incr i} {
      if {[llength  $::EMC::gui::polymernames] == 0} {
      lappend ::EMC::gui::polymernames "[ \
	lindex $tvpolymer $i] [ \
	  expr {[llength [split [lindex $tvpolymersmiles $i] "*"]] -1}] [ \
	lindex $tvpolymersmiles $i]"
      } elseif { [lsearch -index 0 $::EMC::gui::polymernames [ \
	  lindex $tvpolymer $i]] == -1} {
	lappend ::EMC::gui::polymernames "[ \
	  lindex $tvpolymer $i] [ \
	    expr {[llength [split [lindex $tvpolymersmiles $i] "*"]] -1}] [ \
	  lindex $tvpolymersmiles $i]"
	#set ::EMC::gui::polymernames [lsort -index 0 $::EMC::gui::polymernames]
      }
      for {set j $i} {$j < [llength $tvpolymer]} {incr j} {
	for { \
	    set k 1} { \
	    $k <= [ \
	      expr {[llength [split [lindex $tvpolymersmiles $i] "*"]] -1}]} { \
	    incr k} {
	  for { \
	      set l 1} { \
	      $l <= [ \
		expr {[llength [split [lindex $tvpolymersmiles $j] "*"]] -1}]} { \
	      incr l} {
	    if {[info exists ::EMC::gui::polymerarray([ \
		  lindex $tvpolymer $i],[lindex $tvpolymer $j],$k,$l)]} {
	      continue 
	    } elseif {[info exists oldpairs([ \
		  lindex $tvpolymer $i],[lindex $tvpolymer $j],$k,$l) ] } {
	      set \
		::EMC::gui::polymerarray([ \
		  lindex $tvpolymer $i],[lindex $tvpolymer $j],$k,$l) \
		$oldpairs([lindex $tvpolymer $i],[lindex $tvpolymer $j],$k,$l)
	    } else {
	      set \
		::EMC::gui::polymerarray([ \
		  lindex $tvpolymer $i],[lindex $tvpolymer $j],$k,$l) 0
	    } 
	  }
	}
      }
    }      
  }

  # delete the demporary array

  array unset oldpairs
  foreach entry [array names ::EMC::gui::polymerarray] {
    lappend entries $entry
  }
  # puts "polymernames $::EMC::gui::polymernames"
  
  # comment out this to keep order as entered in the gui
  # use leads to unordered connectivity table

  #set ::EMC::gui::polymernames [lsort -index 0 $::EMC::gui::polymernames]

  # generates all the labels, boxes and grids them accordingly
  # polymernames is scanned as a pairlist with i and j to probe all arrayitems
  # whether they exists and to place them at the right position

  for {set h 0} { $h < [llength $::EMC::gui::polymernames] } {incr h} {

    # top row of names of above the boxes

    ttk::labelframe $windowpath.frame0$h

    grid $windowpath.frame0$h \
      -column [expr {$h + 1}] -row 0 -sticky nsew
    ttk::label $windowpath.frame0$h.rowindex0$h \
      -text "[lindex $::EMC::gui::polymernames $h 0]" -anchor center
    grid $windowpath.frame0$h.rowindex0$h \
      -column 0 -row 0 -sticky nsew

    grid columnconfigure $windowpath.frame0$h 0 -weight 1
    grid rowconfigure $windowpath.frame0$h 0 -weight 1
    grid columnconfigure $windowpath $h -weight 0 -uniform polc -minsize 100
  }
  
  for {set i 0} {$i < [llength $::EMC::gui::polymernames]} {incr i} {

    # names left of the boxes generated here
    
    ttk::labelframe $windowpath.indexframe{$i}0
    
    grid $windowpath.indexframe{$i}0 \
      -column 0 -row [expr {$i + 1}] -sticky nsew
    ttk::label $windowpath.indexframe{$i}0.index{$i}0 \
      -text "[lindex $::EMC::gui::polymernames $i 0]" -anchor center
    grid $windowpath.indexframe{$i}0.index{$i}0 \
      -column 0 -row 0 -sticky nsew

    grid columnconfigure $windowpath.indexframe{$i}0 0 -weight 1
    grid rowconfigure $windowpath.indexframe{$i}0 0 -weight 1

    for {set j 0} {$j < [llength $::EMC::gui::polymernames]} {incr j} {

      # frames for the checkboxes are generated here
      
      ttk::labelframe $windowpath.box[expr {$i+1}][expr {$j+1}]
      grid $windowpath.box[expr {$i+1}][expr {$j+1}] -row [expr {$i+1}] \
	-column [expr {$j+1}] -sticky nsew
      
      set toggleallbox 0

      if {[expr {$j+1}] < $i} {
	continue
      }

      # these two loops iterate the rows of boxes and individual boxes

      for {set k 1} {$k <= [lindex $::EMC::gui::polymernames $i 1]} {incr k} {
	for {set l 1} {$l <= [lindex $::EMC::gui::polymernames $j 1]} {incr l} {
	  
	  # individual checkboxes are generated here and linked to the
	  # respective array entries
	  
	  if {[info exists \
	    ::EMC::gui::polymerarray([ \
	      lindex $::EMC::gui::polymernames $i 0],[ \
	      lindex $::EMC::gui::polymernames $j 0],$k,$l)]} {
	    set toggleallbox 1

	    ttk::checkbutton \
	      $windowpath.box[expr {$i+1}][expr {$j+1}].connector$k$l  \
	      -onvalue 1 -offvalue 0 \
	      -variable ::EMC::gui::polymerarray([ \
		lindex $::EMC::gui::polymernames $i 0],[ \
		lindex $::EMC::gui::polymernames $j 0],$k,$l)
	    
	    grid $windowpath.box[expr {$i+1}][expr {$j+1}].connector$k$l \
	      -row $k -column $l

	    # all following sets up the correct balloon for the correct
	    # checkboxes; function also works without this
	    
	    set path "$windowpath.box[expr {$i+1}][expr {$j+1}].connector$k$l"

	    # change length var to change what is shown in the bubbles
	    
	    set length 4
	    set pollist1 [ \
	      ::EMC::gui::StringGetInstances [ \
		lindex $::EMC::gui::polymernames $i 2] *]
	    set pollist2 [ \
	      ::EMC::gui::StringGetInstances [ \
		lindex $::EMC::gui::polymernames $j 2] *]
	    set count1 [lindex $pollist1 [expr {$k-1}]]
	    set count2 [lindex $pollist2 [expr {$l-1}]]

	    if {$count1 == 0} {
	      set smiles1 "[ \
		string range [ \
		  lindex $::EMC::gui::polymernames $i 2] 0 [ \
		  expr {0 + $length}]]\(...\)"
	    } elseif {$count1 == [lindex $pollist1 end]} {
	      set smiles1 "\(...\)[ \
		string range [ \
		  lindex $::EMC::gui::polymernames $i 2] [ \
		  expr {$count1 - $length}] [expr {$count1 + $length}]]\(...\)"
	    } else {
	      set smiles1 "\(...\)[ \
		string range [ \
		  lindex $::EMC::gui::polymernames $i 2] $count1 end]"
	    }

	    if {$count2 == 0} {
	      set smiles2 "[ \
		string range [ \
		  lindex $::EMC::gui::polymernames $j 2] 0 [ \
		  expr {0 + $length}]]\(...\)"
	    } elseif {$count2 == [lindex $pollist1 end]} {
	      set smiles2 "\(...\)[ \
		string range [ \
		  lindex $::EMC::gui::polymernames $j 2] [ \
		  expr {$count2 - $length}] [ \
		  expr {$count2 + $length}]]\(...\)"
	    } else {
	      set smiles2 "\(...\)[ \
		string range [ \
		lindex $::EMC::gui::polymernames $j 2] $count2 end]"
	    }
	    #set smiles1 "[string range [ \
	    #  lindex $::EMC::gui::polymernames $i 2] 0 5]\(...\)"
	    #set smiles2 "[string range [ \
	    #  lindex $::EMC::gui::polymernames $j 2] end-6 end]\(...\)"
	    set help "$smiles1 to $smiles2" 
	    ::EMC::gui::balloon $path $help

	  } else {
	    continue
	  }
	  grid columnconfigure $windowpath.box[expr {$i+1}][expr {$j+1}] $l \
	    -weight 1 -uniform box
	  grid rowconfigure $windowpath.box[expr {$i+1}][expr {$j+1}] $k \
	    -weight 1 -uniform box
	 }
      }
      if {$toggleallbox == 1} {

	# the all button is generated here; only generated if any array entries
	# for 2 group combination is allowed
      
	#set com "\{ ::EMC::gui::SelectAllBox $i $j \}"
	# -command { ::EMC::gui::SelectAllBox [eval $i] [eval $j] }
	ttk::button $windowpath.box[expr {$i+1}][expr {$j+1}].all$i$j \
	  -text "all" \
	  -command "::EMC::gui::SelectAllBox $i $j"
	grid $windowpath.box[expr {$i+1}][expr {$j+1}].all$i$j \
	  -row 0 -column 1 \
	  -columnspan [lindex $::EMC::gui::polymernames $j 1] -padx {5 5}
	grid columnconfigure $windowpath.box[expr {$i+1}][expr {$j+1}] 0 \
	  -weight 1
	grid rowconfigure $windowpath.box[expr {$i+1}][expr {$j+1}] 0 \
	  -weight 1
      }
    
      bind $windowpath.box[expr {$i+1}][expr {$j+1}] <Any-Enter> "
	$windowpath.frame0${j}.rowindex0${j} configure -background red ; $windowpath.indexframe{$i}0.index{$i}0 configure -background red ; 
      "
      bind $windowpath.box[expr {$i+1}][expr {$j+1}] <Any-Leave> "
	$windowpath.frame0${j}.rowindex0${j} configure -background gray ; $windowpath.indexframe{$i}0.index{$i}0 configure -background gray
      "
      #$windowpath.indexframe${i}0.index${i}0 configure -background gray
    }
    grid rowconfigure $windowpath $i -uniform polc -weight 0 -minsize 100
  }
}


#==============================================================================
# This proc provides the strings for the polymer group definitions based on the
# 0,1 of the polymerarray
#==============================================================================

proc ::EMC::gui::WriteGroupDefinitionsPolymer {grouplistname} \
{
  for {set i 0} {$i < [llength $::EMC::gui::polymernames]} {incr i} { 
    set ConnectivityOfGroup [list [lindex $::EMC::gui::polymernames $i 2]]
    for {set j 0} {$j < [llength $::EMC::gui::polymernames]} {incr j} {
      for {set k 1} {$k <= [lindex $::EMC::gui::polymernames $i 1]} {incr k} {
	for {set l 1} {$l <= [lindex $::EMC::gui::polymernames $j 1]} {incr l} {
	  if {[info exists \
	      ::EMC::gui::polymerarray([ \
		lindex $::EMC::gui::polymernames $i 0],[ \
		lindex $::EMC::gui::polymernames $j 0],$k,$l)] && 
	      $::EMC::gui::polymerarray([ \
		lindex $::EMC::gui::polymernames $i 0],[ \
		lindex $::EMC::gui::polymernames $j 0],$k,$l) == 1} {
	    lappend ConnectivityOfGroup ",$k,[ \
	      lindex [split [lindex $::EMC::gui::polymernames $j 0] ":"] 0]:$l"
	  } else {
	    continue
	  }
	}
      }
    }
    lappend ::EMC::gui::GroupList "[ \
      lindex $::EMC::gui::polymernames $i 0] [join $ConnectivityOfGroup ""]"
  }
}

#==============================================================================
# Writes the group definitions for small molecules
# TODO: use the list running in background of treeview for "cleaner" code
#==============================================================================

proc ::EMC::gui::WriteGroupDefinitionsMolecule {grouplistname treeviewpath} \
{
  foreach tvitem [.emc.hlf.nb.chemistry.definechemistry.tv children {}] {
    if {[lindex [$treeviewpath item $tvitem -values] 1] == "small_molecule"} {
      lappend $grouplistname "[ \
	lindex [$treeviewpath item $tvitem -values] 0] [ \
	lindex [$treeviewpath item $tvitem -values] 2]"
    }
  }
}


#==============================================================================
# Writes all cluster entries depending on type
# If concentration variables are used these are also specified here instead of
# the number value
#==============================================================================

proc ::EMC::gui::WriteClusters {treeviewpath trialname} \
{
  append clusters "\n# Clusters section\n\n"
  append clusters "ITEM\tCLUSTERS\n\n"
  foreach tvitem [.emc.hlf.nb.chemistry.definechemistry.tv children {}] {
    set loopindex [ \
      lsearch -index 0 $::EMC::gui::LoopList "[ \
	string tolower [lindex [$treeviewpath item $tvitem -values] 0]_c*]"]
    if {[string first ":" [lindex $::EMC::gui::LoopList $loopindex]] != -1 &&
	$loopindex != -1} {
      set concentrationvar [ \
	string toupper "@{[ \
	  lindex [split [lindex $::EMC::gui::LoopList $loopindex 0] ":"] 0]}"]
    } elseif {$loopindex != -1} {
      set concentrationvar [ \
	string toupper "@{[lindex $::EMC::gui::LoopList $loopindex 0]}"]
    }
    if {[ \
	  lindex [$treeviewpath item $tvitem -values] 1] == "small_molecule" &&
	$loopindex == -1} {
      append clusters "[ \
	format $::EMC::gui::formatstrtriple [ \
	  lindex [$treeviewpath item $tvitem -values] 0] [ \
	  lindex [$treeviewpath item $tvitem -values] 0] [ \
	  lindex [$treeviewpath item $tvitem -values] 3]]\n"
    } elseif {[ \
	  lindex [$treeviewpath item $tvitem -values] 1] == "polymer" &&
	$loopindex == -1} {
      append clusters "[ \
	format $::EMC::gui::formatstrtriple [ \
	  lindex [$treeviewpath item $tvitem -values] 0] [ \
	  lindex [$treeviewpath item $tvitem -values] 2] [ \
	  lindex [$treeviewpath item $tvitem -values] 3]]\n"
    } elseif {[ \
	  lindex [$treeviewpath item $tvitem -values] 1] == "surface" &&
	$loopindex == -1} {
      append clusters "$::EMC::gui::surfoptions(name) \t import \t 1 \t \"$::EMC::gui::surfoptions(filename)\" \t $::EMC::gui::surfoptions(inputtype)\n"
    } elseif {[lindex [$treeviewpath item $tvitem -values] 1] == "TRIAL" && \
	      $loopindex == -1} {
      append clusters "[ \
	format \
	  $::EMC::gui::formatstrtriple \
	  $::EMC::gui::trials($trialname,molname) \
	  $::EMC::gui::trials($trialname,molname) [ \
	lindex [$treeviewpath item $tvitem -values] 3]]\n"
    } elseif {[ \
	  lindex [$treeviewpath item $tvitem -values] 1] == "small_molecule" && 
	$loopindex != -1} {
     append clusters "[ \
      format $::EMC::gui::formatstrtriple [ \
	lindex [$treeviewpath item $tvitem -values] 0] [ \
	lindex [$treeviewpath item $tvitem -values] 0] $concentrationvar]\n"
    } elseif {[ \
	  lindex [$treeviewpath item $tvitem -values] 1] == "polymer" && \
	$loopindex != -1} {
      append clusters "[ \
	format $::EMC::gui::formatstrtriple [ \
	  lindex [$treeviewpath item $tvitem -values] 0] [ \
	  lindex [$treeviewpath item $tvitem -values] 2] $concentrationvar]\n"

    } elseif  {[ \
	  lindex [$treeviewpath item $tvitem -values] 1] == "TRIAL" && \
	$loopindex != -1} {
      append clusters "[ \
	format \
	  $::EMC::gui::formatstrtriple \
	  $::EMC::gui::trials($trialname,molname) \
	  $::EMC::gui::trials($trialname,molname) $concentrationvar]\n"
    }
  }
  append clusters "\nITEM\tEND\t# CLUSTERS\n"
  return $clusters
}


#==============================================================================
# Reads any tabular format with two entries
# Used for reading group name and smiles string of tabular lists
#==============================================================================

proc ::EMC::gui::ReadTabular {input_file_name} \
{
  set output_list {}
  set file [open "$input_file_name" r]
  set output_list_name {}
  while {[gets $file line] > -1} {
    if {[string first \# $line] != -1} {
      continue
    }
    if {[llength $line] =!} {
      continue
    }
    lappend output_list "[lindex $line 0] [lindex $line 1]"
  }
  close $file
  return $output_list
}


#==============================================================================
# Populates the lists which are called in the first
# Used in the initialize proc when opening the winow
#==============================================================================

proc ::EMC::gui::PopulateGuiOptions {list_name} \
{
  foreach option $list_name {
    #puts $option
    switch -exact "[lindex $option 5] [lindex $option 6]" {
      "emc standard" {
	lappend ::EMC::gui::basicemcoptionslist "[ \
	  lindex $option 0] [ \
	  lindex $option 2] [ \
	  lindex $option 3] {[lindex $option 1]}"
      }
      "emc advanced" {
	lappend ::EMC::gui::advancedemcoptionslist "[ \
	  lindex $option 0] [ \
	  lindex $option 2] [ \
	  lindex $option 3] {[lindex $option 1]}"
      }
      "lammps standard" {
	lappend ::EMC::gui::basiclammpslist "[ \
	  lindex $option 0] [ \
	  lindex $option 2] [ \
	  lindex $option 3] {[lindex $option 1]}"
      }
      "lammps advanced" {
	lappend ::EMC::gui::advancedlammpslist "[ \
	  lindex $option 0] [ \
	  lindex $option 2] [ \
	  lindex $option 3] {[lindex $option 1]}"
      }
    }
    switch -exact [lindex $option 5] {
      "analysis" {
	lappend ::EMC::gui::analysisoptions "[ \
	  lindex $option 0] [ \
	  lindex $option 2] [ \
	  lindex $option 3] {[lindex $option 1]} [lindex $option 6]"
      }
      "field" {
	lappend ::EMC::gui::forcefield "[ \
	  lindex $option 0] [ \
	  lindex $option 2] [ \
	  lindex $option 3] {[lindex $option 1]} [lindex $option 6]"
      }
      "top" {
	lappend ::EMC::gui::top "[ \
	  lindex $option 0] [ \
	  lindex $option 2] [ \
	  lindex $option 3] {[lindex $option 1]} [lindex $option 6]"
      }
    }
  }
}


#==============================================================================
# Used prior to final rbuild
# Set options are placed in the final esh file according to their identifier in
# the input text file
#==============================================================================

proc ::EMC::gui::PopulateScriptList {list_name} {
  foreach option $list_name {
    if {[info exists ::EMC::gui::options([lindex $option 0])] == 0} {
      continue
    }

    set mode [lindex $option 4]
    set keyword [lindex $option 0]
    set default [lindex $option 2]
    set value $::EMC::gui::options([lindex $option 0])
      
    if {$keyword == "field_location"} { continue; }
    if {$keyword == "field_name"} { set keyword "field"; }
    if {$::EMC::gui::writealloptions == "false" && "$default" == "$value" && \
	[info exists ::EMC::gui::options([lindex $option 0],usr)] != 1} {
      continue
    } elseif {[lindex $option 6] == "ignore"} {
      continue
    } elseif {$value == "-" || $value == ""} {
      continue
    } elseif { \
	$::EMC::gui::writealloptions == "true" && "$default" == "$value"} {
      switch -exact $mode {
	"environment" {
	  lappend ::EMC::gui::MainOptionList "#$keyword $value"
	}
	"chemistry" {
	  lappend ::EMC::gui::TemplateOptionList "#$keyword $value"
	}
      }
    } else {
#      puts "[LINE [info frame]]: $keyword = $value ($default)"
      switch -exact $mode {
	"environment" {
	  lappend ::EMC::gui::MainOptionList "$keyword $value"
	}
	"chemistry" {
	  lappend ::EMC::gui::TemplateOptionList "$keyword $value"
	}
      }
    }
  }
  lappend ::EMC::gui::MainOptionList "environment true"
  if {$::EMC::gui::options(replace) == "true"} {
    lappend ::EMC::gui::TemplateOptionList "replace true"
  }
}


#==============================================================================
# Main build process where the text file is pieced together
#==============================================================================

proc ::EMC::gui::BuildFile {} \
{
  puts "Info) Writing EMC Script to '[pwd]/$::EMC::gui::options(filename)'"

  set f [open $::EMC::gui::options(filename) "w"]
  set FileContent $::EMC::gui::header_setup
  set MainOptions [::EMC::gui::WriteMainOptions]
  
  append FileContent "$MainOptions"

  if {[llength $::EMC::gui::LoopList] != 0} {
    set Loops [::EMC::gui::WriteLoops]
    append FileContent "$Loops"
  }

  set stage [::EMC::gui:::WriteStage]
  append FileContent $stage
  set Template [::EMC::gui::WriteTemplate]
  append FileContent "$Template"
  if {$::EMC::gui::WriteClusterToTemplate == "false" || \
      $::EMC::gui::WriteGroupsToTemplate == "false"} {
    set trial [::EMC::gui::WriteTrials]
    append FileContent $trial
  }

  puts $f $FileContent
  close $f
}


#==============================================================================
#
#==============================================================================

proc ::EMC::gui::Format {keyword items} \
{
  set l [string length [lindex $keyword 0]]
  
  if {$l < 8} {
    return "$keyword\t\t[join $items ", "]"
  } elseif {$l < 16} {
    return "$keyword\t[join $items ", "]"
  }
  return "$keyword [join $items ", "]"
}


#==============================================================================
# Writes all options which are environment options
# keys for hash taken from mainoptionlist
#==============================================================================

proc ::EMC::gui::WriteMainOptions {} \
{
#  puts "[LINE [info frame]]: WriteMainOptions"
  set content ""
  append content "\n# Options section\n\n"
  append content "ITEM\tOPTIONS\n\n"
  foreach item $::EMC::gui::MainOptionList {
    set main_option [lindex $item 0]
    set main_option_value [lindex $item 1]
    append content "[ \
      ::EMC::gui::Format $main_option $main_option_value]\n"
  }
  append content "\nITEM\tEND\t# OPTIONS\n"
  return $content
}


#==============================================================================
# Prints all items in loop list to the file
#==============================================================================

proc ::EMC::gui::WriteLoops {} \
{
  set loops ""
  append loops "\n# Loops section\n\n"
  append loops "ITEM\tLOOPS\n\n"
  foreach item $::EMC::gui::LoopList {
    set loop_values ""
    for {set i 1} {$i <= [llength $item]} {incr i} {
      if {[string first "_conc" [lindex $item 0]] != -1 && $i == 1} {
	continue
      } else {
	append loop_values "[lindex $item $i] "
      }
    }
    set loop_option [lindex $item 0]
    if {[string first "_conc" [lindex $item 0]] != -1} {
      append loops "[ \
	::EMC::gui::Format $loop_option [lindex $item 1]] $loop_values\n"
    } else {
      append loops "[ \
	::EMC::gui::Format $loop_option $loop_values]\n"
    }
  }
  append loops "\nITEM\tEND\t# LOOPS\n"
  return $loops
}


#==============================================================================
# Writes a stage element with a stage name
# TODO: currently only one stage is written by default
# Theoretically multiple stages could be implemented in the gui at this pointer
# each stage would have a stage name associated with it
#==============================================================================

proc ::EMC::gui::WriteStage {} \
{
  set stage ""
  set stagename [ \
    lindex $::EMC::gui::LoopList [ \
      lsearch -index 0 $::EMC::gui::LoopList "stage"] 1]
  append stage "\nITEM\tSTAGE\t$stagename\n"
  return $stage
}


#==============================================================================
# Writes all information of the template
# Options written are all chemistry options
# Calls subroutines to write the clusters and groups etc.
# TODO: switch is installed which either writes the groups/clusters to the
# 	template or to the respective trial
# This is currently unused: all groups are written to the template and all 
# 	clusters to the individual trials
#==============================================================================

proc ::EMC::gui::WriteTemplate {} \
{
  set template ""
  
  append template "\n# Template section\n\n"
  append template "ITEM\tTEMPLATE\n"
  append template "\n# Template options section\n\n"
  append template "ITEM\tOPTIONS\n\n"
  foreach item $::EMC::gui::TemplateOptionList {
    append template "[ \
      ::EMC::gui::Format [lindex $item 0] [join [lrange $item 1 end] " "]]\n"
  }
  append template "\nITEM\tEND\t# OPTIONS\n"

  if {$::EMC::gui::WriteGroupsToTemplate == true} {
    set Groups [::EMC::gui::WriteGroups .emc.hlf.nb.chemistry.trials.tv]
    append template "$Groups"
  } elseif {$::EMC::gui::WriteGroupsToTemplate == false} {
    append template "\n# Groups section\n\n"
    append template "ITEM\tGROUPS\n\n"
    append template "@{GROUPS}\n\n"
    append template "ITEM\tEND\t# GROUPS\n"
  }

  if {$::EMC::gui::WriteClusterToTemplate == "true"} {
    set Cluster [::EMC::gui::WriteClusters .emc.hlf.nb.chemistry.definechemistry.tv]
    append template "$Clusters"
  } elseif {$::EMC::gui::WriteClusterToTemplate == "false"} {
    append template "\n# Clusters section\n\n"
    append template "ITEM\tCLUSTERS\n\n"
    append template "@{CLUSTERS}\n\n"
    append template "ITEM\tEND\t# CLUSTERS\n"
  } elseif {$::EMC::gui::UsePolymers == "true"} {
    set polymers [::EMC::gui::WritePolymer]
    append template "$polymers"
  }

  if {$::EMC::gui::UsePolymers == "true"} {
    set polymers [::EMC::gui::WritePolymer]
    append template "$polymers"
  }

  append template "\nITEM\tEND\t# TEMPLATE\n"

  return $template
}


#==============================================================================
# Writes the trials
# Calls subroutines to write out the clusters and groups in accordance with
# 	what is written in the template_option
# Same switch as above is used to define whether groups or clusters are written
# 	here or not
#==============================================================================

proc ::EMC::gui::WriteTrials {} \
{
  set alltrials "\n# Trials sections\n"
  set triallist [lindex $::EMC::gui::LoopList [lsearch -all -index 0 $::EMC::gui::LoopList "trial"]]
  for {set i 1} {$i <= [expr {[llength $triallist] - 1}]} {incr i} {
    append alltrials "\nITEM\tTRIAL\t[lindex $triallist $i]\n"
    if {$::EMC::gui::WriteClusterToTemplate == "false"} {
    set Cluster [ \
      ::EMC::gui::WriteClusters \
      .emc.hlf.nb.chemistry.definechemistry.tv \
      [lindex $triallist $i]]
    append alltrials "$Cluster"
    }
    if {$::EMC::gui::WriteGroupsToTemplate == "false"} {
      set Groups [::EMC::gui::WriteGroups .emc.hlf.nb.chemistry.trials.tv]
      append alltrials "$Groups"
    }
  }
  return $alltrials
}


#==============================================================================
#
#==============================================================================

proc ::EMC::gui::WriteTrialLoopListItem {treeviewpath} {
  if {[lsearch -index 0 $::EMC::gui::LoopList "trial"] != -1} {
    set ::EMC::gui::LoopList [ \
      lreplace $::EMC::gui::LoopList [ \
	lsearch -index 0 $::EMC::gui::LoopList "trial"] [ \
	lsearch -index 0 $::EMC::gui::LoopList "trial"]]
  }
  if {$::EMC::gui::trials(use) == "true"} {
    set trialentry {}
    lappend trialentry "trial"
    foreach tvitem [$treeviewpath children {}] {
      lappend trialentry [lindex [$treeviewpath item $tvitem -values] 2]
    }
    lappend ::EMC::gui::LoopList $trialentry
  } elseif {$::EMC::gui::trials(use) == "false"} {
     set trialentry {}
    lappend trialentry "trial"
    lappend trialentry $::EMC::gui::trials(defaulttrial)
    lappend ::EMC::gui::LoopList $trialentry

  }
}


#==============================================================================
#
#==============================================================================

proc ::EMC::gui::WriteStageLoopListItem {} \
{
  set stageentry ""
  lappend stageentry "stage"
  lappend stageentry "$::EMC::gui::stages(defaultstage)"
  lappend ::EMC::gui::LoopList $stageentry
}


#==============================================================================
# Writes the number of copies
# Copies are in the loop code block but only have the a single number for the
# 	number of runs
#==============================================================================

proc ::EMC::gui::WriteCopiesLoopItem {} {
  if {$::EMC::gui::options(multicopies) == "" || \
      $::EMC::gui::options(multicopies) == 1} {
    return
  } else {
    set copiesentry ""
    lappend copiesentry "copy"
    lappend copiesentry $::EMC::gui::options(multicopies)
    lappend ::EMC::gui::LoopList $copiesentry
  }
}


#==============================================================================
# Writes the ITEM POLYMER section
# Uses the information stored in the polymer item list
#==============================================================================

proc ::EMC::gui::WritePolymer {} \
{
  if {[llength $::EMC::gui::PolymerItem] == 0} {
     return
  } else {
    append polymer "\n# Polymers section\n\n"
    append polymer "ITEM\tPOLYMERS\n\n"
    foreach item $::EMC::gui::PolymerItem {
      append polymer "[lindex $item 0] \n"
      append polymer "1\t"
      set groupquantitylist {}
      foreach groupslist [lindex $item 1] {
	lappend groupquantitylist [lindex [split [lindex $groupslist 0] ":"] 0]
	lappend groupquantitylist [lindex [split [lindex $groupslist 2] ":"] 0]
      }
      append polymer "[ \
	join $groupquantitylist ","]\n"
    }
    append polymer "\nITEM\tEND\t# POLYMERS\n"
  }
  return $polymer
}

#==============================================================================
# Writes all groups according to the group list to the file.
#==============================================================================

proc ::EMC::gui::WriteGroups {treeviewpath} \
{
  set groups ""

  append groups "\n# Groups section\n\n"
  append groups "ITEM\tGROUPS\n\n"
  foreach groupitem $::EMC::gui::GroupList {
    append groups "[ \
      ::EMC::gui::Format [ \
	lindex $groupitem 0] [ \
	lindex $groupitem 1]]\n"
  }
  foreach tvitem [$treeviewpath children {}] {
    append groups "[ \
      ::EMC::gui::Format [ \
	lindex [$treeviewpath item $tvitem -values] 0] [ \
	lindex [$treeviewpath item $tvitem -values] 1]]\n"
  }
  append groups "\nITEM\tEND\t# GROUPS\n"
  return $groups
}


#==============================================================================
# !!CURRENTLY NOT IN USE: Translation of surface
#==============================================================================

proc ::EMC::gui::WriteSurfaceVerbatim {} {
  if {[info exists ::EMC::gui::surfoptions(name)] == 0} {
    return
  }
  if {$::EMC::gui::surfoptions(placement) == "verbatimtrue"} {
    set verbatim ""
    append verbatim "\n# EMC section\n\n"
    append verbatim "ITEM\tEMC\n\n"
    append verbatim "translate = \{delta -> \{0.5*geometry(id -> xx), 0, 0\}\}\n"
    append verbatim "\nITEM\tEND\t# EMC\n"
  }
  return $verbatim
}


#==============================================================================
# Calculates the number of phases according to the numbers in the treeview
# This is direcly extracted from the treeview and not called from a separate 
# 	list
#==============================================================================

proc ::EMC::gui::WritePhaseVar {treeviewpath} \
{
  set phaselist {}
  foreach tvitem [$treeviewpath children {}] {
    if {[lindex [$treeviewpath item $tvitem -values] 1] == "surface"} {
      continue
    }
    if {[lsearch $phaselist [ \
	lindex [$treeviewpath item $tvitem -values] 4]] == -1} {
      lappend phaselist [lindex [$treeviewpath item $tvitem -values] 4]
    }
  }
  set phaselist [lsort $phaselist]
  set finalphaselist {}
  if {[llength $phaselist] == 1} {
    return
  } elseif {[llength $phaselist] > 1} {
    foreach phase $phaselist {
      set tempphasedefs {}
      foreach tvitem [$treeviewpath children {}] {
	if {[lindex [$treeviewpath item $tvitem -values] 1] == "surface"} {
	  continue
	}
	if {[lindex [$treeviewpath item $tvitem -values] 4] == $phase} {
	  lappend tempphasedefs "[ \
	    lindex [$treeviewpath item $tvitem -values] 0]"
	}
      }
      lappend finalphaselist "$tempphasedefs"
    }
  }
  set ::EMC::gui::options(phases) "{[join $finalphaselist " + "]}"
}


#==============================================================================
# This should delete all array items which are too much
#==============================================================================

proc ::EMC::gui::DeletePolymerItem {polymername} \
{
  set deleteentrieslist [ \
    lindex $::EMC::gui::PolymerItem [ \
      lsearch -index 0 $::EMC::gui::PolymerItem $polymername]]
  set ::EMC::gui::PolymerItem [ \
    lreplace $::EMC::gui::PolymerItem [ \
      lsearch -index 0 $::EMC::gui::PolymerItem $polymername] [ \
      lsearch -index 0 $::EMC::gui::PolymerItem $polymername]]
  set deletegrouplist [lindex $deleteentrieslist 1]
  for {set i 0} {$i < [llength $deletegrouplist]} {incr i} {
    set ::EMC::gui::polymernames [ \
      lreplace $::EMC::gui::polymernames [ \
	lsearch -index 0 $::EMC::gui::polymernames [ \
	  lindex $deletegrouplist $i 0]] [ \
	lsearch -index 0 $::EMC::gui::polymernames [ \
	  lindex $deletegrouplist $i 0]]]
    for {set j $i} {$j < [llength $deletegrouplist]} {incr j} {
      if {[llength $::EMC::gui::PolymerItem] == 0} {
	array unset ::EMC::gui::polymerarray [ \
	  lindex $deletegrouplist $i 0],[lindex $deletegrouplist $j 0],*
	continue
      }
      foreach item $::EMC::gui::PolymerItem {
	if {[lsearch -index 0 [ \
	      lindex $item 1] [ \
	      lindex $deletegrouplist $i 0]] == -1 && 
	    [lsearch -index  0 [ \
	      lindex $item 1] [ \
	      lindex $deletegrouplist $j 0]] == -1 } {
	  array unset ::EMC::gui::polymerarray [ \
	    lindex $deletegrouplist $i 0],[lindex $deletegrouplist $j 0],*
	}  
      }
    }
  }
 
  if {[winfo exists .emcpoly] == 1} {
    foreach tvitem [.emcpoly.hlf.polymer.tv children {}] {
      if {[lindex [ \
	    .emcpoly.hlf.polymer.tv item $tvitem -values] 0] == $polymername} {
 	.emcpoly.hlf.polymer.tv delete $tvitem
      }
    }
  }

  if {[winfo exists .emcpolconnect] == 1} {
    destroy .emcpolconnect 
    emcpolconnect
  }
}


#==============================================================================
# Assigned to each all button in the MakePolymerUpdateGrid process 
# i and j are passed to ensure it only deletes the given box content
#==============================================================================

proc ::EMC::gui::SelectAllBox {ival jval} \
{
  for {set k 1} {$k <= [lindex $::EMC::gui::polymernames $ival 1]} {incr k} {
    for {set l 1} {$l <= [lindex $::EMC::gui::polymernames $jval 1]} {incr l} {
      if {[info exists \
	    ::EMC::gui::polymerarray([ \
	      lindex $::EMC::gui::polymernames $ival 0],[ \
	      lindex $::EMC::gui::polymernames $jval 0],$k,$l)]} {
	set ::EMC::gui::polymerarray([ \
	  lindex $::EMC::gui::polymernames $ival 0],[ \
	  lindex $::EMC::gui::polymernames $jval 0],$k,$l) 1
      } else {
	continue
      }
    }
  }
}


#==============================================================================
# Setting arg is 0 to turn everything off and 1 to turn everything on
# found in global setting drop down
#==============================================================================

proc ::EMC::gui::PolymerSelectionAllNone {setting} \
{
  for {set i 0} {$i < [llength $::EMC::gui::polymernames]} {incr i} {
    for {set j 0} {$j < [llength $::EMC::gui::polymernames]} {incr j} {
      for {set k 1} {$k <= [lindex $::EMC::gui::polymernames $i 1]} {incr k} {
	for {set l 1} {$l <= [lindex $::EMC::gui::polymernames $j 1]} {incr l} {
	  if {[info exists \
		::EMC::gui::polymerarray([ \
		  lindex $::EMC::gui::polymernames $i 0],[ \
		  lindex $::EMC::gui::polymernames $j 0],$k,$l)]} {
	    set ::EMC::gui::polymerarray([ \
	      lindex $::EMC::gui::polymernames $i 0],[ \
	      lindex $::EMC::gui::polymernames $j 0],$k,$l) $setting
	  } else {
	    continue
	  }
	}
      }
    }
  }
}


#==============================================================================
# Sets head tail of all polymers
# Found in the global setting drop down
#==============================================================================

proc ::EMC::gui::PolymerSelectionSchemeHeadTail {} \
{
  foreach {key value} [array get ::EMC::gui::polymerarray] {
    set ::EMC::gui::polymerarray($key) 0
  }
  for {set i 0} {$i < [llength $::EMC::gui::polymernames]} {incr i} {
    for {set j 0} {$j < [llength $::EMC::gui::polymernames]} {incr j} {
      set ::EMC::gui::polymerarray([ \
	lindex $::EMC::gui::polymernames $i 0],[ \
	lindex $::EMC::gui::polymernames $j 0],1,[ \
	lindex $::EMC::gui::polymernames $j 1]) 1
      set ::EMC::gui::polymerarray([ \
	lindex $::EMC::gui::polymernames $i 0],[ \
	lindex $::EMC::gui::polymernames $j 0],[ \
	lindex $::EMC::gui::polymernames $i 1],1) 1  
     }
   }
}


#==============================================================================
# Appends the looplist with arguments
#==============================================================================

proc ::EMC::gui::WriteEnsembleVars {varname} \
{
  set templooparglist $varname
  if {[string first \, $::EMC::gui::options($varname)] != -1} {
    set splitlist [split $::EMC::gui::options($varname) ","]
    set templooparglist [concat $templooparglist $splitlist]
    lappend ::EMC::gui::LoopList $templooparglist
    set ::EMC::gui::options($varname,temporary) $::EMC::gui::options($varname)
    set ::EMC::gui::options($varname) "@{[string toupper $varname]}"
  } else {
    set ::EMC::gui::options($varname,temporary) $::EMC::gui::options($varname)
  }
}

#==============================================================================
# Writes the loop items for the concentrations
# Each compound is given its own loop variable
# By default, the concentation are treated as paired and the first entry as
# 	double
#==============================================================================

proc ::EMC::gui::WriteConcLoops {treeviewpath} \
{
  set i 1
  foreach tvitem [$treeviewpath children {}] {
    set concentrations [ \
      split [lindex [$treeviewpath item $tvitem -values] 3] ","]
    set data ""
    if {[llength $concentrations] > 1 && 
	$i == 1 && 
	$::EMC::gui::pairconcentration == "true"} {
      append data "[ \
	string tolower [lindex [$treeviewpath item $tvitem -values] 0]_conc]:d"
      set data [concat $data $concentrations]
      lappend ::EMC::gui::LoopList $data
    } elseif {[llength $concentrations] > 1 && 
	      $i != 1 &&
	      $::EMC::gui::pairconcentration == "true"} {
      append data "[ \
	string tolower [lindex [$treeviewpath item $tvitem -values] 0]_conc]:p"
      set data [concat $data $concentrations]
      lappend ::EMC::gui::LoopList $data
    } elseif {[llength $concentrations] > 1 && 
	      $::EMC::gui::pairconcentration == "false"} {
      append data "[ \
	string tolower [lindex [$treeviewpath item $tvitem -values] 0]_conc]"
      set data [concat $data $concentrations]
      lappend ::EMC::gui::LoopList $data
    }
    incr i
  }
}


#==============================================================================
# Checks the concentration entries of all components in the system
# Concentrations must be comma separated without spaces
# Decimal points are allowed
#==============================================================================

proc ::EMC::gui::CheckConcentration {treeviewpath} \
{
  set errorlist {}
  set maxlength 1 
  foreach tvitem [$treeviewpath children {}] {
    if {[llength [split [\
	  lindex [$treeviewpath item $tvitem -values] 3] ","]] > $maxlength} {
      set maxlength [llength [split [ \
	  lindex [$treeviewpath item $tvitem -values] 3] ","]]
    }
  }
  foreach tvitem [$treeviewpath children {}] {
    if {[llength [split [ \
	  lindex [$treeviewpath item $tvitem -values] 3] " "]] != 1} {
      lappend errorlist [ \
	list \
	  "[lindex [$treeviewpath item $tvitem -values] 0]" \
	  "Illegal whitespace"]
    }
    if {[llength [split [ \
	  lindex [$treeviewpath item $tvitem -values] 3] ","]] == 1 &&
	$maxlength != 1} {
      lappend errorlist [ \
	list \
	  "lindex [$treeviewpath item $tvitem -values] 0]" \
	  "length not matched! No multiple entries."]
    }
    if {[llength [split [ \
	  lindex [$treeviewpath item $tvitem -values] 3] ","]] != $maxlength } {
      set discrepancy [expr { $maxlength -[llength [split [ \
	  lindex [$treeviewpath item $tvitem -values] 3] ","]] }]
      lappend errorlist [ \
	list \
	  "[lindex [$treeviewpath item $tvitem -values] 0]" \
	  "length differs by $discrepancy entries"]
    }
    if {[llength [split [ \
	  lindex [$treeviewpath item $tvitem -values] 3] ":"]] != 1} {
      lappend errorlist [ \
	list \
	  "[lindex [$treeviewpath item $tvitem -values] 0]" \
	  "Illegal symbol (:) in concentrationlist"]
    }
  }
  if {[llength $errorlist] > 0} {
    set messagetext ""
    foreach index $errorlist {
      append messagetext "[lindex $index 0]: [lindex $index 1]\n"
    }
    tk_messageBox -type ok -icon error \
      -title "Concentration Irregularity" -parent .emc \
      -message "$messagetext"
    return 1
  }
  return 0
}


#==============================================================================
# NOT USED - TRASH !!
#==============================================================================

proc ::EMC::gui::AutoCompleteConcentrations {treeviewpath} \
{
  # automatically complete according to logic
  
  set concentrationlist {}
  set max 0
  set maxname ""
  set sumofconc 0
  set sumofconclocked 0
  foreach [$treeviewpath children {}] {
    if {[lindex $tvitem 7] == 1} {
     set sumofconclocked [expr {$sumofconclocked + [lindex [split [lindex $tvitem 3] ","] 0]}]
     set sumofconc [expr {$sumofconc + [lindex [split [lindex $tvitem 3] ","] 0]}]
    } 
  }
  foreach tvitem [$treeviewpath children {}] {
    set tempstorage ""
    append tempstorage "[lindex $tvitem 0]"
    append tempstorage "[split [lindex $tvitem 3] ","]"
    append tempstorage "[llength [split [lindex $tvitem 3] ","]]"
    append tempstorage "[lindex $tvitem 7]"
    append tempstorage "[expr {[lindex $tvitem 7] / sumofconclocked} ]"
    lappend concentrationlist $tempstorage
    
    if {[llength [split [lindex $tvitem 3] ","]] > $max} {
      set max [llength [split [lindex $tvitem 3] ","]] 
      set maxname [lindex $tvitem 0]
    }
  } 
  if {$max < 2} {
    tk_messageBox -type ok -icon error -title "Autocomplete Failed" \
	-message "Only single concentration given. Nothing to complete."
    return
  }
  foreach tvitem [$treeviewpath children {}] {
    if {$max == [lindex $tvitem 3]} {
      continue
    }
    if {[lindex $tvitem 6] == 0 } {
      continue 
    }
    if {[lindex $tvitem 5] == 1} {
      set difference [expr {$max - [llength [split [lindex $tvitem 3] ","]]}
      foreach [lindex $concentrationlist 2] {
	
      }
    } elseif {[lindex $tvitem 6] == 1} {
      
      # constant concentration throughout simulation
      
      set difference [expr {$max - [llength [split [lindex $tvitem 3] ","]]}
      set refconc [lindex [split [lindex $tvitem 3] ","]] 0]
      set currentconc [lindex $tvitem 3]
      for {set i 1} {$i <= $difference} {incr i} {
	append currentconc ",$refconc"
      }
      set editdata [$treeviewpath item [$treeviewpath $tvitem -values]]
      set ::EMC::gui::tempconcentration $currentconc
      set ::EMC::gui::tempphase [lindex $editdata 4]
      set ::EMC::gui::tempname [lindex $editdata 0]
      set ::EMC::gui::temptype [lindex $editdata 1]
      set ::EMC::gui::teppolymer [lindex $editdata 2]
      set ::EMC::gui::tempconstm
      set ::EMC::gui::templock
      $treeviewpath item [$treeviewpath $tvitem] \
	-values [list ]
    }
  }
}


proc ::EMC::gui::NormalizeAllEntriesPercent {} \
{
}


proc ::EMC::gui::MakeConcentrationTable {} \
{
  # similar to write loops 
  # writes up all simulations which are written to the 
}


proc ::EMC::gui::WildcardEntry {treeviewpath} \
{
  # sample multiple compounds
  
  $treeviewpath insert {} end -id Trialknot -text "Wildcard"
  $treeviewpath insert Trialknot end -values [list test test test test test]
  $treeviewpath insert Trialknot end -values [list test test test test test]
}


#==============================================================================
#
#==============================================================================

proc ::EMC::gui::WriteConcentrations {} \
{
  set refconc ::EMC::gui::tempconcentration
  foreach tvitem [.emc.hlf.nb.chemistry.definechemistry.tv children {}] {
    set newconc [expr {[lindex [ \
	.emc.hlf.nb.chemistry.definechemistry.tv item [ \
	.emc.hlf.nb.chemistry.definechemistry.tv selection] \
      -values] 0] / $refconc}]
  }
}


#==============================================================================
# Saves the group items as table
#==============================================================================

proc ::EMC::gui::SaveGrouptable {treeviewpath} \
{
  set types {
    {{ESH Files} {.esh}}
    {{Text Files} {.txt}} 
    {{All Files} *}
  }
  set tempfile [ \
    tk_getSaveFile \
      -title "Save File As" \
      -defaultextension {.txt} \
      -filetypes $types]

  if {$tempfile ne ""} {
    set f [open $tempfile w]
    set formatstr {%-15s%-15s}

    puts $f "#Generated with the EMC gui"
    foreach tvitem [$treeviewpath children {}] {
      puts $f [ \
	format $formatstr [ \
	  lindex [$treeviewpath item $tvitem -values] 0] [ \
	  lindex [$treeviewpath item $tvitem -values] 1]]
    }
    close $f
  } else {
    return
  }
}


#==============================================================================
# Adapt according to code in concentration manager
# Only for complex tasks
#==============================================================================

proc ::EMC::gui::NormalizeConcentrations {} \
{
  set steps {$::EMC::gui::concarray(startconc)}
  set numberofsteps [ \
    expr { \
      ($::EMC::gui::concarray(startconc) - \
	$::EMC::gui::concarray(stopconc)) / \
      $::EMC::gui::concarray(concincrement)}]

  for {set i 1} {$i <= $numberofsteps} {incr i} {
    lappend steps [ \
      expr { \
	$::EMC::gui::concarray(startconc) + \
	($::EMC::gui::concarray(concincrement) * $i)}]
  }
}


#==============================================================================
# Binary code for the infobutton image
#==============================================================================

proc EMC::gui::infoImage {} \
{
  set image {R0lGODlhFAAUAOefADVLnDdNnThOnjlPnjxSoD5UoUJXo0FYpENYo0RbpkZdp0tjq01jqlFkqlBorlRnrVdsr\
    1VtsVhtsFlws1pxtFxxslxys1pztV91tV92tl94uGF6uWV+vGZ/vWiAvGmBvmqDv3GEvW6GwG+IwnuKv3uKwHeMwnSOxn\
    mOxICPwniRyH6QxIGQw4CRxHmTyYaVxX6YzICYy4CZzIGazYKbzoObzYWbzIWczYqcy4Oe0I+cyYef0JGgzIij04qj04+i\
    z5Gjz5aizI6k0pOl0Y2p14+r2JCs2ZWr1ZGs2ZSs15iv2J+u1aCu1Z6v1pqw2Z+w1pyy2pqz3KCy2J6z2qex1Zu03Kmy1a\
    K23KS22q+52au83ra/3LbB3rbC4LjC3rnD4LvF4LzH4sHI4b/M5cDO6MHQ6MbQ58bS6s7U6MvV6c7W6s/W6c7Y69PY6tbb7\
    Njc7Njd7dje7tne7dXf79jf79rf7d3i797i8Nzj8d3k8d7k8eHk8N/m8+Lo8+Pp9OXp8+nu9+zu9e3v9u7x+O/x+O7y+PDy+\
    PHz+PL0+fL1+vT1+fT2+vX3+/b3+/b4+/f4+/j5+/j5/Pj6/Pn6/Pr6/Pn7/fr7/Pv7/fv8/fz8/fz8/vz9/v39/v3+/v7+/v\
    //////////////////////////////////////////////////////////////////////////////////////////////////\
    //////////////////////////////////////////////////////////////////////////////////////////////////\
    ////////////////////////////////////////////////////////////////////////////////////////////////\
    ///////////////////////////////////////////////////////////////////////////////////////////////y\
    H+EUNyZWF0ZWQgd2l0aCBHSU1QACH5BAEKAP8ALAAAAAAUABQAAAj+AI0IHEiwYEEiCBMmLBKlChKFCXtInNijDCBNkiZdqk\
    SGYo8cIHP4UOIJE58rSaBMOcNojpOQMGLCoOEJz4yYRwp50rLDUx+ZLoLWWORHSFAXYzh5khE0EZagJ6LqWXQjalQVdKTEiM\
    omT9QRI2wwMgMWbJpLiDiVfTIJLAgQahw1eQuCkacwmRD9eDvE01sOHAYxEgF4CacOXTxF+gAYyCbAGjRwsrQhMgoPGiZ5ih\
    NZwxdCkS9c8ORJtGkTiBzhMI2JiegIEQQ9ogAbNhhPjybA5oIpA2wHDrwY4gEceCdPaICv8LSm+IIFIf7Yeb7AQqNJLRZg8H\
    SH+gIF4LNWPGIhQcGLRofckG4DoQJ4BQfiJ9DxaEv8Ops8NSrBAI6c+AcQIKCADxziyR46pEBCEIFAIgYCBQgYwIQUGmDFG5\
    5QQokiVDRA4YQAhCjiiAMIMOKIAQEAOw==}
  return $image
}


#==============================================================================
# Adapted from vmd qwikmd
# Generates the infobutton and links the infowindow frame to it 
#==============================================================================

proc ::EMC::gui::createInfoButton {frame row column} \
{
  image create photo ::EMC::gui::logo -data [::EMC::gui::infoImage]
  grid [ \
    ttk::label $frame.info \
      -image ::EMC::gui::logo -anchor center \
      -background $::EMC::gui::bgcolor] \
    -row $row -column $column -sticky e -padx {5 5} -pady {5 5}
  $frame.info configure -cursor hand1
}


#==============================================================================
# Adapted from vmd qwikmd
# Generates the info window frame which is called in each infobutton
#==============================================================================

proc ::EMC::gui::infoWindow {name text title} \
{
  set wname ".$name"

  if {[winfo exists $wname] != 1} {
      toplevel $wname
  } else {
      wm deiconify $wname
      return
  }
  wm geometry $wname 600x400
  grid columnconfigure $wname 0 -weight 2
  grid rowconfigure $wname 0 -weight 2

  # Title of the windows
  
  wm title $wname $title

  grid [ttk::frame $wname.txtframe] -row 0 -column 0 -sticky nsew
  grid columnconfigure  $wname.txtframe 0 -weight 1
  grid rowconfigure $wname.txtframe 0 -weight 1

  grid [ \
    text $wname.txtframe.info \
      -wrap word -width 420 -bg white \
      -yscrollcommand [list $wname.txtframe.scr1 set] \
      -xscrollcommand [list $wname.txtframe.scr2 set] \
      -exportselection true] \
    -row 0 -column 0 -sticky nsew -padx 2 -pady 2
  
  for {set i 0} {$i <= [llength $text]} {incr i} {
    set txt [lindex [lindex $text $i] 0]
    set font [lindex [lindex $text $i] 1]
    $wname.txtframe.info insert end $txt
    set ini [$wname.txtframe.info search -exact $txt 1.0 end]
    
    set line [split $ini "."]
    set fini [expr [lindex $line 1] + [string length $txt] ]
     
    $wname.txtframe.info tag add $wname$i $ini [lindex $line 0].$fini
    if {$font == "title"} {
      set fontarg "helvetica 15 bold"
    } elseif {$font == "subtitle"} {
      set fontarg "helvetica 12 bold"
    } else {
      set fontarg "helvetica 12"
    } 
    $wname.txtframe.info tag configure $wname$i -font $fontarg
  }
  
  # vertical scroll bar

  scrollbar $wname.txtframe.scr1 \
    -orient vertical -command [list $wname.txtframe.info yview]
  grid $wname.txtframe.scr1 \
    -row 0 -column 1  -sticky ens

  # horizontal scroll bar
  
  scrollbar $wname.txtframe.scr2 \
    -orient horizontal -command [list $wname.txtframe.info xview]
  grid $wname.txtframe.scr2 \
    -row 1 -column 0 -sticky swe

  grid [ttk::frame $wname.linkframe] \
    -row 1 -column 0 -sticky ew -pady 2 -padx 2

  grid columnconfigure $wname.linkframe 0 -weight 2
  grid rowconfigure $wname.linkframe 0 -weight 2

  grid [ \
    tk::text $wname.linkframe.text -bg [ \
	ttk::style lookup $wname.linkframe -background] \
      -width 100 -height 1 -relief flat -exportselection yes -foreground blue] \
    -row 1 -column 0 -sticky w
  $wname.linkframe.text configure -cursor hand1
  $wname.linkframe.text see [expr [string length $::EMC::gui::link] * 1.0 -1]
  $wname.linkframe.text tag add link 1.0 [ \
    expr [string length $::EMC::gui::link] * 1.0 -1]
  $wname.linkframe.text insert 1.0 $::EMC::gui::link link
  $wname.linkframe.text tag bind link <Button-1> {
    if {$tcl_platform(platform) eq "windows"} {
      set command [list {*}[auto_execok start] {}]
      set url [string map {& ^&} $url]
    } elseif {$tcl_platform(os) eq "Darwin"} {
      set command [list open]
    } else {
      set command [list xdg-open]
    }
    exec {*}$command $::EMC::gui::link &
  }

  bind link <Button-1> <Enter>
  $wname.linkframe.text tag configure link -foreground blue -underline true
  $wname.linkframe.text configure -state disable
  $wname.txtframe.info configure -state disable
}


#==============================================================================
# Adapted from vmd qwikmd
# Generates the ballon and the hover binding
#==============================================================================

proc ::EMC::gui::balloon {w help} \
{
  bind $w <Any-Enter> "after 700 [ \
    list \
      ::EMC::gui::balloon:show \
      %W \
      [list $help]]"
  bind $w <Any-Leave> "destroy %W.balloon"
}


#==============================================================================
# Adapted from vmd qwikmd
# Generates the yellow ballon window
#==============================================================================

proc ::EMC::gui::balloon:show {w arg} \
{
  if {[eval winfo containing  [winfo pointerxy .]]!=$w} { return }
  set top $w.balloon
  catch {destroy $top}
  toplevel $top -bd 1 -bg black
  wm overrideredirect $top 1
  if {[string equal [tk windowingsystem] aqua]}  {
    ::tk::unsupported::MacWindowStyle style $top help none
  }   
  pack [message $top.txt -aspect 10000 -bg lightyellow -font fixed -text $arg]
  set wmx [winfo rootx $w]
  set wmy [expr [winfo rooty $w]+[winfo height $w]]
  wm geometry $top \
    [winfo reqwidth $top.txt]x[winfo reqheight $top.txt]+$wmx+$wmy
  raise $top
}

#==============================================================================
# Reads esh files; begins read when the GROUPS keyword is found
#==============================================================================

proc ::EMC::gui::ReadEshGroups {input_file_name} \
{
  set output_list {}
  set file [open "$input_file_name" r]
  set begin 0
  set output_list_name {}
  
  while {[gets $file line] > -1} {
    if {[string first \; $line] != -1} {
      continue
    } elseif {[llength $line] == 0 || [llength $line] == 1} {
      continue
    } elseif {[string first \# $line] != -1} {
      continue
    } elseif {[string first "ITEM" $line] != -1 && \
	      [string first "GROUPS" $line] != -1 } {
      set begin 1
      continue
    } elseif {[string first \@ $line] == 0 && $begin == 1} {
      continue
    } elseif {$begin == 1 && \
	      [string first "ITEM" $line] != -1 && \
	      [string first "END" $line] != -1} {
      set begin 0
      continue
    } elseif {$begin == 1} {
      set name "[lindex $line 0]"
      set smiles "[lindex [split [lindex $line 1] ","] 0]"
      lappend output_list [list $name $smiles]
      unset name
      unset smiles
    }
  }
  close $file
  return $output_list
}


#==============================================================================
# Reads an esh files options based on the option keyword
# Some entries such as ; are illegal entries in text lines are therefore 
# 	skipped
#==============================================================================

proc ::EMC::gui::ReadEshOptions {} \
{
  set input_file_name [ \
    tk_getOpenFile \
      -title "Import Options from File" \
      -filetypes {{esh {.esh}}} \
      -parent .emc ]
  if {$input_file_name == ""} { 
    return
  }
  set file [open "$input_file_name" r]
  set begin 0
  while {[gets $file line] > -1} {
    if {[string first ";" $line] != -1} {
      continue
    } elseif {[llength $line] == 0} {
      continue
    } elseif {[string first \# $line] != -1} {
      continue
    } elseif {[string first "ITEM" $line] != -1 && \
	      [string first "OPTIONS" $line] != -1 } {
      set begin 1
      continue
    } elseif {[string first \@ $line] == 0 && $begin == 1} {
      continue
    } elseif {$begin == 1 && \
	      [string first "ITEM" $line] != -1 && \
	      [string first "END" $line] != -1} {
      set begin 0
      continue
    } elseif {$begin == 1} {
      set data [join $line " "]
      if {[info exists ::EMC::gui::options([lindex $data 0])] == 1 && \
	  [llength $data] == 2} {
	set ::EMC::gui::options([lindex $data 0]) [lindex $data 1]
      }
    }
  }
  close $file
  return
}


#==============================================================================
#
#==============================================================================

proc ::EMC::gui::DeleteSurfaceItem {} \
{
  array unset ::EMC::gui::surfoptions
}


#==============================================================================
# Resets some lists which are only needed to execute build; these need to be
# 	deleted after each run
#==============================================================================

proc ::EMC::gui::ClearAfterRun {} \
{
  set ::EMC::gui::LoopList {}
  set ::EMC::gui::MainOptionList {}
  set ::EMC::gui::TemplateOptionList {}
  set ::EMC::gui::options(temperature) $::EMC::gui::options(temperature,temporary) 
  set ::EMC::gui::options(pressure) $::EMC::gui::options(pressure,temporary)
  set ::EMC::gui::options(field) $::EMC::gui::options(field,temporary)
  set ::EMC::gui::GroupList {}
  set ::EMC::gui::options(phases) ""
  unset ::EMC::gui::options(temperature,temporary)
  unset ::EMC::gui::options(pressure,temporary)
  unset ::EMC::gui::options(field,temporary)
  #unset ::EMC::gui::options(field_location)
  #unset ::EMC::gui::options(field_name)
  foreach {key value} [array get ::EMC::gui::options *,usr] {
    unset ::EMC::gui::options($key)
  }
}


#==============================================================================
# Main proc generating all gui windows dynamically based on the table in
# 	emc_setup which is read in
# Detailed desciption available in the developers guide
# j indicates the column: this is necessary to achieve two columns
# The separator is always in the middle row in column 3
# i inidcates the row
#==============================================================================

proc ::EMC::gui::MakeGuiOptionsSection {windowpath menu_type treatment} {
  set i 1
  set j 0

  foreach listindex [ \
      lsearch -all -index 5 $::EMC::gui::optionlist "$menu_type"] {
    if {[lindex $::EMC::gui::optionlist $listindex 6] != "$treatment"} {
      continue
    }
    if {[lindex $::EMC::gui::optionlist $listindex 3] == "boolean"} {
      ttk::label $windowpath.[ \
	  lindex $::EMC::gui::optionlist $listindex 0]lbl \
	-text "[lindex $::EMC::gui::optionlist $listindex 0]:" \
	-anchor e
      ttk::checkbutton $windowpath.[ \
	  lindex $::EMC::gui::optionlist $listindex 0]box \
	-text "On/Off" \
	-variable ::EMC::gui::options([ \
	  lindex $::EMC::gui::optionlist $listindex 0]) \
	-offvalue false -onvalue true
      grid $windowpath.[ \
	  lindex $::EMC::gui::optionlist $listindex 0]lbl \
	-column [expr {$j + 0}] -row $i -sticky nsew -padx {5 5} -pady {0 5}
      grid $windowpath.[ \
	  lindex $::EMC::gui::optionlist $listindex 0]box \
	-column [expr {$j + 1}] -row $i -sticky nsew -padx {0 0} -pady {0 5}
      if {$j == 4} {
	incr i 
      }
    } elseif {[lindex $::EMC::gui::optionlist $listindex 3] in \
	      {"integer" "real" "string" "list" "browse"}} {
      ttk::label $windowpath.[ \
	  lindex $::EMC::gui::optionlist $listindex 0]lbl \
	-text "[lindex $::EMC::gui::optionlist $listindex 0]:" \
	-anchor e
      ttk::entry $windowpath.[ \
	  lindex $::EMC::gui::optionlist $listindex 0]box \
	-textvariable ::EMC::gui::options([ \
	  lindex $::EMC::gui::optionlist $listindex 0])
      grid $windowpath.[ \
	  lindex $::EMC::gui::optionlist $listindex 0]lbl \
	-column [expr {$j + 0}] -row $i -sticky nsew -padx {5 5} -pady {0 5}
      grid $windowpath.[ \
	  lindex $::EMC::gui::optionlist $listindex 0]box \
	-column [expr {$j + 1}] -row $i -sticky nsew -padx {0 0} -pady {0 5}

      # depending on the type entry the string behind the text entry fields
      # if entry type is added the list above must be changed too!
      
      switch -exact [lindex $::EMC::gui::optionlist $listindex 3] {
	"list" {
	  ttk::label $windowpath.[ \
	      lindex $::EMC::gui::optionlist $listindex 0]descriptor \
	    -text "(arg,arg,arg,\[...\])" -justify left
	  grid $windowpath.[ \
	      lindex $::EMC::gui::optionlist $listindex 0]descriptor \
	    -column [expr {$j + 2}] -row $i -padx {5 5} -pady {0 5} -sticky w
	}
	"string" {
	  ttk::label $windowpath.[ \
	      lindex $::EMC::gui::optionlist $listindex 0]descriptor \
	    -text "(String)" -justify left
	  grid $windowpath.[ \
	      lindex $::EMC::gui::optionlist $listindex 0]descriptor \
	    -column [expr {$j + 2}] -row $i -padx {5 5} -pady {0 5} -sticky w
	}
	"real" {
	  $windowpath.[ \
	      lindex $::EMC::gui::optionlist $listindex 0]box configure \
	    -validate key -validatecommand {string is double %P}
	  ttk::label $windowpath.[ \
	      lindex $::EMC::gui::optionlist $listindex 0]descriptor \
	    -text "(Real)" -justify left
	  grid $windowpath.[ \
	      lindex $::EMC::gui::optionlist $listindex 0]descriptor \
	    -column [expr {$j + 2}] -row $i -padx {5 5} -pady {0 5}  -sticky w
	}
	"integer" {
	  $windowpath.[ \
	      lindex $::EMC::gui::optionlist $listindex 0]box configure \
	    -validate key -validatecommand {string is int %P}
	  ttk::label $windowpath.[ \
	      lindex $::EMC::gui::optionlist $listindex 0]descriptor \
	    -text "(Integer)" -justify left
	  grid $windowpath.[ \
	      lindex $::EMC::gui::optionlist $listindex 0]descriptor \
	    -column [expr {$j + 2}] -row $i -padx {5 5} -pady {0 5}  -sticky w
	}
	"browse" {
	  ttk::button $windowpath.[ \
	      lindex $::EMC::gui::optionlist $listindex 0]descriptor \
	    -text "Browse" \
	    -command "::EMC::gui::browseproc $listindex"
	  grid $windowpath.[ \
	      lindex $::EMC::gui::optionlist $listindex 0]descriptor \
	  -column [expr {$j + 2}] -row $i -padx {5 5} -pady {0 5}  -sticky w
	}
      }
      if {$j == 4} {
	incr i 
      }
    } elseif {[lindex $::EMC::gui::optionlist $listindex 3] == "option" || \
	      [string first "," "[ \
	      lindex $::EMC::gui::optionlist $listindex 7]"] != -1} {
      set valuelist "[ \
	  lindex $::EMC::gui::optionlist $listindex 2] [split [ \
	  lindex $::EMC::gui::optionlist $listindex 7] ","]"
      ttk::label $windowpath.[ \
	  lindex $::EMC::gui::optionlist $listindex 0]lbl \
	-text "[lindex $::EMC::gui::optionlist $listindex 0]:" -anchor e
      ttk::combobox $windowpath.[ \
	  lindex $::EMC::gui::optionlist $listindex 0]box \
	-textvariable ::EMC::gui::options([ \
	  lindex $::EMC::gui::optionlist $listindex 0]) -state readonly \
	-values $valuelist
      grid $windowpath.[ \
	  lindex $::EMC::gui::optionlist $listindex 0]lbl \
	-column [expr {$j + 0}] -row $i -sticky nsew -padx {5 5} -pady {0 5}
      grid $windowpath.[ \
	  lindex $::EMC::gui::optionlist $listindex 0]box \
	-column [expr {$j + 1}] -row $i -sticky nsew -padx {0 0} -pady {0 5}
      if {$j == 4} {
	incr i 
      }
    } else {
      continue
    }
    
    set path "$windowpath.[lindex $::EMC::gui::optionlist $listindex 0]box"
    set help [lindex $::EMC::gui::optionlist $listindex 1] 
    
    ::EMC::gui::balloon $path $help  
    bind $windowpath.[ \
      lindex $::EMC::gui::optionlist $listindex 0]box <ButtonRelease-1> \
      "set ::EMC::gui::options([ \
	lindex $::EMC::gui::optionlist $listindex 0],usr) 1"

    # j controls the multiple entries per row; j goes from 0 to 4 then then
    # the row (i) is iterated by 1

    if {$j == 0} {
      set j 4
    } elseif {$j == 4} {
      set j 0
    }
  }
  ttk::separator $windowpath.centerseparator -orient vertical
  grid $windowpath.centerseparator \
    -column 3 -row 1 -rowspan [llength [grid slaves $windowpath -column 1]] \
    -sticky nsew -padx {30 30} -pady {5 5}
}


#==============================================================================
# This proc is called by the browse button. Multi lined commands in quotes need
# 	to be in a proc. command only allows single-line commands
# Quotes are required to have tcl interpret the variable in the first pass
# 	setting a point to the right list element
#==============================================================================

proc ::EMC::gui::browseproc {listindex} {
  set types {
    { {All Files} *}
  }
  set tempfile [ \
    tk_getOpenFile \
      -parent .emc \
      -title "Select [lindex $::EMC::gui::optionlist $listindex 0] File " \
      -filetypes $types -initialdir $::EMC::gui::options(directory)] ;
  if {$tempfile != ""} {
    set ::EMC::gui::options([ \
	lindex $::EMC::gui::optionlist $listindex 0]) $tempfile
  } else {
    return 0
  }
}


#==============================================================================
# Checks several factors for validity. Envoked always but thought to be used in
# 	check status
#==============================================================================

proc ::EMC::gui::CheckAllEntryValidity {} {
  set errorcode 0
  set errormessage {}
  if {$::EMC::gui::options(directory) == ""} {
    append errormessage "No Directory specified!\n"
    set errorcode 1
  }
  if {$::EMC::gui::options(filename) == ""} {
    append errormessage "No Filename specified!\n"
    set errorcode 1
  }
  if {$::EMC::gui::options(ncores) == ""} {
    append errormessage "Number of cores (ncores) not specified!\n"
    set errorcode 1
  }
  foreach entry $::EMC::gui::optionlist {
    set option [lindex $entry 0]
    set value $::EMC::gui::options($option)
    if {$option != "phases" && $value == "" && [lindex $entry 2] != ""} {
      # puts "[lindex $entry 0] = $::EMC::gui::options([lindex $entry 0])"
      append errormessage \
	"[lindex $entry 0] is empty. Please specify a value!\n"
      set errorcode 1
    }
  }
  foreach tvitem [.emc.hlf.nb.chemistry.definechemistry.tv children {}] {
    if { \
	[ \
	  lindex \
	  [.emc.hlf.nb.chemistry.definechemistry.tv item $tvitem -values] \
	  1 \
	] == $::EMC::gui::options(project)} {
      append errormessage \
	"The Project Name May not be the same as a cluster name!"
      set errorcode 1
    } elseif { \
	[ \
	  lindex \
	  [.emc.hlf.nb.chemistry.definechemistry.tv item $tvitem -values] \
	  1 \
	] == $::EMC::gui::options(filename)} {
      append errormessage \
	"The Project Name May not be the same as a cluster name!"
      set errorcode 1
    }
  }

  foreach index [lsearch -index 3 -all $::EMC::gui::optionlist "string"] {
    if {[ \
      llength [ \
	split [ \
	  lindex $::EMC::gui::optionlist $index 2] \
	":"]] != [ \
      llength [ \
	split $::EMC::gui::options([ \
	  lindex $::EMC::gui::optionlist $index 0]) ":"]] && [ \
      llength [ \
	split [ \
	  lindex $::EMC::gui::optionlist $index 2] ":"]] > 1} {
      append errormessage \
	"Wrong entry string in [ \
	  lindex $::EMC::gui::optionlist $index 0]! should be HH:MM:SS"
    }
  }
  set conc_check [ \
    ::EMC::gui::CheckConcentration .emc.hlf.nb.chemistry.definechemistry.tv]
  if {$conc_check == 1} {
    set errorcode 1
  }
  ::EMC::gui::CheckDPDCharge .emc.hlf.nb.chemistry.definechemistry.tv
  if {$errorcode == 1} {
    tk_messageBox \
      -title "Fatal Build Error" \
      -icon error \
      -type ok \
      -parent .emc \
      -message "The following Errors Impaired your Sytem Setup:\n$errormessage"
  }
  return $errorcode
}


#==============================================================================
# Catches errors arising when running emc setup
#==============================================================================

proc ::EMC::gui::GetSetupPlErrors {} {
  set errormsg ""
  if [catch { 
      exec \
	$::EMC::gui::EMC_ROOTDIR/scripts/emc_setup.pl \
	$::EMC::gui::options(filename)} msg] {
    append errormsg "ERROR WARNING - EMC SETUP EXEC FAILED\n"	
    append errormsg "ErrorMsg: $msg\n"
    puts "Error) EMC Setup failure: $msg"
    return $errormsg
  } else {
    return 0
  }
}


#==============================================================================
# Check and warningbox. Each molecule is checked whether there is any charge 
# 	present. If so the user is asked if this should be changed
# LAMMPS will run error free even if this flag is not set even though it makes
# 	no sense
#==============================================================================

proc ::EMC::gui::CheckDPDCharge {treeviewpath} {
  if {$::EMC::gui::options(field) != "dpd"} {
    return
  }
  set charge 0
  if {$::EMC::gui::options(field) == "dpd"} {
    foreach tvitem [.emc.hlf.nb.chemistry.definechemistry.tv children {}] {
      if {[ \
	  string first "+" [ \
	    lindex [$treeviewpath item $tvitem -values] 2]] != -1 || [ \
	  string first "-" [ \
	    lindex [$treeviewpath item $tvitem -values] 2]] != -1} {
	set charge 1
      }
    }
    foreach item $::EMC::gui::polymernames {
      if {[ \
	  string first "+" [ \
	    lindex $item 2]] != -1 || [ \
	  string first "-" [ \
	    lindex $item 2]] != -1} {
	set charge 1
      }
    }
  }
  if {$charge == 0 && $::EMC::gui::options(charge) == "true"} {
    set answer [ \
      tk_messageBox \
	-message "Your DPD groups contain no charges! Do you want to set the charge option to FALSE?" \
	-icon info \
	-type yesno \
	-parent .emc]
    switch -- $answer {
      yes {set ::EMC::gui::options(charge) "false"}
      no {return}
    }
  }
  if {$charge == 1 && $::EMC::gui::options(charge) == "false"} {
    set answer [ \
      tk_messageBox \
	-message "Your DPD groups contain charges! You should probably set charge to TRUE..." \
	-icon info \
	-type yesno \
	-parent .emc]
    switch -- $answer {
      yes {set ::EMC::gui::options(charge) "true"}
      no {return}
    }
  }
  unset charge
}


#==============================================================================
# Automatically get the extension of host (emc_air emc_turing etc.). inserted
# 	in the option host on the run option page
#==============================================================================

proc ::EMC::gui::GetHostVarFromRoot {} {
  if {$::EMC::gui::options(host) == ""} {
    set host ""
    if {$::env(HOST) != ""} {
      set host $::env(HOST)
    }
    if {[file exists $::EMC::gui::EMC_ROOTDIR/bin/emc_$host] == 0} {
      set host [exec ls $::EMC::gui::EMC_ROOTDIR/bin/ | grep emc_]
      set host [lindex [split "$host" "_"] 1]
    }
    set ::EMC::gui::options(host) $host
#     puts "[LINE [info frame]]: host = $::EMC::gui::options(host)"
  }
}


#==============================================================================
# Check the user defined esh filename. absolute paths will be converted to
# 	relative paths
# If .esh extension is missing or wrong it will be automatically corrected
#==============================================================================

proc ::EMC::gui::AppendFileNamePath {} { 
  set fileend [lindex [split $::EMC::gui::options(filename) "/"] end]
  set name [lindex [split $fileend "."] 0]
  set ::EMC::gui::options(filename) "$name.esh"
}


#==============================================================================
# Checks whether emc exists upon startup
# EMC rootdirectory is required for this to work
# User is othwerwise prompted to specify the rootdirectory in the file browser
#==============================================================================

proc ::EMC::gui::GetEMCRootDir {} {
  if {[info exists ::env(EMC_ROOT)]} {
    set ::EMC::gui::EMC_ROOTDIR $::env(EMC_ROOT)
  } else {
    set answer [ \
      tk_messageBox \
	-message "EMC root directory (EMC_ROOT) not found in env! Do you want to manually set it?" \
	-icon error \
	-type yesno]
    switch -- $answer {
      "yes" {  
	set tempdir [ \
	  tk_chooseDirectory -parent .emc -title "Select Project Dir"]
	if {$tempdir != ""} {
	  set ::EMC::gui::EMC::ROOTDIR $tempdir
	} elseif {$tempdir == ""} {
	  set ::EMC::gui::fatalexit 1
	  return  
	}
      }
      "no" {
	set ::EMC::gui::fatalexit 1    
	return
      }
    }
  }
}


#==============================================================================
# Workaround for the sample options which are all in one option and separated
# 	with (:)
#==============================================================================

proc ::EMC::gui::WriteSampleOption {} {
  set samplestring {}
  if {$::EMC::gui::options(sample,e) == "true"} {
    append samplestring "energy=true "
  } elseif {$::EMC::gui::options(sample,e) == "false" } {
    append samplestring "energy=false "
  }
    if {$::EMC::gui::options(sample,p) == "true"} {
    append samplestring "pressure=true "
  } elseif {$::EMC::gui::options(sample,p) == "false" } {
    append samplestring "pressure=false "
  }
  if {$::EMC::gui::options(sample,v) == "true"} {
    append samplestring "volume=true"
  } elseif {$::EMC::gui::options(sample,v) == "false" } {
    append samplestring "volume=false"
  }
  set ::EMC::gui::options(sample) $samplestring
}


#==============================================================================
# According to table in emc_setup the windows are disabled or enabled (ff
# 	dependent function)
#==============================================================================

proc ::EMC::gui::EnableFieldOptions {windowpath enable} {
   set i 0
   foreach listitem $::EMC::gui::optionlist {
     if {[ \
	string length [ \
	  lindex $listitem 7]] != 0 && [ \
	string first "," [ \
	  lindex $listitem 7]] == -1 && [ \
	string first "general" [ \
	  lindex $listitem 7]] != -1 } {
      switch [lindex $listitem 6] {
	"standard" { \
	  $windowpath.basic.[lindex $listitem 0]box configure -state normal}
	"advanced" { \
	  $windowpath.advanced.[lindex $listitem 0]box configure -state normal}
	}
     } elseif {[ \
	string length [ \
	  lindex $listitem 7]] != 0 && [ \
	string first "," [ \
	  lindex $listitem 7]] == -1 && [ \
	string first "$enable" [ \
	  lindex $listitem 7]] != -1} {
      switch [lindex $listitem 6] {
	"standard" { \
	  $windowpath.basic.[lindex $listitem 0]box configure -state normal}
	"advanced" { \
	  $windowpath.advanced.[lindex $listitem 0]box configure -state normal}
      }
    } elseif {[ \
	string length [ \
	  lindex $listitem 7]] != 0 && [ \
	string first "," [ \
	  lindex $listitem 7]] == -1 && [ \
	string first "$enable" [ \
	  lindex $listitem 7]] == -1} {
      switch [lindex $listitem 6] {
	"standard" { \
	  $windowpath.basic.[lindex $listitem 0]box configure -state disable}
	"advanced" { \
	  $windowpath.advanced.[lindex $listitem 0]box configure -state disable}
      }
    }
    incr i
  }
}


#==============================================================================
# When ff is changed emc_setup is sourced again with a different flag
# Imports all options which are different
# Everything what has been touched by the user is not changed! (potentially
# 	error prone)
#==============================================================================

proc ::EMC::gui::ReloadOptionsFromEmcforForceField {fieldtype} \
{
  ::EMC::gui::ImportOptions

  foreach item $::EMC::gui::optionlist {
    if {[info exists ::EMC::gui::options([lindex $item 0],usr)] == 1} {
      unset ::EMC::gui::options([lindex $item 0],usr)
    }
  }
  set ::EMC::gui::options(field) $fieldtype
  set \
    ::EMC::gui::options(field_location,temporary) \
    $::EMC::gui::options(field_location)
  set \
    ::EMC::gui::options(field_name,temporary) \
    $::EMC::gui::options(field_name)
}


#==============================================================================
# Counts the number of generated folders and systems 
# If number of runs is 1 the gui suggest running it locally
#==============================================================================

proc ::EMC::gui::CheckNumOfRuns {} {
  set lengthloops 2
  foreach item $::EMC::gui::LoopList {
    if {[llength $item] > 2} {
      set lengthloops [llength $item]
    }
  }
#   puts "[LINE [info frame]]: length = $length"
  return $lengthloops

}


#==============================================================================
# Invokes the test run build. Works exactly as the real run
# WARNING: the order of the write loop items procs is essential! a mix up will
# 	result in mismatches between real run and test run
# TODO: consolidate all pre-build procs into one large function to avoid
# 	mismatch between real and test build
#==============================================================================

proc ::EMC::gui::MakeAndCheckTempDirectory {} {
   set ::EMC::gui::statusmessage "Status: Running Test Build..."
   if {[::EMC::gui::CheckAllEntryValidity] != 0} {
      set ::EMC::gui::statusmessage "Status: Error"
      return
   }
  ::EMC::gui::AppendFileNamePath
  cd $::EMC::gui::options(directory)
  set timestamp [clock format [clock seconds] -format %Y_%m_%d-%H%M%S]
  ::EMC::gui::WriteStageLoopListItem
  ::EMC::gui::WriteTrialLoopListItem .emc.hlf.nb.chemistry.trials.tv
  ::EMC::gui::WriteCopiesLoopItem
  ::EMC::gui::WriteConcLoops .emc.hlf.nb.chemistry.definechemistry.tv
  ::EMC::gui::WriteSampleOption 
  ::EMC::gui::WriteProfileOptions
  ::EMC::gui::WriteParameterOptions .emc.hlf.nb.ffsettings.browserframe.tv2
  ::EMC::gui::WriteEnsembleVars temperature
  ::EMC::gui::WriteEnsembleVars pressure
  ::EMC::gui::GetHostVarFromRoot
  ::EMC::gui::WritePhaseVar .emc.hlf.nb.chemistry.definechemistry.tv
  lappend ::EMC::gui::TemplateOptionList "emc_test true"
  lappend ::EMC::gui::TemplateOptionList "replace true"
  ::EMC::gui::PopulateScriptList $::EMC::gui::optionlist

  set \
    ::EMC::gui::MainOptionList [ \
      lreplace $::EMC::gui::MainOptionList [ \
	lsearch -index 0 $::EMC::gui::MainOptionList "queue_build"] [ \
	lsearch -index 0 $::EMC::gui::MainOptionList "queue_build"]]
  lappend ::EMC::gui::MainOptionList "queue_build local"
  lappend ::EMC::gui::MainOptionList "replace true"
  
  ::EMC::gui::WriteGroupDefinitionsPolymer \
    ::EMC::gui::GroupList
  ::EMC::gui::WriteGroupDefinitionsMolecule \
    ::EMC::gui::GroupList .emc.hlf.nb.chemistry.definechemistry.tv
  
  foreach tvitem [.emc.hlf.nb.chemistry.definechemistry.tv children {}] {
    if {[lindex [ \
	.emc.hlf.nb.chemistry.definechemistry.tv item $tvitem -values] \
      1] == "polymer"} {
      set ::EMC::gui::UsePolymers "true"
    }
  }

  set home [pwd]
  fmkdir test
  cd test
  fmkdir tmp
  cd tmp
  fmkdir setup

  cd setup
  ::EMC::gui::BuildFile
  cd ..
  
  set errormsg ""
  if {[catch { \
      exec \
	$::EMC::gui::EMC_ROOTDIR/scripts/emc_setup.pl \
	  ./setup/$::EMC::gui::options(filename)} msg] == 1} {
    append errormsg "ERROR WARNING - EMC SETUP EXEC FAILED\n"	
    append errormsg "ErrorMsg: $msg\n"
    puts "Error) EMC Setup failure: $msg"
    set answer [ \
      tk_messageBox \
	-title "Fatal Error EMC Setup" \
	-icon error \
	-type yesno \
	-parent .emc \
	-message "$errormsg\nDo you want to keep the temporary directory?"]
    ::EMC::gui::ClearAfterRun
    cd $home/test
    switch -- $answer {
      yes { puts "Info) Keeping '/$home/test/tmp'" }
      no {  file delete -force tmp }
    }
    set ::EMC::gui::statusmessage "Status: Test Build Failed!"
    cd $home
    return
  }

  ::EMC::gui::ClearAfterRun

  set emcerrors [::EMC::gui::TriggerEmcTestRun]
  if {$emcerrors != ""} {
    puts $emcerrors
    set answer [ \
      tk_messageBox \
	-title "Fatal Error EMC Build" \
	-icon error \
	-type yesno \
	-parent .emc \
	-message "The Test Build Failed While building $emcerrors\nDo you want to keep temporary directory?"]
    cd $home/test
    switch -- $answer {
      yes { puts "Info) Keeping '/$home/test/tmp'" }
      no {  file delete -force tmp }
    }
    set ::EMC::gui::statusmessage "Status: Test Build Failed!"
    cd $home
    return
  }
    
  set ::EMC::gui::currentdirlist {}
  set tempdirlist [lsort [ffind . "build.emc"]]
  foreach dir $tempdirlist {
    set split [split $dir "/"]
    set split [lreplace $split end end]
    set joined [join $split "/"]
    lappend ::EMC::gui::currentdirlist $joined
  }
  
  set systemsummary "#\n"
  append systemsummary "#  File:\t[file rootname $::EMC::gui::options(filename)].dat\n"
  append systemsummary "#  Author:\tEMC GUI v$::EMC::gui::version, $::EMC::gui::date\n"
  append systemsummary "#  Date:\t[date]\n"
  append systemsummary "#  Purpose:\tSystem summary\n"
  append systemsummary "#\n"
  foreach path $::EMC::gui::currentdirlist {
    append systemsummary "[::EMC::gui::PrintSystemOutput $path]"
  }

  #  execute emcbuild esh and execute emc
  #  get test build directories for files
   
  append summary "testsummary"
#  file delete -force $home/test/tmp
  cd $home

  # check for existing data files
  
  ::EMC::gui::CheckForExistingFiles

  set shfilename [lindex [split $::EMC::gui::options(filename) "."] 0]
  set f [open $shfilename.dat "w"]
  puts $f $systemsummary
  close $f
  puts "Info) Test run complete"
  puts "Info) Saved as '[pwd]/$shfilename.dat'"
  puts "Info) Summary:\n"
  puts $systemsummary
  cd $::EMC::gui::options(directory)
  .emc.hlf.nb.run.runframe.realrun configure -state normal
  set ::EMC::gui::statusmessage "Status: Ready"
}


#==============================================================================
# Triggers the test run from the MakeAndCheckTempDirectory proc
# Seprate so one can return the errormessage if it fails.
#==============================================================================

proc ::EMC::gui::TriggerEmcTestRun {} {
  set errormsg ""
  set shfilename [file rootname $::EMC::gui::options(filename)]
  exec ./build/$shfilename.sh
  after 1000
  set testoutputs [lsort [ffind . "build.out"]]
#  puts $testoutputs
  foreach outfile $testoutputs {
    if {[catch {exec grep "Error:" $outfile} msg] == 0} {
      append errormsg "Error) In file '$outfile':\nError)   [ \
	string trimleft [exec grep -A1 "Error:" $outfile | tail -1] " "]"
    }
  }
  if {$errormsg != ""} {
    return [join [split $errormsg " "] " "]
  } else {
    return
  }
}


#==============================================================================
# Submits the real build to the cluster or locally. 
# If only one run is detected this envokes the infobox where the the user is
# 	prompted to build locally
# Only with one run to avoid crashing head node!
#==============================================================================

proc ::EMC::gui::RunEmcBuild {} {
  set ::EMC::gui::statusmessage "Status: Submitting Build..."
  if {[::EMC::gui::CheckAllEntryValidity] != 0} {
    set ::EMC::gui::statusmessage "Status: Error"
    return
  }
  ::EMC::gui::AppendFileNamePath
  cd $::EMC::gui::options(directory)

  #::EMC::gui::AppendFileNamePath
  ::EMC::gui::WriteStageLoopListItem
  ::EMC::gui::WriteTrialLoopListItem .emc.hlf.nb.chemistry.trials.tv
  ::EMC::gui::WriteCopiesLoopItem
  ::EMC::gui::WriteConcLoops .emc.hlf.nb.chemistry.definechemistry.tv
  ::EMC::gui::WriteSampleOption 
  ::EMC::gui::WriteProfileOptions
  ::EMC::gui::WriteParameterOptions .emc.hlf.nb.ffsettings.browserframe.tv2
  ::EMC::gui::WriteEnsembleVars temperature
  ::EMC::gui::WriteEnsembleVars pressure
  ::EMC::gui::GetHostVarFromRoot
  ::EMC::gui::WritePhaseVar .emc.hlf.nb.chemistry.definechemistry.tv
  ::EMC::gui::PopulateScriptList $::EMC::gui::optionlist

  #  single run locally

  if {[llength $::EMC::gui::currentdirlist] == 1 && \
       $::EMC::gui::options(queue_build) != "local"} {
    set answer [ \
      tk_messageBox \
	-message "Only one system will be built. Would you prefer building it locally instead of on the cluster?" \
	-icon info -type yesno -parent .emc \
    ]
    switch -- $answer {
      yes {
	set ::EMC::gui::options(queue_build) "local"
	set ::EMC::gui::MainOptionList [ \
	  lreplace $::EMC::gui::MainOptionList [ \
	    lsearch -index 0 $::EMC::gui::tvdefchemistrylist "queue_build"
	  ] [ \
	    lsearch -index 0 $::EMC::gui::MainOptionList "queue_build" \
	  ] \
	]
	lappend ::EMC::gui::MainOptionList "queue_build local"
      }
      no {
	puts "continue"
      }
    }
  }
  ::EMC::gui::WriteGroupDefinitionsPolymer ::EMC::gui::GroupList
  ::EMC::gui::WriteGroupDefinitionsMolecule ::EMC::gui::GroupList \
    .emc.hlf.nb.chemistry.definechemistry.tv
  foreach tvitem [ \
    .emc.hlf.nb.chemistry.definechemistry.tv children {} ] {
    if {[ \
	lindex [ \
	  .emc.hlf.nb.chemistry.definechemistry.tv item $tvitem -values] 1 \
	] == "polymer"} {
      set ::EMC::gui::UsePolymers "true"
    }
  }
  if {[file exists ./setup/] == 0} {
    exec mkdir setup
  }

  cd setup
  ::EMC::gui::BuildFile

  cd ..
  set errormsg ""
  if {[catch {exec \
      $::EMC::gui::EMC_ROOTDIR/scripts/emc_setup.pl \
      ./setup/$::EMC::gui::options(filename)} msg] == 1} {
    append errormsg "ERROR WARNING - EMC SETUP EXEC FAILED\n"	
    append errormsg "ErrorMsg: $msg\n"
    puts "Error) EMC Setup failure: $msg"
    tk_messageBox \
      -title "Fatal Error EMC Setup" -icon error -type ok -parent .emc \
      -message "$errormsg"
    ::EMC::gui::ClearAfterRun
    set ::EMC::gui::statusmessage "Status: Build Failed!"
    return
  }

  ::EMC::gui::ClearAfterRun

  # triggers script submission
  
  set shfilename [file rootname $::EMC::gui::options(filename)]
  
  set ::EMC::gui::progress "-"
  set ::EMC::gui::interrupt(done) 0
  puts "Info) Running '[pwd]/build/$shfilename.sh'"
  thread::create "
    [list exec ./build/$shfilename.sh];
    [list thread::send [thread::id] {set ::EMC::gui::interrupt(done) 1}];
    thread::exit"
  set ::EMC::gui::statusmessage "Status: Build Submitted Successfully"
  puts "Info) Building structure(s): see 'Results/Summary' tab for progress"
  puts "Info) DO NOT apply a break!!"
  cd $::EMC::gui::options(directory)
  .emc.hlf.nb.run.runframe.realrun configure -state disable
  ::EMC::gui::PopulateTvItemsStatusRun .emc.hlf.nb.results.tv true

  interrupt 1000 {
    ::EMC::gui::CheckRunStatusClusterBuild .emc.hlf.nb.results.tv
#    puts "[LINE [info frame]]: Info) progress = $::EMC::gui::progress"
  }
  vwait ::EMC::gui::interrupt(done)
  interrupt cancel $::EMC::gui::interrupt(id)
  puts "Info) EMC build finished"

  #  add if for error control
  # write f
    
  # execute emcbuild esh and execute emc
  # get test build directories for files
}


#==============================================================================
#
#==============================================================================

proc ::EMC::gui::RunWriteEmcScript {} {
  ::EMC::gui::AppendFileNamePath
  cd $::EMC::gui::options(directory)
  ::EMC::gui::WriteCopiesLoopItem
  ::EMC::gui::WriteStageLoopListItem
  ::EMC::gui::WriteConcLoops .emc.hlf.nb.chemistry.definechemistry.tv
  ::EMC::gui::WriteTrialLoopListItem .emc.hlf.nb.chemistry.trials.tv
  ::EMC::gui::WriteSampleOption 
  ::EMC::gui::WriteProfileOptions
  ::EMC::gui::WriteParameterOptions .emc.hlf.nb.ffsettings.browserframe.tv2
  ::EMC::gui::WriteEnsembleVars temperature
  ::EMC::gui::WriteEnsembleVars pressure
  ::EMC::gui::GetHostVarFromRoot
  ::EMC::gui::WritePhaseVar .emc.hlf.nb.chemistry.definechemistry.tv
  ::EMC::gui::PopulateScriptList $::EMC::gui::optionlist
  ::EMC::gui::WriteGroupDefinitionsPolymer \
    ::EMC::gui::GroupList
  ::EMC::gui::WriteGroupDefinitionsMolecule \
    ::EMC::gui::GroupList .emc.hlf.nb.chemistry.definechemistry.tv
  foreach tvitem [.emc.hlf.nb.chemistry.definechemistry.tv children {}] {
    if {[ \
	lindex [ \
	  .emc.hlf.nb.chemistry.definechemistry.tv item $tvitem -values \
	] 1] == "polymer"} {
      set ::EMC::gui::UsePolymers "true"
    }
  }
  ::EMC::gui::BuildFile
#     set plerrors [::EMC::gui::GetSetupPlErrors]
#     if {$plerrors != 0} {
#       tk_messageBox -title "Fatal Error While Executing Build" -icon error -type ok -parent .emc \
#       -message "$plerrors"
#       exec rm $::EMC::gui::options(filename)
#      ::EMC::gui::ClearAfterRun
#       return 
#     }
  ::EMC::gui::ClearAfterRun
}


#==============================================================================
# Checks how far the runs are. loops over all entries in the treeviewlist
#==============================================================================

proc ::EMC::gui::CheckRunStatusClusterBuild {treeviewpath} {
  foreach tvitem [$treeviewpath children {}] {
    set actualpath [lindex [$treeviewpath item $tvitem -values] 4]
    if {[file exists "$actualpath/build.out"] == 0} {
      set ::EMC::gui::processes($actualpath,build) "pending"
      continue
    }
    if {[file exists "$actualpath/build.out"] == 1} {
      set currentstatus [exec tail -n 2 $actualpath/build.out | head -1]
      set currentstatus [string map {"\{" "\\\{"} $currentstatus]
      set currentstatus [string map {"\}" "\\\}"} $currentstatus]
      if {[string first "Info: P.J. in 't Veld and G.C. Rutledge, Macromolecules 2003, 36, 7358" $currentstatus] != -1} {
	set ::EMC::gui::processes($actualpath,build) "completed"
      } else {
	set p [lindex $currentstatus 0]
	if {[string is double -strict $p]} {
	  set \
	    ::EMC::gui::processes($actualpath,build) "$p%"
	  set ::EMC::gui::progress $::EMC::gui::processes($actualpath,build)
	}
      }
    }
    $treeviewpath item $tvitem \
      -values [ \
	list \
	  $::EMC::gui::processes($actualpath,sysinfo) \
	  $::EMC::gui::processes($actualpath,queue) \
	  $::EMC::gui::processes($actualpath,build) \
	  $::EMC::gui::processes($actualpath,molid) $actualpath]
  }
}


#==============================================================================
# This proc operates dependent on the selection state of the tv item see the
# 	bind process of the respective 
# tv to see how it works
#==============================================================================

proc ::EMC::gui::LoadVisualizationState {treeviewpath} {
  if {[$treeviewpath selection] == ""} {
    return
  }
  if {$::EMC::gui::currentstatus != "completed" || \
      $::EMC::gui::currentmolid != -1} {
    return
  }
  set shfilename [lindex [split $::EMC::gui::options(filename) "."] 0]
  if {[catch {exec ls | grep ".vmd"}] == 0} {
    set shfilename  [lindex [split [exec ls | grep ".vmd"] "."] 0]
  }
  if {[::EMC::gui::GetProjectName ./setup/$::EMC::gui::options(filename)] == 1} {
    set shfilename $::EMC::gui::options(project)
  }
  cd $::EMC::gui::currentpath
  source [glob ./$shfilename.vmd]
  set currentmolid [molinfo top]
  mol rename $currentmolid $::EMC::gui::currentpath
  set ::EMC::gui::processes($::EMC::gui::currentpath,molid) $currentmolid
  $treeviewpath item [$treeviewpath selection] \
    -values [ \
      list \
	$::EMC::gui::processes($::EMC::gui::currentpath,sysinfo) \
	$::EMC::gui::processes($::EMC::gui::currentpath,queue) \
	$::EMC::gui::processes($::EMC::gui::currentpath,build) \
	$::EMC::gui::processes($::EMC::gui::currentpath,molid) \
	$::EMC::gui::currentpath]
  cd $::EMC::gui::options(directory)
  set temppath [\
    .emc.hlf.nb.results.tv item [.emc.hlf.nb.results.tv selection] -values]
  set ::EMC::gui::currentpath [lindex $temppath 4]
  set ::EMC::gui::currentstatus [lindex $temppath 2]
  set ::EMC::gui::currentmolid [lindex $temppath 3]
}


#==============================================================================
# This proc operates dependent on the selection state of the tv item see the
# 	bind process of the respective 
# tv to see how it works
#==============================================================================

proc ::EMC::gui::DeleteVisualizationState {treeviewpath} {
  if {$::EMC::gui::currentstatus != "completed" || \
      $::EMC::gui::currentmolid == -1} {
    return
  }
  mol delete $::EMC::gui::processes($::EMC::gui::currentpath,molid)
  set ::EMC::gui::processes($::EMC::gui::currentpath,molid) -1
  $treeviewpath item [$treeviewpath selection] \
    -values [ \
      list \
	$::EMC::gui::processes($::EMC::gui::currentpath,sysinfo) \
	$::EMC::gui::processes($::EMC::gui::currentpath,queue) \
	$::EMC::gui::processes($::EMC::gui::currentpath,build) \
	$::EMC::gui::processes($::EMC::gui::currentpath,molid) \
	$::EMC::gui::currentpath]
    set temppath [ \
      .emc.hlf.nb.results.tv item [.emc.hlf.nb.results.tv selection] -values]
    set ::EMC::gui::currentpath [lindex $temppath 4]
    set ::EMC::gui::currentstatus [lindex $temppath 2]
    set ::EMC::gui::currentmolid [lindex $temppath 3]
}


#==============================================================================
# deletes all active molid representations and sets them to -1
#==============================================================================

proc ::EMC::gui::ClearAllEmcRepresentations {treeviewpath} {
  foreach tvitem [$treeviewpath children {}] {
    set actualpath [lindex [$treeviewpath item $tvitem -values] 4]
    mol delete $::EMC::gui::processes($actualpath,molid)
    set ::EMC::gui::processes($actualpath,molid) -1
      $treeviewpath item $tvitem \
	-values [ \
	  list \
	    $::EMC::gui::processes($actualpath,sysinfo) \
	    $::EMC::gui::processes($actualpath,queue) \
	    $::EMC::gui::processes($actualpath,build) \
	    $::EMC::gui::processes($actualpath,molid) $actualpath]
  }
  set temppath [ \
    .emc.hlf.nb.results.tv item [.emc.hlf.nb.results.tv selection] -values]
  set ::EMC::gui::currentpath [lindex $temppath 4]
  set ::EMC::gui::currentstatus [lindex $temppath 2]
  set ::EMC::gui::currentmolid [lindex $temppath 3]
}


#==============================================================================
# Populates the results treeview after submitting a build. 
# If deletetag is set to true it will clear all of the results before adding
# 	the new ones. This is the default behavior in the gui when a new a new
# 	run is submitted
#============================================================================== 

proc ::EMC::gui::PopulateTvItemsStatusRun {treeviewpath deletetag} {
  if {$deletetag == "true"} {
    ::EMC::gui::ClearAllEmcRepresentations .emc.hlf.nb.results.tv
    $treeviewpath delete [$treeviewpath children {}]
    array unset ::EMC::gui::processes
  }
  set shfilename [lindex [split $::EMC::gui::options(filename) "."] 0]

  foreach actualpath $::EMC::gui::currentdirlist {
    
    set exists 0
    
    foreach tvitem [$treeviewpath children {}] {
      if {[lindex [$treeviewpath item $tvitem -values] 4] == $actualpath} {
	set exists 1
      }
    }
    if {$exists == 1} {
      puts "Info) $actualpath already exists"
      continue 
    }
  
    if {[llength $::EMC::gui::currentdirlist] > 1 && \
	$::EMC::gui::options(queue_build) != "local"} {
      set ::EMC::gui::processes($actualpath,queue) "on cluster"
    } elseif {$::EMC::gui::options(queue_build) == "local"} {
      set ::EMC::gui::processes($actualpath,queue) "local"
    } else {
      set ::EMC::gui::processes($actualpath,queue) "undefined"
    }
    set systeminfo [join [lrange [split $actualpath "/"] 1 end-1] "/"]
    set ::EMC::gui::processes($actualpath,sysinfo) "$systeminfo"
    
    # vmd_id says whether it has been loaded
    # necessary to later destroy the visualization

    set ::EMC::gui::processes($actualpath,molid) -1
    if {[file exists "$actualpath/build.out"] == 0} {
      set ::EMC::gui::processes($actualpath,build) "pending"
    } elseif {[file exists "$actualpath/$shfilename.vmd"] != 0} {
      set ::EMC::gui::processes($actualpath,build) "completed"
    } elseif {[file exists "$actualpath/build.out"] == 1} {
      set currentstatus [exec tail -n 2 $actualpath/build.out | head -1]
      if {[string first "Info: P.J. in 't Veld and G.C. Rutledge, Macromolecules 2003, 36, 7358" $currentstatus] != -1} {
	set ::EMC::gui::processes($actualpath,build) "completed"
      } else {
	set ::EMC::gui::processes($actualpath,build) "[lindex $currentstatus 0]%"
      }
    }
#    puts "[LINE [info frame]]: [ \
#      list \
#	"$::EMC::gui::processes($actualpath,sysinfo)" \
#	"$::EMC::gui::processes($actualpath,queue)" \
#	"$::EMC::gui::processes($actualpath,build)" \
#	"$::EMC::gui::processes($actualpath,molid)" "$actualpath"]"
    $treeviewpath insert {} end -values [ \
      list \
	"$::EMC::gui::processes($actualpath,sysinfo)" \
	"$::EMC::gui::processes($actualpath,queue)" \
	"$::EMC::gui::processes($actualpath,build)" \
	"$::EMC::gui::processes($actualpath,molid)" "$actualpath"]
  }
}


#==============================================================================
# Performed after running test build
# It prints system info to tk console and to a txt file with relative path,
# 	num of clusters, weight and massfraction
# Info: rounding error in emc which results in wrong results.
#==============================================================================

proc ::EMC::gui::PrintSystemOutput {relsystempath} {
  set infile [glob -path $relsystempath/ *.esh]
  set outfile [glob -path $relsystempath/ *.params]
  set cluster_list {}
  set file [open "$infile" r]
  set begin 0
  set output_list_name {}
  while {[gets $file line] > -1} {
    set $line "[string trimleft $line " "]"
    if {[string first \# $line] == 0} {
      continue
    } elseif {[llength $line] == 0} {
      continue
    } elseif {[string first \# $line] == 0} {
      continue
    } elseif {[string first "ITEM" $line] == 0} {
      if {[string first "CLUSTERS" "$line"] != -1} {
	set begin 1
      } else {
	set begin 0
      }
      continue
    } elseif {[string first \@ $line] == 0 && $begin == 1} {
      continue
    } elseif {$begin == 1} {
      lappend cluster_list [lindex $line 0]
    }
  }
  close $file
  set rundata ""
  set form {%-18s%-18s%-18s%-18s}
  append rundata "System: $relsystempath\n"
  append rundata [format $form "Cluster:" "NClusters:" "Molecular Mass:" "Mass fraction:"]\n
  set end [lindex $cluster_list end]
  set totalmass [lindex [exec grep "mtotal" $outfile] 3]
  foreach cluster $cluster_list {
    if {[catch {exec grep -w "nl_$cluster" $outfile} msg] == 0 && \
	[catch {exec grep -w "m_$cluster" $outfile} msg2] == 0} {
      set numofclusters  [lindex [exec grep -w "nl_$cluster" $outfile] 3]
      set massofclusters [lindex [exec grep -w "m_$cluster" $outfile] 3]
      set clustermassfraction [ \
	expr {double(round(10000*$numofclusters*$massofclusters/$totalmass))/10000}]
      append rundata \
	"[format $form $cluster $numofclusters $massofclusters $clustermassfraction]\n"
    }
  }
  return $rundata
}


#==============================================================================
# Infobox when running test build. Checks whether data file exists. build
# 	shell script will not run if data already exists in a folder.
# Finds and deletes the respective file and overwrites everything in that
# 	folder 
#==============================================================================

proc ::EMC::gui::CheckForExistingFiles {} {
  set existingfilelist {}
  set exitcode 0
  set shfilename [lindex [split $::EMC::gui::options(filename) "."] 0]
  foreach actualpath $::EMC::gui::currentdirlist {
    if {[file exists $actualpath/$shfilename.data] == 1} {
      lappend existingfilelist "$actualpath/$shfilename.data"
    }
  }
  if {[llength $existingfilelist] != 0} {
    set answer [ \
      tk_messageBox \
	-message "Data files with identical names exist in your directory.\n Do you want to delete these?" \
	-icon warning -type yesno -parent .emc]
    switch -- $answer {
      "yes" {
	foreach item $existingfilelist {
	  file delete $item
	}
      }
      "no" {
	set $exitcode 1
      }
    }
  }
  return $exitcode
}


#==============================================================================
# Delete from results treeview and from vmd list
#==============================================================================

proc ::EMC::gui::DeleteVizFromTreeview {treeviewpath} {
  if {[$treeviewpath selection] == ""} {
    return
  }

  set actualpath [ \
    lindex [$treeviewpath item [$treeviewpath selection] -values] 4]
  $treeviewpath delete [$treeviewpath selection] 
  if {$::EMC::gui::processes($actualpath,molid) != -1} {
    mol delete $::EMC::gui::processes($actualpath,molid)
  }
  lreplace $::EMC::gui::currentdirlist [ \
    lsearch $::EMC::gui::currentdirlist $actualpath] [ \
    lsearch $::EMC::gui::currentdirlist $actualpath] 
  array unset ::EMC::gui::processes $actualpath,*
}


#==============================================================================
#
#==============================================================================

proc ::EMC::gui::WriteFieldOptionFromTv {} {
}


#==============================================================================
# Original author read-in: Eduard Schreiner
# Generates all paths from the esh files LOOP block
# Only works with a single loop block in a file. Old files with multiple might
# 	not work.
# WARNING: generats all paths and then checks afterwards if they exist: :p :d
# 	are not recognized
#==============================================================================

proc ::EMC::gui::GetPathsFromEshFile {} {
  set homedir ""
  set tempfile ""
  set types {
    {{Esh Files} {.esh}}
    {{All Files} *}
  }
  set tempfile [ \
    tk_getOpenFile \
      -parent .emc \
      -title "Select Existing ESH File" \
      -filetypes $types \
      -initialdir $::EMC::gui::options(directory)]
  if {$tempfile != ""} {
    set setup_filename $tempfile
  } else {
    return 0
  }
  set psplit [split $setup_filename "/"]
  set ::EMC::gui::options(filename) [lindex $psplit end]
  set shfilename [lindex [split $::EMC::gui::options(filename) "."] 0]
  if {[lindex $psplit end-1] == "setup"} {
    set psplit [lreplace $psplit end end]
    set psplit [lreplace $psplit end end]
    set joined [join $psplit "/"]
    set homedir $joined
  } else {
    set psplit [lreplace $psplit end end]
    set joined [join $psplit "/"]
  }
  if {$::EMC::gui::options(directory) != "" && \
      [string first $joined $::EMC::gui::options(directory)] != -1} {
    set ::EMC::gui::options(directory) $homedir
  } elseif {[file exists "$joined/data"] == 0 && $homedir == ""} {
    set homedir [tk_chooseDirectory -parent .emc -title "Select Data Directory" -initialdir $::EMC::gui::options(directory)]
    set ::EMC::gui::options(directory) $homedir
  } elseif {$homedir == ""} {
    set homedir "$joined"
    set ::EMC::gui::options(directory) $homedir
  } elseif {$homedir != ""} {
    set ::EMC::gui::options(directory) $homedir
  }

  cd $::EMC::gui::options(directory)

  set path_parts [list]
  set fp [open "$setup_filename" r]
  set begin 0
  while {[gets $fp line] > -1} {
    
    # find the loops block
    
    if {[string first \; $line] != -1} {
      continue
    } elseif {[llength $line] == 0} {
      continue
    } elseif {[string first \# $line] != -1} {
      continue
    } elseif {[string first "project" $line] != -1} {
      set entry [join $line " "]
      set project [lindex $entry 1]
      continue
    } elseif {[string first "ITEM" $line] != -1 && \
	      [string first "LOOPS" $line] != -1 } {
      set begin 1
      continue	
    } elseif {$begin == 1 && \
	      [string first "ITEM" $line] != -1 && \
	      [string first "END" $line] != -1} {
      set begin 0
      continue
    } elseif {$begin == 1} { 
      
      # within the loops block, find values for trial, stage, copy
      
      set entry [join $line " "]
      if {[lindex $entry 0] == "copy"} {
	set copies [list ]
	for {set i 0} {$i < [lindex $entry 1]} {incr i} {
	    lappend copies [format {%02d} $i]
	} 
	lappend path_parts [list copy ${copies}]
      } else {
	lappend path_parts [list [lindex ${entry} 0] [lrange ${entry} 1 end]]
      }
    }
  }
  close $fp

  # preprocess list
  
  set temp_path_parts {}
  for {set i 0} {$i < [llength $path_parts]} {incr i} {
    set substitution {}
    set subname ""
    set sublist {}
    if {[string first ":p" [lindex $path_parts $i 0]] != -1} {
      set subname "[lindex $path_parts $i 0]"
      for {set j 0} {$j < [llength [lindex $path_parts $i 1]]} {incr j} {
	lappend sublist "[ \
	  lindex $temp_path_parts end 1 $j]/[lindex $path_parts $i 1 $j]"
      }
      set substitution [list $subname $sublist]
      set temp_path_parts [lreplace $temp_path_parts end end $substitution]
    } elseif {[string first ":h" [lindex $path_parts $i 0]] != -1} {
      continue 
    } else {
      lappend temp_path_parts [lindex $path_parts $i]
    }
  }
  set path_parts $temp_path_parts

  set paths [list ]
  set tmp_list2 [list ]
  
  # initialize path list
  
  foreach part [lindex [lindex ${path_parts} 0] 1] {
      lappend paths "./data/${part}" 
  }
  
  # fill in the rest
  
  set count 0
  for {set i 1} {${i} < [llength ${path_parts}]} {incr i} {
    set part [lindex ${path_parts} ${i}]
    set tmp_list2 ${paths}
    set paths [list ]
    foreach part1 [lindex $part 1] {
      foreach part2 ${tmp_list2} {
	lappend paths "${part2}/${part1}"
	incr count
      } 
    }
  }

  foreach singlepath $paths {
    if {[file exists $singlepath] == 1 && \
	[lsearch $::EMC::gui::currentdirlist "$singlepath/build"] == -1 && \
	[file exists "$singlepath/build/build.emc"] != -1} {
      lappend ::EMC::gui::currentdirlist "$singlepath/build"
    }
  }

  # this sorts the list; comment out if sorting not desired
  
  set ::EMC::gui::currentdirlist [lsort $::EMC::gui::currentdirlist]
  return 1
}


#==============================================================================
#
#==============================================================================

proc ::EMC::gui::GetProjectName {filename} {
  if {[catch {exec grep "project" $filename} msg] == 0} {
    set line [exec grep "project" $filename]
    set ::EMC::gui::options(project) [lindex $line 1]
    return 1
  } else {
    return 0
  }
}


#==============================================================================
# Checks whether any polymer monomer has two connectors at the beginning of
# 	the string. This is illegal in emc and has to be caught.
#==============================================================================

proc ::EMC::gui::CheckPolymerTerminators {} {
  set terminatorcount 0
  foreach tvitem [.emceditpolymer.hlf.tv2 children {}]  {
    if {[ \
      string first ":t" [\
	lindex [ .emceditpolymer.hlf.tv2 item $tvitem -values] 0]] != -1} {
      set terminatorcount [ \
	expr {$terminatorcount + \
	      [lindex [.emceditpolymer.hlf.tv2 item $tvitem -values] 2]}]
    } elseif {[ \
      llength [ \
	split [ \
	  lindex [ \
	    .emceditpolymer.hlf.tv2 item $tvitem -values] 1] "*"]] == 2} {
      set terminatorcount [ \
	expr {$terminatorcount + [ \
	  lindex [.emceditpolymer.hlf.tv2 item $tvitem -values] 2]}]
    }
  }
  if {$terminatorcount < 2} {
    return 1
  }
  return 0
}


#==============================================================================
# Generates the parameter list according to the file structure.
# Updates the forcefield treeview
#==============================================================================

proc ::EMC::gui::GetUpdateParameterList {} {
  set ::EMC::gui::ffbrowse {}
  set ::EMC::gui::fffilelist {}
  set field $::EMC::gui::options(field)
  set fieldlist [dict get $::EMC::gui::fields $field items]
  set fielddir $::EMC::gui::EMC_ROOTDIR/field/$field

  .emc.hlf.nb.ffsettings.browserframe.tv \
    delete [.emc.hlf.nb.ffsettings.browserframe.tv children {}]
  .emc.hlf.nb.ffsettings.browserframe.tv2 \
    delete [.emc.hlf.nb.ffsettings.browserframe.tv2 children {}]

  foreach item $fieldlist {
    if {[llength $fieldlist] == 1} {
      lappend ::EMC::gui::fffilelist [list $item $fielddir/$item]
      .emc.hlf.nb.ffsettings.browserframe.tv2 \
	insert {} end -values [list $item $fielddir/$item]
    } elseif {[string first "src" $item] == -1} {
      lappend ::EMC::gui::ffbrowse [list $item $fielddir/$item]
      .emc.hlf.nb.ffsettings.browserframe.tv \
	insert {} end -values [list $item $fielddir/$item]
    }
  }
}


#==============================================================================
# Writes the force field parameter files to the field option
# If the user does not change the treeview entries in the gui only the 
#	shortname is used (basf, compass, martini etc.)
# EMC searches for the files on its own then
#==============================================================================

proc ::EMC::gui::WriteParameterOptions {treeview} {
  if {[info exists ::EMC::gui::options(field,custom)] == 1} {
    set ::EMC::gui::options(field,temporary) \
      $::EMC::gui::options(field)
    unset ::EMC::gui::options(field)
    ::EMC::gui::SetFieldLocationAndName \
      .emc.hlf.nb.ffsettings.browserframe.tv2
  } else {
    set ::EMC::gui::options(field,temporary) \
      $::EMC::gui::options(field)
    return
  }
  return
}


#==============================================================================
#
#==============================================================================

proc ::EMC::gui::CheckFieldPaths {treeviewpath1 treeviewpath2} {
  foreach tvitem [$treeviewpath children {}] {
    if { [ \
      lindex [$treeviewpath1 item [$treeviewpath1 selection] -values] 1] != [ \
      lindex [$treeviewpath2 item $tvitem -values] 0]} {
      tk_messageBox \
	-title "Inconsistent File Path!" \
	-icon error -type ok -parent .emc \
	-message "The Force Field File path does not match the existing files.\nAll FF files must be located in the same directory. " 
      return 1
    }
  }
  return 0
}


#==============================================================================
#
#==============================================================================

proc ::EMC::gui::SetFieldLocationAndName {treeviewpath} {
  set filepath [lindex $::EMC::gui::fffilelist 0 1]
  set field $::EMC::gui::options(field,temporary)
  set ::EMC::gui::options(field_location) $::EMC::gui::EMC_ROOTDIR/field
  set field_name_list {}
  
  foreach tvitem [$treeviewpath children {}] {
#     lappend field_name_list [lindex [$treeviewpath item $tvitem -values] 0]
    lappend field_name_list $field/[ \
      lindex [ \
	split [lindex [$treeviewpath item $tvitem -values] 0] "."] 0]
  }
  set ::EMC::gui::options(field_name) [join $field_name_list ","]
}


#==============================================================================
# preprocessing of strings for the lammps output option 
#==============================================================================

proc ::EMC::gui::WriteProfileOptions {} {
  set samplestring {}
  if {$::EMC::gui::options(profile,density) == "true"} {
    append samplestring "density=true "
  } elseif {$::EMC::gui::options(profile,density) == "false" } {
    append samplestring "density=false "
  }
    if {$::EMC::gui::options(profile,pressure) == "true"} {
    append samplestring "pressure=true"
  } elseif {$::EMC::gui::options(profile,pressure) == "false" } {
    append samplestring "pressure=false"
  }
#   puts $samplestring
  set ::EMC::gui::options(profile) $samplestring
}


#==============================================================================
#
#==============================================================================

proc ::EMC::gui::CheckSurfaceInputfile {} {
  if {[string first "." $::EMC::gui::surfoptions(name)] != -1 && $::EMC::gui::surfoptions(inputtype) == "insight"} {
    set ::EMC::gui::surfoptions(name) [lindex [split $::EMC::gui::surfoptions(name) "."] 0]
  }
}

#==============================================================================
# General importfunction for all groups
# Called by the polymer and small molecule group window
#==============================================================================

proc ::EMC::gui::ImportFile {grouptype parentwindow} {

  set types {
   {{ESH Files} {.esh}}
   {{Text Files} {.txt}} 
   {{All Files} *}
  }
  set tempfile [ \
    tk_getOpenFile \
      -title "Import Group File" \
      -filetypes $types \
      -parent $parentwindow \
      -initialdir $::EMC::gui::options(directory)]
  if {$tempfile == ""} {
    return 
  }
  set garbagelist {}
  set templist {}
  if {[string first ".esh" $tempfile] != -1} {
    set templist [::EMC::gui::ReadEshGroups $tempfile]
  } else {
    set templist [::EMC::gui::ReadTabular $tempfile]
  }

  foreach item $templist {
    if {[llength [split [lindex $item 1] "*"]] == 1 && 
	$grouptype == "polymer"} {
      append garbagelist "[lindex $item 0] [lindex $item 1]\n"
    } elseif {[llength [split [lindex $item 1] "*"]] > 1 && 
	      $grouptype == "small_molecule"} {
      append garbagelist "[lindex $item 0] [lindex $item 1]\n"
    } elseif {[llength $item] != 2} {
      continue
    } elseif {$grouptype == "polymer"} {
      if {[lsearch -index 0 $::EMC::gui::polgrouplist [lindex $item 0]] == -1} {
	lappend \
	  ::EMC::gui::polgrouplist [list [lindex $item 0] [lindex $item 1]]
	.emcpoly.hlf.groups.tv insert {} end \
	  -values [list [lindex $item 0] [lindex $item 1]]
      }
    } elseif {$grouptype == "small_molecule"} {
      if {[lsearch -index 0 $::EMC::gui::smgrouplist [lindex $item 0]] == -1} {
	lappend \
	  ::EMC::gui::smgrouplist [list [lindex $item 0] [lindex $item 1]]
	.emcsm.hlf.tv insert {} end \
	  -values [list [lindex $item 0] [lindex $item 1]]
      }
    }
  }

  if {[llength $garbagelist] > 1} {
    set answer [ \
      tk_messageBox \
	-type yesno \
	-icon info \
	-title "Import Warning" \
	-parent $parentwindow \
	-message "The following Groups were not imported:\n$garbagelist\nDo you want to import them as well?"]
    switch -- $answer {
      yes {
	foreach {name smiles} $garbagelist {
	  if {$grouptype == "small_molecule"} {
	    lappend ::EMC::gui::polgrouplist "$name $smiles"
	    if {[winfo exists .emcpoly] == 1} {
	      .emcpoly.hlf.groups.tv insert {} end -values [list $name $smiles]
	    }
	  } elseif {$grouptype == "polymer"} {
	    lappend ::EMC::gui::smgrouplist "$name $smiles"
	    if {[winfo exists .emcsm] == 1} {
	      .emcsm.hlf.tv insert {} end -values [list $name $smiles]
	    }
	  }
	}
      }
    }
  }
  unset garbagelist
}


#==============================================================================
# called by the use trials checkbox. adds the trial variable wildcard to the
# 	define chemistry treeview
# disables/enables the gui buttons associated with this section.
#==============================================================================

proc ::EMC::gui::AddRemoveTrial {} {
  if {$::EMC::gui::trials(use) == true } {
    .emc.hlf.nb.chemistry.trials.addtrial configure -state normal
    .emc.hlf.nb.chemistry.trials.removetrial configure -state normal
    .emc.hlf.nb.permanentsettings.trialname configure -state disable
    if {[lsearch -index 0 $::EMC::gui::tvdefchemistrylist "VARIABLE"] == -1} {
      .emc.hlf.nb.chemistry.definechemistry.tv insert {} end -values [ \
	list "VARIABLE" "TRIAL"  "VARIABLE" 1 1]
      lappend ::EMC::gui::tvdefchemistrylist  "VARIABLE TRIAL VARIABLE 1 1"
    }
  } elseif {$::EMC::gui::trials(use) == false} {
    .emc.hlf.nb.permanentsettings.trialname configure -state normal
    .emc.hlf.nb.chemistry.trials.addtrial configure -state disable
    .emc.hlf.nb.chemistry.trials.removetrial configure -state disable
    set ::EMC::gui::tvdefchemistrylist [ \
      lreplace $::EMC::gui::tvdefchemistrylist [ \
	lsearch -index 0 $::EMC::gui::tvdefchemistrylist "VARIABLE"] [ \
	  lsearch -index 0 $::EMC::gui::tvdefchemistrylist "VARIABLE"]]
  #delete from main treeview
    foreach tvitem [.emc.hlf.nb.chemistry.definechemistry.tv children {}] {
      if {[lindex [ \
	.emc.hlf.nb.chemistry.definechemistry.tv item $tvitem -values] 1] == "TRIAL"} {
	.emc.hlf.nb.chemistry.definechemistry.tv delete $tvitem
      }
    }
  }
}


#==============================================================================
# preprocesses the textfile from the manual removing all @item, @tab and
# 	@code{} entries 
# to be called separately from this gui for preprocessing
#==============================================================================

proc ::EMC::gui::InterpretOptionList {input_file_name output_file_name} {
  set output_list {}
  set file [open "$input_file_name" r]
  set i 1
  set tempoutput {}

  while {[gets $file line] > -1} {
    if {[string first "@item" $line] == -1 && 
	[string first "@tab" $line] == -1} {
      continue
    }

    if {[string first "@item" $line] == 0 ||
	[string first "@tab" $line] == 0} {
      lappend tempoutput [ \
	lreplace [string map {"\}" ""} [string map {"@code\{" ""} $line]] 0 0]
      incr i
    }
    if {$i == 4} {
      lappend output_list $tempoutput
      set i 1
      set tempoutput {}
    }
  }
  close $file

  set file [open "$output_file_name" "w"]
  foreach listitem $output_list {
    puts $file "$listitem"
  }

  close $file
}

#==============================================================================
#
#==============================================================================

proc ::EMC::gui::ReadOptionText {input_file_name} {
  set output_list {}
  set file [open "$input_file_name" r]
  set output_list_name {}
  
  while {[gets $file line] > -1} {
    if {[string first \# $line] != -1} {
      continue
    }
    if {[llength $line] == 0} {
      continue
    }
    lappend output_list "$line"
   }
  close $file
  return $output_list
}


#==============================================================================
# Outputs the text for the infoboxes in the gui based on the text in the EMC
# 	users guide
#==============================================================================

proc ::EMC::gui::PopulateHelpOptions {menu_type} {
  set helptext ""
  foreach optionentry [ \
      lsearch -all -index 5 $::EMC::gui::optionlist "$menu_type"] {
    if {[lindex $::EMC::gui::optionlist $optionentry 6] == "ignore"} {
      continue
    } elseif {[ \
      lsearch -index 0 $::EMC::gui::helpentries [ \
	lindex $::EMC::gui::optionlist $optionentry 0]] != -1} {
      set tempentry [ \
	lindex $::EMC::gui::helpentries [ \
	  lsearch -index 0 $::EMC::gui::helpentries [ \
	    lindex $::EMC::gui::optionlist $optionentry 0]] ]
      append helptext "[ \
	lindex $tempentry 0]\t\t\t \([ \
	  lindex $tempentry 1]\) \t\t\t[ \
	    lindex $tempentry 2]\n\n"
    } elseif {[ \
	lsearch -index 0 $::EMC::gui::helpentries [ \
	  lindex $optionentry 0]] == -1} {
      append helptext "[ \
	lindex $::EMC::gui::optionlist $optionentry 0]\t\t\t \([ \
	  lindex $::EMC::gui::optionlist $optionentry 2]\) \t\t\t[ \
	    lindex $::EMC::gui::optionlist $optionentry 1]\n\n"
    } else {
      continue
    }	
  }
  return $helptext
}

#==============================================================================
#
#==============================================================================

proc ::EMC::gui::AnalysisOptionsInfo {} {
  set text0 "Analysis Options Tab\n"
  set font0 "title"
  set text1 "The analyis options are relevant for LAMMPS runs following an EMC build. It changes several \
   LAMMPS flags which modify the output files generated during a simulation and the subsequent analysis scripts which are provided. \
  The option descriptions as found in the Users Guide are listed below.\n\n"
  set font1 "text"
  set text2 "Analysis Options Overview\n\n"
  set font2 "subtitle"
  set text3 "[::EMC::gui::PopulateHelpOptions analysis]"
  set font3 "text"
  set link {montecarlo.sourceforge.net/emc/Welcome.html}
  set text [list [list $text0 $font0] [list $text1 $font1] [list $text2 $font2] [list $text3 $font3]]
  set title "Analysis Tab Information"

  return [list ${text} $link $title]
}


#==============================================================================
# gets all ff names from the root directory.
#==============================================================================

proc ::EMC::gui::GetForceFieldNames {} {
  set fielddir $::EMC::gui::EMC_ROOTDIR/field
  set n0 [llength [file split $fielddir]]
  set ::EMC::gui::fields [dict create]

  foreach file [ffind $fielddir {*.prm *.frc}] {
    set names [file split $file]
    set field [lindex $names $n0]
    set name [ \
      join [ \
	lrange $names [expr $n0 + 1] [expr [llength $names] - 1]] "/"]
    ::EMC::gui::dictnlappend ::EMC::gui::fields $field items $name
  }
  set ::EMC::gui::fflist [dict keys $::EMC::gui::fields]
#  foreach f [dict keys $::EMC::gui::fields] {
#    puts $f
#    set names [dict get $::EMC::gui::fields $f items]
#    puts "\\_ $names"
#  }
}


#==============================================================================
#
#==============================================================================

proc ::EMC::gui::dictnlappend {dictname keys args} {
  upvar 1 $dictname d
  if {![llength $args]} return 
  if {![dict exists $d {*}$keys]} {
    dict set d {*}$keys {}
  }
  set keys1 [lrange $keys 0 end-2] 
  while {[dict exists $d {*}$keys1 d[incr i]]} {}
  upvar 1 $dictname d$i
  dict with d$i [list dict lappend {*}[lrange $keys end-1 end] {*}$args]
  set d$i
}

#==============================================================================
# returns the integer for all appearances of a certain pattern in a string
#==============================================================================

proc ::EMC::gui::StringGetInstances {targetstring searchpattern} {
  set searchpatternlength [string length $searchpattern]
  set instancelist {}
  set tempstring $targetstring

  for {set i 0} {$i < [string length $targetstring]} {incr i} {
    if {[string index $targetstring $i] == $searchpattern} {
      lappend instancelist $i
    }
  }
  return $instancelist
}


#==============================================================================
# content of the add ff button. Adds a ff field to the used ff list from the
#	available ffields.
#==============================================================================

proc ::EMC::gui::AddForceFieldButton {} {
  if {[.emc.hlf.nb.ffsettings.browserframe.tv selection] == ""} {
    return
  }
  lappend ::EMC::gui::fffilelist "[ \
    lindex [ \
      .emc.hlf.nb.ffsettings.browserframe.tv item [ \
	.emc.hlf.nb.ffsettings.browserframe.tv selection] -values] 0] [ \
    lindex [ \
      .emc.hlf.nb.ffsettings.browserframe.tv item [ \
	.emc.hlf.nb.ffsettings.browserframe.tv selection] -values] 1]"
  .emc.hlf.nb.ffsettings.browserframe.tv2 insert {} end -values "[ \
    lindex [ \
      .emc.hlf.nb.ffsettings.browserframe.tv item [ \
	.emc.hlf.nb.ffsettings.browserframe.tv selection] -values] 0] [ \
    lindex [ \
      .emc.hlf.nb.ffsettings.browserframe.tv item [ \
	.emc.hlf.nb.ffsettings.browserframe.tv selection] -values] 1]"
  set ::EMC::gui::ffbrowse [ \
    lreplace $::EMC::gui::ffbrowse [ \
      lsearch -index 0 $::EMC::gui::ffbrowse "[ \
	lindex [ \
	  .emc.hlf.nb.ffsettings.browserframe.tv item [ \
	    .emc.hlf.nb.ffsettings.browserframe.tv selection] -values] 0]"] [ \
      lsearch -index 0 $::EMC::gui::ffbrowse "[ \
	lindex [ \
	  .emc.hlf.nb.ffsettings.browserframe.tv item [ \
	    .emc.hlf.nb.ffsettings.browserframe.tv selection] -values] 0]"]]
  .emc.hlf.nb.ffsettings.browserframe.tv delete [ \
    .emc.hlf.nb.ffsettings.browserframe.tv selection]
}


#==============================================================================
# content of the remove ff button. Deletes ff from the used ff list
#==============================================================================

proc ::EMC::gui::RemoveForceFieldButton {} {
  if {[.emc.hlf.nb.ffsettings.browserframe.tv2 selection] == ""} {
    return
  }
  .emc.hlf.nb.ffsettings.browserframe.tv insert {} end -values "[ \
    lindex [ \
      .emc.hlf.nb.ffsettings.browserframe.tv2 item [ \
	.emc.hlf.nb.ffsettings.browserframe.tv2 selection] -values] 0] [ \
    lindex [ \
      .emc.hlf.nb.ffsettings.browserframe.tv2 item [ \
	.emc.hlf.nb.ffsettings.browserframe.tv2 selection] -values] 1]"
  lappend ::EMC::gui::ffbrowse "[ \
    lindex [ \
      .emc.hlf.nb.ffsettings.browserframe.tv2 item [ \
	.emc.hlf.nb.ffsettings.browserframe.tv2 selection] -values] 0] [ \
    lindex [ \
      .emc.hlf.nb.ffsettings.browserframe.tv2 item [ \
	.emc.hlf.nb.ffsettings.browserframe.tv2 selection] -values] 1]"

  set ::EMC::gui::fffilelist [ \
    lreplace $::EMC::gui::fffilelist [ \
      lsearch -index 0 $::EMC::gui::fffilelist "[ \
	lindex [ \
	  .emc.hlf.nb.ffsettings.browserframe.tv2 item [ \
	    .emc.hlf.nb.ffsettings.browserframe.tv2 selection] -values] 0]"] [ \
      lsearch -index 0 $::EMC::gui::fffilelist "[ \
	lindex [ \
	  .emc.hlf.nb.ffsettings.browserframe.tv2 item [ \
	    .emc.hlf.nb.ffsettings.browserframe.tv2 selection] -values] 0]"]]
  .emc.hlf.nb.ffsettings.browserframe.tv2 delete [ \
    .emc.hlf.nb.ffsettings.browserframe.tv2 selection]
}


#==============================================================================
# END OF THE GUI AND MAIN FUNCTIONS
#==============================================================================

#==============================================================================
# INFO: This is the content of all infoboxes in the gui
# This code is used in the qwikmd gui and is used without major modification
# The text and fond are defined as a string
#==============================================================================

proc ::EMC::gui::selectInfo {} {
  set text [list \
    [list "Selection Window\n\n" "title"] \
    [list "The selection section of QwikMD allows the user to select each parts of the PDB will be prepared for the MD simulation. For example, structures obtained with NMR spectroscopy usually have more than one state of the protein. It is also common that PDB structures solved with X-ray Crystallography have oligomers of the protein, separated in different chains. These oligomers are frequently an effect of the crystallization process and the protein in solution is presented as a monomer. QwikMD allows the user to select the desired NMR state or protein chains for the MD step.\n\n" "text" ] \
    \
    [list "NMR Structures\n\n" "subtitle"] \
    [list "Nuclear magnetic resonance spectroscopy of proteins, usually abbreviated protein NMR, is a field of structural biology in which NMR spectroscopy is used to obtain information of the structure and dynamics of proteins, nucleic acids, and their complexes. NMR structure in the PDB usually have multiple steps. In order to start a MD simulation one have to select one of the steps as the initial coordinates. It is usual, when running more than one simulation of the same system, to select different initial steps to improve sampling of conformational structure.\n\n" "text"] \
    \
    [list "X-ray Crystallography \n\n" "subtitle"] \
    [list "X-ray crystallography methods utilize the optical rule that electromagnetic radiation will interact most strongly with matter the dimensions of which are close to the wavelength of that radiation. X-rays are diffracted by the electron clouds in molecules, since both the wavelength of the X-rays and the diameter of the cloud are on the order of Angstroms. The diffraction patterns formed when a group of molecules is arranged in a regular, crystalline array, may be used to reconstruct a 3-D image of the molecule. Hydrogen atoms, however, are not typically detected by X-ray crystallography since their sizes are too small to interact with the radiation and since they contain only a single electron.\n\n" "text"] \
    \
    [list "Select chain/type\n\n" "subtitle"] \
    [list "With this button the user can select or deselect chains and types of molecules inside these chains. The selected groups will be the one that will be present in the MD simulation prepared with QwikMD.\n\n" "text"] \
    \
    [list "Structure Manipulation\n\n" "subtitle"] \
    [list "This button will open a new window where the user can do mutations, rename molecules that have wrong names - read more below - change protonation states, delete parts of the molecules and also inspect the structure with a interactive residue/molecule list. Select Resid is especially important in cases where one of the molecules/ions have wrong names, or names that are different from the name used in the CHARMM force field. For instance, it is common in the PDB that Ca2+ ions have the name CA. CHARMM recognize the name CA as alpha-Carbon of protein structures, and CA resname - residue name - is not recognized by CHARMM. Select Resid allow for the user to rename CA ions to proper Calcium parameters that will be compatible with the CHARMM force field.\n\n" "text"] \
    \
    [list "QwikMD Main Window\n\n" "subtitle"] \
    [list "In the main window of QwikMD, every chain is separated by type of molecule forming a group - chain/type. VMD has several types of molecules, including: protein, nucleic, lipids, water, among others. The user can select different Representations for each of the groups and also different colors.\n\n\n\n" "text"] \
    \
    [list "Scripting in VMD\n\n" "title"] \
    [list "Providing VMD with user made scripts can do the steps you are doing employing QwikMD. Advanced VMD users usually prefer to create their own scripts, as these scripts allow for total control and reproducibility of the analysis. Scripts are very powerful tools inside VMD as they allow the user to easily perform analyses that are not yet implemented. To learn more about scripting with VMD visit the link at the bottom of this window.\n\n" "text"] \
  ]
  set title "Selection section info"
  set link {http://www.ks.uiuc.edu/Training/Tutorials/vmd/bak/node4.html}
  return [list ${text} $link $title]
}


#==============================================================================
#
#==============================================================================

proc ::EMC::gui::MainMenuInfo {} {
  set text [list \
    [list "Main Menu Information\n\n" "title"] \
    [list "The top main menu has several important functionalities.\n\n" "text" ] \
    \
    [list "New Session\n" "subtitle"] \
    [list "Completely deletes everything from the gui and resets all options to the startup defaults.\n\n" "text"] \
    \
    [list "Save Session\n" "subtitle"] \
    [list "The information stored in the gui can be saved by creating a session file. All options, molecules and gui related settings are saved in this file and can be loaded at any time.\n\n" "text"] \
    \
    [list "Load Session\n" "subtitle"] \
    [list "Session files can be loaded at any point and will restore a previous session. If defaults have been changed beforehand and the session has not been cleared it might be the case that data is loaded into an existing session. Clearing the session before loading a new one is advisable.\n\n" "text"] \
    \
    [list "Populate Options from Script\n" "subtitle"] \
    [list "The options from an existing esh file can be imported and applied to an existing session. This way one does not have to manually set all options each time the gui is reopened or a previous simulation is re-run.\n\n" "text"] \
    \
    [list "Restore Options to Defaults\n" "subtitle"] \
    [list "All options are restored to the default values. This does not influence the defined chemistry.\n\n" "text"] \
  ]
  set title "Main Menu Information"
  set link {montecarlo.sourceforge.net/emc/Welcome.html}
  return [list ${text} $link $title]
}


#==============================================================================
#
#==============================================================================

proc ::EMC::gui::FixedMenuInfo {} {
  set text [list \
    [list "General Menu Information\n\n" "title"] \
    [list "The top window contains the most important and special options for the use of EMC. These options should be considered and set for each run individually because they manage the global behavior of the system size and type of simulation. The Project directory determines where the system will be set up. It's the top directory where the gui always refers to to set up the folder structures, write files, and execute tests. If the emc generated folders already exists the new paths will be placed in the existing folder structure. The size of the system is determined by the number of atoms. Mol, mass or volume fractions will be calculated to match the total amount of atoms desired. This alleviates the calculation of required cores for a given system size. The only exception arises when the absolute number of molecules is chosen as calculation method. Here the number of atoms equals exactly the number as it arises from the number of molecules the user specified. A summary of some key data can be found in the overview after completing the Test build. Internally, EMC always normalizes the user specified values to one. The number of copies sets up several identical systems to increase sampling. The only difference is the random seed used for setup and run. The ensemble, either NVT or NPT, is used both in EMC as well as LAMMPS. If NPT is chosen both temperature and pressure must be set. Shape defines the box shape by changing the x/y box length ratio. Density sets the density for the entire system. If a multi-phase system is built, each phases' density may be set by comma separating the values. In accordance with the phase order. Stage Name and Trial Name define the names of the respective sections and the according folder structure. Trial and stage will appear as loop variables. The top trial name will be void if the Multiple Trial Sampling is used.\n\n" "text"] \
  ]
  set link {montecarlo.sourceforge.net/emc/Welcome.html}
  set title "General Menu Information"
  return [list ${text} $link $title]
}


#==============================================================================
#
#==============================================================================

proc ::EMC::gui::DefineChemistryInfo {} {
  set text [list \
    [list "The Define Chemistry Tab\n\n" "title"] \
    [list "The chemistry tab manages all the systems properties i.e. which molecules will be built, at which concentration and whether in bulk phase or in individual defined phases. The treeview shows the group name, the type of molecule the amount which will be built and the phase. Default all molecules are built in one phase as bulk solution. Only if the phase number is altered the phase option is invoked and written to the esh file. The amount field can be edited to change the amount of molecules or concentrations respectively. When No. of molecules is chosen in the top window the displayed number is an absolute molecule count. Otherwise, EMC uses ntotal as the number of atoms and calculates based on the given ratios (mol, vol or mass fractions). It is important to bear in mind how large the systems might get and to set the build time (time_build) accordingly. One can also set up several systems in one run by using the comma separation. This sets up multiple loop variables. The number of values per compound must be the same if multiple entries are used. The loops are paired meaning they are interpreted columnwise and the respective systems set up. Info: The default behavior of EMC is setting up a system for each possible combination of loop variables from the top down. Therefore, the order of the loop variables block is important. The gui appends with a ':p' which means the loop variable is paired with the prior one, allowing for columnwise handling. The trial treeview allows the user to introduce a wildcard into the system. This adds multiple trials to the system and exchange of one compound in the system for several chemicals is possible. Please see the Stage/Trial description to see the use of trials. Assuming one might want to test several solvent combinations, instead of setting up each simulation by itself one can simply list the solvents in the trial box and the esh file will be written such that each trials uses a different solvent while maintaining the remaining composition of the system. Then, each of the systems is encoded by the given trial name. these may still be sampled with altering concentrations as well.\n\n" "text"] \
    \
    [list "Option tabs\n\n" "subtitle"] \
    [list "Force field, EMC and LAMMPS options are set in the option tabs. These are sorted alphabetically and influence the way EMC builds will proceed or how the LAMMPS input files will be written. A short info is displayed when hovering above the entry field of a specific option for some time. The force field tab sets options related to the force field and its behavior. The file browser allows for defining own force field files. When running DPD simulations this is a necessity. If the default value remains unchanged it will not be written to the options in the esh file as emc will set it correctly internally. Therefore, these options will not be specified in the options code block in the esh files. Aside from the main options the individual options are mainly for advanced users which know what they are doing." "text"] \
  ]
  set link {montecarlo.sourceforge.net/emc/Welcome.html}
  set title "Define Chemistry Information"
  return [list ${text} $link $title]
}


#==============================================================================
#
#==============================================================================

proc ::EMC::gui::TrialsInfo {} {
  set text0 "Trial Selector Window\n\n"
  set font0 "title"
  set text1 "The trial treeview allows the user to introduce a wildcard into the system. This adds multiple trials to the \
 system and exchange of one compound in the system for several chemicals is possible. Please see the Stage/Trial description \
 to see the use of trials. \
Assuming one might want to test several solvent combinations, instead of setting up each simulation by itself one can simply \
 list the solvents in the trial box and the esh file will be written such that each trials uses a different solvent while \
 maintaining the remaining composition of the system. Then, each of the systems is encoded by the given trial name. \
 these may still be sampled with altering concentrations as well.\n\n\n"
  set font1 "text"
  set link {montecarlo.sourceforge.net/emc/Welcome.html}
  set text [list [list $text0 $font0] [list $text1 $font1]
  set title "Trial Information"
  
  return [list ${text} $link $title]
}


#==============================================================================
#
#==============================================================================

proc ::EMC::gui::ForceFieldOptionsInfo {} {
  set text [list \ 
    [list "Force Field Options Tab\n\n" "title"] \
    [list "The force field options allow for customization of the force field used for EMC and the following LAMMPS run. Options which are not relevant to the selected force field will be grayed out and unchangable. the default values for the individual options change with each field. Any settings which were chosen with another field will be overwritten and should be reviewed by the user prior to use. The option descriptions as found in the Users Guide are listed below.\n\n" "text"] \
    \
    [list "Force Field Browser\n\n" "subtitle"] \
    [list "The order in which the force field files are specified they will be called and used for the typing process within EMC. Therefore, specific force fields (amino acids, lipids etc.) are called first and only later the more general force fields are used. This way it is guaranteed that the more accurate force fields are used first. Keep this in mind when specifying the order of force fields in the force field browser." "text"] \
    \
    [list "Force Field Options Overview\n\n" "subtitle"] \
    [list "[::EMC::gui::PopulateHelpOptions field]" "text"] \
  ]
  set link {montecarlo.sourceforge.net/emc/Welcome.html}
  set title "Force Field Tab Information"
  return [list ${text} $link $title]
}


#==============================================================================
#
#==============================================================================

proc ::EMC::gui::EMCOptionsInfo {} {
  set text [list \
    [list "EMC Options Tab\n\n" "title"] \
    [list "EMC options contain options which influence the EMC build process and the features which are directly linked with EMC. this is only a small subset of the available functionality of emc. Further functionality is accessible by directly modifying the build.emc scripts which are generated by emc_setup or writing the from scratch by hand. The option descriptions as found in the Users Guide are listed below.\n\n" "text"] \
    \
    [list "EMC Options Overview\n\n" "subtitle"] \
    [list "[::EMC::gui::PopulateHelpOptions emc]" "text"] \
  ] \
  set link {montecarlo.sourceforge.net/emc/Welcome.html}
  set title "EMC Options Information"
  return [list ${text} $link $title]
}


#==============================================================================
#
#==============================================================================

proc ::EMC::gui::LammpsOptionsInfo {} {
  set text [list \
    [list "LAMMPS Options Tab\n\n" "title"] \
    [list "LAMMPS options contain all options which are relevant for the LAMMPS runs following an emc build, such as run time, number of steps or output frequencies. It is important to think about the desired simulation lengths prior to building systems as changing some of the parameters and options after submitting jobs is difficult. This would also be the case if the emc environment is not used. The option descriptions as found in the Users Guide are listed below.\n\n" "text"] \
    \
    [list "Lammps Options Overview\n\n" "subtitle"] \
    [list "[::EMC::gui::PopulateHelpOptions lammps]" "text"] \
  ]
  set link {montecarlo.sourceforge.net/emc/Welcome.html}
  set title "LAMMPS Options Information"
  return [list ${text} $link $title]
}


#==============================================================================
#
#==============================================================================

proc ::EMC::gui::AnalysisOptionsInfo {} {
  set text [list \
    [list "Analysis Options Tab\n\n" "title"] \
    [list "The analyis options are relevant for LAMMPS runs following an EMC build. It changes several LAMMPS flags which modify the output files generated during a simulation and the subsequent analysis scripts which are provided. The option descriptions as found in the Users Guide are listed below.\n\n" "text"] \
    \
    [list "Analysis Options Overview\n\n" "subtitle"] \
    [list "[::EMC::gui::PopulateHelpOptions analysis]" "text"] \
  ]
  set link {montecarlo.sourceforge.net/emc/Welcome.html}
  set title "Analysis Options Information"
  return [list ${text} $link $title]
}

#==============================================================================
#
#==============================================================================

proc ::EMC::gui::CheckRunInfo {} {
  set text [list 
    [list "Check/Run Info\n\n" "title"] \
    [list "This tab is where the actual simulations are executed. The run options are important options which handle the queues and runtimes for builds, runs and analyses which are allocated. Below are several buttons to trigger several potential usages of the gui: Check run is an internal check which ensures the most important options have been set and some common user mistakes are caught here. These tests are custom and completely independent of emc_setup or emc. Write emc script simply writes the esh file which results from the users options and the chemistry which has been defined. These can be then run manually, edited, expanded or used for other purposes. These files are only checked by the check function and not by emc and may not run. Test Run Build offers the best way to check the integrity of the file. In a temporary directory the file is written and emc_setup is executed to generate all files. Any errors occurring within emc_setup, if one were to use the desired settings, are caught here. The file is only altered by adding the emc_test flag which skips the actual monte carlo steps of emc. EMC will return any errors such as missing parameters or other errors which impair the integrity of the build. A summary in the tk console and terminal show the number of molecules built, mass and massfraction of the total system (occasionally there are some rounding errors which result from emc). Afterwards the emc build can be triggered. Using the test build prior to the real build minimizes the potential errors significantly. This submits all builds according to the specified queuing systems and queuing times.\n\n" "text"] \
  ]
  set link {montecarlo.sourceforge.net/emc/Welcome.html}
  set title "Run Information"
  return [list ${text} $link $title]
}


#==============================================================================
#
#==============================================================================

proc ::EMC::gui::ResultsSummaryInfo {} {
  set text [list \
    [list "Results and Summary Information\n\n" "title"] \
    [list "All emc builds which were submitted by the gui are displayed here in a treeview indicating the system name according to its path, the queue type (local or remote), progess of the build and the visualization state in the vmd main window.  Update status checks the progress of the emc builds based on their out files and displays their progress. Upon completion one can visualize the chosen system directly from this tab by choosing load visualization. If multiple molecules are loaded always the selected item from the treeview is displayed and the other active ones are hidden. Molid -1 refers to molecules which have not been loaded to the vmd main menu and, therefore, do not have a molid yet (Molid is a running number; if a molecule is deleted form the main window and then reloaded it will have a new molid. This is normal behavior of vmd). The load esh file button allows old files which were not generated in the gui or if sessions were not saved in the gui to be loaded into the summary window. The paths which result from the loops code block are reconstructed based on this information.\n\n" "text"] \
    \
    [list "Button Usage\n\n" "subtitle"] \
    [list "Update Status: " "subtitle"] \
    [list "This updates the status of all the runs in the treeview. Pending jobs have not been started, running jobs will display their progress percentage and jobs which have been build will be marked as completed. Only if a job is completed one can vizualize the results. If any unusual text is displayed in the status column one can assume that something went wrong during the build process. these systems should be discarded.\n\n" "text"] \
    [list "Load Viz state: " "subtitle"] \
    [list "Once a run is completed the built system can be visualized. The .vmd file generated by emc will be called and open a visualization state of the system in vmd.\n\n" "text"]\
    [list "Remove Viz state: " "subtitle"] \
    [list "The selected visualization state is deleted from vmd.\n\n" "text"] \
    [list "Clear All Viz States: " "subtitle" ]\
    [list "All visualization states are removed from vmd.\n\n" "text"] \
    [list "Read ESH File: " "subtitle"] \
    [list "This allows reading in a previously generated ESH file. This does not necessarily have to originate from the GUI.\n\n" "text"] \
    [list "Delete Entry: " "subtitle"] \
    [list "Completely removes the entry from the treeview whithout the possibility of reloading it at that point.\n\n" "text"] \
  ]
  set link {montecarlo.sourceforge.net/emc/Welcome.html}
  set title "Results/Summary Information"
  return [list ${text} $link $title]
}


#==============================================================================
#
#==============================================================================

proc ::EMC::gui::SmallMoleculeInfo {} {
  set text [list \
    [list "Small Molecule Window\n\n" "title"] \
    [list "With the small molecule window the user has the possibility to define individual small molecules which are introduced in the system as is. The Window offers a treeview list which consists of a 2-column list with group name and smiles definition as entries. Any entry which is used is added to this list. Additionally, many more groups can be defined here for later use or imported. The list is merely used to give the user the opportunity to reuse groups he has defined in previous builds to minimize the necessity to retype all the strings. The import function is able to read 2 column lists or existing esh files. Here the ITEM GROUPS section is read and imported to the list. The groups which are supposed to be used still have to be added to the system before they are used in any build run! The list can be saved as 2 column text file or is also saved as a state file when a session is saved. With add entry and edit entry and delete entry is managed during usage of the gui. This does not influence the behavior of main window where the chemistry is defined.\n\n" "text"] \
    \
    [list "Button Usage\n\n" "subtitle"] \
    [list "Import File: " "subtitle" ] \
    [list "Allows the import of tables of compounds containing group name and smiles string. Groups from previously written esh files can be read as well. Monomers from polymeric systems will be ignored.\n\n" "text"] \
    [list "Save File: " "subtitle" ] \
    [list "The list of groups displazed in the small molecule list can be saved in tabular form as simple text file.\n\n" "text"] \
    [list "Delete Entry and Clear All: " "subtitle"] \
    [list "Deletes a single entry in the table or clears all entries. this only affects the groups in the overview window. This will not delete the groups in the main window, which have already been defined for a build.\n\n" "text"] \
    [list "Move Up and Move Down: " "subtitle"] \
    [list "Allows individual entries to be moved around for sorting. This merely changes the position in the table for sorting entries. This has no further implications for the build.\n\n" "text"] \
    [list "Add Entry: " "subtitle"] \
    [list "This adds the entry to the group list above. Adding an entry to this list does not automatically add it to the system which is being built. To add it to the system use the add molecule to system button below.\n\n" "text"] \
    [list "Edit Entry: " "subtitle"] \
    [list "If a group is selected in the group table and it is edited in the entry fields, this will update the entry with the changes. If one chooses \" Add Entry \" a new instance of the group will be generated.\n\n" "text"] \
    [list "Add Molecule to System: " "subtitle"] \
    [list "The molecule is added to the Defined Chemistry table in the main window. Theses groups are the ones which will be built.\n\n" "text"] \
  ]
  set link {montecarlo.sourceforge.net/emc/Welcome.html}
  set title "Small Molecule Window Information"
  return [list ${text} $link $title]
}


#==============================================================================
#
#==============================================================================

proc ::EMC::gui::SurfacesInfo {} {
  set text [list \
    [list "Surface Definiton Window\n\n" "title"] \
    [list "Currently surfaces can only be defined using the insight format. The crystal lattice needs to be defined in insight and exported. This file name can be imported by emc with an import command. The surface always occupies the inner most phase in the gui. An additional emc type input is theoretically possible, however this is not supported by the gui. Please consult the emc manual for further information.\n\n" "text"] \
    \
    [list "Usage Of Buttons\n\n" "subtitle"] \
    [list "" "text"] \
  ]
  set link {montecarlo.sourceforge.net/emc/Welcome.html}
  set title "Surface Window Information"
  return [list ${text} $link $title]
}


#==============================================================================
#
#==============================================================================

proc ::EMC::gui::PolymerGroupInfo {} {
  set text [list \
    [list "Monomer Group Definition Browser\n\n" "title"] \
    [list "The polymer window allows the definition of monomer groups and polymers which are based on these. The monomers are defined similar to small molecules. Each group needs at least one (*) which indicates in the smiles string where groups are connected to eachother. The groups are always defined in their saturated form, not the chemical precursor for a polymerization reaction. Groups can be added manually to the monomerlist or imported from tables or existing esh files. The list is managed with the buttons left of the panel allowing to edit, delete, move or save the entries of the list for later use.\n\n" "text"] \
    \
    [list "Usage of Button\n\n" "subtitle"] \
    [list "Import File: " "subtitle"] \
    [list "Allows the import of tables of compounds containing group name and smiles string. Groups from previously written esh files can be read as well. Monomers from polymeric systems will be ignored.\n\n" "text"] \
    [list "Save File: " "subtitle"] \
    [list "The list of groups displazed in the small molecule list can be saved in tabular form as simple text file.\n\n" "text"] \
    [list "Delete Entry and Clear All: " "subtitle"] \
    [list "Deletes a single entry in the table or clears all entries. this only affects the groups in the overview window. This will not delete the groups in the main window, which have already been defined for a build.\n\n" "text"] \
    [list "Move Up and Move Down: " "subtitle"] \
    [list "Allows individual entries to be moved around for sorting. This merely changes the position in the table for sorting entries. This has no further implications for the build.\n\n" "text"] \
    [list "Add Entry: " "subtitle"] \
    [list "This adds the entry to the group list above. Adding an entry to this list does not automatically add it to the system which is being built. To add it to the system use the add molecule to system button below.\n\n" "text"] \
    [list "Edit Entry: " "subtitle"] \
    [list "If a group is selected in the group table and it is edited in the entry fields, this will update the entry with the changes. If one chooses 'Add Entry' a new instance of the group will be generated.\n\n" "text"] \
    [list "Add Molecule to System: " "subtitle"] \
    [list "The molecule is added to the Defined Chemistry table in the main window. Theses groups are the ones which will be built." "text"] \
  ]
  set link {montecarlo.sourceforge.net/emc/Welcome.html}
  set title "Polymer Groups Information"
  return [list ${text} $link $title]
}


#==============================================================================
#
#==============================================================================

proc ::EMC::gui::PolymerDefinitionInfo {} {
  set text [list \
    [list "Polymer Definition Window\n\n" "title"] \
    [list "Below the polymers which have been defined are listed. One can add a new polymer, delete or edit and existing one. In accordance to this list the polymer connectivity grid is updated. Since a monomer group might appear in multiple polymers it is necessary to always update the polymer grid in accordance with all defined polymers so no connectivity is missing. The polymers can be easily edited here in the GUI. This is due to some technical reasons as to how EMC works when handling groups.\n\n" "text"] \
    \
    [list "Usage of Buttons\n\n" "subtitle"] \
    [list "New Polymer: " "subtitle"] \
    [list "Opens a new instance of a polymer. The edit polymer window is opened. All previously defined groups in the monomer list are available. When additional groups are to be added the window has to be reopened. Be advised that each polymer needs at least 2 terminating groups which are either specified by the :t key or must have only one connector asterisk.\n\n" "text"] \
    [list "Edit Polymer: " "subtitle"] \
    [list "Opens the instance of the polymer which is selected in the treeview for editing. Be advised that changing existing polymers will also influence the connectivity grid. Therefore, always check whether the connectivity is still up to date and add apply the necessary changes.\n\n" "text"] \
    [list "Delete and Clear All: " "subtitle"] \
    [list "This will delete a selected or all polymer entries from the list. Respectively the polymer connectivity grid will be updated to reflect these changes. It is advised to check whether all connectivies are still in order when deleting groups.\n\n" "text"] \
    [list "Edit Connection: " "subtitle"] \
    [list "Opens the Connector grid which defines the interconnectivity between the individual groups of the polymers. Usually the grid is always opened when a change to the total group list is made and user input is required.\n\n" "text"] \
    \
    [list "Why one should think carefully about the polymers one wants to build:\n\n" "subtitle"] \
    [list "Each group is defined once and contains all the connectivity information which defines its relation to other groups. These must only be defined once otherwise emc will fail when ambiguity arises between the individual group definition. By first defining all polymers and their compositions the polymer connectivity grid will correctly displayed with all possible connections. Each group needs at least one other group it is linked to otherwise it will generate an error. Groups specified as terminator (:t) but containing two connectors may only be linked to a single connector (but multiple groups within multiple polymers)\n\n" "text"] \
  ]
  set link {montecarlo.sourceforge.net/emc/Welcome.html}
  set title "Polymer Definition information"
  return [list ${text} $link $title]
}


#==============================================================================
# Debugging
#==============================================================================

proc LINE {frame_info} {
  # Getting value of the key 'line' from the dictionary 
  # returned by 'info frame'
  return [dict get [info frame $frame_info] line]
}


#==============================================================================
#
# IMPORTANT TO ADD TO VMD MENU AS EXTERNAL PLUGIN
#
#==============================================================================

proc emc_gui_tk {} {
  ::EMC::gui::emc_gui
  return $::EMC::gui::w
}

vmd_install_extension emc_gui emc_gui_tk "EMC/GUI"

