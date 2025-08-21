#!/usr/bin/env perl
#
#  script:	emc.pl
#  author:	Pieter J. in 't Veld
#  date:	February 4-9, August 10, 2012, April 27, 2013, March 29,
#  		June 12, November 2, 18, 24, 29, December 20, 22, 2014,
#  		February 5, 11, April 8, 16, 24-30, May 11, 19, 22,
#  		June 10, 30, July 14, August 1, September 25, November 11-17,
#  		23-30, 2015, January 19-26, February 17, 22, March 10, 15, 
#  		May 24, June 15, 20, 24, July 1, August 18, September 8, 
#  		October 24-31, 2016, March 11, 24-26, April 6, 9, 12, 
#  		May 8, 14, 17, June 15, 22, 24, July 1, 11, 17-21, August,
#  		September 12, 16-17, 2017, January 18-31, February 1-24, 2018,
#  		etc. (See notes)
#  purpose:	Wrapper for creating EMC and LAMMPS input scripts for atomistic
#  		and coarse-grained [[multi-]interface] simulations; part of
#  		EMC distribution
#
#  Copyright (c) 2004-2025 Pieter J. in 't Veld
#  Distributed under GNU Public License as stated in LICENSE file in EMC root
#  directory
#
#  notes:
#    20120204	Inception
#    20120210	Addition of temperature to parameters
#    20120224	Addition of build, assume, and frequency flags
#    20120419	Bug-fix concerning density profile cluster order
#    		Alignment of pressure profile frequency with density profiles
#    		Inclusion of _chem and _parm wildcard suffixes
#    20120502	Mass-related bug fix
#    20120503	Addition of charge paragraphs
#    20120612	Bug-fix phase determination in read_chemistry
#    		Added molecular volume read from chemistry column 5
#		Added volume flag to allow for weighting by molecular volume
#		Added extra flag for creating parameter copies
#		Stream-lined fraction interpretations
#    20120614	Corrected mistakes in bond interpretation
#    		Added global setting of parameters to constant value
#    		Added number check on lammps density profiles
#    		Added lower bound on parameters
#    20140327	Changed to implement as DPD force field
#    		Added -angle and reference file for cut off and mass scaling
#    20140614	Added multiple phases to command line by introducing a '+' sign
#    		as demarcation
#    		Fixed issues upon absence of a reference file
#    20140730	Added -seed flag to set initial random seed
#    		Updated use of charges
#    20141019	Added checks for force field topology
#    20141102	Combined dpd_setup.pl and atom_setup.pl into emc_setup.pl
#    20141118	Repaired appearance of density profiles in LAMMPS script
#    20141124	Addition of referenced extra parameters
#    20141129	Addition of dpd_setup.pl routines
#    20141218	Added atomistic interpretation of ntotal
#    		Added lbox determination in terms of mass density [g/cc]
#    20141220	Changed to using mass() and nsites() in EMC scripting
#    20141222	Repaired msd and profile flag operation
#    		Added extra comments to lammps input script
#    20150205	Changed opls{aa, ua} to opls-{aa, ua}
#    		Added trappe force field options
#    20150211	Added radius and grace adaptations for dpd force fields
#    		Debugged multiphase system setup
#    20150216	Added overwrite safeguards for created scripts
#    		Added density designation for each phase
#    20150303	Corrected entries for CHARMM and MARTINI implementations
#    20150306	Added refinements to accomodate DPD implementations
#    20150316	Added neighbor paragraph for DPD implementations
#    20150408	Added cross flag to lammps for DPD and MARTINI
#    20150416	Added coulomb->pair for non-DPD force fields
#    20150424	Corrected minor bugs for DPD implementations
#    20150428	Adapted mass interpretation for DPD implementations
#    20150430	Added disallowed cluster names
#    20150511	Added inclusion of extra clusters in LAMMPS input script when
#    		using the . separator in SMILES
#    		Altered behavior of -emc, -lammps, and -params flags
#    		Added -replace flag
#    20150519	Reworked chemistry.csv format to include polymers, using 
#    		paragraph keywords starting with 'ITEM'; legacy file format
#    		is still valid
#    20150522	Added correction for DPD interaction parameters based on
#    		reference volumes and actual volumes
#    20150528	Added -communicate to cover change from communicate to 
#    		comm_modify in newest versions of LAMMPS
#    20150610	Added focus for molecules
#    20150630	Added id[:t] to identify forced terminator groups
#    20150714	Added group[:group[:...]] and n[:w:w[:...]] to POLYMERS to
#    		allow for statistical drawing of group identities
#    20150801	Added 'ITEM SHORTHAND' and 'ITEM COMMENTS' to chemistry file
#    20150925	Corrected behavior when selecting mol fractions
#    20151111	Changes in LAMMPS input script for DPD:
#    		- Removed langevin thermostat
#    		- Changed neigh_modify from 'delay 1 every 1' to 'delay 0 every 2'
#    		- Reduced default charge cutoff from 4.0 to 3.0
#    20151117	Added keyword VERBATIM to chemistry file interpretor for
#    		adding verbatim EMC scripting to build file
#    20151123	Broadened force field recognition (e.g. -field=dpd/general)
#    		Debugged interpretation of -charge=false for -field=dpd
#    20151127	Added $::EMC::Lammps{prefix} for adding project prefix to output
#    		and $::EMC::Lammps{chunk} for using chunk approach in profiles
#    20151130	Added $::EMC::MD{restart} and $::EMC::Shear
#    20160119	Refined force field choice
#    20160120	Generalized LAMMPS input script to be used for either
#		equilibration or restart
#    20160126	Added block on mass and volume entry in chemistry file for
#		atomistic force field
#    20160217	Added increment warning flag to navigate missing increments
#    20160222	Added line extensions '&' and '\' to input
#    		Added surface incorporation to CLUSTERS
#    20160310	Added -nparallel for surfaces
#    		Added BOND and ANGLE paragraph to chemistry file for definition
#    		of specific bonds and angles
#    		Added -bond=type1,type1,k,l & -angle=type1,type2,type3,k,theta
#    		command line options to allow for command line addition of
#    		specific bonds and angles
#    20160315	Added -momentum flag to allow for zeroing momentum in lammps
#    20160321	Added verbatim end operation possibility
#    		Incorporated variable changes as a result of invoking surfaces
#    20160422	Adapted inclusion of unit mass for added replicas
#    20160511	Fixed replica addition with missing references.csv
#    20160524	Altered behavior of mixed use of space and tab separators
#    		Altered passing of numbers of clusters from EMC to LAMMPS by
#    		introducing variables starting with 'nl_'
#    20160615	Added Born potential hooks
#    20160620	Fixed replica interpretation
#    		Added variable paragraph to chemistry file
#    20160624	Added option -warn to allow for warning output control
#    20160628	Added ITEM OPTIONS for setting command line options in the
#    		chemistry file
#    20160720	Added 'old', 'new', and year options for -lammps to set -chunk
#    		and -communicate; set default to new LAMMPS versions
#    20160804	Added all field flag options for angle, torsion, improper, and
#    		increment (angle now has dual functionality)
#    20160818	Fixed chunk usage
#    		Added -dtthermo, -dtrestart, -trun, and -tequil
#    20160908	Added -center, -depth, and -record
#    20160922	Added -hexadecimal
#    20161025	Added internal shake flag to allow for stable runs
#    20161026	Added pressure and shear paragraphs to be reflected in lammps
#    		input file
#    20161031	Added environment mode for generation of project directory
#    		structure and parallel run scripts
#    20161114	Corrected nl_ composition for polymers
#    20161121	Added loop pairing to pair variable with previous
#    20170106	Added replacement of one nonbond entry with another
#    20170113	Added build directory creation to environment setup
#    		Take chemistry file name as default for run names
#    20170124	Added shake option and adapted type interpretation
#    20170131	Fixed issues with field designation
#    20170207	Allowing only unique entries in LOOP variables
#    20170208	Adapted interpretation of multiple LOOP sections
#    		Added energy and volume time average paragraphs for LAMMPS
#    		input script
#    20170209	Renamed options 'location', 'name' and 'type' to 
#    		'field_location', 'field_name' and 'field_type' respectively
#    		Added option 'name_scripts' to set analyze, build, and run
#    		names simultaneously
#    20170220	Added 'field_error' option
#    20170223	Added skip on existing .data during build
#    		Fixed thermo output in restart mode
#    20170311	Changed indexing of %::EMC::Field by adding @::EMC::Fields
#    20170326	Added -nchains option, allowing for chains of simulations
#    		Included emc build phase in lammps run scripts
#    20170406	Added -pdb_cut, allowing for cutting bonds spanning the box
#    		Added 'import' to CLUSTERS paragraph as type to allow for
#    		importing structures in either EMC or InsightII serving as
#    		surfaces etc.
#    20170409	Added -execute flag for executing EMC build script
#    20170412	Added -direction flag for using different phase build
#    		directions
#    20170424	Added pairwise exclude region when importing structures
#    		Added -region_epsilon and -region_sigma for defining exclusion
#    		regions
#    		Added -pdb_fixed and -pdb_rigid flags
#    20170506	Changed from environment 'phase' to 'stage', maintaining
#    		backwards compatibility
#    20170508	Changed calling of -file for LAMMPS restart
#    20170514	Added green-kubo as sample option
#    20170517	Added reserved word 'copy' to environment loop variables
#    20170221	Added -analyze_last to control inclusion of last frame during
#    		analysis
#    20170530	Added project name to queue submission
#    20170615	Cleaned up structure interpretation
#    		Added :d or :double mode to environment loop variables
#    20170622	Excluded DPD nonbond wildcard entry when -auto=false
#    20170624	Addition of -options export to GUI
#    20170701	Improved behavior when importing structures
#    20170711	Added EMC environment testing mode
#    20170717	Added -cut=repulsive for transfering purely repulsive
#		potentials to LAMMPS
#    20170718	Added -number for interpreting cluster fractions as number of 
#    		molecules
#    		Fixed an issue with empty additional variables as offered to
#    		write_emc_variables()
#    20170721	Added -replace_build flag for ignoring existing .data files
#		during build script execution; can alo be invoked by adding
#		-replace flag to ./build/.sh script
#		Added use of -build flag in conjunction with ./run/.sh scripts,
#		allowing for invoking LAMMPS executing after EMC build; uses
#		queueing system chains
#    20170725	Added -thermo_multi to invoke multi thermo style in LAMMPS
#    20170726	Added pressure profile sampling to LAMMPS script
#    20170728	Fixed issue with multi-phase exclusion regions for DPD
#    20170805	Corrected output of number of polymers when using -number=true
#    20170810	Fixed issue with profile per type not being written
#    20170812	Moved write_emc_field_apply() from write_emc_clusters() to
#    		write_emc_phase()
#    20170814	Fixed issue with profile per type not using the correct types
#    20170816	Added pressure profile for all atoms when selected
#    20170818	Fixed issue with structures containing formatting signs in
#    		SMILES
#    20170822	Added -pdb_connect option
#    20170823	Excluded project name as possible profile name
#    		Added :h to LOOPS in environment to exclude variable from
#    		directory structure
#    20170830	Added type 'density3d' to option and item profiles
#    		Added 'binsize' to options
#    20170912	Resolved issue with zero repeat units in polymers
#    20170914	Set initial value of $::EMC::Lammps{trun_flag} to false 
#    20170917	Consolidation of EMC, Lammps, and Parameter flags
#    		Application of strict Perl variable handling
#		Addition of force field module for inclusion of full fields
#		through ITEM FIELD
#		Fixed use of multiple entries for -field_name
#    20170919	Addition of references through ITEM REFERENCES
#		Addition of parameters through ITEM PARAMETERS
#    20170920	Corrected error checking on existence of environment trial
#    		Fixed issue with usage of copy keyword in loops
#    		Fixed issue with reading field_name option
#    20170921	Fixed issue with profiles
#    20170927	Fixed issue with recognizing loop variables when using colons
#    		Fixed issue with polymer fractions when using variables
#    		Corrected phase box sizing when building polymers
#    20171012	Added -percolate option for crystalline InsightII structures
#    		Disabled NPT when invoking -pressure=false
#    20171018	Added -expert to allow overrides of number checks for polymers
#    20171024	Added -tighten to tighten simulation box around imports
#    20171025	Added triclinic treatment of box geometry
#    20171029	Added ITEM LAMMPS paragraph for verbatim additions to LAMMPS
#    		script
#    20171031	Added -crystal option for imported crystalline structures
#    20171106	Added keyword 'number' to import of clusters
#    20171109	Added sequences to loops when pairing variables
#    20171116	Added -triclinic flag to force triclinic boxes in LAMMPS;
#    		Added (un)coupling of directions for LAMMPS NPT as extra 
#    		keyword when defining pressure
#    20171125	Added treatment for imported structures
#    		Added -pdb_pbc and -pdb_unwrap flags to resp. control periodic
#    		boundary conditions and unwrapping in PDBs
#    20171127	Added -weight for energetic weighting of force components as
#    		used by EMC during structure building; replaces -grace
#    20171203	Updated various BASH script interpretational issues, including
#    		obtaining th queueing system job ID for chaining LAMMPS jobs
#    20180109	Added flexible barostat options to reflect different coupling
#    		scenarios
#    20180118	Fixed issues with replacement while executing run script with
#    		-norestart option
#    		Added help for command line options for build and run scripts
#    20180120	Added -emc_output for EMC output control
#    20180123	Added Berendsen barostat to LAMMPS input script for DPD
#    		Improved barostat coupling and direction options
#    		Loosened behavior of & line concatenation
#    20180124	Added interpretation of pdb_cut, pdb_unwrap, and pdb_vdw for
#    		analyze_last in environment option paragraph
#    		Added control for execution of EMC for building during
#    		execution of build and run scripts
#    20180126	Added -[no]emc and -[no]pdb flags to analysis scripts
#    		Adapted formatting of bash scripts
#    		Added deformation of imported structures
#    		Added project name to chemistry/stages for template writing
#    20180131	Changed mkdir to mkpath (File::Path) to create multi level
#    		directories
#    20180201	Updated deformation of imported structures
#    20180207	Added ITEM ANALYSIS for addition of user defined analysis
#    20180212	Distinguished between build and run walltime in run scripts
#    20180215	Added parameter evaluation for DPD forcefield definition
#    20180217	Rearranged order in run_emc() for both build and run scripts
#		Changed focus behavior
#    20180224	Added -analyze_data to control creation of exchange tar archive
#    		Added -analyze_replace to control replacement of existing
#    		results
#    20180308	Added -emc_run and -emc_traject for Monte Carlo equilibration
#    		after building
#    20180402	Fixed default behavior of set_list()
#    		Added -name_testdir for adding tests of chemistry paragraphs in
#    		environment files; creates ./test/${name_testdir}/setup.sh
#    20180404	Added interpretation of field type colloid including shear
#    		Renamed -replace_build to -build_replace
#    		Refined and streamlined behavior of -build_replace
#    20180424	Changed interpretation of 'copy' loop variable to allow for
#    		sequences
#    20180503	Corrected a directory issue with already existing builds while
#    		running emc through build or run scripts
#    20180512	Adapted designation of type variable for creation of type
#    		specific profiles: moved to EMC .params file
#    20180526	Added -namd for creation of NAMD input
#    		Added -pdb_parameters for creation of NAMD .prm input
#    		Added multiple jobs per node using job packing
#    20180601	Added sequence interpretation for test setup.sh
#    20180612	Improved functionality for using -build flag on run scripts
#    20180620	Fixed creation of test paths
#    20180622	Fixed interpretation of pressure coupling for equal signs
#    20180626	Added '(*' and '*)' at start of line as comment delimiters
#    20180628	Fixed write_emc_field_apply() to avoid empty types -> {}
#    20180705	Improved run behavior upon LAMMPS restart
#    20180708	Added items ENVIRONMENT [project] (acts as OPTIONS; sets
#		project when supplied) and CHEMISTRY (identical to TEMPLATE)
#    20180710	Moves option -depth to -emc_depth
#    20180716	Changed behavior of -record to allow for more control of
#    		resulting PDB
#    20180718	Changed behavior with respect to queue sizing for preset
#    		machines
#    20180801	Added -skin and integrated -units into LAMMPS input script
#    20180803	Fixed inclusion of atomistic and united atom force fields
#    		Added -field_reduced to override reduced units defaults
#    20180814	Changed compute com/msd to msd/chunk
#    20180825	Forced -emc_execute=false in environment mode
#    20180901	Corrected behavior for nonbonded wildcards
#    20180919	Expanded loop sequence interpretation to include previously
#    		defined loop variables (e.g. @X refers to x)
#    		Added -lammps_pdamp and -lammps_tdamp for setting damping
#    		constants
#    20180921	Renamed -chemistry to -script and changed associated internal
#		variables
#		Reorganized global constants
#    20180925	Added :w option to sequence interpretation to enforce equal
#    		width (usage: e.g. s:2:10:2:w)
#    20180926	Added possibility for adding optional cutoff and gamma to
#    		DPD nonbonds
#    20180930	Added radius of gyration analysis
#    20181008	Added -analyze_source to set the location source of the data
#		directory
#		Added -polymer_niters to control the number of iterations used
#		to build (branched) random polymers
#    20181009	Corrected inclusion of .params file during analysis
#    20181010	Allowing for project names with slash in name: last part will
#    		will be project name; whole name will be script location
#    20181013	Changed behavior for fields with possibly uncharged systems
#    20181014	Added end-to-end analysis
#    20181027	Corrected multiple jobs per node behavior for local queues
#    20181029	Corrected behavior for (re)starting packed jobs
#    20181103	Corrected inclusion of field in template
#    		Added -build_order to build clusters in order as provided by
#    		-phases
#    		Migrated -center to -build_center
#		Updated variable behavior to avoid incorrect interpretation
#		when using e.g. @A and @AA as loop variables
#		Correction for field type colloid
#    20181116	Added -field_format to control format in generated field when
#    		using 'ITEM FIELD'
#    20181129	Corrected behavior for additional user analysis scripts
#    20181214	Fixed issue assigning chunks for MSDs in LAMMPS input
#    		Added -field_nbonded to DPD field bonded inclusions
#    		Corrected the use of chunks for profiles and MSD
#    		Added average as choice for option -msd combined with
#    		new LAMMPS compute msd/chunk/ave (derived from msd/chunk) and
#    		analysis routines
#    20181218	Corrected missing initial creation of chemistry directory
#    20181228	Adapted interpretation of sample flags for analysis
#    		Added -- to all calls to perl to allow for arguments starting
#    		with a minus sign (GNU convention: point where options stop)
#    20190110	Adapted treatment of CHARMM to include correct use of switching
#    		function for both pair and pair14 (in dihedral) contributions
#    20190126	Added :f[ield]=id option to group identifiers to force
#    		using a specific field id for typing when using multiple fields
#    20190318	Altered behavior of ITEM VERBATIM 0 [0|1], which allows for
#    		usage of verbatim before (mode 0) and after (mode 1) sizing
#    		old(ITEM VERBATIM 0 [0]) = new(ITEM VERBATIM 0 1)
#    		Added expert mode to interpretation of environment variables,
#    		such that constants can be used in conjunction with loops
#    20190408	Corrected parsing behavior of loop variables
#    		Added -pdb_compress option
#    20190410	Changed location interpretation of chemistry/stages dirs
#    		Added -niterations for control of build interations
#    		Consolodated build settings in $::EMC::Build
#    20190416	Allowing for undefined clusters in expert mode when defining
#    		phase contributors
#    		Cleaned up command line behavior for setting project name and
#    		main script
#    20190418	Allowing for hash as comment in options
#    		Allowing for non-existing polymer definitions in expert mode
#    20190424	Changed behavior of -build_replace in subsequent run scripts
#    		Added value of option -seed to build.emc
#    		Added -field_dpd options
#    20190427	Changed -pdb_compress default to true
#    20190501	Improved behavior for additional nonbonded parameters using
#    		'ITEM NONBONDS'
#    20190503	Added phase=# and spot=# to 'ITEM VERBATIM' where # can be a
#    		number or the word 'last', phase E [0,..,nphases], 
#    		spot E [0,1,2]
#    20190511	Changed replace.pl to add curly brackets around variable
#    		definitions
#    20190521	Added keyword 'all' to -phases option to indicate all clusters
#    		Refined phase splitting
#    20190604	Added -pdb_rank to allow for rank analysis for PDB output
#    20190606	Updated behavior of phase=-1 for ITEM VERBATIM
#    20190622	Improved variable replacement handling
#    		Added exclude as identifier for importing in ITEM CLUSTERS
#    		Improved ITEM VERBATIM option handling
#    		Added environment variable 'WORKDIR'
#    		Added option -workdir to set an alternate work directory
#    20190701	Reordering of phase build up, coupling field apply to clusters
#    20190710	Added -pdb for controlling PDB/PSF output
#    		Changed behavior of -lammps and -emc to exclude reset_flags()
#    20190715	Retired -units=lj and introduced -inits=reduced instead
#    20190718	Changed neighbor list to multi for DPD; added -nocite to lammps
#    20190728	Added -moves_cluster for controlling molecular distribution
#    		Added use of moves and types keywords in EMC build script
#    20190817	Added -queue for general access to queue settings,
#		-queue_account to allow for queue accounting and -queue_user
#		for queue-specific user-defined commands
#    20190902	Added -lammps_dlimit for controling nve/limit maximum distance
#    20191006	Added ITEM EMC as equivalent to ITEM VERBATIM
#    20191118	Added update_field() to update behavior of field options
#    20191119	Changed behavior of non-occurring cluster from warning to error
#    20200127	Added check on number of clusters for polymer mass and length
#    		normalization
#    20200131	Corrected behavior of adding additional bonds when transferring
#    		DPD nonbonds to bonds
#    20200214	Added -cutoff option to set a list of cut offs
#		Added -ghost_cut option for setting LAMMPS ghost region size
#    20200219	Changed behavior of -field option to include improved search
#    20200407	Generalized use of field_id
#    		Added unwrap and guess options to cluster import
#    20200428	Added sorting of fields
#    		Added element targets for group connections
#    		Adapted sorting of field ids
#    20200511	Added -pdb_expand option to allow for expanded format for PSF
#    20200518	Added -insight option for writing InsightII CAR and MDF
#    20200602	Improved variable handling in loops
#    		Altered -build_center to allow for setting of origin
#    20200615	Corrected variable handling
#    20200630	Corrected initial sizing of imported structures
#    		Introduced lprevious as variable for length of previous phase
#    20200801	New version: 3.9.7
#    20200804	Added trim functionality for trimming terminal spaces
#    		Adapted behavior of lines with mixed comma and space separators
#    20200817	Corrected InsightII import
#    20200821	Added environment variable 'EMCROOT'
#    		Added option 'formal' to cluster import options
#    20200825	Forced all variables to be lower case when reported in .params
#    20200915	New version: 3.10.1
#    		Added polymeric group capabilities
#    		Sorted group connectivities
#    20200921	Improved cluster profile designation
#    20200928	Added normalization control to source fractions of replicas 
#    		(see create_replicas())
#    20201029	Added optional comment option to all ITEM statements, i.e.
#		ITEM [COMMAND] [comment=[true|false]]
#    20201121	Added bias to polymer options
#    20201223	Adapted field locator to function properly under MSWindows
#		using Strawberry Perl
#    20210224	New version: 3.10.2
#    		Added -emc_exclude option to control exclusion of sections
#    		Added -emc_export option to control exported formats
#    20210316	Changed interpretation of -pair
#    20210328	Changed internal ITEM VARIABLES representation
#    20210406	Added -emc_progress to control progress indicators
#    20210424	Moved CMAP call to EMC .params
#		Enriched placement of ITEM LAMMPS verbatim paragraphs
#		Expanded -shake option to specify types, bonds, angles, and
#		masses by using type indicators
#    20210429   Updated ITEM ANALYSIS to correctly interpret script name
#    20210521	Fixed double write-out of LAMMPS input script footer
#    20210527	Added -system and -system_geometry options; the latter checks,
#    		if new geometries are large enough to contain polymers from
#    		previous phases (switched on by default)
#    20210530	New version: 4.0
#    		Retired .csv as a valid script extension; valid is only .esh
#    		Added ITEM INCLUDE to include separate parts of scripts
#    		Added ITEM WRITE to write out a line of text
#    		Added -location to prepend paths for various file locations
#    		Fixed usage of ~ in field_location path
#    20210628	Corrected behavior of expert and profile options
#    20210704	Improved field locator
#    20210710	New version: 4.1
#    		Added -split to control partitioning of surface clusters
#    20210718	Fixed ITEM LAMMPS verbatim additions to lammps input script
#    		Added gyration to sample option for radii of gyration
#    		determination through sampling by LAMMPS
#    20210721	Changed the creation of mass in case of replicas; mass is
#    		not redefined when already set under ITEM MASSES
#    20210722	Improved field location routines
#    20210723	Added rudimentary math for ITEM MASSES
#    20210729	Changed variable replacement order
#    20210801	Web publication
#    20211006	Changed -phases interpretation: unused clusters are assigned
#    		to the first empty phase; remaining empty phases cause an
#    		error
#    20211029	Added -lammps_error to control restart upon error
#    		Added -[no]error to resulting run shell scripts
#    		Added -[no]debug to resulting analyze, build, and run shell
#    		scripts
#    20211129	New version: 4.1.1
#    		Updated behavior for defining polymers; to further 'include', 
#    		polymers can be defined before clusters when in expert mode
#    		Changed bash script global loop variable names to all caps
#    20220107	Fixed issue with bash script variable names
#    20220112	Fixed issues with with paired loop variables in bash scripts
#    		Added permutations to loop variables with extensions :2, :3,
#    		and :4
#    20220118	Updated split_data() and get_data() routines
#    		Added new get_data_quick() routine for reading parameters
#    20220131	New version: 4.1.2
#		Added gauss as force field; defaults set similar to dpd
#    		Added the use of the C preprocessor
#    20220203	Adapted -shake interpretation
#    20220207	Fixed polymer type setting for included polymers
#    20220216	Ironed out preprocessing issues with line extenders & and \
#    		Refined error on missing polymer definitions
#    20220223	Added rmax to -cutoff for use with gauss field
#    20220224	Correction to parameter interpretation
#    		Preprocessing only when specifically set under environment
#    		Updated default coarse-graining coulombic parameters
#    		Gaussian bond constants set to k=5 and l=0
#    20220316	Added type=system to import of structures
#    20220324	Corrected use of sequences in loops
#    20220330	New version: 4.1.3
#    		Added $::EMC::Lammps{newer_version} to use neighbor list style
#    		multi/old for versions newer that 2020 through option -lammps
#    		Updated option -modules to [command=]module and inclusion into
#    		run.sh
#    		Improved packing mechanism of multiple jobs on one node
#    20220407	Importing DPD references through get_data_quick()
#    20220727	Added map keyword to cluster import
#    20220801	Web publication
#    20220806	New version: 4.1.4 
#		Improved behavior of ITEM INCLUDE
#    		Allowing for clusters to have the same name as polymeric groups
#    20220830	Migration of list() to EMC::Hash::text()
#    		and set_list() to EMC::Hash::set()
#    20230101	New version: 5.0
#    		Full modularization
#    20230316	Altered run_sh() in write_job_functions() to reflect using
#		third line from last of run.sh output for obtaining job id
#    20230611	Improved variable interpretation in bash script loops
#    		Repaired preprocessing
#    20230701	Fixed use of item variables in environment mode
#    20230801	Fixed quotation of loop sequenced variables by adding
#    		sequence check EMC::Environment::job_loop_sequence_q()
#    20230905	Added -scratch and -sync for using local compute node storage
#    20231003	Updated -emc_moves by improving EMC::Hash::set() and text()
#    20231101	New version: 5.1
#    		Added select to group connectivity for grafting purposes
#    20240103	Repaired issues with -nchains
#    20240109	Added '\' as line extensions (in addition to '&')
#    		Repaired group connectivity issues
#    		Repaired cluster ending in resulting EMC build scripts
#    20240214	Repaired issues with ITEM EMC and LAMMPS
#    20240319	Updated behavior with CHARMM CMAP files
#    20240324	Addition of #include to preprocessing
#    20240522	Reversed the occurence of field location references
#    20240617	Addition of MARTINI3
#    		Additions for template use in force fields
#    20240711	Corrected Green-Kubo viscosity calculation
#    20240801	Web publication
#    20241001	New version: 5.2
#    20241005	Added options -lammps_dump_box for including box multiples in
#    		LAMMPS trajectory files, -field_inverse for field inverse cut 
#    		off, all -gromacs for GROMACS port related settings,
#    		-polymer_flory and -polymer_poisson for setting global
#    		defaults, and -queue_bind for processor binding policies on
#    		compute nodes
#    20241212	Addition of -pdb_licorice for VMD licorice representation
#    20250215	Addition of -xyz and derivatives for .xyz output
#    20250318	New subversion: 5.2.1
#    		Addition of polymeric groups
#    		Addition of -polymer_link to support of polymeric groups
#    20250422	Addition of -md_engine
#    		Addition of GROMACS hooks
#    20250702	Repaired -emc_export smiles
#    20250715	Repaired radius of gyration (gyration) and mean-squared 
#    		displacement (msd) sampling with LAMMPS
#    20250726	Repaired -split to appear at the correct position in build.emc
#    		Addition of phase indication and cluster selections for
#    		option -moves_cluster
#    20250801	Web publication
#        		
#  file formats:
#    parameters	column1	column2		column3		...
#    	line1	-	-		temperature[K]	...
#    	line2	bead a	bead b		parameter	...
#		...	...		...		...
#
#    references	column1	column2	column3	column4	column5	column6	column7	column8
#    	line1	short	id	M g/mol	V nm^3	nconns	charge	nrepeat	comment
#		...	...	...	...	...	...	...	...
#
#    chemistry	column1	column2	column3	...
#    	ITEM	OPTIONS
#    		option	value	[...]
#    	ITEM	SHORT
#    		id[:t]	smiles	frac	[mass	[volume]]
#	ITEM	GROUPS
#		id[:t]	smiles	[end	group	[end	group	[...]]]
#	ITEM	CLUSTERS
#		id	group	frac	[mass	[volume]]
#	surf:	id	surface	nx	filename
#	poly:	id	type	frac
#		type can be either random, alternate, or block
#	ITEM	POLYMERS
#	line1	name
#	line2	frac	group[:group[:...]=w[:...]]	n	[group n [...]]
#	[...]
#	ITEM	VERBATIM	phase#
#		verbatim EMC scripting executed before building phase#
#	ITEM	END
#		ends each paragraph
#
#    ITEMS for DPD only:
#
#	ITEM	NONBONDS
#		type1	type2	a	[cutoff	[gamma]]
#	[...]
#	ITEM	BONDS
#		type1	type2	k	l0
#	[...]
#	ITEM	ANGLES
#		type1	type2	type3	k	theta0
#	[...]
#	ITEM	REPLICAS
#		dest[:f]	src[:f]	[src[:f]	...]	[offset]	
#	[...]
#
#  shorthand chemistry file formats:
#    chemistry	column1	column2		column3		column4		column5
#    	line1	mol id	smiles string	fraction	mol mass	mol vol
#		...	...		...		...		...
#

use strict;

# Identity

$::EMC::Identity = {
  version		=> "5.2.1",
  date			=> "August 1, 2025",
  author		=> "Pieter J. in 't Veld",
};

# Module initialization

BEGIN {
  use File::Basename;
  if (-d dirname($0)."/modules") {
    $::EMC::Modules{dir} = dirname($0)."/modules";
  } else {
    $::EMC::Modules{dir} = $ENV{EMC_ROOT}."/scripts/modules";
  }
  if (! -d $::EMC::Modules{dir}) {
    print("Error: cannot locate modules directory: set EMC_ROOT?\n\n");
    exit(-1);
  }
}
use lib $::EMC::Modules{dir};
use EMC;


# Construct

sub construct {
  my $ptr = shift(@_);

  my $root = EMC::Common::element($ptr);
  my $global = EMC::Common::hash($root, "global");

  set_identity($global);
  set_defaults($global);

  return EMC::construct($ptr);
}


sub set_identity {
  my $global = EMC::Common::hash(shift(@_));
  my $win = $^O eq "MSWin32" ? 1 : 0;
  my $emc = EMC::IO::scrub_dir(
    dirname($0).($win ? "/../bin/emc_win32.exe" : "/emc.sh"));
  $emc =~ s/\//\\/g if ($win);
  my $version = !$win && -e $emc ? (split(" ", `$emc -version`))[2] : "9.4.4";
  my $split = ($win ? "\\\\" : "/");
  my @arg = split($split, $0);
  my $root = EMC::IO::emc_root();
  
  @arg = (split($split, $ENV{'PWD'}), @arg[-1]) if (@arg[0] eq ".");
  my $script = @arg[-1];
  $global = EMC::Common::attributes(
    EMC::Common::hash($global),
    {
      identity		=>  EMC::Common::attributes(
	$::EMC::Identity,
	{
	  main		=> "EMC",
	  script	=> $script,
	  name		=> "Setup",
	  copyright	=> "2004-".EMC::Common::date_year(),
	  command_line	=> "[-command[=#[,..]]] project [phase 1 clusters [+ ...]]",
	  emc		=> {
	    exec	=> $emc,
	    root	=> $root,
	    version	=> $version
	  }
	}
      )
    }
  );
  return $global;
}


sub set_defaults {
  my $global = EMC::Common::hash(shift(@_));

  return $global;
}


# Initialization

sub initialize {
  my $root = EMC::Common::hash(shift(@_));
  my $struct = {root => $root, line => -1};
  my $global = $root->{global};
  my $flag = $global->{flag};
  my $result = undef;

  my $script = $global->{script};
  my $ext = $script->{extension};

  # determine script

  if (! -e $script->{name}.$ext) {
    EMC::Options::set_help($struct) if (!scalar(@ARGV));
    foreach (@ARGV) {
      my @a = split("=");
      $script->{extension} = $ext = @a[1] if (@a[0] eq "-extension");
      next if (substr($_,0,1) eq "-");
      $script->{name} = EMC::IO::strip($_, $ext);
      last;
    }
  }

  my $emc = $root->{emc};
  my $options = $root->{options};
  my $chemistry;
  my $name;
  my @phase;

  # check command line

  $emc->{phases} = [];
  foreach (@ARGV) {
    if (substr($_,0,1) eq "-") {
      my @arg = split("=", substr($_,1));
      $struct->{option} = shift(@arg);
      $struct->{args} = [@arg];
      $result = EMC::Options::set_options($options, $struct);
      if (defined($result) ? 0 : $flag->{ignore} ? 0 : 1) {
	EMC::Options::set_help($struct, 1);
      }
      $chemistry = $script->{name} if ($arg[0] eq "-chemistry");
    } elsif (!defined($name)) {
      my @a = split("\\.", basename($_)); 
      $ext = ".@a[-1]" if (scalar(@a)>1);
      $chemistry = EMC::IO::strip($_, $ext); 
      my $dir = dirname($_);
      $name = basename($_, $ext);
      $name = "$dir/$name" if ($dir ne ".");
      $struct->{names} = [$name];
    } elsif($_ eq "+") {
      push(@{$emc->{phases}}, [@phase]);
      @phase = ();
    } else {
      push(@phase, $_);
    }
  }
  EMC::Options::version($root->{options}) if ($flag->{version});
  push(@{$emc->{phases}}, [@phase]) if (scalar(@phase));
  EMC::Options::set_help($struct) if (!defined($struct->{names}));
  EMC::Options::header($root->{options});
  EMC::Options::set_context($root);

  # reading of script
  
  $script->{extension} = $ext;
  EMC::Common::attributes(
    $global->{project}, {name => $name, script => $name});
  EMC::Script::read($root, $name, [$ext, $script->{suffix}.$ext]);
 
  # aftermath

  foreach (@ARGV) {					# command line override
    next if (substr($_,0,1) ne "-");
    my @arg = split("=", substr($_,1));
    $struct->{option} = shift(@arg);
    $struct->{args} = [@arg];
    EMC::Options::set_options($options, $struct);
  }
  
  my $flag = $global->{flag};
  my $project = $global->{project};
  my $lammps = $root->{md}->{lammps};

  return if (EMC::Common::element($root, "environment", "flag", "active"));
  
  EMC::Options::set_context($root);
  EMC::Message::error("no project name was set.\n") if ($project->{name} eq "");
  if ($::EMC::ProfileFlag{pressure} && !$lammps->{flag}->{chunk}) {
    EMC::Message::error(
      "pressure profiles currently only supported with LAMMPS chunks.\n");
  }
  EMC::Message::info("project = %s\n", $project->{name});
  EMC::Message::info("ntotal = %s\n", $global->{ntotal}) if (!$flag->{number});
  EMC::Message::info("direction = %s\n", $global->{direction}->{x});
  EMC::Message::info("shape = %s\n", $global->{shape});

  # create DPD field

  my $fields = $root->{fields};
  my $field = $fields->{field};
  my $build = $root->{emc}->{context}->{build};

  EMC::Fields::set_fields($fields);
  EMC::Fields::update_fields($fields) if (!defined($fields->{fields}));
  EMC::Fields::update_fields($fields, "list");

  EMC::Message::info("force field type = \"%s\"\n", $field->{type});
  EMC::Fields::output_fields($fields, "name");
  EMC::Fields::output_fields($fields, "location");
  
  EMC::Message::info(
    "build structures for MD script in \"%s\"\n", $build->{dir});
  
  EMC::Options::write_warnings($options);
  EMC::Message::error(
    "aborted due to warnings\n") if (scalar(@{$options->{warnings}}));

  return $root;
}


sub execute {
  my $root = shift(@_);
  my $global = EMC::Common::element($root, "global");
  my $script = EMC::Common::element($root, "global", "script");
  my $project = EMC::Common::element($root, "global", "project");
  my $build = EMC::Common::element($root, "emc", "context", "build");
  my $types = EMC::Common::hash($root, "types");
  my $references = EMC::Common::element($types, "references");
  my $parameters = EMC::Common::element($types, "parameters");

  # - interpret items
  # - export scripts
  # 	- environment
  # 	- build
  # 	- MD

  EMC::Script::interpret($root);
  EMC::EMC::check_validity($root);
  EMC::Global::set_densities($global);

  my $ext = $script->{extension};
  my $list = $root->{emc}->{flag}->{types} ? EMC::Groups::types($root) : undef;

  if ($list) {
    if (EMC::Message::get_flag("info")) {
      EMC::Message::info("types = {%s}\n", join(", ", @{$list}));
    } else {
      print(join(" ", @{$list}), "\n");
    }
  }

  if (EMC::Common::element($references, "name")) {
    $references->{name} =
      EMC::IO::strip($references->{name}, @{$global->{ext}});
    EMC::References::read($references,
      $references->{name}, [@{$global->{ext}}, $references->{suffix}.$ext]);
  }
  if (EMC::Common::element($references, "name")) {
    $parameters->{name} = 
      EMC::IO::strip($parameters->{name}, @{$global->{ext}});
    EMC::Parameters::read($parameters,
      $parameters->{name}, [@{$global->{ext}}, $parameters->{suffix}.$ext]);
  }
  EMC::Types::write_field($types, $project->{name});
  
  if (EMC::Common::element($root, "environment", "flag", "active")) {
    EMC::Environment::create($root);
  } else {
    EMC::MD::write_script($root, $project->{name});
    EMC::EMC::write_script($root, $build->{name});
  }

  if (!EMC::EMC::execute($root)) {
    print("\n") if (EMC::Message::get_flag("info"));
  }
}


# Main

{
  my $root = {};
  
  initialize(construct(\$root));
  execute($root);
}

