#!/usr/bin/env perl
#
#  program:	emc_setup.pl
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
#  Copyright (c) 2004-2021 Pieter J. in 't Veld
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
#    20151130	Added $::EMC::Lammps{restart} and $::EMC::Shear
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

# Perl modules

use Cwd;
use Data::Dumper; # use as print(Dumper($var)) where $var can be a pointer to complex variables
use File::Basename;
use File::Find;
use File::Path;
use Time::Piece;

# Module initialization

use lib $::EMC::Modules{dir} = dirname($0)."/modules";
opendir(DIR, $::EMC::Modules{dir});
foreach(readdir(DIR)) { 
  require $_ if (substr($_,-3) eq ".pm" && -f "$::EMC::Modules{dir}/$_" ); }
close DIR;

use strict;

# General constants

$::EMC::OSType = $^O;

$::EMC::Year = "2021";
$::EMC::Copyright = "2004-$::EMC::Year";
$::EMC::Version = "4.1";
$::EMC::Date = "August 1, $::EMC::Year";
$::EMC::EMCVersion = "9.4.4";
$::EMC::pi = 3.14159265358979323846264338327950288;
{
  my $win = $^O eq "MSWin32" ? 1 : 0;
  my $emc = scrub_dir(dirname($0).($win ? "/../bin/emc_win32.exe" : "/emc.sh"));
  my $split = ($win ? "\\\\" : "/");
  $emc =~ s/\//\\/g if ($win);

  # $::EMC::EMCVersion  
  
  $::EMC::EMCVersion = (split("\n", `$emc -version`))[0] if (!$win && -e $emc);

  # $::EMC::Root
  
  my @arg = split($split, $0);
  @arg = (split($split, $ENV{'PWD'}), @arg[-1]) if (@arg[0] eq ".");
  $::EMC::Script = @arg[-1];
  if (defined($ENV{EMC_ROOT})) {
    $::EMC::Root = $ENV{EMC_ROOT};
    $::EMC::Root =~ s/~/$ENV{HOME}/g if ($^O ne "MSWin32");
  } else {
    pop(@arg); pop(@arg);
    pop(@arg) if (@arg[-1] eq "");
    $::EMC::Root = join("/", @arg);
  }
}

# A

%::EMC::Analyze = (
  skip => 0, window => 1, archive => 1, data => 1, replace => 1,
  user => "", source => "", target => "",
  location => [scrub_dir("$::EMC::Root/scripts/analyze")],
 
  scripts	=> {
    bond	=> {			# Bond distance from trajectory
      active	=> 0,
      queue	=> 1,
      script	=> "script.sh",
      options	=> {
	type	=> "bond",
	binsize	=> 0.01,
	queue	=> "\${queue}",
	walltime => "\${walltime}"
      }
    },
    cavity	=> {			# Cavity size ditribution from
      active	=> 0,			# trajectory
      queue	=> 1,
      script	=> "cavity.sh",
      options	=> {
	type	=> "cavity",
	queue	=> "\${queue}",
	walltime => "\${walltime}"
      }
    },
    density 	=> {			# Density profile post processing
      active	=> 1,
      queue	=> 0,
      script	=> "files.sh",
      options	=> {
	type	=> "density"
      }
    },
    distance	=> {			# End-to-end distance from trajectory
      active	=> 0,
      queue	=> 1,
      script	=> "script.sh",
      options	=> {
	type	=> "distance",
	queue	=> "\${queue}",
	walltime => "\${walltime}"
      }
    },
    energy	=> {			# Energy tensor post processing
      active	=> 1,
      queue	=> 0,
      script	=> "project.sh",
      options	=> {
	type	=> "energy"
      }
    },
    gr		=> {			# Radius of gyration from trajectory
      active	=> 0,
      queue	=> 1,
      script	=> "script.sh",
      options	=> {
	type	=> "gyration",
	cutoff	=> "\${cutoff}",
	queue	=> "\${queue}",
	walltime => "\${walltime}"
      }
    },
    "green-kubo" => {			# Green-Kubo post processing
      active	=> 1,
      queue	=> 0,
      script	=> "project.sh",
      options	=> {
	type	=> "green-kubo"
      }
    },
    gyration	=> {			# Radius of gyration from trajectory
      active	=> 0,
      queue	=> 0,
      script	=> "files.sh",
      options	=> {
	type	=> "gyration",
      }
    },
    last	=> {			# Last frame from trajectory
      active	=> 0,
      queue	=> 0,
      script	=> "last.sh",
      options	=> {
	emc	=> "\${femc}",
	pdb	=> "\${fpdb}"
      }
    },
    msd		=> {			# MSD post processing
      active	=> 1,
      queue	=> 0,
      script	=> "files.sh",
      options	=> {
	null	=> 0,
	type	=> "msd"
      }
    },
    pressure	=> {			# Pressure profile post processing
      active	=> 1,
      queue	=> 0,
      script	=> "files.sh",
      options	=> {
	type	=> "pressure"
      }
    },
    volume	=> {			# Volume tensor post processing
      active	=> 1,
      queue	=> 0,
      script	=> "project.sh",
      options	=> {
	type	=> "volume"
      }
    }
  }
);
$::EMC::AngleConstants = "5,180";

# B

$::EMC::BinSize = 0.01;
$::EMC::BondConstants = "20,1";
%::EMC::Build = (
  center	=> 0,
  dir		=> "../build",
  name		=> "build",
  order		=> "random",
  origin	=> {x => 0, y => 0, z => 0},
  niterations	=> 1000,
  nrelax	=> 100,
  radius	=> -1,
  replace	=> 0,
  theta		=> 0,
  weight	=> {
    bond	=> -1,
    focus	=> 1,
    nonbond	=> -1
  }
);

# C

%::EMC::ClusterFlag = (
  first		=> 1,
  mass		=> 0,
  volume	=> 0
);
$::EMC::Columns = 80;
$::EMC::Core = -1;
%::EMC::CutOff = (
  center	=> -1,
  charge	=> -1, 
  ghost		=> -1,
  inner		=> -1,
  outer		=> -1,
  pair		=> -1,
  repulsive	=> 0
);

# D

%::EMC::Deform = (
  flag		=> 0,
  ncycles	=> 100,
  nblocks	=> 1,
  type		=> "relative",
  xx		=> 1,
  yx		=> 0,
  yy		=> 1,
  zx		=> 0,
  zy		=> 0,
  zz		=> 1,
  ignore	=> []
);
$::EMC::Density = "";
$::EMC::Dielectric = -1;
%::EMC::Direction = (
  x		=> "x",
  y		=> "y",
  z		=> "z"
);

# E

%::EMC::EMC = (
  depth		=> 8,
  execute	=> "-",
  suffix	=> -1,
  test		=> 0,
  write		=> 1,

  exclude	=> {
    build	=> 0
  },
  export	=> {
    smiles	=> ""
  },
  moves		=> {
    displace	=> 1
  },
  output	=> {
    debug	=> 0,
    info	=> 1,
    warning	=> 1,
    exit	=> 1
  },
  progress	=> {
    build	=> 1,
    clusters	=> 0
  },
  run		=> {
    nequil	=> 0,
    ncycles	=> 0,
    nblocks	=> 100, 
    clusters	=> "all",
    groups	=> "all",
    sites	=> "all"
  },
  traject	=> {
    frequency	=> 0,
    append	=> "true"
  }
);
%::EMC::ENV = (
  HOME		=> $ENV{HOME},
  HOST		=> $ENV{HOST},
  host		=> ""
);

# F

%::EMC::Flag = (
  angle		=> 0,
  assume	=> 0,
  atomistic	=> 0,
  bond		=> -1,
  charge	=> -1,
  chi		=> 0,
  comment	=> 0,
  cross		=> -1,
  crystal	=> -1,
  debug		=> 0,
  environment	=> 0,
  ewald		=> -1,
  exclude	=> 1,
  expert	=> 0,
  focus		=> 0,
  hexadecimal	=> 0,
  info		=> 1,
  mass		=> 0,
  mass_entry	=> -1,
  mol		=> 1,
  msd		=> 0,
  norestart	=> 0,
  number	=> 0,
  omit		=> 0,
  pair		=> 1,
  percolate	=> 0,
  reduced	=> -1,
  rules		=> 0,
  shake		=> -1,
  triclinic	=> 0,
  version	=> 0,
  volume	=> 0,
  warn		=> 1,
  width		=> 0
);
%::EMC::Field = (
  dpd		=> {auto => 0, bond => 0},
  flag		=> 0,
  "format"	=> "%15.10e",
  id		=> "opls-ua",
  name		=> scrub_dir("opls/2012/opls-ua"),
  type		=> "opls",
  location	=> scrub_dir("$::EMC::Root/field/"),
  write		=> 1
);
%::EMC::FieldFlag = (
  angle		=> 0,
  bond		=> 0,
  charge	=> 1,
  check		=> 1,
  debug		=> "false",
  error		=> 1,
  group		=> 0,
  improper	=> 0,
  increment	=> 0,
  nbonded	=> 0,
  torsion	=> 0
);
%::EMC::FieldFlags = (
  complete	=> 1,
  empty		=> 1,
  error		=> 1,
  false		=> 1,
  first		=> 1,
  ignore	=> 1,
  reduced	=> 1,
  true		=> 1,
  "warn"	=> 1
);
%::EMC::FieldList = (
  id		=> {},
  name		=> [],
  location	=> [scrub_dir("$::EMC::Root/field/")]
);

# H

%::EMC::HostDefaults = (
  quriosity	=> {
    ppn		=> 40,
    memory	=> 4
  }
);

# I

%::EMC::ImportDefault = (
  charges	=> -1,
  density	=> "mass",
  depth		=> -1,
  exclude	=> "box",
  flag		=> "rigid",
  focus		=> 1,
  formal	=> 1,
  guess		=> -1,
  mode		=> "",
  name		=> "",
  ncells	=> "1:auto:auto",
  ntrials	=> 10000,
  percolate	=> -1,
  translate	=> 0,
  type		=> "surface",
  unwrap	=> 0
);
$::EMC::ImportNParallel = 0;
$::EMC::Increment = "";
%::EMC::Insight = (
  compress	=> 0,
  pbc		=> 1,
  unwrap	=> 1,
  write		=> 0
);
%::EMC::Include = (
  extension	=> ".dat",
  location	=> ["."]
);

# K

$::EMC::Kappa = -1;

# L

%::EMC::Lammps = (
  chunk		=> 1, 
  comm		=> 0,
  cutoff	=> 0,
  dlimit	=> 0.1,
  dtthermo	=> 1000,
  dtdump	=> 100000,
  dtrestart	=> 100000,
  momentum_flag	=> 1, 
  momentum	=> [100,1,1,1,"angular"],
  multi		=> 0,
  nchains	=> "", 
  nsample	=> 1000, 
  pdamp		=> 1000,
  prefix	=> 0, 
  restart	=> 0, 
  restart_dir	=> "..",
  skin		=> -1,
  tdamp		=> 100,
  tequil	=> 1000,
  tfreq		=> 10, 
  trun		=> 10000000,
  trun_flag	=> 0,
  version	=> 2018, 
  new_version	=> 2015,
  write		=> 1,
  stage		=> [
    "header", "variables", "interaction", "equilibration", "simulation",
    "integration", "sampling", "intermediate", "run"
  ],
  spot		=> {
    head	=> 0,
    tail	=> 1,
    false	=> 0,
    true	=> 1,
    0		=> 0,
    1		=> 1,
    "-1"	=> 1
  },
  func		=> {
    header	=> \&write_lammps_header,
    variables	=> \&write_lammps_variables,
    interaction	=> \&write_lammps_interaction,
    equilibration => \&write_lammps_equilibration,
    simulation	=> \&write_lammps_simulation,
    integration	=> \&write_lammps_integrator,
    sampling	=> \&write_lammps_sample,
    intermediate => \&write_lammps_intermediate,
    run		=> \&write_lammps_footer
  }
);
%::EMC::Location = (
  analyze	=> $::EMC::Analyze{location},
  field		=> $::EMC::FieldList{location},
  include	=> $::EMC::Include{location}
);

# M

@::EMC::Modules	= ();
%::EMC::Moves = (
  cluster	=> {
    active	=> "false",
    cut		=> 0.05,
    frequency	=> 1,
    limit	=> "auto:auto",
    max		=> "0:0",
    min		=> "auto:auto"
  }
);

# N

%::EMC::NAMD = (
  dtcoulomb	=> 1,
  dtdcd		=> 10000,
  dtnonbond	=> 1,
  dtrestart	=> 100000,
  dtthermo	=> 1000,
  dttiming	=> 10000,
  dtupdate	=> 20,
  pres_period	=> 100.0,
  pres_decay	=> 50.0,
  temp_damp	=> 3,
  timestep	=> 2.0,
  tminimize	=> 50000,
  trun		=> 10000000,
  write		=> 0
);
$::EMC::NAv = "";
$::EMC::NChains = -1;
$::EMC::NIterations = 1000;
$::EMC::NPhases = 1;
$::EMC::NTotal = 10000;

# O

%::EMC::OptionsFlag = (
  perl		=> 0,
  python	=> 0,
  tcl		=> 0
);

# P

%::EMC::PairConstants = (
  a		=> 25,
  r		=> 1,
  gamma		=> 4.5
);
%::EMC::Parameters = (
  flag		=> 0,
  name		=> "parameters",
  read		=> 0,
  suffix	=> "_parm"
);
%::EMC::PDB = (
  atom		=> "index",
  compress	=> 1,
  connect	=> 0,
  cut		=> 0,
  extend	=> 0,
  fixed		=> 1,
  parameters	=> 0,
  pbc		=> 1,
  rank		=> 0,
  residue	=> "index",
  rigid		=> 1,
  segment	=> "index",
  unwrap	=> 1,
  vdw		=> 0,
  write		=> 1
);
%::EMC::PolymerFlag = (
  bias		=> "none",
  cluster	=> 0,
  fraction	=> "number",
  niterations	=> -1,
  order		=> "list",
  ignore	=> ["cluster"]
);
%::EMC::Polymers = (
);
$::EMC::Precision = -1;
%::EMC::Pressure = (
  flag		=> 0,
  couple	=> "couple",
  direction	=> "x+y+z",
  value		=> 1
);
%::EMC::ProfileFlag = (
  density	=> 0,
  density3d	=> 0,
  pressure	=> 0
);
%::EMC::Project = (
  name		=> "",
  script	=> ""
);

# Q

%::EMC::Queue = (
  account	=> "none",
  analyze	=> "default",
  build		=> "default",
  memory	=> "default",
  ncores	=> -1,
  ppn		=> "default",
  run		=> "default",
  user		=> "none"
);

# R

%::EMC::Record = (
  flag		=> 0,
  name		=> '""',
  frequency	=> 1,
  inactive	=> "true",
  unwrap	=> "sites",
  pbc		=> "true",
  cut		=> "false"
);
%::EMC::Reference = (
  length	=> -1,
  volume	=> -1,
  mass		=> -1,
  type		=> "",
  flag		=> 0,
  name		=> "references",
  suffix	=> "_ref"
);
%::EMC::Replace = (
  flag		=> 0,
  analysis	=> 1,
  build		=> 1,
  run		=> 1,
  test		=> 1
);
%::EMC::Region = (
  epsilon	=> 0.1,
  sigma		=> 1
);
%::EMC::RunTime = (
  analyze	=> "00:30:00",
  build		=> "00:10:00",
  run		=> "24:00:00"
);
%::EMC::RunName = (
  analyze	=> "",
  build		=> "",
  run		=> "",
  test		=> "-"
);

# S

%::EMC::Sample = (
  energy	=> 0,
  "green-kubo"	=> 0,
  gyration	=> 0,
  msd		=> 0,
  pressure	=> 1,
  volume	=> 0
);
%::EMC::Script = (
  extension	=> ".esh",
  flag		=> 0,
  name		=> "chemistry",
  ncolums	=> 80,
  suffix	=> "_chem"
);
$::EMC::Seed = -1;
%::EMC::Shake = (
  iterations	=> 20,
  output	=> 0,
  tolerance	=> 0.0001
);
$::EMC::Shape = "";
@::EMC::ShapeDefault = (
  1,
  1.5
);
%::EMC::Shear = (
  flag		=> 0,
  mode		=> "",
  ramp		=> 100000,
  rate		=> ""
);
%::EMC::Split = (
  phase		=> 1,
  thickness	=> 1,
  fraction	=> 0.5,
  type		=> "relative",
  mode		=> "random",
  sites		=> "all",
  groups	=> "all",
  clusters	=> "all"
);
$::EMC::Splits = ();
%::EMC::System = (
  id		=> "main",
  charge	=> 1,
  geometry	=> 1,
  map		=> 1,
  pbc		=> 1
);

# T

$::EMC::Temperature = "";
$::EMC::Tighten = -1;
$::EMC::Timestep = -1;

# U

%::EMC::Units = (
  energy	=> -1,
  length	=> -1,
  type		=> -1
);

# W

$::EMC::WorkDir = scrub_dir(cwd());

# General functions

sub date {
  my $t = Time::Piece::localtime();
  return $t->strftime("%a %b %d %H:%M:%S %Z %Y")."\n";
}


sub flag {
  my %allowed = ("true" => 1, "false" => 0, "1" => 1, "0" => 0, "auto" => -1);
  
  return 
    @_[0] eq "" ? 1 : defined($allowed{@_[0]}) ? $allowed{@_[0]} : eval(@_[0]);
}


sub flag_q {
  my %allowed = ("true" => 1, "false" => 0, "1" => 1, "0" => 0, "auto" => -1);
  
  return defined($allowed{@_[0]}) ? 1 : 0;
}


sub value_q {
  return @_[0] =~ m/^([+-]?)(?=\d|\.\d)\d*(\.\d*)?([Ee]([+-]?\d+))?$/ ? 1 : 0;
}


sub boolean {
  return @_[0] if (@_[0] eq "true");
  return @_[0] if (@_[0] eq "false");
  return @_[0] ? @_[0]<0 ? "auto" : "true" : "false";
}


$::EMC::Round = 0.00001;
sub round {
  my $round = @_[1] eq "" ? $::EMC::Round>0 ? $::EMC::Round : 0.001 : @_[1];
  return int(@_[0]/$round+(@_[0]<0 ? -1 : 1)*(0.5+1e-10))*$round;
}


sub strref {
  return @_[0]<0 ? "" : length(@_[0])<1 ? "" : round(@_[0]);
}


sub trim {
  my $s = shift(@_);
  $s =~ s/^\s+|\s+$//g;
  return $s;
}


sub trim_left {
  my $s = shift(@_);
  $s =~ s/^\s+//g;
  return $s;
}


sub trim_right {
  my $s = shift(@_);
  $s =~ s/\s+$//g;
  return $s;
}


sub list {
  my $hash = shift(@_);
  my $type = shift(@_);
  my %ignore = set_ignore($hash);
  my %special = (); foreach (@_) { $special{$_} = 1; }
  my @arg;

  foreach (sort(keys(%{$hash}))) {
    next if (defined($ignore{$_}));
    my $result;
    if (defined($special{$_})) {
      $result = ${$hash}{$_};
    } elsif ($type eq "array") {
      $result = join(":", @{${$hash}{$_}});
    } elsif ($type eq "boolean") {
      $result = boolean(${$hash}{$_});
    } else {
      $result = ${$hash}{$_};
    }
    #push(@arg, $result eq "" ? "$_" : "$_=$result");
    push(@arg, "$_=$result");
  }
  return join(", ", @arg);
}


sub number {
  if (@_[0] =~ /^[0-9\.\-\+\/\*e]+$/) { 
    if (@_[0] =~ /-e/) { return 0; }
    if (@_[0] =~ /\+e/) { return 0; }
    return 1; }
  return (@_[0]+0) eq (@_[0]) ? 1 : 0;
}


sub grace {
  my $weight = shift(@_);
  my @order = ("nonbond", "bond", "focus");
  my @grace;

  foreach (@order) { push(@grace, 1.0-${$weight}{$_}); }
  return @grace;
}


sub path_append {
  my $array = shift(@_);
  my @set = @_;
  my %exist;

  foreach (@{$array}) {
    $_ = scrub_dir($_);
    $exist{$_} = 1;
  }
  foreach (@set) {
    $_ = scrub_dir($_);
    next if (defined($exist{$_}));
    push(@{$array}, $_) if (-d fexpand($_));
  }
}


sub path_prepend {
  my $array = shift(@_);
  my @set = @_;
  my %exist;

  foreach (@{$array}) {
    $_ = scrub_dir($_);
    $exist{$_} = 1;
  }
  foreach (@set) {
    $_ = scrub_dir($_);
    next if (defined($exist{$_}));
    unshift(@{$array}, $_) if (-d fexpand($_));
  }
}


sub set_commands {

# GUI array:	[var type, menu location, menu type, treatment, misc]
# var type:	[boolean, integer, real, string, list, option]
# menu:		[environment, chemistry]
# menu type:	[analysis, emc, field, lammps, top]
# treatment:	[advanced, standard, ignore]
# misc:		[general, pull down items in case var type being option]

$::EMC::PolymerFlag{cluster} = boolean($::EMC::PolymerFlag{cluster});

%::EMC::Commands = (

  # A

  analyze_archive => {
    comment	=> "archive file names associated with analyzed data",
    default	=> boolean($::EMC::Analyze{archive}),
    gui		=> ["boolean", "environment", "analysis", "standard"]},
  analyze_data => {
    comment	=> "create tar archive from exchange file list",
    default	=> boolean($::EMC::Analyze{data}),
    gui		=> ["boolean", "environment", "analysis", "standard"]},
  analyze_last	=> {
    comment	=> "include last trajectory frame (deprecated)",
    default	=> boolean(${${$::EMC::Analyze{scripts}}{last}}{active}),
    gui		=> ["boolean", "environment", "analysis", "standard"]},
  analyze_replace => {
    comment	=> "replace already exisiting analysis results",
    default	=> boolean($::EMC::Analyze{replace}),
    gui		=> ["boolean", "environment", "analysis", "standard"]},
  analyze_skip	=> {
    comment	=> "set the number of initial frames to skip",
    default	=> $::EMC::Analyze{skip},
    gui		=> ["integer", "environment", "analysis", "standard"]},
  analyze_source => {
    comment	=> "set data source directory for analysis scripts",
    default	=> $::EMC::Analyze{source},
    gui		=> ["string", "environment", "analysis", "ignore"]},
  analyze_user	=> {
    comment	=> "set directory for user analysis scripts",
    default	=> $::EMC::Analyze{user},
    gui		=> ["string", "environment", "analysis", "standard"]},
  analyze_window => {
    comment	=> "set the number of frames in window average",
    default	=> $::EMC::Analyze{window},
    gui		=> ["integer", "environment", "analysis", "standard"]},
  angle		=> {
    comment	=> "set DPD angle constants k and theta or set angle field option (see below)",
    default	=> $::EMC::AngleConstants,
    gui		=> ["list", "chemistry", "field", "advanced", "general"]},
  auto		=> {
    comment	=> "add wildcard entry to mass and nonbond sections in DPD .prm",
    default	=> boolean(${$::EMC::Field{dpd}}{auto}),
    gui		=> ["boolean", "chemistry", "field", "advanced", "general"]},

  # B

  binsize	=> {
    comment	=> "set bin size for LAMMPS profiles",
    default	=> $::EMC::BinSize,
    gui		=> ["real", "chemistry", "lammps", "advanced"]},
  bond		=> {
    comment	=> "set DPD bond constants k,l",
    default	=> $::EMC::BondConstants,
    gui		=> ["list", "chemistry", "field", "advanced", "general"]},
  build		=> {
    comment	=> "set build script name",
    default	=> $::EMC::Build{name},
    gui		=> ["string", "chemistry", "emc", "advanced"]},
  build_center	=> {
    comment	=> "insert first site at the box center",
    default	=> boolean($::EMC::Build{center}),
    gui		=> ["boolean", "chemistry", "emc", "advanced"]},
  build_dir	=> {
    comment	=> "set build directory for LAMMPS script",
    default	=> $::EMC::Build{dir},
    gui		=> ["string", "chemistry", "lammps", "advanced"]},
  build_order	=> {
    comment	=> "set build order of clusters",
    default	=> $::EMC::Build{order},
    gui		=> ["string", "chemistry", "emc", "advanced"]},
  build_origin	=> {
    comment	=> "set build order of clusters",
    default	=> list($::EMC::Build{origin}),
    gui		=> ["string", "chemistry", "emc", "advanced"]},
  build_replace	=> {
    comment	=> "replace already existing build results",
    default	=> boolean($::EMC::Build{replace}),
    gui		=> ["boolean", "environment", "top", "advanced"]},
  build_theta	=> {
    comment	=> "set the minimal insertion angle",
    default	=> boolean($::EMC::Build{theta}),
    gui		=> ["boolean", "environment", "top", "advanced"]},

  # C

  charge	=> {
    comment	=> "chemistry contains charges",
    default	=> boolean($::EMC::Flag{charge}),
    gui		=> ["boolean", "chemistry", "lammps", "advanced"]},
  charge_cut	=> {
    comment	=> "set charge interaction cut off",
    default	=> $::EMC::CutOff{charge},
    gui		=> ["real", "chemistry", "field", "standard", "general"]},
  chunk		=> {
    comment	=> "use chunk approach for profiles in LAMMPS script",
    default	=> boolean($::EMC::Lammps{chunk}),
    gui		=> ["boolean", "chemistry", "lammps", "advanced"]},
  communicate	=> {
    comment	=> "use communicate keyword in LAMMPS script",
    default	=> boolean($::EMC::Lammps{communicate}),
    gui		=> ["boolean", "chemistry", "lammps", "advanced"]},
  core		=> {
    comment	=> "set core diameter",
    default	=> $::EMC::Core,
    gui		=> ["real", "chemistry", "field", "advanced", "borne"]},
  cross		=> {
    comment	=> "include nonbond cross terms in LAMMPS params file",
    default	=> boolean($::EMC::Flag{cross}),
    gui		=> ["boolean", "chemistry", "lammps", "advanced"]},
  crystal	=> {
    comment	=> "treat imported structure as a crystal",
    default	=> boolean($::EMC::Flag{crystal}),
    gui		=> ["boolean", "chemistry", "emc", "advanced"]},
  cut		=> {
    comment	=> "set pairwise interaction cut off",
    default	=> $::EMC::CutOff{pair},
    gui		=> ["real", "chemistry", "field", "standard", "general"]},
  cutoff	=> {
    comment	=> "set pairwise interaction cut off",
    default	=> list(\%::EMC::CutOff, "real"),
    gui		=> ["string", "chemistry", "field", "ignore", "general"]},

  # D

  debug		=> {
    comment	=> "control debugging information",
    default	=> boolean($::EMC::Flag{debug}),
    gui		=> ["boolean", "environment", "top", "ignore"]},
  deform	=> {
    comment	=> "deform system from given density",
    default	=> list(\%::EMC::Deform, "integer"),
    gui		=> ["boolean", "environment", "top", "ignore"]},
  density	=> {
    comment	=> "set simulation density in g/cc for each phase",
    default	=> $::EMC::Density,
    gui		=> ["list", "chemistry", "top", "standard"]},
  dielectric	=> {
    comment	=> "set charge medium dielectric constant",
    default	=> $::EMC::Dielectric,
    gui		=> ["real", "chemistry", "field", "advanced"]},
  direction	=> {
    comment	=> "set build direction of phases",
    default	=> $::EMC::Direction{x},
    gui		=> ["option", "chemistry", "emc", "advanced", "x,y,z"]},
  dtdump	=> {
    comment	=> "set LAMMPS trajectory file write frequency",
    default	=> $::EMC::Lammps{dtdump},
    gui		=> ["integer", "chemistry", "lammps", "standard"]},
  dtrestart	=> {
    comment	=> "set LAMMPS restart file frequency",
    default	=> $::EMC::Lammps{dtrestart},
    gui		=> ["integer", "chemistry", "lammps", "standard"]},
  dtthermo	=> {
    comment	=> "set LAMMPS thermodynamic output frequency",
    default	=> $::EMC::Lammps{dtthermo},
    gui		=> ["integer", "chemistry", "lammps", "standard"]},

  # E

  emc		=> {
    comment	=> "create EMC build script",
    default	=> boolean($::EMC::EMC{write}),
    gui		=> ["boolean", "chemistry", "top", "ignore"]},
  emc_depth	=> {
    comment	=> "set ring recognition depth in groups paragraph",
    default	=> $::EMC::EMC{depth},
    gui		=> ["integer", "chemistry", "emc", "advanced"]},
  emc_export	=> {
    comment	=> "set EMC section to export",
    default	=> list($::EMC::EMC{export}, "string"),
    gui		=> ["string", "chemistry", "top", "string"]},
  emc_exclude	=> {
    comment	=> "set EMC section to exclude",
    default	=> list($::EMC::EMC{exclude}, "boolean"),
    gui		=> ["string", "chemistry", "top", "ignore"]},
  emc_execute	=> {
    comment	=> "execute EMC build script",
    default	=> boolean($::EMC::EMC{execute}),
    gui		=> ["boolean", "chemistry", "top", "ignore"]},
  emc_moves	=> {
    comment	=> "set Monte Carlo moves for after build",
    default	=> list($::EMC::EMC{moves}, "integer"),
    gui		=> ["string", "chemistry", "top", "emc"]},
  emc_output	=> {
    comment	=> "set EMC output modes",
    default	=> list($::EMC::EMC{output}, "boolean"),
    gui		=> ["string", "chemistry", "top", "ignore"]},
  emc_progress	=> {
    comment	=> "set progress indicators",
    default	=> list($::EMC::EMC{progress}, "boolean"),
    gui		=> ["string", "chemistry", "top", "ignore"]},
  emc_run	=> {
    comment	=> "set Monte Carlo run conditions for after build",
    default	=> list($::EMC::EMC{run}, "string"),
    gui		=> ["string", "chemistry", "top", "emc"]},
  emc_test	=> {
    comment	=> "test EMC build script",
    default	=> boolean($::EMC::EMC{test}),
    gui		=> ["boolean", "chemistry", "top", "ignore"]},
  emc_traject	=> {
    comment	=> "settings for EMC trajectory",
    default	=> list($::EMC::EMC{traject}, "string"),
    gui		=> ["string", "chemistry", "top", "emc"]},
  environment	=> {
    comment	=> "create project environment",
    default	=> boolean($::EMC::Flag{environment}),
    gui		=> ["boolean", "chemistry", "top", "ignore"]},
  ewald		=> {
    comment	=> "set long range ewald summations",
    default	=> boolean($::EMC::Flag{ewald}),
    gui		=> ["boolean", "chemistry", "lammps", "standard"]},
  exclude	=> {
    comment	=> "exclude previous phase during build process",
    default	=> boolean($::EMC::Flag{exclude}),
    gui		=> ["boolean", "chemistry", "emc", "ignore"]},
  expert	=> {
    comment	=> "set expert mode to diminish error checking",
    default	=> boolean($::EMC::Flag{expert}),
    gui		=> ["boolean", "chemistry", "emc", "ignore"]},
  extension	=> {
    comment	=> "set environment script extension",
    default	=> $::EMC::Script{extension},
    gui		=> ["string", "environment", "top", "ignore"]},
  extra		=> {
    comment	=> "set extra interactions dest:src:offset (deprecated)",
    default	=> "",
    gui		=> ["list", "chemistry", "top", "ignore"]},

  # F

  field		=> {
    comment	=> "set force field type and name based on root location",
    default	=> "",
    gui		=> ["list", "chemistry", "top", "standard", "born,basf,charmm,compass,dpd,martini,opls,pcff,sdk,trappe"]},
  field_angle	=> {
    comment	=> "set angle field option (see below)",
    default	=> "-",
    gui		=> ["option", "chemistry", "field", "advanced", "complete,empty,ignore,error,warn"]},
  field_bond	=> {
    comment	=> "set bond field option (see below)",
    default	=> "-",
    gui		=> ["option", "chemistry", "field", "advanced", "complete,empty,ignore,error,warn"]},
  field_charge	=> {
    comment	=> "check system charge after applying force field ",
    default	=> boolean($::EMC::FieldFlag{charge}),
    gui		=> ["option", "chemistry", "field", "advanced"]
  },
  field_check	=> {
    comment	=> "check force field compatibility",
    default	=> boolean($::EMC::FieldFlag{check}),
    gui		=> ["option", "chemistry", "field", "advanced"]
  },
  field_debug	=> {
    comment	=> "set debug field option",
    default	=> boolean($::EMC::FieldFlag{debug}),
    gui		=> ["boolean", "chemistry", "field", "ignore", "general"]},
  field_dpd	=> {
    comment	=> "set various DPD options",
    default	=> list($::EMC::Field{dpd}, "boolean"),
    gui		=> ["string", "chemistry", "field", "ignore", "general"]},
  field_error	=> {
    comment	=> "override field errors (used for debugging)",
    default	=> boolean($::EMC::FieldFlag{error}),
    gui		=> ["boolean", "chemistry", "field", "ignore", "general"]},
  field_format	=> {
    comment	=> "parameter format of generated force field ",
    default	=> $::EMC::Field{format},
    gui		=> ["string", "chemistry", "field", "advanced"]
  },
  field_group	=> {
    comment	=> "set group field option (see below)",
    default	=> "-",
    gui		=> ["option", "chemistry", "field", "ignore", "complete,empty,ignore,error,warn"]},
  field_id	=> {
    comment	=> "set force field id",
    default	=> $::EMC::Field{id},
    gui		=> ["string", "chemistry", "top", "advanced"]},
  field_improper => {
    comment	=> "set improper field option (see below)",
    default	=> "-",
    gui		=> ["option", "chemistry", "field", "advanced", "complete,empty,ignore,error,warn"]},
  field_increment => {
    comment	=> "set increment field option (see below)",
    default	=> "-",
    gui		=> ["option", "chemistry", "field", "advanced", "complete,empty,ignore,error,warn"]},
  field_location => {
    comment	=> "set force field location",
    default	=> $::EMC::Field{location},
    gui		=> ["string", "chemistry", "top", "advanced"]},
  field_name	=> {
    comment	=> "set force field name",
    default	=> $::EMC::Field{name},
    gui		=> ["string", "chemistry", "top", "advanced"]},
  field_nbonded	=> {
    comment	=> "set number of excluded bonded interactions",
    default	=> $::EMC::FieldFlag{nbonded},
    gui		=> ["boolean", "chemistry", "field", "ignore", "general"]},
  field_reduced	=> {
    comment	=> "set force field reduced units flag",
    default	=> boolean($::EMC::Flag{reduced}),
    gui		=> ["boolean", "chemistry", "top", "ignore"]},
  field_torsion	=> {
    comment	=> "set torsion field option (see below)",
    default	=> "-",
    gui		=> ["option", "chemistry", "field", "advanced", "complete,empty,ignore,error,warn"]},
  field_type	=> {
    comment	=> "set force field type",
    default	=> $::EMC::Field{type},
    gui		=> ["string", "chemistry", "top", "ignore"]},
  field_write	=> {
    comment	=> "create field parameter file",
    default	=> boolean($::EMC::Field{write}),
    gui		=> ["boolean", "chemistry", "field", "ignore"]},
  focus		=> {
    comment	=> "list of molecules to focus on",
    default	=> "-",
    gui		=> ["string", "chemistry", "emc", "standard"]},

  # G

  ghost_cut	=> {
    comment	=> "set pairwise interaction cut off",
    default	=> $::EMC::CutOff{ghost},
    gui		=> ["real", "chemistry", "field", "standard", "general"]},
  grace		=> {
    comment	=> "(deprecated: use weight) set build relaxation grace",
    default	=> join(",", grace($::EMC::Build{weight})),
    gui		=> ["list", "chemistry", "emc", "ignore"]},

  # H

  help		=> {
    comment	=> "this message",
    default	=> "",
    gui		=> ["boolean", "environment", "top", "ignore"]},
  hexadecimal	=> {
    comment	=> "set hexadecimal index output in PDB",
    default	=> boolean($::EMC::Flag{hexadecimal}),
    gui		=> ["boolean", "chemistry", "emc", "advanced"]},
  host		=> {
    comment	=> "set host on which to run EMC and LAMMPS",
    default	=> $::EMC::ENV{HOST},
    gui		=> ["string", "environment", "emc", "advanced"]},

  # I

  info		=> {
    comment	=> "control runtime information",
    default	=> boolean($::EMC::Flag{info}),
    gui		=> ["boolean", "chemistry", "top", "ignore"]},
  inner		=> {
    comment	=> "set inner cut off",
    default	=> $::EMC::CutOff{inner},
    gui		=> ["real", "chemistry", "field", "advanced"]},
  insight	=> {
    comment	=> "create InsightII CAR and MDF output",
    default	=> boolean($::EMC::Insight{write}),
    gui		=> ["string", "chemistry", "emc", "advanced"]},
  insight_compress => {
    comment	=> "set InsightII CAR and MDF compression",
    default	=> boolean($::EMC::Insight{compress}),
    gui		=> ["option", "chemistry", "emc", "advanced"]},
  insight_pbc	=> {
    comment	=> "apply periodic boundary conditions",
    default	=> boolean($::EMC::Insight{pbc}),
    gui		=> ["boolean", "chemistry", "emc", "advanced"]},
  insight_unwrap => {
    comment	=> "apply unwrapping",
    default	=> boolean($::EMC::Insight{unwrap}),
    gui		=> ["boolean", "chemistry", "emc", "advanced"]},

  # K

  kappa		=> {
    comment	=> "set electrostatics kappa",
    default	=> $::EMC::Kappa,
    gui		=> ["real", "chemistry", "field", "advanced", "dpd"]},

  # L

  lammps	=> {
    comment	=> "create LAMMPS input script or set LAMMPS version using year, e.g. -lammps=2014 (new versions start at $::EMC::Lammps{new_version})",
    default	=> boolean($::EMC::Lammps{write}),
    gui		=> ["boolean", "chemistry", "lammps", "ignore"]},
  lammps_cutoff	=> {
    comment	=> "generate output of pairwise cut off in parameter file",
    default	=> boolean($::EMC::Lammps{cutoff}),
    gui		=> ["boolean", "chemistry", "lammps", "advanced"]},
  lammps_dlimit	=> {
    comment	=> "set LAMMPS nve/limit distance",
    default	=> $::EMC::Lammps{dlimit},
    gui		=> ["real", "chemistry", "lammps", "advanced"]},
  lammps_pdamp	=> {
    comment	=> "set LAMMPS barostat damping constant",
    default	=> $::EMC::Lammps{pdamp},
    gui		=> ["real", "chemistry", "lammps", "advanced"]},
  lammps_tdamp	=> {
    comment	=> "set LAMMPS thermostat damping constant",
    default	=> $::EMC::Lammps{tdamp},
    gui		=> ["real", "chemistry", "lammps", "advanced"]},
  location	=> {
    comment	=> "prepend paths for various file locations",
    default	=> list(\%::EMC::Location, "array"),
    gui		=> ["string", "chemistry", "emc", "advanced"]},

  # M

  mass		=> {
    comment	=> "assume mass fractions in chemistry file",
    default	=> boolean($::EMC::Flag{mass}),
    gui		=> ["boolean", "chemistry", "top", "standard"]},
  memorypercore	=> {
    comment	=> "set queue memory per core in gb",
    default	=> $::EMC::Queue{memory},
    gui		=> ["string", "environment", "top", "ignore"]},
  modules	=> {
    comment	=> "swap modules to use in format old=new",
    default	=> "", # @::EMC::Modules,
    gui		=> ["string", "environment", "top", "ignore"]},
  mol		=> {
    comment	=> "assume mol fractions in chemistry file",
    default	=> boolean($::EMC::Flag{mol}),
    gui		=> ["boolean", "chemistry", "top", "standard"]},
  momentum	=> {
    comment	=> "set zero total momentum in LAMMPS",
    default	=> ($::EMC::Lammps{momentum_flag} ? join(",", @{$::EMC::Lammps{momentum}}) : "false"),
    gui		=> ["list", "chemistry", "lammps", "advanced"]},
  moves_cluster	=> {
    comment	=> "define cluster move settings used to optimize build",
    default	=> list($::EMC::Moves{cluster}, "string"),
    gui		=> ["string", "chemistry", "emc", "advanced"]},
  msd		=> {
    comment	=> "set LAMMPS mean square displacement output",
    default	=> $::EMC::Sample{msd}!=2 ? boolean($::EMC::Sample{msd}):"average",
    gui		=> ["boolean", "chemistry", "analysis", "standard"]},


  # N

  namd		=> {
    comment	=> "create NAMD input script and parameter file",
    default	=> boolean($::EMC::NAMD{write}),
    gui		=> ["string", "chemistry", "top", "ignore"]},
  namd_dtcoulomb => {
    comment	=> "set electrostatic interaction update frequency",
    default	=> $::EMC::NAMD{dtcoulomb},
    gui		=> ["string", "chemistry", "top", "ignore"]},
  namd_dtdcd	=> {
    comment	=> "set output frequency of DCD file",
    default	=> $::EMC::NAMD{dtdcd},
    gui		=> ["string", "chemistry", "top", "ignore"]},
  namd_dtnonbond => {
    comment	=> "set nonbonded interaction update frequency",
    default	=> $::EMC::NAMD{dtnonbond},
    gui		=> ["string", "chemistry", "top", "ignore"]},
  namd_dtrestart => {
    comment	=> "set output frequency of restart files",
    default	=> $::EMC::NAMD{dtrestart},
    gui		=> ["string", "chemistry", "top", "ignore"]},
  namd_dtthermo	=> {
    comment	=> "set output frequency of thermodynamic quantities",
    default	=> $::EMC::NAMD{dtthermo},
    gui		=> ["string", "chemistry", "top", "ignore"]},
  namd_dttiming	=> {
    comment	=> "set timing frequency",
    default	=> $::EMC::NAMD{dttiming},
    gui		=> ["string", "chemistry", "top", "ignore"]},
  namd_dtupdate	=> {
    comment	=> "set update frequency",
    default	=> $::EMC::NAMD{dtupdate},
    gui		=> ["string", "chemistry", "top", "ignore"]},
  namd_pres_period => {
    comment	=> "set pressure ensemble period",
    default	=> $::EMC::NAMD{pres_period},
    gui		=> ["string", "chemistry", "top", "ignore"]},
  namd_pres_decay => {
    comment	=> "set pressure ensemble decay",
    default	=> $::EMC::NAMD{pres_decay},
    gui		=> ["string", "chemistry", "top", "ignore"]},
  namd_temp_damp => {
    comment	=> "set temperature ensemble damping",
    default	=> $::EMC::NAMD{temp_damp},
    gui		=> ["string", "chemistry", "top", "ignore"]},
  namd_tminimize => {
    comment	=> "set number of minimization timesteps",
    default	=> $::EMC::NAMD{tminimize},
    gui		=> ["string", "chemistry", "top", "ignore"]},
  namd_trun	=> {
    comment	=> "set number of timesteps for running",
    default	=> $::EMC::NAMD{trun},
    gui		=> ["string", "chemistry", "top", "ignore"]},
  name_analyze	=> {
    comment	=> "set job analyze script name",
    default	=> $::EMC::RunName{analyze},
    gui		=> ["string", "chemistry", "top", "ignore"]},
  name_build	=> {
    comment	=> "set job build script name",
    default	=> $::EMC::RunName{build},
    gui		=> ["string", "chemistry", "top", "ignore"]},
  name_run	=> {
    comment	=> "set job run script name",
    default	=> $::EMC::RunName{run},
    gui		=> ["string", "chemistry", "top", "ignore"]},
  name_testdir	=> {
    comment	=> "set job test directory as created in ./test/",
    default	=> $::EMC::RunName{test},
    gui		=> ["string", "chemistry", "top", "ignore"]},
  name_scripts	=> {
    comment	=> "set analyze, job, and build script names simultaneously",
    default	=> "",
    gui		=> ["string", "chemistry", "top", "ignore"]},
  nchains	=> {
    comment	=> "set number of chains for execution of LAMMPS jobs",
    default	=> "",
    gui		=> ["integer", "chemistry", "lammps", "standard"]},
  ncores	=> {
    comment	=> "set number of cores for execution of LAMMPS jobs",
    default	=> $::EMC::Queue{ncores},
    gui		=> ["integer", "environment", "lammps", "standard"]},
  ncorespernode	=> {
    comment	=> "set queue cores per node for packing jobs",
    default	=> $::EMC::Queue{ppn},
    gui		=> ["integer", "environment", "top", "ignore"]},
  niterations	=> {
    comment	=> "set number of build insertion iterations",
    default	=> $::EMC::Build{niterations},
    gui		=> ["integer", "chemistry", "emc", "standard"]},
  nparallel	=> {
    comment	=> "set number of surface parallel repeat unit cells",
    default	=> "auto",
    gui		=> ["integer", "chemistry", "emc", "advanced"]},
  norestart	=> {
    comment	=> "control possibility of restarting when rerunning",
    default	=> boolean($::EMC::Flag{norestart}),
    gui		=> ["integer", "chemistry", "emc", "ignore"]},
  nrelax	=> {
    comment	=> "set number of build relaxation cycles",
    default	=> $::EMC::Build{nrelax},
    gui		=> ["integer", "chemistry", "emc", "standard"]},
  nsample	=> {
    comment	=> "number of configuration in profile",
    default	=> $::EMC::Lammps{nsample},
    gui		=> ["integer", "chemistry", "analysis", "standard"]},
  ntotal	=> {
    comment	=> "set total number of atoms",
    default	=> $::EMC::NTotal,
    gui		=> ["integer", "chemistry", "top", "standard"]},
  number	=> {
    comment	=> "assume number of molecules in chemistry file",
    default	=> boolean($::EMC::Flag{number}),
    gui		=> ["boolean", "chemistry", "top", "standard"]},

  # O

  omit		=> {
    comment	=> "omit fractions from chemistry file",
    default	=> boolean($::EMC::Flag{omit}),
    gui		=> ["boolean", "chemistry", "top", "ignore"]},
  options_perl	=> {
    comment	=> "export options, comments, and default values in Perl syntax",
    default	=> boolean($::EMC::OptionsFlag{perl}),
    gui		=> []},
  options_tcl	=> {
    comment	=> "export options, comments, and default values in Tcl syntax",
    default	=> boolean($::EMC::OptionsFlag{tcl}),
    gui		=> []},
  outer		=> {
    comment	=> "set outer cut off",
    default	=> $::EMC::CutOff{outer},
    gui		=> ["real", "chemistry", "field", "advanced"]},

  # P

  pair		=> {
    comment	=> "set DPD pair constants",
    default	=> list(\%::EMC::PairConstants, "real"),
    gui		=> ["list", "chemistry", "field", "advanced", "dpd"]},
  parameters	=> {
    comment	=> "set parameters file name",
    default	=> $::EMC::Parameters{name},
    gui		=> ["browse", "chemistry", "field", "advanced", "dpd"]},
  params	=> {
    comment	=> "create field parameter file",
    default	=> boolean($::EMC::Field{write}),
    gui		=> ["boolean", "chemistry", "field", "ignore"]},
  pdb		=> {
    comment	=> "create PDB and PSF output",
    default	=> boolean($::EMC::PDB{write}),
    gui		=> ["string", "chemistry", "top", "ignore"]},
  pdb_atom	=> {
    comment	=> "set atom name behavior",
    default	=> $::EMC::PDB{atom},
    gui		=> ["option", "chemistry", "emc", "advanced", "detect,index,series"]},
  pdb_compress	=> {
    comment	=> "set PDB and PSF compression",
    default	=> boolean($::EMC::PDB{compress}),
    gui		=> ["option", "chemistry", "emc", "advanced"]},
  pdb_connect	=> {
    comment	=> "add connectivity information",
    default	=> boolean($::EMC::PDB{connect}),
    gui		=> ["boolean", "chemistry", "emc", "advanced"]},
  pdb_cut	=> {
    comment	=> "cut bonds spanning simulation box",
    default	=> boolean($::EMC::PDB{cut}),
    gui		=> ["boolean", "chemistry", "emc", "advanced"]},
  pdb_extend	=> {
    comment	=> "use extended format for PSF",
    default	=> boolean($::EMC::PDB{extend}),
    gui		=> ["boolean", "chemistry", "emc", "advanced"]},
  pdb_fixed	=> {
    comment	=> "do not unwrap fixed sites",
    default	=> boolean($::EMC::PDB{fixed}),
    gui		=> ["boolean", "chemistry", "emc", "advanced"]},
  pdb_parameters => {
    comment	=> "generate NAMD parameter file",
    default	=> boolean($::EMC::PDB{parameters}),
    gui		=> ["boolean", "chemistry", "emc", "advanced"]},
  pdb_pbc	=> {
    comment	=> "apply periodic boundary conditions",
    default	=> boolean($::EMC::PDB{pbc}),
    gui		=> ["boolean", "chemistry", "emc", "advanced"]},
  pdb_rank	=> {
    comment	=> "apply rank evaluation for coarse-grained output",
    default	=> boolean($::EMC::PDB{rank}),
    gui		=> ["boolean", "chemistry", "emc", "advanced"]},
  pdb_residue	=> {
    comment	=> "set residue name behavior",
    default	=> $::EMC::PDB{residue},
    gui		=> ["option", "chemistry", "emc", "advanced", "detect,index,series"]},
  pdb_rigid	=> {
    comment	=> "do not unwrap rigid sites",
    default	=> boolean($::EMC::PDB{rigid}),
    gui		=> ["boolean", "chemistry", "emc", "advanced"]},
  pdb_segment	=> {
    comment	=> "set segment name behavior",
    default	=> $::EMC::PDB{segment},
    gui		=> ["option", "chemistry", "emc", "advanced", "detect,index,series"]},
  pdb_unwrap	=> {
    comment	=> "apply unwrapping",
    default	=> flag_unwrap($::EMC::PDB{unwrap}),
    gui		=> ["boolean", "chemistry", "emc", "advanced"]},
  pdb_vdw	=> {
    comment	=> "add Van der Waals representation",
    default	=> boolean($::EMC::PDB{vdw}),
    gui		=> ["boolean", "chemistry", "emc", "advanced"]},
  percolate	=> {
    comment	=> "import percolating InsightII structure",
    default	=> boolean($::EMC::Flag{percolate}),
    gui		=> ["boolean", "chemistry", "emc", "advanced"]},
  phases	=> {
    comment	=> "sets which clusters to assign to each phase; each phase is separated by a +-sign; default assigns all clusters to phase 1",
    default	=> "all",
    gui		=> ["list", "chemistry", "top", "standard"]},
  polymer	=> {
    comment	=> "default polymer settings for groups",
    default	=> list(\%::EMC::PolymerFlag, "string"),
    gui		=> ["list", "chemistry", "top", "ignore"]},
  port		=> {
    comment	=> "port EMC setup variables to other applications",
    default	=> "",
    gui		=> ["list", "chemistry", "top", "ignore"]},
  precision	=> {
    comment	=> "set charge kspace precision",
    default	=> $::EMC::Precision,
    gui		=> ["real", "chemistry", "lammps", "advanced"]},
  prefix	=> {
    comment	=> "set project name as prefix to LAMMPS output files",
    default	=> boolean($::EMC::Lammps{prefix}),
    gui		=> ["boolean", "chemistry", "lammps", "ignore"]},
  pressure	=> {
    comment	=> "set system pressure and invoke NPT ensemble; optionally add direction and/or (un)couple for specifying directional coupling",
    default	=> ($::EMC::Pressure{flag} ?
		      $::EMC::Pressure{value} : "false").",".
		   ("direction=".$::EMC::Pressure{direction}).",".
		   ($::EMC::Pressure{couple}),
    gui		=> ["real", "chemistry", "top", "standard"]},
  profile	=> {
    comment	=> "set LAMMPS profile output",
    default	=> list(\%::EMC::ProfileFlag, "boolean"),
    gui		=> ["boolean", "chemistry", "analysis", "standard"]},
  project	=> {
    comment	=> "set project name; slashes are used to create subdirectories",
    default	=> $::EMC::Project{script},
    gui		=> ["string", "chemistry", "top", "standard"]},

  # Q

  queue		=> {
    comment	=> "queue settings",
    default	=> list(\%::EMC::Queue, "string"),
    gui		=> ["string", "environment", "top", "advanced"]},
  queue_account	=> {
    comment	=> "set queue account for billing",
    default	=> $::EMC::Queue{account},
    gui		=> ["string", "environment", "top", "advanced"]},
  queue_analyze	=> {
    comment	=> "set job analyze script queue",
    default	=> $::EMC::Queue{analyze},
    gui		=> ["string", "environment", "top", "advanced"]},
  queue_build	=> {
    comment	=> "set job build script queue",
    default	=> $::EMC::Queue{build},
    gui		=> ["string", "environment", "top", "advanced"]},
  queue_memory	=> {
    comment	=> "set queue memory per core in gb",
    default	=> $::EMC::Queue{memory},
    gui		=> ["string", "environment", "top", "advanced"]},
  queue_ncores	=> {
    comment	=> "set number of cores for execution of LAMMPS jobs",
    default	=> $::EMC::Queue{ncores},
    gui		=> ["integer", "environment", "lammps", "standard"]},
  queue_run	=> {
    comment	=> "set job run script queue",
    default	=> $::EMC::Queue{run},
    gui		=> ["string", "environment", "top", "advanced"]},
  queue_ppn	=> {
    comment	=> "set queue cores per node for packing jobs",
    default	=> $::EMC::Queue{ppn},
    gui		=> ["string", "environment", "top", "advanced"]},
  queue_user	=> {
    comment	=> "options to be passed directly to queuing system",
    default	=> $::EMC::Queue{user},
    gui		=> ["string", "environment", "top", "advanced"]},
  quiet		=> {
    comment	=> "turn off all information",
    default	=> "",
    gui		=> ["boolean", "chemistry", "top", "ignore"]},

  # R

  radius	=> {
    comment	=> "set build relaxation radius",
    default	=> $::EMC::Build{radius},
    gui		=> ["real", "chemistry", "emc", "standard"]},
  record	=> {
    comment	=> "set record entry in build paragraph",
    default	=> list(\%::EMC::Record, "string"),
    gui		=> ["list", "chemistry", "top", "ignore"]},
  references	=> {
    comment	=> "set references file name",
    default	=> $::EMC::Reference{name},
    gui		=> ["browse", "chemistry", "field", "advanced"]},
  region_epsilon => {
    comment	=> "set epsilon to use for exclusion regions",
    default	=> $::EMC::Region{epsilon},
    gui		=> ["real", "chemistry", "field", "advanced"]},
  region_sigma	=> {
    comment	=> "set sigma to use for exclusion regions",
    default	=> $::EMC::Region{sigma},
    gui		=> ["real", "chemistry", "field", "advanced"]},
  replace	=> {
    comment	=> "replace all written scripts as produced by EMC setup",
    default	=> boolean($::EMC::Replace{flag}),
    gui		=> ["boolean", "environment", "top", "advanced"]},
  replica	=> {
    comment	=> "set replica interactions dest:src:offset",
    default	=> "",
    gui		=> ["string", "chemistry", "field", "advanced", "dpd"]},
  restart	=> {
    comment	=> "create LAMMPS restart script",
    default	=> boolean($::EMC::Lammps{restart}).",".$::EMC::Lammps{restart_dir},
    gui		=> ["boolean", "chemistry", "lammps", "ignore"]},
  rlength	=> {
    comment	=> "set reference length",
    default	=> strref($::EMC::Reference{length}),
    gui		=> ["real", "chemistry", "field", "advanced", "dpd"]},
  rmass		=> {
    comment	=> "set reference mass",
    default	=> strref($::EMC::Reference{mass}),
    gui		=> ["real", "chemistry", "field", "advanced", "dpd"]},
  rtype		=> {
    comment	=> "set reference type",
    default	=> $::EMC::Reference{type},
    gui		=> ["string", "chemistry", "field", "advanced", "dpd"]},

  # S

  sample	=> {
    comment	=> "set sampling options for LAMMPS input script",
    default	=> list(\%::EMC::Sample, "boolean"),
    gui		=> ["string", "chemistry", "top", "standard"]},
  script	=> {
    comment	=> "set script file name",
    default	=> $::EMC::Script{name},
    gui		=> ["string", "chemistry", "top", "standard"]},
  script_ncolums => {
    comment	=> "set number of colums in output scripts",
    default	=> $::EMC::Script{ncolums},
    gui		=> ["string", "chemistry", "top", "ignore"]},
  seed		=> {
    comment	=> "set initial random seed",
    default	=> $::EMC::Seed,
    gui		=> ["integer", "chemistry", "emc", "advanced"]},
  shake		=> {
    comment	=> "set shake types",
    default	=> "",
    gui		=> ["list", "chemistry", "lammps", "advanced"]},
  shake_iterations => {
    comment	=> "set maximum number of shake iterations",
    default	=> $::EMC::Shake{iterations},
    gui		=> ["integer", "chemistry", "lammps", "advanced"]},
  shake_output	=> {
    comment	=> "set shake output frequency",
    default	=> ($::EMC::Shake{output} ? $::EMC::Shake{output} : "never"),
    gui		=> ["integer", "chemistry", "lammps", "advanced"]},
  shake_tolerance => {
    comment	=> "set shake tolerance",
    default	=> $::EMC::Shake{tolerance},
    gui		=> ["real", "chemistry", "lammps", "advanced"]},
  shape		=> {
    comment	=> "set shape factor",
    default	=> $::EMC::Shape,
    gui		=> ["real", "chemistry", "top", "standard"]},
  shear		=> {
    comment	=> "add shear paragraph to LAMMPS input script",
    default	=> ($::EMC::Shear{flag} ? $::EMC::Shear : "false"),
    gui		=> ["list", "chemistry", "analysis", "ignore"]},
  skin		=> {
    comment	=> "set LAMMPS skin",
    default	=> $::EMC::Lammps{skin},
    gui		=> ["real", "chemistry", "lammps", "advanced"]},
  split		=> {
    comment	=> "sets which clusters to partition; each split is separated by a +-sign; default assigns no clusters to split",
    default	=> list(\%::EMC::Split, "string"),
    gui		=> ["list", "chemistry", "emc", "advanced"]},
  suffix	=> {
    comment	=> "set EMC and LAMMPS suffix",
    default	=> $::EMC::EMC{suffix},
    gui		=> ["string", "chemistry", "top", "ignore"]},
  system	=> {
    comment	=> "system identification and checks during building",
    default	=> list(\%::EMC::System, "boolean", "id"),
    gui		=> ["boolean", "chemistry", "emc", "advanced"]},
  system_charge	=> {
    comment	=> "check for charge neutrality after build",
    default	=> boolean($::EMC::System{charge}),
    gui		=> ["boolean", "chemistry", "emc", "advanced"]},
  system_geometry => {
    comment	=> "check geometry sizing upon building",
    default	=> boolean($::EMC::System{geometry}),
    gui		=> ["boolean", "chemistry", "emc", "advanced"]},
  system_id	=> {
    comment	=> "check for charge neutrality after build",
    default	=> $::EMC::System{id},
    gui		=> ["string", "chemistry", "emc", "advanced"]},
  system_map	=> {
    comment	=> "map system box before build",
    default	=> boolean($::EMC::System{map}),
    gui		=> ["boolean", "chemistry", "emc", "advanced"]},
  system_pbc	=> {
    comment	=> "apply periodic boundary conditions after build",
    default	=> boolean($::EMC::System{pbc}),
    gui		=> ["boolean", "chemistry", "emc", "advanced"]},

  # T

  temperature	=> {
    comment	=> "set simulation temperature in K",
    default	=> $::EMC::Temperature,
    gui		=> ["real", "chemistry", "top", "standard"]},
  tequil	=> {
    comment	=> "set LAMMPS equilibration time",
    default	=> $::EMC::Lammps{tequil},
    gui		=> ["integer", "chemistry", "lammps", "standard"]},
  tfreq		=> {
    comment	=> "set LAMMPS profile sampling frequency",
    default	=> $::EMC::Lammps{tfreq},
    gui		=> ["integer", "chemistry", "lammps", "standard"]},
  thermo_multi	=> {
    comment	=> "set LAMMPS thermo style to multi",
    default	=> boolean($::EMC::Lammps{multi}),
    gui		=> ["boolean", "chemistry", "lammps", "ignore"]},
  tighten	=> {
    comment	=> "set tightening of simulation box for imported structures",
    default	=> $::EMC::Tighten eq "" ? "false" : $::EMC::Tighten,
    gui		=> ["real", "chemistry", "emc", "standard"]},
  time_analyze	=> {
    comment	=> "set job analyze script wall time",
    default	=> $::EMC::RunTime{analyze},
    gui		=> ["string", "environment", "analysis", "standard"]},
  time_build	=> {
    comment	=> "set job build script wall time",
    default	=> $::EMC::RunTime{build},
    gui		=> ["string", "environment", "emc", "standard"]},
  time_run	=> {
    comment	=> "set job run script wall time",
    default	=> $::EMC::RunTime{run},
    gui		=> ["string", "environment", "lammps", "standard"]},
  timestep	=> {
    comment	=> "set integration time step",
    default	=> $::EMC::Timestep,
    gui		=> ["string", "chemistry", "lammps", "standard"]},
  triclinic	=> {
    comment	=> "set LAMMPS triclinic mode",
    default	=> $::EMC::Lammps{triclinic},
    gui		=> ["string", "chemistry", "lammps", "standard"]},
  trun		=> {
    comment	=> "set LAMMPS run time",
    default	=> $::EMC::Lammps{trun},
    gui		=> ["string", "chemistry", "lammps", "standard"]},

  # U

  units		=> {
    comment	=> "set units type",
    default	=> $::EMC::Units{type},
    gui		=> ["string", "chemistry", "field", "advanced", "units"]},
  units_energy	=> {
    comment	=> "set units for energetic scale",
    default	=> $::EMC::Units{energy},
    gui		=> ["real", "chemistry", "field", "advanced", "units"]},
  units_length	=> {
    comment	=> "set units for length scale",
    default	=> $::EMC::Units{length},
    gui		=> ["real", "chemistry", "field", "advanced", "units"]},

  # V

  volume	=> {
    comment	=> "set recalculation based on molecular volume",
    default	=> boolean($::EMC::Flag{volume}),
    gui		=> ["boolean", "chemistry", "lammps", "advanced"]},
  version	=> {
    comment	=> "output version information",
    default	=> boolean($::EMC::Flag{version}),
    gui		=> ["boolean", "chemistry", "top", "ignore"]},

  # W

  warn		=> {
    comment	=> "control warning information",
    default	=> boolean($::EMC::Flag{warn}),
    gui		=> ["boolean", "chemistry", "top", "ignore"]},
  weight	=> {
    comment	=> "set build relaxation energetic weights",
    default	=> list($::EMC::Build{weight}, "real"),
    gui		=> ["string", "chemistry", "emc", "standard"]},
  width		=> {
    comment	=> "use double width in scripts",
    default	=> boolean($::EMC::Flag{width}),
    gui		=> ["boolean", "environment", "top", "advanced"]
  },
  workdir	=> {
    comment	=> "set work directory",
    default	=> $::EMC::WorkDir,
    gui		=> ["boolean", "environment", "top", "advanced"]
  }
);

@::EMC::Notes = (
  "This script comes with no warrenty of any kind.  It is distributed under the same terms as EMC, which are described in the LICENSE file included in the EMC distribution.",
  "Queue name 'default' refers to whichever queue is default; queue name 'local' executes all jobs sequentially on local machine",
  "Reference and parameter file names are assumed to have .csv extensions",
  "Chemistry and environment file names are assumed to have $::EMC::Script{extension} extensions",
  "File names with suffixes _chem can be taken as chemistry file names wild cards",
  "Chemistry file format: mol id, smiles string, fraction, mol mass[, mol vol]",
  "Reserved environment loop variables are: stage, trial, and copy",
  "Densities for multiple phases are separated by commas",
  "Shears are defined in terms of erate; values < 0 turns shear off",
  "Inner and outer cut offs are interpreted as fractions for colloidal force fields",
  "Valid field options are: ignore, complete, warn, empty, or error",
  "A '+' sign demarcates clusters of each phase"
);
}


# initialization

sub set_origin {
  my @arg = split("/", @_[0]);
  @arg = (split("/", $ENV{'PWD'}), @arg[-1]) if (@arg[0] eq ".");
  $::EMC::Script = @arg[-1];
  if (defined($ENV{EMC_ROOT})) {
    $::EMC::Root = $ENV{EMC_ROOT};
    $::EMC::Root =~ s/~/$ENV{HOME}/g;
  } else {
    pop(@arg); pop(@arg);
    pop(@arg) if (@arg[-1] eq "");
    $::EMC::Root = join("/", @arg);
  }
}


sub set_variables {
  path_prepend(
    $::EMC::Analyze{location}, ".");
  path_append(
    $::EMC::Analyze{location}, 
    $::EMC::WorkDir."/chemistry/analyze", $::EMC::Root."/scripts/analyze");
  path_prepend(
    $::EMC::Include{location}, ".");
  path_append(
    $::EMC::Include{location}, $::EMC::WorkDir."/chemistry/include");
  path_prepend(
    $::EMC::FieldList{location}, ".");
  path_append(
    $::EMC::FieldList{location}, 
    $::EMC::WorkDir."/chemistry/field", $::EMC::Root."/field");

  if (!scalar(@{$::EMC::FieldList{name}})) {
    update_fields();
  }
  if ($::EMC::EMC{suffix}<0) {
    my $suffix;
    if ($::EMC::ENV{HOST} ne "") {
      $suffix = $::EMC::ENV{HOST}; }
    elsif ($^O eq "MSWin32" || $^O eq "MSWin64") { 
      $suffix = "win32"; }
    elsif ($^O eq "darwin") { 
      $suffix = "macos"; }
    elsif ($^O eq "linux") { 
      $suffix = `uname -m` eq "x86_64\n" ? "linux64" : "linux"; }
    $::EMC::EMC{suffix} = "_$suffix";
  }
  $::EMC::Columns = $ENV{COLUMNS} if (defined($ENV{COLUMNS}));
  $::EMC::EMC{suffix} = (split("\n", $::EMC::EMC{suffix}))[0];
  $::EMC::Units{type} = (
    $::EMC::Field{type} eq "colloid" ? "real" :
    $::EMC::Field{type} eq "dpd" ? "lj" : "real") if ($::EMC::Units{type}<0);
  $::EMC::Lammps{skin} = (
    $::EMC::Units{type} eq "cgs" ? 0.1 :
    $::EMC::Units{type} eq "lj" ? 0.3 :
    $::EMC::Units{type} eq "metal" ? 2.0 :
    $::EMC::Units{type} eq "real" ? (
      $::EMC::Field{type} eq "colloid" ? 200.0 : 2.0) :
    $::EMC::Units{type} eq "si" ? 0.001 : -1) if ($::EMC::Lammps{skin}<0);
  if ($::EMC::Lammps{skin}<0) {
    error("undetermined LAMMPS skin.\n");
  }
  $::EMC::Units{energy} = 1 if ($::EMC::Units{energy}<0);
  $::EMC::Units{"length"} = 1 if ($::EMC::Units{"length"}<0);
  $::EMC::CutOff{pair} = (
    $::EMC::Field{type} eq "dpd" ? 1.0 :
    $::EMC::Field{type} eq "cff" ? 9.5 :
    $::EMC::Field{type} eq "colloid" ? 500.0 :
    $::EMC::Field{type} eq "charmm" ? 12.0 :
    $::EMC::Field{type} eq "opls" ? 9.5 :
    $::EMC::Field{type} eq "born" ? 10.5 :
    $::EMC::Field{type} eq "martini" ? 12.0 :
    $::EMC::Field{type} eq "trappe" ? 14.0 :
    $::EMC::Field{type} eq "standard" ? 2.5 :
    $::EMC::Field{type} eq "sdk" ? 15.0 : -1) if ($::EMC::CutOff{pair}<0);
  $::EMC::CutOff{center} = (
    $::EMC::Field{type} eq "martini" ? 0.00001 : -1) if ($::EMC::CutOff{center}<0);
  $::EMC::CutOff{inner} = (
    $::EMC::Field{type} eq "charmm" ? 10.0 :
    $::EMC::Field{type} eq "colloid" ? 1.00001: 
    $::EMC::Field{type} eq "martini" ? 9.0 : -1) if ($::EMC::CutOff{inner}<0);
  $::EMC::CutOff{outer} = (
    $::EMC::Field{type} eq "colloid" ? 1.25 : -1) if ($::EMC::CutOff{outer}<0);
  $::EMC::Core = (
    $::EMC::Field{type} eq "born" ? 1.0 : -1) if ($::EMC::Core<0);
  $::EMC::CutOff{ghost} = (
    $::EMC::Field{type} eq "dpd" ? 4.0 : -1) if ($::EMC::CutOff{ghost}<0);
  $::EMC::Flag{atomistic} = (
    $::EMC::Field{type} eq "born" ? 1 :
    $::EMC::Field{type} eq "cff" ? 1 :
    $::EMC::Field{type} eq "charmm" ? 1 : 0);
  foreach (@{$::EMC::FieldList{name}}) {
    if ($::EMC::Field{type} eq "opls" && substr($_, -6) eq "opls-aa") {
      $::EMC::Flag{atomistic} = 1;
    }
  }
  $::EMC::Field{name} = join(",", @{$::EMC::FieldList{name}});
  $::EMC::Flag{charge} = (
    $::EMC::Field{type} eq "dpd" ? 1 :
    $::EMC::Field{type} eq "cff" ? 1 :
    $::EMC::Field{type} eq "charmm" ? 1 :
    $::EMC::Field{type} eq "opls" ? 1 :
    $::EMC::Field{type} eq "born" ? 1 :
    $::EMC::Field{type} eq "martini" ? 0 :
    $::EMC::Field{type} eq "trappe" ? 1 :
    $::EMC::Field{type} eq "standard" ? 0 :
    $::EMC::Field{type} eq "sdk" ? 0 : 0) if ($::EMC::Flag{charge}<0);
  $::EMC::Flag{shake} = (
    $::EMC::Field{type} eq "charmm" ?
      defined($::EMC::Shake{flag}) ? flag($::EMC::Shake{flag}) :
      0 : 0) if ($::EMC::Flag{shake}<0);
  $::EMC::Build{radius} = (
    $::EMC::Field{type} eq "dpd" ? 1.0 : 5.0) if ($::EMC::Build{radius}<0);
  foreach (keys(%{$::EMC::Build{weight}})) {
    if (${$::EMC::Build{weight}}{$_}<0) {
      ${$::EMC::Build{weight}}{$_} = (
	$::EMC::Field{type} eq "dpd" ? 0.01 : 0.0001);
    }
  }
  $::EMC::BondConstants = 
    "25,1" if ($::EMC::Field{dpd}&&($::EMC::Flag{bond}<0));
  $::EMC::Dielectric = (
    $::EMC::Field{type} eq "dpd" ? 0.2 : 
    $::EMC::Field{type} eq "martini" ? 15 : 1.0) if ($::EMC::Dielectric<0);
  $::EMC::Precision = (
    $::EMC::Field{type} eq "dpd" ? 0.1 : 0.001) if ($::EMC::Precision<0);
  $::EMC::Flag{cross} = (
    $::EMC::Field{type} eq "dpd" ? 1 :
    $::EMC::Field{type} eq "born" ? 1 :
    $::EMC::Field{type} eq "martini" ? 1 : 0) if ($::EMC::Flag{cross}<0);
  $::EMC::Timestep = (
    $::EMC::Field{type} eq "dpd" ? 0.025 :
    $::EMC::Field{type} eq "standard" ? 0.005 :
    $::EMC::Field{type} eq "charmm" ? 2 :
    $::EMC::Field{type} eq "opls" ? 2 : 1) if ($::EMC::Timestep<0);
  $::EMC::NAMD{dtnonbond} = int($::EMC::NAMD{dtnonbond});
  $::EMC::NAMD{dtnonbond} = 1 if ($::EMC::NAMD{dtnonbond}<1);
  $::EMC::NAMD{dtcoulomb} = int($::EMC::NAMD{dtcoulomb});
  $::EMC::NAMD{dtcoulomb} = 1 if ($::EMC::NAMD{dtcoulomb}<1);
  $::EMC::CutOff{charge} = (
    $::EMC::Field{type} eq "dpd" ? 3.0 : $::EMC::CutOff{pair}) if ($::EMC::CutOff{charge}<0);
  $::EMC::Kappa = (
    $::EMC::Field{type} eq "dpd" ? 1.0 : 4.0) if ($::EMC::Kappa<0);
  $::EMC::Reference{volume} = (
    $::EMC::Field{type} eq "dpd" ? 0.1 : -1) if ($::EMC::Reference{volume}<0);
  $::EMC::Reference{flag} = (
    $::EMC::Field{type} eq "dpd" ? 0 : 1);
  $::EMC::Flag{ewald} = (
    $::EMC::Flag{charge}<0 ? 0 : $::EMC::Flag{charge}) if ($::EMC::Flag{ewald}<0);
  $::EMC::Flag{mass_entry} = (
    $::EMC::Field{type} eq "dpd" ? 1 : 
    $::EMC::Field{type} eq "martini" ? 1 : 0) if ($::EMC::Flag{mass_entry}<0);
  $::EMC::Flag{dpd} = (
    $::EMC::Field{type} eq "dpd" ? 1 : 0);
  $::EMC::Tighten = (
    $::EMC::Field{type} eq "dpd" ? 1.0 : 3.0) if ($::EMC::Tighten<0);
  if ($::EMC::Lammps{write}>0) {
    $::EMC::Lammps{version} = $::EMC::Lammps{new_version} if ($::EMC::Lammps{write}>1);
    $::EMC::Lammps{version} = $::EMC::Lammps{write} if ($::EMC::Lammps{write}>2000);
    $::EMC::Lammps{communicate} = $::EMC::Lammps{version}<$::EMC::Lammps{new_version} ? 1 : 0;
    $::EMC::Lammps{chunk} = $::EMC::Lammps{version}<$::EMC::Lammps{new_version} ? 0 : 1;
  }
  if (!$::EMC::EMC{write}) {
    $::EMC::EMC{execute} = $::EMC::EMC{test} = 0;
  } if (flag($::EMC::EMC{execute})) {
    $::EMC::EMC{executable} = $::EMC::ENV{HOST} ne "" ? "emc_$::EMC::ENV{HOST}" : "emc$::EMC::EMC{suffix}";
  } elsif ($::EMC::EMC{execute} eq "-" || !flag($::EMC::EMC{execute})) {
    $::EMC::EMC{execute} = 0;
  } elsif ($::EMC::EMC{execute} ne "-") {
    $::EMC::EMC{executable} = $::EMC::EMC{execute};
  }
  $::EMC::Lammps{pdamp} = (
    $::EMC::Field{type} eq "dpd" ? 10 : 1000);
  $::EMC::NChains = -1 if ($::EMC::NChains<2);
  $::EMC::Flag{ewald} = 0 if ($::EMC::Flag{charge}==0);
  $::EMC::NPhases = scalar(@::EMC::Phases);
  $::EMC::Flag{reduced} = (
    $::EMC::Field{type} eq "dpd" ? 1 :
    $::EMC::Field{type} eq "standard" ? 1 :
    0) if ($::EMC::Flag{reduced}<0);
  $::EMC::Shape = $::EMC::ShapeDefault[$::EMC::NPhases>1 ? 1 : 0] if ($::EMC::Shape eq "");
  $::EMC::Density = $::EMC::Field{type} eq "dpd" ? 3.0 : 1.0 if ($::EMC::Density eq "");
  $::EMC::NAv = $::EMC::Flag{reduced} ? 1.0 : 0.6022141179 if ($::EMC::NAv eq "");
  $::EMC::Temperature = $::EMC::Flag{reduced} ? 1.0 : 300.0 if ($::EMC::Temperature eq "");
  $::EMC::Script{name} = (split($::EMC::Script{extension}, $::EMC::Script{name}))[0];
  $::EMC::System{charge} = (
    $::EMC::FieldFlag{charge} &= $::EMC::System{charge});
  
  if (!$::EMC::Flag{rules}) {
    my %allowed = (born => 1, charmm => 1, opls => 1, trappe => 1);
    $::EMC::Flag{rules} = defined($allowed{$::EMC::Field{type}});
  }

  foreach (keys(%::EMC::HostDefaults)) {
    if ($_ eq $::EMC::ENV{HOST}) {
      my $ptr = $::EMC::HostDefaults{$_};
      foreach (keys(%{$ptr})) { 
	$::EMC::Queue{$_} = ${$ptr}{$_} if ($::EMC::Queue{$_} eq "default");
      }
    }
  }
  
  if ($::EMC::Queue{ppn}>0) {
    if ($::EMC::Queue{ncores}>$::EMC::Queue{ppn}) {
      if ($::EMC::Queue{ncores} % $::EMC::Queue{ppn}) {
	warning("queue_ncores % queue_ppn != 0.\n");
      }
    } else {
      if ($::EMC::Queue{ppn} % $::EMC::Queue{ncores}) {
	warning("queue_ppn % queue_ncores != 0.\n");
      }
    }
  }
  
  if ($::EMC::Queue{ncores}<$::EMC::Queue{ppn} && $::EMC::NChains>1) {
    error("cannot use chains when queue_ncores<queue_ppn.\n");
  }
  
  my $name = (split("/", $::EMC::Script{name}))[-1];
  
  foreach (keys(%::EMC::RunName)) {
    next if ($::EMC::RunName{$_} ne "");
    $::EMC::RunName{$_} = $name;
  }
  
  if ($::EMC::NAMD{write}) {
    $::EMC::PDB{parameters} = 1;
  }
  
  error("no adequate cutoff has been set (correct force field?)\n") if ($::EMC::CutOff{pair}<0);

  foreach (keys(%::EMC::Sample)) {
    if (!${${$::EMC::Analyze{scripts}}{$_}}{active}) {
      ${${$::EMC::Analyze{scripts}}{$_}}{active} = $::EMC::Sample{$_};
    }
  }
}


sub set_direction {
  my $dir = shift(@_);
  my %direction = (
    x => ["x", "y", "z"],
    y => ["y", "z", "x"],
    z => ["z", "x", "y"]);

  if (!defined($direction{$dir})) {
    error("direction '$dir' is not allowed\n"); }
  $::EMC::Direction{x} = @{$direction{$dir}}[0];
  $::EMC::Direction{y} = @{$direction{$dir}}[1];
  $::EMC::Direction{z} = @{$direction{$dir}}[2];
}


sub set_densities {
  my $i = scalar(@::EMC::Densities);
  my $n = $::EMC::NPhases<2 ? 1 : $::EMC::NPhases;
  while ($i<$n) { $::EMC::Densities[$i++] = $::EMC::Density; }
}


sub set_fields {
  return if (%::EMC::Fields);

  if (!defined($::EMC::FieldList{name})) {
    @{$::EMC::FieldList{name}} = [$::EMC::Project{name}];
    $::EMC::FieldList{id} = {$::EMC::Project{name} => $::EMC::Project{name}};
  }

  foreach (@{$::EMC::FieldList{name}}) {
    $::EMC::Field{id} = $::EMC::FieldList{id}->{$_};
    $::EMC::Field{name} = $_;
    $::EMC::Field{type} = $::EMC::Field{type};
    push(@::EMC::Fields, {%::EMC::Field});
  }
}


sub update_fields {
  my $option = shift(@_);
  my $id = $::EMC::Field{id};
  my $i = 0;
  my @locations; 
  my %location;
  my @names;
  my %ids;

  %::EMC::Fields = () if ($option eq "reset");
  $::EMC::Fields{$id} = {%::EMC::Field} if ($option ne "list");
  if (defined($::EMC::FieldList{location})) {
    foreach (@{$::EMC::FieldList{location}}) {
      $location{$_} = $i++;
      push(@locations, $_);
    }
  }
  foreach (sort(keys(%::EMC::Fields))) {
    my $ptr = $::EMC::Fields{$_};
    push(@names, $ptr->{name});
    $ids{$ptr->{name}} = $_;
    if (defined($location{$ptr->{location}})) {
      $ptr->{ilocation} = $location{$ptr->{location}};
    } else {
      $location{$ptr->{location}} = $ptr->{ilocation} = $i++;
      push(@locations, $ptr->{location});
    }
  }
  #return if ($option ne "list");
  $::EMC::FieldList{location} = [@locations];
  $::EMC::FieldList{name} = [sort(@names)];
  $::EMC::FieldList{id} = {%ids};
}


sub update_field {
  my $flag = 0;

  if (defined($::EMC::Fields{$::EMC::Field{id}})) {
    ${$::EMC::Fields{$::EMC::Field{id}}}{@_[0]} = @_[1];
    $flag = 1;
  }
  $::EMC::Field{@_[0]} = @_[1];
  return $flag;
}


sub output_fields {
  my $id = shift(@_);
  my %entries;
  my @entries;

  foreach (keys(%::EMC::Fields)) { 
    my $ptr = $::EMC::Fields{$_};
    $entries{$ptr->{$id}} = 1;
  }
  foreach (sort(keys(%entries))) {
    push(@entries, "\"$_\"");
  }
  if (scalar(@entries)>1) {
    info("force field $id"."s = {".join(", ", @entries)."}\n");
  } else {
    info("force field $id = ".@entries[0]."\n");
  }
}


sub reset_flags {
  return if (!$Reset::EMC::Flags);
  $Reset::EMC::Flags = 0;
  $::EMC::EMC{write} = 0;
  $::EMC::Field{write} = 0;
  $::EMC::Lammps{write} = 0;
  $::EMC::NAMD{write} = 0;
  $::EMC::PDB{write} = 0;
}


sub set_field_flag {
  my $type = shift(@_);
  my $flag = shift(@_);
  my %types = (
    bond => 0, angle => 0, torsion => 1, improper => 1, increment => 1,
    group => 1);
  
  if (!defined($types{$type})) {
    error("illegal field flag type [$type]\n"); }
  if (!defined($::EMC::FieldFlags{$flag})) {
    if ($types{$type}) {
      error("unknown field flag [$flag]\n"); }
    return 0;
  }
  $::EMC::FieldFlag{$type} = $flag;
  return 1;
}


sub set_pdb_flag {
  my $type = shift(@_);
  my $mode = shift(@_);
  my $line = shift(@_);
  my %allow = (detect => 1, index => 1, series => 1);

  if (!$allow{$mode}) {
    error_line($line, "illegal PDB $type flag '$mode'\n");
  }
  $::EMC::PDB{$type} = $mode;
}


sub field_type {
  my $name = shift(@_);
  my $add = shift(@_);
  my $stream = fopen($name, "r");
  my $define = 0;
  my @arg = split("\.", (split($^O eq "MSWin32" ? "\\\\" : "/", $name))[-1]); pop(@arg);
  my $type = join("\.", @arg);
  my $read = 0;

  foreach (<$stream>) {
    chop();
    @arg = split(" ");
    return "cff" if (uc(join(" ", @arg)) eq "!BIOSYM FORCEFIELD 1");
    if (@arg[0] eq "ITEM") {
      $read = 1 if (@arg[1] eq "DEFINE");
      $read = 0 if (@arg[1] eq "END");
      next;
    }
    next if (!$read);
    next if (@arg[0] ne "FFMODE" && @arg[0] ne "FFNAME");
    $type = lc(@arg[1]);
    last;
  }
  return $type;
}


sub scrub_dir {
  my $result;
  my @arg;

  if ($^O eq "MSWin32") {
    my $a = @_[0];

    $a =~ s/\//\\/g;
    foreach (split("\\\\", $a)) {
      push(@arg, $_) if ($_ ne "");
    }
    $result = join("/", @arg);
  } else {
    $result = substr(@_[0], 0, 1) eq "/" ? "/" : "";
    foreach (split("/", @_[0])) {
      push(@arg, $_) if ($_ ne "");
    }
    $result .= join("/", @arg);
    $result =~ s/^$ENV{HOME}/~/;
  }
  return $result;
}


sub set_field {
  my $line = shift(@_);
  my $warning = shift(@_);
  my @string = @_;
  my @extension = ("frc", "prm", "field");
  my @path = @{$::EMC::FieldList{location}};
  my $last_type;
  my @names;
  my %flag;

  push(@path, $::EMC::Field{location}) if (!scalar(@path));
  tdebug(__LINE__.":", @path);
  tdebug(__LINE__.":", @string);
  foreach (@string) {
    tdebug(__LINE__.":", $_);
    my @arg = split(":");
    my $string = @arg[0];
    my $style = @arg[1];
    my $index = index($string, "-");
    my $name = "";
    my %result;

    $index = index($string, "/") if ($index<0);
    my $field = $index>0 ? substr($string, 0, $index) : $string;
    foreach (".", @path) {
      my $ext;
      my $root = scrub_dir($_);
      my $split = $root;
      if (substr($_,0,6) eq "\$root+") {
	my $tmp = scrub_dir("$split/$field");
	$root = $tmp if (-d $tmp);
      } else {
	my $tmp = $split = scrub_dir($_);
	$tmp =~ s/~/$ENV{HOME}/g if ($^O ne "MSWin32");
	$root = $split if (-d $tmp);
      }
      $split .= "/" if (length($split));
      my %styles = {};

      if ($style ne "" && !defined($styles{$style})) {
	error_line($line, "illegal field style '$style'\n");
      }

      my $add = $index>0 ? substr($string, $index) : "";
      my %type = ("prm" => $field, "frc" => "cff", "field" => "get");
      my %convert = (basf => "cff", pcff => "cff", compass => "cff");
      my $offset = scalar(split("/", $root.$add));

      $root =~ s/~/$ENV{HOME}/g if ($^O ne "MSWin32");
      
      tdebug(__LINE__.":", "string", $string);
      tdebug(__LINE__.":", "root", $root);
      if (-d "$root") {
	foreach ("/$field", "") {
	  my $dir = "$root$_";
	  next if (! -d "$dir");
	  foreach (@extension) {
	    $ext = $_;
	    foreach (sort(ffind($dir."/", "*.$ext"))) {
	      next if (m/\/src\//);
	      my $index = index($_, $field.$add); 
	      next if ($index<0);
	      $field = field_type($name = $_, $add);
	      last;
	    }
	    last if ($name ne "");
	  }
	  last if ($name ne "");
	}
	#if ($name eq "") {
	#  foreach (@extension) {
	#    $ext = $_;
	#    foreach (sort(ffind($root."/", "*$field*.$ext"))) {
	#      next if (m/\/src\//);
	#      $name = $_; last;
	#    }
	#    last if ($name ne "");
	#  }
	#}
	if ($name ne "") {
	  $name = scrub_dir($name);
	  tdebug(__LINE__.":", "SUCCESS", $name, "\n");
	  $result{type} = defined($convert{$field}) ? $convert{$field} : $field;
	  $result{name} = (split("\.$ext", substr($name, length($split))))[0];
	  $result{location} = scrub_dir($split);
	  last;
	} else {
	  tdebug(__LINE__.":", "FAILURE\n");
	}
      }
    }
    if ($name eq "") {
      push(@{$warning},"field '$string' not found; no changes"); }
    else {
      if ($last_type ne "" && $last_type ne $result{type}) {
	error_line($line, 
	  "unsupported merging of field types $last_type and $result{type}\n");}
      $::EMC::Field{flag} = 1;
      $::EMC::Field{id} = $string;
      $::EMC::Field{name} = $result{name};
      $::EMC::Field{location} = $result{location};
      $::EMC::Field{type} = $last_type = $result{type};
      update_fields();
    }
  }
}


sub set_convert_key {
  my $type = shift(@_);					# used during init
  my $key = shift(@_);
  my $index = 1;

  $::EMC::Convert{$type}->{$key} = 1;
  foreach (sort(keys(%{$::EMC::Convert{type}}))) {
    $::EMC::Convert{$type}->{$_} = $index++;
  }
}


sub convert_key {
  return 
    scalar(@_)>1 ?
    defined($::EMC::Convert{@_[0]}) ?
    defined(${$::EMC::Convert{@_[0]}}{@_[1]}) ?
    ${$::EMC::Convert{@_[0]}}{@_[1]} : 0 : 0 : 0;
}


sub set_ignore {
  my $list = shift(@_);
  my %hash = ();

  $hash{flag} = 1;
  $hash{ignore} = 1;
  if (defined(${$list}{ignore})) {
    foreach (@{${$list}{ignore}}) {
      $hash{$_} = 1;
    }
  }
  return %hash;
}


sub set_list {
  my $line = shift(@_);
  my $hash = shift(@_);
  my $type = shift(@_);
  my $default = shift(@_);
  my %ignore = set_ignore($hash);
  my %special; foreach (@{shift(@_)}) { $special{$_} = 1; }

  foreach(@_) {
    my @arg = split("=");
    if (scalar(@arg) == 1) { 
      @arg = split(":");
      @arg = (shift(@arg), join(":", @arg)) if (scalar(@arg)>1);
    }
    if (!defined(${$hash}{@arg[0]}) || defined($ignore{@arg[0]})) {
      error_line($line, "illegal option \'@arg[0]\'\n") if (!flag_q(@arg[0]));
    }
    if (defined($special{@arg[0]}) || $type eq "string") {
      @arg[1] =~ s/^"+|"+$//g;
    } elsif ($type eq "array") {
      my @a = split(":", @arg[1]);
      @arg[1] = $default ? [@a, @{${$hash}{@arg[0]}}] : [@a];
    } elsif ($type eq "boolean") {
      if (scalar(@arg) == 1) {
	if ($default eq "") {
	  @arg = (@arg[0], 1);
	}
	elsif (
	    @arg[0] eq "0" || @arg[0] eq "1" ||
	    @arg[0] eq "false" || @arg[0] eq "true") {
	  @arg = ($default, @arg[0]);
	}
      }
      if (@arg[1] eq "true" || @arg[1] eq "") {
	@arg[1] = 1;
      } elsif (@arg[1] eq "false") {
	@arg[1] = 0;
      } elsif (@arg[1] == 0 && @arg[1] ne "0") {
	error_line($line, "illegal option value \'@arg[1]\'\n");
      }
      @arg[1] = 1 if (scalar(@arg)==1);
      @arg[1] = 0 if (@arg[1] eq "false");
      @arg[1] = 1 if (@arg[1] eq "true");
    } elsif ($type eq "integer") {
      @arg[1] = int(eval(@arg[1]));
      @arg[1] = 0 if (@arg[1]<0);
    } elsif ($type eq "real") {
      @arg[1] = eval(@arg[1]);
    }
    ${$hash}{@arg[0]} = @arg[1];
  }
  ${$hash}{flag} = 1;
}


sub set_list_polymer {
  my $line = shift(@_);
  my $hash = shift(@_);
  my %allowed = (
    bias => {none => 1, binary => 1, accumulative => 1},
    fraction => {number => 1, mass => 1},
    order => {list => 1, random => 1}
  );

  set_list($line, $hash, "string", "", [], @_);
  foreach (sort(keys(%allowed))) {
    if (!defined(${$allowed{$_}}{${$hash}{$_}})) {
      error_line($line, "illegal option for keyword '$_'\n");
    }
  }
  ${$hash}{cluster} = flag(${$hash}{cluster});
}


sub set_list_split {
  my $line = shift(@_);
  my %split = %::EMC::Split;
  my $first = 1;
  my $phase = $split{phase};
  my %allowed = (
    mode => {distance => 1, random => 1},
    type => {absolute => 1, relative => 1}
  );
  my @args = @_;

  if (scalar(@args)==1) {
    @args = split(" ", @args[0]);
  }

  #tprint(__LINE__.":", @args);
  foreach (@args) {
    my $i = index($_, "=");
    my $key = $i<0 ? $_ : substr($_,0,$i);
    my @arg = $i<0 ? undef : split(":", substr($_, $i+1));
    my $all = 0;

    if ($i<0) {
      error_line($line, "missing equal sign\n") if ($key ne "+");
    } elsif (!defined($split{$key})) {
      error_line($line, "illegal split keyword '$key'\n");
    }
    foreach (@arg) { 
      $_ =~ s/^"+|"+$//g;
      if ($_ eq "all") { $all = 1; last; }
    }
    #tprint(__LINE__.":", $key, @arg);
    if ($key eq "phase" || $key eq "+") {
      if (!$first) {
       	@::EMC::Splits[$phase] = [] if (!defined(@::EMC::Splits[$phase]));
	push(@{@::EMC::Splits[$phase]}, \%split);
      }
      %split = %::EMC::Split;
      $split{phase} = $phase = eval(@arg[0]);
    } elsif ($key eq "clusters") {
      $split{clusters} = $all ? "all" : [@arg];
    } elsif ($key eq "groups") {
      $split{groups} = $all ? "all" : [@arg];
    } elsif ($key eq "sites") {
      $split{sites} = $all ? "all" : [@arg];
    } elsif ($key eq "fraction") {
      $split{fraction} = @arg[0];
    } elsif ($key eq "thickness") {
      $split{thickness} = @arg[0];
    } else {
      if (!defined(${$allowed{$key}}{@arg[0]})) {
	error_line($line, "illegal option for keyword '$key'\n");
      }
      $split{$key} = @arg[0];
    }
    $first = 0;
  }
  if (!$first) {
    @::EMC::Splits[$phase] = [] if (!defined(@::EMC::Splits[$phase]));
    push(@{@::EMC::Splits[$phase]}, \%split);
  }
  #print(__LINE__.": ", Dumper(\@::EMC::Splits));
}


sub set_allowed {
  my $line = shift(@_);
  my $option = shift(@_);
  my %allowed;

  foreach (@_) { $allowed{$_} = 1; }
  if (!defined($allowed{$option})) {
    error_line($line, "unallowed option '$option'\n");
  }
  return $option;
}


sub set_options {
  my $line = shift(@_);
  my $options = shift(@_);
  my $items = shift(@_);
  my $ignore = shift(@_);
  my $string = shift(@_);
  my %allowed;
  my %answer;
  my @xref;
  my $n = 0;

  foreach (@{$options}) {
    $xref[$allowed{@{$_}[0]} = $n++] = @{$_}[0];
    $answer{@{$_}[0]} = @{$_}[1];
  }
  if (!defined($allowed{comment})) {
    $xref[$allowed{comment} = $n++] = "comment";
    $answer{comment} = 0;
  }
  my $index = 0; foreach(@{$items}) {
    $_ =~ s/ //g;
    my @arg = split("=");
    my $option = @arg[0];
    my $value;
    my $i = $index++;

    if (scalar(@arg)>1) {
      if (!defined($allowed{@arg[0]})) {
	error_line($line, "unallowed option '@arg[0]'\n") if (!$ignore);
	--$index;
	next;
      }
      $i = $allowed{@arg[0]}; shift(@arg);
    } else {
      next if ($i>=$n);
    }
    $answer{$xref[$i]} = @arg[0] eq "last" ? -1 : 
			 @arg[0] eq "true" ? 1 : 
			 @arg[0] eq "false" ? 0 : 
			 $string ? @arg[0] : eval(@arg[0]);
  }
  return %answer;
}


sub set_options_flag {
  my $flag = shift(@_);
  my $value = shift(@_);

  foreach (keys(%::EMC::OptionsFlag)) { $::EMC::OptionsFlag{$_} = 0; };
  $::EMC::OptionsFlag{$flag} = flag($value);
}


sub set_port {
  my $line = shift(@_);
  my %port = (options => {perl => 1, tcl => 1}, field => 1);

  foreach (@_) {
    my @arg = split(":");
    if (scalar(keys(%{$port{@arg[0]}}))) {
      if (!defined(${$port{@arg[0]}}{@arg[1]})) {
	error_line($line, "illegal '@arg[0]' option '@arg[1]'\n");
      }
    }
    if (@arg[0] eq "options") {
      foreach (keys(%::EMC::OptionsFlag)) { $::EMC::OptionsFlag{$_} = 0; }
      $::EMC::OptionsFlag{@arg[1]} = 1;
    } elsif (@arg[0] eq "field") {
      error_line($line, "field option currently unavailable\n");
    } else {
      error_line($line, "illegal port '@arg[0]'\n");
    }
  }
}


sub my_eval {
  my $string;
  my $first = 1;
  my $error = 0;

  foreach (split(//, @_[0])) {
    next if ($first && $_ eq "0");
    $string .= $_;
    $first = 0;
  }
  $string = "0" if ($string eq "");
  {
    local $@;
    no warnings;
    unless (eval($string)) { $error = 1; }
  }
  return $error ? $string : eval($string);
}


sub expand_tilde {
  my $dir = shift(@_);

  if (substr($dir,0,2) eq "~/") { $dir =~ s/~/\${HOME}/; }
  elsif (substr($dir,0,1) eq "~") { $dir =~ s/~/\${HOME}\/..\//; }
  return $dir;
}


sub options {
  my @value;
  my $line = shift(@_);
  my $warning = shift(@_);
  my @arg = @_;
  @arg = split("=", @arg[0]) if (scalar(@arg)<2);
  @arg[0] = substr(@arg[0],1) if (substr(@arg[0],0,1) eq "-");
  @arg[0] = lc(@arg[0]);
  my @tmp = @arg; shift(@tmp);
  @tmp = split(",", @tmp[0]) if (scalar(@tmp)<2);
  @tmp = split(":", @tmp[0]) if (scalar(@tmp)<2 &&
				 @arg[0] ne "average" &&
				 @arg[0] ne "deform" &&
				 @arg[0] ne "emc_output" &&
				 @arg[0] ne "port" &&
				 @arg[0] ne "profile" &&
				 @arg[0] ne "sample" &&
				 @arg[0] ne "shake" &&
				 substr(@arg[0],0,4) ne "time");

  my @string;
  foreach (@tmp) { 
    last if (substr($_,0,1) eq "#");
    push(@string, $_);
    push(@value,
      $_ eq "-" ? 0 :
      substr($_,0,1) eq "/" ? 0 : 
      substr($_,0,1) eq "~" ? 0 :
      defined($::EMC::FieldFlags{$_}) ? 0 :
      my_eval($_));
  }
  my $n = scalar(@string);

  tdebug(__LINE__.":", @arg[0]);

  if (!defined($::EMC::Commands{@arg[0]})) { return 1; }

  # A

  elsif ($arg[0] eq "analyze_archive") {
    $::EMC::Analyze{archive} = flag(@string[0]); }
  elsif ($arg[0] eq "analyze_data") {
    $::EMC::Analyze{data} = flag(@string[0]); }
  elsif ($arg[0] eq "analyze_last") {
    ${${$::EMC::Analyze{scripts}}{last}}{active} = flag(@string[0]); }
  elsif ($arg[0] eq "analyze_replace") {
    $::EMC::Analyze{replace} = flag(@string[0]); }
  elsif ($arg[0] eq "analyze_skip") {
    $::EMC::Analyze{skip} = @value[0]<0 ? 0 : int(@value[0]); }
  elsif ($arg[0] eq "analyze_source") {
    $::EMC::Analyze{source} = expand_tilde(@string[0]); }
  elsif ($arg[0] eq "analyze_user") {
    $::EMC::Analyze{user} = expand_tilde(@string[0]); }
  elsif ($arg[0] eq "analyze_window") {
    $::EMC::Analyze{window} = @value[0]<1 ? 1 : int(@value[0]); }
  elsif ($arg[0] eq "angle") {
    $::EMC::Flag{angle} = 1;
    if ($n==2) { $::EMC::AngleConstants = join(",", @value[0,1]); }
    elsif ($n=5) {
      $::EMC::Angles{join("\t", @string[0,1,2])} = join(",", @value[3,4]); }
  }
  elsif ($arg[0] eq "auto") { ${$::EMC::Field{dpd}}{auto} = flag(@string[0]); }

  # B

  elsif ($arg[0] eq "binsize") { $::EMC::BinSize = $value[0] if ($value[0]>0); }
  elsif ($arg[0] eq "bond") {
    $::EMC::Flag{bond} = 1; 
    if ($n==2) { $::EMC::BondConstants = join(",", @value[0,1]); }
    elsif ($n=4) {
      $::EMC::Bonds{join("\t", @string[0,1])} = join(",", @value[2,3]); }
  }
  elsif ($arg[0] eq "build") { $::EMC::Build{name} = $string[0]; }
  elsif ($arg[0] eq "build_center") {
    $::EMC::Build{center} = flag($string[0]);
  }
  elsif ($arg[0] eq "build_dir") { $::EMC::Build{dir} = $string[0]; }
  elsif ($arg[0] eq "build_order") {
    $::EMC::Build{order} = set_allowed($line, $string[0], "random", "sequence");
  }
  elsif ($arg[0] eq "build_origin") {
    set_list($line, $::EMC::Build{origin}, "string", "0", [], @string);
  }
  elsif ($arg[0] eq "build_replace") {
    $::EMC::Build{replace} = flag($string[0]);
  }
  elsif ($arg[0] eq "build_theta") {
    $::EMC::Build{theta} = $value[0];
  }

  # C

  elsif ($arg[0] eq "charge") { $::EMC::Flag{charge} = flag($string[0]); }
  elsif ($arg[0] eq "charge_cut") { $::EMC::CutOff{charge} = $value[0]; }
  elsif ($arg[0] eq "chunk") { $::EMC::Lammps{chunk} = flag($string[0]); }
  elsif ($arg[0] eq "communicate") { $::EMC::Lammps{communicate} = flag($string[0]); }
  elsif ($arg[0] eq "core") { $::EMC::Core = $value[0]; }
  elsif ($arg[0] eq "cross") { $::EMC::Flag{cross} = flag($string[0]); }
  elsif ($arg[0] eq "crystal") { $::EMC::Flag{crystal} = flag($string[0]); }
  elsif ($arg[0] eq "cut") {
    $::EMC::Lammps{cutoff} = 
      $::EMC::CutOff{repulsive} = $string[0] eq "repulsive" ? 1 : 0;
    $::EMC::CutOff{pair} = $value[0] if (!$::EMC::CutOff{repulsive});
  }
  elsif ($arg[0] eq "cutoff") {
    set_list($line, \%::EMC::CutOff, "real", "-1", [], @value); }

  # D

  elsif ($arg[0] eq "debug") { $::EMC::Flag{debug} = flag($string[0]); }
  elsif ($arg[0] eq "deform") {
    set_list($line, \%::EMC::Deform, "string", "xx", [], @string); }
  elsif ($arg[0] eq "density") {
    $::EMC::Density = $value[0]; @::EMC::Densities = @value; }
  elsif ($arg[0] eq "dielectric") { $::EMC::Dielectric = $value[0]; }
  elsif ($arg[0] eq "direction") { set_direction($string[0]); }
  elsif ($arg[0] eq "dtdump") { $::EMC::Lammps{dtdump} = $value[0]; }
  elsif ($arg[0] eq "dtrestart") { $::EMC::Lammps{dtrestart} = $value[0]; }
  elsif ($arg[0] eq "dtthermo") { $::EMC::Lammps{dtthermo} = $value[0]; }

  # E

  elsif ($arg[0] eq "emc") { 
    $::EMC::EMC{write} = flag($string[0]); }
  elsif ($arg[0] eq "emc_depth") { 
    if ($string[0] eq "auto") { $::EMC::EMC{depth} = "auto"; }
    elsif ($value[0]>2) { $::EMC::EMC{depth} = $value[0]; }
    else { 
      error_line($line, "ring depth can only be set to auto or values > 2\n");
    }
  }
  elsif ($arg[0] eq "emc_export") {
    my %allowed = (csv => 1, json => 2, math => 3, false => 0, true => 1);
    my @convert = ("", "csv", "json", "math");
    set_list($line, $::EMC::EMC{export}, "string", "", [], @string);
    my $ptr = $::EMC::EMC{export};
    foreach (sort(keys(%{$ptr}))) {
      next if ($_ eq "flag");
      if (!defined($allowed{$ptr->{$_}})) {
	error_line($line, "illegal emc_export $_ argument\n");
      }
      $ptr->{$_} = @convert[$allowed{$ptr->{$_}}];
    }
  }
  elsif ($arg[0] eq "emc_exclude") {
    set_list($line, $::EMC::EMC{exclude}, "boolean", "", [], @string); }
  elsif ($arg[0] eq "emc_execute") { $::EMC::EMC{execute} = flag($string[0]); }
  elsif ($arg[0] eq "emc_moves") {
    set_list($line, $::EMC::EMC{moves}, "integer", "", [], @string); }
  elsif ($arg[0] eq "emc_output") { 
    set_list($line, $::EMC::EMC{output}, "boolean", "", [], @string); }
  elsif ($arg[0] eq "emc_progress") {
    set_list($line, $::EMC::EMC{progress}, "boolean", "", [], @string); }
  elsif ($arg[0] eq "emc_run") {
    set_list($line, $::EMC::EMC{run}, "string", "", [], @string); }
  elsif ($arg[0] eq "emc_test") { $::EMC::EMC{test} = flag($string[0]); }
  elsif ($arg[0] eq "emc_traject") { 
    set_list($line, $::EMC::EMC{traject}, "string", "", [], @string); }
  elsif ($arg[0] eq "environment") { $::EMC::Flag{environment} = flag($string[0]); }
  elsif ($arg[0] eq "ewald") { $::EMC::Flag{ewald} = flag($string[0]); }
  elsif ($arg[0] eq "exclude") { $::EMC::Flag{exclude} = flag($string[0]); }
  elsif ($arg[0] eq "expert") { $::EMC::Flag{expert} = flag($string[0]); }
  elsif ($arg[0] eq "extension") { $::EMC::Script{extension} = $string[0]; }
  elsif ($arg[0] eq "replica" || $arg[0] eq "extra") {
    @arg[2] = 0 if ($n==2);
    error_line($line, "missing $arg[0] types\n") if ($n<2);
    push(@::EMC::Replica, [@string]); }

  # F

  elsif ($arg[0] eq "field") { set_field($line, $warning, @string); }
  elsif ($arg[0] eq "field_angle") { set_field_flag("angle", @string[0]); }
  elsif ($arg[0] eq "field_bond") { set_field_flag("bond", @string[0]); }
  elsif ($arg[0] eq "field_charge") {
    $::EMC::FieldFlag{charge} = flag($string[0]); }
  elsif ($arg[0] eq "field_check") {
    $::EMC::FieldFlag{check} = flag($string[0]); }
  elsif ($arg[0] eq "field_dpd") {
    set_list($line, $::EMC::Field{dpd}, "boolean", "", [], @string); }
  elsif ($arg[0] eq "field_debug") {
    $::EMC::FieldFlags{debug} = 1;
    if (@string[0] eq "0" || @string[0] eq "false") { 
      $::EMC::FieldFlags{debug} = 0;
      $::EMC::FieldFlag{debug} = "false"; }
    elsif (@value[0]==1 || @string[0] eq "true" || @string[0] eq "full") {
      $::EMC::FieldFlag{debug} = "full"; }
    elsif (@value[0]==2 || @string[0] eq "reduced") {
      $::EMC::FieldFlag{debug} = "reduced"; }
    else {
      error_line($line, "illegal field_debug option\n"); }
  }
  elsif ($arg[0] eq "field_error") {
    $::EMC::FieldFlag{error} = flag(@string[0]) ? "true" : "false"; }
  elsif ($arg[0] eq "field_format") {
    $::EMC::Field{format} = @string[0]; }
  elsif ($arg[0] eq "field_group") {
    set_field_flag("group", @string[0]); }
  elsif ($arg[0] eq "field_id" ) { 
    update_field("id", $string[0]);
    update_fields();
  }
  elsif ($arg[0] eq "field_improper") {
    set_field_flag("improper", @string[0]); }
  elsif ($arg[0] eq "field_increment") {
    set_field_flag("increment", @string[0]); }
  elsif ($arg[0] eq "field_location" ) {
    foreach (@string) { $_ = scrub_dir($_); }
    $::EMC::FieldList{location} =
      [list_unique(0, @string, @{$::EMC::FieldList{location}})];
    update_field("location", @string[0]);
  }
  elsif ($arg[0] eq "field_name" ) {
    $::EMC::FieldList{name} =
      [list_unique($line, @{$::EMC::FieldList{name}}, @string)];
    update_field("name", @string[0]);
    update_fields();
  }
  elsif ($arg[0] eq "field_nbonded") {
    $::EMC::FieldFlag{nbonded} = @value[0]<0 ? 0 : int(@value[0]); }
  elsif ($arg[0] eq "field_reduced") {
    $::EMC::Flag{reduced} = flag($string[0]); }
  elsif ($arg[0] eq "field_torsion") {
    set_field_flag("torsion", @string[0]); }
  elsif ($arg[0] eq "field_type" ) {
    update_field("type", $string[0]);
    update_fields();
  }
  elsif ($arg[0] eq "field_write") {
    reset_flags(); $::EMC::Field{write} = flag($string[0]); }
  elsif ($arg[0] eq "focus") {
    my $flag = -1;
    @::EMC::Focus = ();
    foreach (@string) {
       if ($_ eq "-" || $_ eq "false" || $_ eq "none") { $flag = 0; last; }
       if ($_ eq "all" || $_ eq "true") { $flag = 1; last; }
    }
    if ($flag<0) {
      push(@::EMC::Focus, @string) if (scalar(@string));
      $::EMC::Flag{focus} = 1;
    }
    else { 
      $::EMC::Flag{focus} = $flag;
    }
  }

  # G

  elsif ($arg[0] eq "ghost_cut") { $::EMC::CutOff{ghost} = $value[0]; }
  elsif ($arg[0] eq "grace") {
    warning("'grace' has been deprecated; please use 'weight' instead\n");
    $n = 3 if ($n>3);
    my $i; for ($i=0; $i<$n; ++$i) {
      ${$::EMC::Build{weight}}{
	("nonbond", "bond", "focus")[$i]} = 1.0-@value[$i]; }
  }

  # H

  elsif ($arg[0] eq "help") { help(); }
  elsif ($arg[0] eq "hexadecimal") {
    $::EMC::Flag{hexadecimal} = flag($string[0]); }
  elsif ($arg[0] eq "host") {
    $::EMC::ENV{HOST} = $::EMC::ENV{HOST} = $string[0]; }

  # I

  elsif ($arg[0] eq "info") { $::EMC::Flag{info} = flag($string[0]); }
  elsif ($arg[0] eq "inner") { $::EMC::CutOff{inner} = $value[0]; }
  elsif ($arg[0] eq "insight") { 
    $::EMC::Insight{write} = flag($string[0]); }
  elsif ($arg[0] eq "insight_compress") { 
    $::EMC::Insight{compress} = flag($string[0]); }
  elsif ($arg[0] eq "insight_pbc") { 
    $::EMC::Insight{pbc} = flag($string[0]); }
  elsif ($arg[0] eq "insight_unwrap") { 
    $::EMC::Insight{unwrap} = flag($string[0]); }

  # K

  elsif ($arg[0] eq "kappa") { $::EMC::Kappa = $value[0]; }

  # L

  elsif ($arg[0] eq "lammps") {
    if ($string[0] eq "old" ) {
      $::EMC::Lammps{write} = $::EMC::Lammps{new_version}-1; }
    elsif ($string[0] eq "new") {
      $::EMC::Lammps{write} = $::EMC::Lammps{new_version}; }
    elsif ($value[0]>2000) {
      $::EMC::Lammps{write} = $value[0]; }
    else {
      $::EMC::Lammps{write} = flag($string[0]); } }
  elsif ($arg[0] eq "lammps_cutoff") {
    $::EMC::Lammps{cutoff} = $::EMC::CutOff{repulsive} = flag($value[0]); }
  elsif ($arg[0] eq "lammps_dlimit") {
    $::EMC::Lammps{dlimit} = $value[0]; }
  elsif ($arg[0] eq "lammps_pdamp") {
    $::EMC::Lammps{pdamp} = $value[0]; }
  elsif ($arg[0] eq "lammps_tdamp") {
    $::EMC::Lammps{tdamp} = $value[0]; }
  elsif (@arg[0] eq "location") {
    set_list($line, \%::EMC::Location, "array", 1, [], @string);
    update_field("location", @{$::EMC::Location{field}}[0]);
  }

  # M

  elsif ($arg[0] eq "mass") { 
    $::EMC::Flag{mol} = $::EMC::Flag{number} = $::EMC::Flag{volume} = 0 if (($::EMC::Flag{mass} = flag($string[0]))); }
  elsif ($arg[0] eq "memorypercore") { $::EMC::Queue{memory} = $value[0]; }
  elsif ($arg[0] eq "modules") {
    @::EMC::Modules = ();
    foreach (@string) {
      my @arg = split("=");
      foreach (@arg) { $_ =~ s/^\s+|\s+$//g; }	# remove space from start/end
      if (scalar(@arg)!=2) { error_line($line, "expecting module old=new\n"); }
      push(@::EMC::Modules, "unload=@arg[0]") if (scalar(@arg)>1);
      push(@::EMC::Modules, "load=@arg[-1]");
    }
  }
  elsif ($arg[0] eq "mol") { 
    $::EMC::Flag{mass} = $::EMC::Flag{number} = $::EMC::Flag{volume} = 0 if (($::EMC::Flag{mol} = flag($string[0]))); }
  elsif ($arg[0] eq "momentum") {
    $string[0] = 0 if ($value[0]<0);
    if (($::EMC::Lammps{momentum_flag} = flag($string[0]))) {
      if (@string[0] ne "true") {
	my $i; for ($i=0; $i<($n<4 ? $n : 4); ++$i) {
	  @{$::EMC::Lammps{momentum}}[$i] = @value[$i]; }
	@{$::EMC::Lammps{momentum}}[4] = "" if (@string[4] eq "none" || @string[4] eq "-");
      }
    }
  }
  elsif ($arg[0] eq "moves_cluster") {
    set_list($line, $::EMC::Moves{cluster}, "string", "", [], @string);
  }
  elsif ($arg[0] eq "msd") {
    $::EMC::Sample{msd} = $string[0] ne "average" ? flag($string[0]) : 2;
  }

  # N

  elsif ($arg[0] eq "namd") { 
    $::EMC::PDB{write} = 1 if (($::EMC::NAMD{write} = flag(@string[0]))); }
  elsif ($arg[0] eq "namd_dtcoulomb") { $::EMC::NAMD{dtcoulomb} = @value[0]; }
  elsif ($arg[0] eq "namd_dtdcd") { $::EMC::NAMD{dtdcd} = @value[0]; }
  elsif ($arg[0] eq "namd_dtnonbond") { $::EMC::NAMD{dtnonbond} = @value[0]; }
  elsif ($arg[0] eq "namd_dtrestart") { $::EMC::NAMD{dtrestart} = @value[0]; }
  elsif ($arg[0] eq "namd_dtthermo") { $::EMC::NAMD{dtthermo} = @value[0]; }
  elsif ($arg[0] eq "namd_dttiming") { $::EMC::NAMD{dttiming} = @value[0]; }
  elsif ($arg[0] eq "namd_dtupdate") { $::EMC::NAMD{dtupdate} = @value[0]; }
  elsif ($arg[0] eq "namd_pres_decay") { $::EMC::NAMD{pres_decay} = @value[0]; }
  elsif ($arg[0] eq "namd_pres_period") { $::EMC::NAMD{pres_period} = @value[0]; }
  elsif ($arg[0] eq "namd_temp_damp") { $::EMC::NAMD{temp_damp} = @value[0]; }
  elsif ($arg[0] eq "namd_tminimize") { $::EMC::NAMD{tminimize} = @value[0]; }
  elsif ($arg[0] eq "namd_trun") { $::EMC::NAMD{trun} = @value[0]; }
  elsif ($arg[0] eq "name_scripts" ) { 
    $::EMC::RunName{analyze} = $::EMC::RunName{build} = $::EMC::RunName{run} = $string[0]; }
  elsif ($arg[0] eq "name_analyze") { $::EMC::RunName{analyze} = $string[0]; }
  elsif ($arg[0] eq "name_build") { $::EMC::RunName{build} = $string[0]; }
  elsif ($arg[0] eq "name_run") { $::EMC::RunName{run} = $string[0]; }
  elsif ($arg[0] eq "name_testdir") { $::EMC::RunName{test} = $string[0]; }
  elsif ($arg[0] eq "nchains") { $::EMC::NChains = @value[0]; }
  elsif ($arg[0] eq "ncores") { $::EMC::Queue{ncores} = @value[0]; }
  elsif ($arg[0] eq "ncorespernode") { $::EMC::Queue{ppn} = @value[0]; }
  elsif ($arg[0] eq "niterations") { $::EMC::Build{niterations} = $value[0]; }
  elsif ($arg[0] eq "norestart") { $::EMC::Flag{norestart} = flag(@string[0]); }
  elsif ($arg[0] eq "nparallel") {
    $::EMC::ImportNParallel = $value[0]<1 ? 0 : $value[0]; }
  elsif ($arg[0] eq "nrelax") { $::EMC::Build{nrelax} = $value[0]; }
  elsif ($arg[0] eq "nsample") { $::EMC::Lammps{nsample} = $value[0]; }
  elsif ($arg[0] eq "ntotal") { $::EMC::NTotal = $value[0]; }
  elsif ($arg[0] eq "number") {
    $::EMC::Flag{number} = flag($string[0]);
    if (flag($string[0])) {
      $::EMC::Flag{mass} = $::EMC::Flag{mol} = $::EMC::Flag{volume} = 0;
    }
  }

  # O

  elsif ($arg[0] eq "omit") { $::EMC::Flag{omit} = flag($string[0]); }
  elsif ($arg[0] eq "options_perl") {
    set_options_flag("perl", $string[0]); }
  elsif ($arg[0] eq "options_tcl") { 
    set_options_flag("tcl", $string[0]); }
  elsif ($arg[0] eq "outer") {
    $::EMC::CutOff{outer} = $value[0]; }

  # P

  elsif ($arg[0] eq "pair") { 
    $::EMC::Flag{pair} = 1; 
    set_list($line, \%::EMC::PairConstants, "real", "-1", [], @value); }
  elsif ($arg[0] eq "parameters") {
    $::EMC::Parameters{name} = $string[0]; $::EMC::Parameters{read} = 1; }
  elsif ($arg[0] eq "params") {
    reset_flags(); $::EMC::Field{write} = flag($string[0]); }
  elsif ($arg[0] eq "pdb") {
    $::EMC::NAMD{write} = 0 if (!($::EMC::PDB{write} = flag(@string[0]))); }
  elsif ($arg[0] eq "pdb_atom") {
    set_pdb_flag("atom", $string[0], $line); }
  elsif ($arg[0] eq "pdb_compress") {
    $::EMC::PDB{compress} = flag($string[0]); }
  elsif ($arg[0] eq "pdb_connect") {
    $::EMC::PDB{connect} = flag($string[0]); }
  elsif ($arg[0] eq "pdb_cut") {
    $::EMC::PDB{cut} = flag($string[0]); }
  elsif ($arg[0] eq "pdb_extend") {
    $::EMC::PDB{extend} = flag($string[0]); }
  elsif ($arg[0] eq "pdb_fixed") {
    $::EMC::PDB{fixed} = flag($string[0]); }
  elsif ($arg[0] eq "pdb_parameters") {
    $::EMC::PDB{parameters} = flag($string[0]); }
  elsif ($arg[0] eq "pdb_pbc") {
    $::EMC::PDB{pbc} = flag($string[0]); }
  elsif ($arg[0] eq "pdb_rank") {
    $::EMC::PDB{rank} = flag($string[0]); }
  elsif ($arg[0] eq "pdb_residue") {
    set_pdb_flag("residue", $string[0], $line); }
  elsif ($arg[0] eq "pdb_rigid") {
    $::EMC::PDB{rigid} = flag($string[0]); }
  elsif ($arg[0] eq "pdb_segment") {
    set_pdb_flag("segment", $string[0], $line); }
  elsif ($arg[0] eq "pdb_unwrap") {
    $::EMC::PDB{unwrap} = flag_unwrap($string[0]); }
  elsif ($arg[0] eq "pdb_vdw") {
    $::EMC::PDB{vdw} = flag($string[0]); }
  elsif ($arg[0] eq "percolate") {
    $::EMC::Flag{percolate} = flag($string[0]); }
  elsif ($arg[0] eq "phases") {
    my @phase;
    foreach (@string) {
      if ($_ eq "+") {
       	push(@::EMC::Phases, [@phase]) if (scalar(@phase)); @phase = ();
      }
      elsif (index($_, "\+")>=0) {
	my $first = 1;
	foreach (split("\\+")) {
	  next if ($_ eq "");
	  push(@phase, $_) if ($first);
	  push(@::EMC::Phases, [@phase]) if (scalar(@phase)); 
	  @phase = $first ? () : ($_); $first = 0;
	}
      }
      else {
       	push(@phase, $_) if ($_ ne "");
      }
    }
    push(@::EMC::Phases, [@phase]) if (scalar(@phase));
    if (scalar(@::EMC::Phases)==1 && scalar(@phase)==1 && @phase[0] eq "all") {
      @::EMC::Phases= ();
    }
    $::EMC::NPhases = scalar(@::EMC::Phases);
  }
  elsif ($arg[0] eq "polymer") {
    set_list_polymer($line, \%::EMC::PolymerFlag, @string);
  }
  elsif ($arg[0] eq "polymer_niters") {
    $::EMC::PolymerFlag{niterations} = @value[0]; }
  elsif ($arg[0] eq "port") { set_port($line, @string); }
  elsif ($arg[0] eq "precision") { $::EMC::Precision = $value[0]; }
  elsif ($arg[0] eq "prefix") { $::EMC::Lammps{prefix} = flag($string[0]); }
  elsif ($arg[0] eq "pressure") {
    $::EMC::Pressure{value} = $value[0] if ((
	$::EMC::Pressure{flag} = $string[0] ne "false"));
    my $ncouple = 0;
    my $ndir = scalar(split"[+]", $::EMC::Pressure{direction});
    my @s = @string; shift(@s); foreach (@s) {
      my @arg = split(":", @string[1]);
      @arg = split("=", @string[1]) if (scalar(@arg)==1);
      my @dir = sort(split("[+]", @arg[1]));
      my %d = (x => 0, y => 0, z => 0);
      foreach (@dir) {
	if (!defined($d{$_})) { error_line($line, "illegal direction '$_'\n"); }
	$d{$_} = 1;
      }
      @dir = (); foreach (sort(keys(%d))) { push(@dir, $_) if ($d{$_}); }
      if (@arg[0] eq "couple") {
	$::EMC::Pressure{couple} = "couple";
	$::EMC::Pressure{couple} .= ":".join("+", @dir) if (scalar(@dir));
	$ncouple = scalar(@dir) if (scalar(@dir));
      } elsif (@arg[0] eq "uncouple") {
	$::EMC::Pressure{couple} = "uncouple";
	$::EMC::Pressure{couple} .= ":".join("+", @dir) if (scalar(@dir));
	$ncouple = scalar(@dir) if (scalar(@dir));
      } elsif (@arg[0] eq "direction") {
	$::EMC::Pressure{direction} = join("+", @dir) if (scalar(@dir));
	$ndir = scalar(@dir) if (scalar(@dir));
      }
    }
    if ($ncouple>$ndir) {
      error_line($line, "coupling and direction inconsistency\n");
    }
  }
  elsif ($arg[0] eq "profile") { 
    set_list($line, \%::EMC::ProfileFlag, "boolean", "density", [], @string); }
  elsif ($arg[0] eq "project") { 
    $::EMC::Project{name} = basename($::EMC::Project{script} = @string[0]);
    $::EMC::Project{directory} = dirname(@string[0]);
    $::EMC::Project{directory} = "" if ($::EMC::Project{directory} eq $::EMC::Project{name});
    $::EMC::Project{directory} = "" if ($::EMC::Project{directory} eq ".");
    $::EMC::Project{directory} .= "/" if (length($::EMC::Project{directory}));
  }

  # Q

  elsif ($arg[0] eq "queue") {
    set_list($line, \%::EMC::Queue, "string", "", [], @string); }
  elsif ($arg[0] eq "queue_account") { $::EMC::Queue{account} = $string[0]; }
  elsif ($arg[0] eq "queue_analyze") { $::EMC::Queue{analyze} = $string[0]; }
  elsif ($arg[0] eq "queue_build") { $::EMC::Queue{build} = $string[0]; }
  elsif ($arg[0] eq "queue_memory") { $::EMC::Queue{memory} = $value[0]; }
  elsif ($arg[0] eq "queue_ncores") { $::EMC::Queue{ncores} = @value[0]; }
  elsif ($arg[0] eq "queue_ppn") { $::EMC::Queue{ppn} = $value[0]; }
  elsif ($arg[0] eq "queue_run") { $::EMC::Queue{run} = $string[0]; }
  elsif ($arg[0] eq "queue_user") { $::EMC::Queue{user} = join(" ", @string); }
  elsif ($arg[0] eq "quiet") { $::EMC::Flag{info} = $::EMC::Flag{debug} = $::EMC::Flag{warn} = 0; }

  # R

  elsif ($arg[0] eq "radius") { $::EMC::Build{radius} = $value[0]; }
  elsif ($arg[0] eq "record") {
    $::EMC::Record{flag} = 1;
    my $n = 0; foreach (@string) { ++$n if (scalar(split("="))==1); }
    if ($n) {
      if (scalar(@string)!=$n) {
	error_line($line, "record is missing identifiers\n");
      }
      if ($n!=3) {
	error_line($line,
	  "record needs exactly 3 entries when omitting identifiers\n");
      }
    }
    if ($n==3) {
      if (!length($string[0])) {
	error_line($line, "record name cannot be empty\n"); }
      if (!$value[1]) {
	error_line($line, "record frequency has to be larger than 1\n"); }
      $::EMC::Record{name} = @string[0];
      $::EMC::Record{frequency} = @value[1];
      $::EMC::Record{inactive} = boolean(flag($string[2]));
    } else {
      set_list($line, \%::EMC::Record, "string", "", [], @string);
      foreach (keys(%::EMC::Record)) {
	if ($_ eq "frequency") { 
	  $::EMC::Record{$_} = eval($::EMC::Record{$_});
	} elsif ($_ eq "unwrap") {
	  $::EMC::Record{$_} = flag_unwrap($::EMC::Record{$_});
	} elsif ($_ ne "name") {
	  $::EMC::Record{$_} = boolean(flag($::EMC::Record{$_}));
	}
      }
    }
  }
  elsif ($arg[0] eq "references") { $::EMC::Reference{name} = $string[0]; }
  elsif ($arg[0] eq "region_epsilon") {
    $::EMC::Region{epsilon} = $value[0]>0.0 ? $value[0] : $string[0] if ($value[0]>=0.0); }
  elsif ($arg[0] eq "region_sigma") {
    $::EMC::Region{sigma} = $value[0]>0.0 ? $value[0] : $string[0] if ($value[0]>=0.0); }
  elsif ($arg[0] eq "replace") { $::EMC::Replace{flag} = flag($string[0]); }
  elsif ($arg[0] eq "restart") { 
    $::EMC::Lammps{restart} = flag($string[0]);
    $::EMC::Lammps{restart_dir} = $string[1] if ($string[1] ne ""); }
  elsif ($arg[0] eq "rlength") { $::EMC::Reference{length} = $value[0]; }
  elsif ($arg[0] eq "rmass") { $::EMC::Reference{mass} = $value[0]; }
  elsif ($arg[0] eq "rtype") { $::EMC::Reference{type} = $string[0]; }

  # S

  elsif ($arg[0] eq "sample") { 
    set_list($line, \%::EMC::Sample, "string", "", [], @string);
    my %average = (msd => 1);
    my %allowed = (false => 0, true => 1, average => 2);
    foreach (sort(keys(%::EMC::Sample))) {
      my $s = $::EMC::Sample{$_};
      my $v = defined($allowed{$s}) ? $allowed{$s} : -1;
      $v = $s ne "" ? ($s !~ /\D/ ? int(eval($s)) : -1) : 1 if ($v<0);
      $v = -1 if (defined($average{$_}) ? $v>2 : $v>1);
      error_line($line, "unallowed option '$s' for keyword '$_'\n") if ($v<0);
      $::EMC::Sample{$_} = $v;
    }
  }
  elsif ($arg[0] eq "script") { $::EMC::Script{name} = $string[0]; }
  elsif ($arg[0] eq "seed") { $::EMC::Seed = $arg[1]; }
  elsif ($arg[0] eq "shake") {
    foreach (@string) {
      my @arg = split("=");
      my $n = scalar(@arg);
      my $type = $n<2 ? "active" : shift(@arg);
      my %allowed = (
	t => "t", type => "t", b => "b", bond => "b", a => "a", angle => "a",
	m => "m", mass => "m", active => "f"
      );
      my %name = (
	t => "type", b => "bond", a => "angle", m => "mass", f => "active");
      my %ntypes = (
	type => 1, bond => 2, angle => 3, mass => 1, active => 1);

      if (!defined($allowed{$type})) {
	error_line($line, "unallowed shake mode '$type'\n"); }
      @arg = split(":", @arg[0]);
      $type = $name{$allowed{$type}};
      if (scalar(@arg)!=$ntypes{$type}) {
	error_line($line, "incorrect number of types for shake mode '$type'\n");
      }
      if ($type eq "active") {
	$::EMC::Shake{flag} = flag($string[0]); 
      } else {
	if (!defined($::EMC::Shake{$type})) { $::EMC::Shake{$type} = []; }
	@arg = reverse(@arg) if (@arg[-1] lt @arg[0]);
	foreach (@arg) { $_ = strtype($_) if ($type ne "mass"); };
	push(@{$::EMC::Shake{$type}}, [@arg]);
	$::EMC::Shake{flag} = 0;
      }
    }
  }
  elsif ($arg[0] eq "shake_iterations") { $::EMC::Shake{iterations} = $value[0]; }
  elsif ($arg[0] eq "shake_output") { $::EMC::Shake{output} = $string[0] eq "never" ? 0 : $value[0]; }
  elsif ($arg[0] eq "shake_tolerance") { $::EMC::Shake{tolerance} = $value[0]; }
  elsif ($arg[0] eq "shape") { $::EMC::Shape = $value[0]; }
  elsif ($arg[0] eq "shear") {
    $::EMC::Shear{rate} = @value[0]; $::EMC::Shear{flag} = flag($string[0]); 
    $::EMC::Shear{mode} = $string[1] if ($string[1] ne ""); 
    $::EMC::Shear{ramp} = @value[2] if ($string[2] ne ""); }
  elsif ($arg[0] eq "skin") { $::EMC::Lammps{skin} = $value[0]; }
  elsif ($arg[0] eq "split") { set_list_split($line, @string); }
  elsif ($arg[0] eq "suffix") { $::EMC::EMC{suffix} = $string[0]; }
  elsif ($arg[0] eq "system") { 
    set_list($line, \%::EMC::System, "boolean", "", ["id"], @string); }
  elsif ($arg[0] eq "system_charge") { $::EMC::System{charge} = flag($string[0]); }
  elsif ($arg[0] eq "system_geometry") { $::EMC::System{geometry} = flag($string[0]); }
  elsif ($arg[0] eq "system_id") { $::EMC::System{id} = $string[0]; }
  elsif ($arg[0] eq "system_map") { $::EMC::System{map} = flag($string[0]); }
  elsif ($arg[0] eq "system_pbc") { $::EMC::System{pbc} = flag($string[0]); }

  # T

  elsif ($arg[0] eq "temperature") { $::EMC::Temperature = $value[0]; }
  elsif ($arg[0] eq "tequil") { $::EMC::Lammps{tequil} = $value[0]; }
  elsif ($arg[0] eq "tfreq") { $::EMC::Lammps{tfreq} = $value[0]; }
  elsif ($arg[0] eq "thermo_multi") { $::EMC::Lammps{multi} = flag($string[0]); }
  elsif ($arg[0] eq "tighten") { 
    if ($string[0] eq "false" || $string[0] eq "-") {
      $::EMC::Tighten = "";
    } else {
      $::EMC::Tighten = $value[0]<0 ? "" : $value[0];
    }
  }
  elsif ($arg[0] eq "time_analyze") { $::EMC::RunTime{analyze} = $string[0]; }
  elsif ($arg[0] eq "time_build") { $::EMC::RunTime{build} = $string[0]; }
  elsif ($arg[0] eq "time_run") { $::EMC::RunTime{run} = $string[0]; }
  elsif ($arg[0] eq "timestep") { $::EMC::Timestep = $value[0]; }
  elsif ($arg[0] eq "triclinic") { $::EMC::Flag{triclinic} = flag($string[0]); }
  elsif ($arg[0] eq "trun") { 
    if (($::EMC::Lammps{trun_flag} = $string[0] eq "-" ? 0 : 1)) {
      my @s = @string; shift(@s);
      $::EMC::Lammps{trun} = 
	$n==1 ? $value[0] : "\"".join(" ", $value[0], @s)."\"";
    } 
  }

  # V

  elsif ($arg[0] eq "version") { $::EMC::Flag{version} = flag($string[0]); }

  # U

  elsif ($arg[0] eq "units") {
    my %allow = (lj => 1, real => 1, si => 1, reduced => 1);
    if (!defined($allow{$string[0]})) {
      error_line($line, "unallowed units option '$string[0]'\n"); }
    $string[0] = "reduced" if ($string[0] eq "lj");
    $::EMC::Units{type} = $string[0];
  }
  elsif ($arg[0] eq "units_energy") {
    if ($value[0]<=0) {
      error_line($line, "energy units <= 0\n"); }
    $::EMC::Units{energy} = $value[0];
  }
  elsif ($arg[0] eq "units_length") {
    if ($value[0]<=0) {
      error_line($line, "length unit <= 0\n"); }
    $::EMC::Units{length} = $value[0];
  }

  # V

  elsif ($arg[0] eq "volume") { 
    if (($::EMC::Flag{volume} = flag($string[0]))) {
      $::EMC::Flag{mol} = $::EMC::Flag{mass} = 0; } }

  # W

  elsif ($arg[0] eq "warn") { $::EMC::Flag{warn} = flag($string[0]); }
  elsif ($arg[0] eq "weight") { 
    set_list($line, $::EMC::Build{weight}, "real", "", [], @string); }
  elsif ($arg[0] eq "width") { $::EMC::Flag{width} = flag($string[0]); }
  elsif ($arg[0] eq "workdir") { $::EMC::WorkDir = $string[0]; }
  else { return 1; }
  
  return 0;
}


sub initialize {
  my $name = "";
  my @phase = ();
  my @warning = ();
  my $chemistry;
  my $ext = $::EMC::Script{extension};

  @::EMC::Focus = ();
  @::EMC::Phases = ();
  set_commands();
  $Reset::EMC::Flags = 1;
  if (! -e $::EMC::Script{name}.$ext) {
    help() if (!scalar(@ARGV));
    foreach (@ARGV) {
      my @a = split("=");
      $ext = @a[1] if (@a[0] eq "-extension");
      next if (substr($_,0,1) eq "-");
      $::EMC::Script{name} = my_strip($_, $ext); last;
    }
  }

  foreach (@ARGV) {
    if (substr($_,0,1) eq "-") { 
      help() if (options(-1, \@warning, $_));
      my @a = split("=");
      $chemistry = $::EMC::Script{name} if (@a[0] eq "-chemistry");
    }
    elsif ($name eq "") { 
      my @a = split("\\.", basename($_)); 
      $ext = ".@a[-1]" if (scalar(@a)>1);
      $chemistry = my_strip($_, $ext); 
      $name = basename($_, $ext);
    }
    elsif ($_ eq "+") { push(@::EMC::Phases, [@phase]); @phase = (); }
    else { push(@phase, $_); }
  }
  $::EMC::Project{script} = $::EMC::Project{name} = $name;
  $::EMC::Script{extension} = $ext;

  version() if ($::EMC::Flag{version});
  push(@::EMC::Focus, "-") if (!scalar(@::EMC::Focus));
  foreach (sort(keys(%::EMC::OptionsFlag))) {
    options_export($_) if ($::EMC::OptionsFlag{$_});
  }
  push(@::EMC::Phases, \@phase) if (scalar(@phase));
  header() if ($::EMC::Flag{info});
  foreach ($ext, ".csv") {
    $ext = $_;
    $::EMC::Script{name} = $chemistry if (-e $chemistry.$ext);
    $::EMC::Script{name} = my_strip($::EMC::Script{name}, $ext);
    last if (-e $::EMC::Script{name}.$ext);
  }
  read_script(
    $::EMC::Script{name}, [$ext, $::EMC::Script{suffix}.$ext], \@warning);

  foreach (@ARGV) {
    options(-1, \@warning, $_) if (substr($_,0,1) eq "-");
  }
  
  # info("elements = {".join(", ", sort(keys(%::EMC::Elements)))."}\n");
  
  return if ($::EMC::Flag{environment});
  set_variables();
  error("no project name was set.\n") if ($::EMC::Project{name} eq "");
  if ($::EMC::ProfileFlag{pressure} && !$::EMC::Lammps{chunk}) {
    error("pressure profiles currently only supported with LAMMPS chunks.\n");
  }
  info("project = %s\n", $::EMC::Project{name});
  info("ntotal = %s\n", $::EMC::NTotal) if (!$::EMC::Flag{number});
  info("direction = %s\n", $::EMC::Direction{x});
  info("shape = %s\n", $::EMC::Shape);
  $ext = $::EMC::Script{extension};
  $::EMC::Reference{name} = (split(".csv", $::EMC::Reference{name}))[0];
  read_references(
    $::EMC::Reference{name}, [".csv", $::EMC::Reference{suffix}.$ext]);
  $::EMC::Parameters{name} = (split(".csv", $::EMC::Parameters{name}))[0];
  read_parameters(
    $::EMC::Parameters{name}, [".csv", $::EMC::Parameters{suffix}.$ext]);
  set_densities();
  set_fields();
  update_fields() if (!%::EMC::Fields);
  update_fields("list");

  info("force field type = \"%s\"\n", $::EMC::Field{type});
  output_fields("name");
  output_fields("location");
  
  info("build for LAMMPS script in \"%s\"\n", $::EMC::Build{dir});
  
  foreach (@warning) { warning("$_\n"); }
}	


# general routines

sub flag_unwrap {
  my %allowed = (clusters => 1, sites => 1);
  return @_[0] if (defined($allowed{@_[0]}));
  my @flag = ("none", "clusters", "sites");
  my $value = flag(@_[0]);
  return @flag[$value<0 ? 0 : $value>2 ? 2 : $value];
}


sub version {
  print("EMC Setup v$::EMC::Version, $::EMC::Date\n");
  print("Copyright (c) $::EMC::Copyright Pieter J. in 't Veld\n");
  exit();
}

sub header {
  print("EMC Setup v$::EMC::Version ($::EMC::Date), ");
  print("(c) $::EMC::Copyright Pieter J. in 't Veld\n\n");
}


sub help {
  my $n;
  my $key;
  my $format;
  my $columns;
  my $offset = 3;

  header();
  set_variables();
  set_commands();
  $columns = $::EMC::Columns-3;
  foreach (keys %::EMC::Commands) {
    $n = length($_) if (length($_)>$n); }
  $format = "%-$n.".$n."s";
  $offset += $n;

  print("Usage:\n  $::EMC::Script ");
  print("[-command[=#[,..]]] project [phase 1 clusters [+ ...]]\n\n");
  print("Commands:\n");
  foreach $key (sort(keys %::EMC::Commands)) {
    printf("  -$format", $key);
    $n = $offset;
    foreach (split(" ", ${$::EMC::Commands{$key}}{comment})) {
      if (($n += length($_)+1)>$columns) {
	printf("\n   $format", ""); $n = $offset+length($_)+1; }
      print(" $_");
    }
    if (${$::EMC::Commands{$key}}{default} ne "") {
      foreach (split(" ", "[${$::EMC::Commands{$key}}{default}]")) {
	if (($n += length($_)+1)>$columns) {
	  printf("\n   $format", ""); $n = $offset+length($_)+1; }
	print(" $_");
      }
    }
    print("\n");
  }

  printf("\nNotes:\n");
  $offset = $n = 3;
  $format = "%$n.".$n."s";
  foreach (@::EMC::Notes) { 
    $n = $offset;
    printf($format, "*");
    foreach (split(" ")) {
      if (($n += length($_)+1)>$columns) {
	printf("\n$format", ""); $n = $offset+length($_)+1; }
      print(" $_");
    }
    print("\n");
  }
  printf("\n");
  exit(-1);
}


sub options_export {
  my $language = shift(@_);

  return if (!$::EMC::OptionsFlag{$language});
  set_variables();
  set_commands();
  if ($::EMC::OptionsFlag{perl}) {
    my $comma = 0;

    print("(\n");
    foreach(sort(keys(%::EMC::Commands))) {
      next if (substr($_, 0, 7) eq "options");
      print(",\n") if ($comma);
      my $ptr = $::EMC::Commands{$_};
      my @arg = (${$ptr}{comment}, ${$ptr}{default}, @{${$ptr}{gui}});
      foreach (@arg) { $_ =~ s/\"/\\\"/g; $_ =~ s/\$/\\\$/g; $_ = "\"$_\""; }
      print("  $_ => [", join(", ", @arg), "]");
      $comma = 1;
    }
    print("\n)\n");
    exit(0);
  } elsif ($::EMC::OptionsFlag{tcl}) {
    print("{\n");
    foreach(sort(keys(%::EMC::Commands))) {
      next if (substr($_, 0, 7) eq "options");
      my $ptr = $::EMC::Commands{$_};
      my @arg = (${$ptr}{comment}, ${$ptr}{default}, @{${$ptr}{gui}});
      foreach (@arg) { $_ =~ s/\"/\\\"/g; $_ =~ s/\$/\\\$/g; $_ = "\"$_\""; }
      print("  $_ {", join(" ", @arg), "}\n");
    }
    print("}\n");
    exit(0);
  }
  print("Export of options to $language is currently not supported\n\n");
  exit(-1);
}


sub text_line {
  my $line = shift(@_);
  my $input = $::EMC::Flag{source} ne "" ? $::EMC::Flag{source} : "input";

  if ($line<0) { return (@_); }
  else { 
    my $format = shift(@_);
    $format =~ s/\n/ in line $line of $input\n/g;
    if (scalar(@_)) { return ($format, @_); }
    else { return ($format); }
  }
}


sub info {
  printf("Info: ".shift(@_), @_) if ($::EMC::Flag{info});
}


sub debug {
  printf("Debug: ".shift(@_), @_) if ($::EMC::Flag{debug});
}


sub tdebug {
  print(join("\t", "Debug:", @_), "\n") if ($::EMC::Flag{debug});
}


sub warning {
  printf("Warning: ".shift(@_), @_) if ($::EMC::Flag{warn});
}


sub message {
  printf("Message: ".shift(@_), @_) if ($::EMC::Flag{info});
}


sub error {
  printf("Error: ".shift(@_), @_);
  printf("\n");
  exit(-1);
}


sub expert {
  if ($::EMC::Flag{expert}) { warning(@_); }
  else { error(@_); }
}


sub error_line {
  error(text_line(@_));
}


sub expert_line {
  expert(text_line(@_));
}


sub tprint {
  print(join("\t", @_), "\n");
}


sub my_warn {
  my ( $file, $line ) = ( caller )[1,2];
  $file = scalar reverse(reverse($file) =~ m{^(.*?)[\\/]});
  warn ("$file:$line ", @_);
}


sub my_strip {
  my $sep = $::EMC::OSType eq "MSWin32" ? "\\" : "/";
  return dirname(@_).$sep.basename(@_);
}


# i/o routines

sub fexpand {
  return @_[0] if (substr(@_[0],0,1) ne "~");
  return $ENV{HOME}.substr(@_[0],1) if (substr(@_[0],1,1) eq "/");
  return $ENV{HOME}."/../".substr(@_[0],1);
}


sub fexist {
  my $name = fexpand(shift(@_));

  return 1 if (-f $name);
  foreach (@_) { return 1 if (-f $name.$_); }
  return 0;
}


sub flocate {
  my $name = shift(@_);
  my @ext = ("", shift(@_));

  foreach ("", @_) {
    my $root = ($_ eq "" ? "" : $_."/").$name;
    foreach (@ext) {
      my $file = $root.$_;
      return $file if (-f fexpand($file));
    }
  }
  return "";
}


sub ffind {
  my $dir = shift(@_);
  my $pattern = shift(@_);
  my @dirs;
  my @files;

  find( sub{ -d $_ and push @dirs, $File::Find::name; }, $dir );
  foreach (@dirs) {
    my @glob = sort(glob($_."/".$pattern));
    push(@files, @glob) if (scalar(@glob));
  }
  return @files;
}


sub fopen {
  my $name = fexpand(shift(@_));
  my $mode = shift(@_);
  my @ext = @_;
  my $stream;
  
  if ($mode eq "r") {
    open($stream, "<$name");
    if (!scalar(stat($stream))) {
      foreach (@ext) {
	next if (! -f $name.$_);
	open($stream, "<".($name .= $_));
	last;
      }
    }
  } elsif ($mode eq "w") {
    open($stream, ">$name");
  } elsif ($mode eq "a") {
    open($stream, ">>$name");
  } else {
    error("unsupported mode \"$mode\"\n");
  }
  if (!scalar(stat($stream))) {
    error("cannot open \"$name\"\n");
  }
  return scalar(@ext) ? ($stream, $name) : $stream;
}


sub check_exist {
  my $type = shift(@_);
  my $name = fexpand(shift(@_));

  if (!$::EMC::Replace{flag} && -e $name) {
    warning("\"$name\" exists; use -replace flag to overwrite\n");
  } elsif (!defined($::EMC::CheckExist{$type})) {
    ${$::EMC::CheckExist{$type}}{$name} = 1; return 0;
  } elsif (!defined(${$::EMC::CheckExist{$type}}{$name})) {
    ${$::EMC::CheckExist{$type}}{$name} = 1; return 0;
  }
  return 1;
}


sub split_data {
  my @arg = split("\t", @_[0]);
  my @result = split(",", @arg[0]);

  @result = scalar(split(":", @result[0]))>1 ? (shift(@arg)) : ();
  foreach(@arg) { 
    foreach (split(",", $_)) { 
      push(@result, $_);
    }
  }
  @result = split(" ", @_[0]) if (scalar(@result)==1);
  foreach (@result) { 
    $_ = trim($_);
  }
  @arg = split(" ", @result[0]);
  if (scalar(@arg)>1) {
    shift(@result);
    unshift(@result, @arg);
  }
  push (@result, ",") if (substr(@_[0],-1,1) eq ",");
  @arg = (); 
  foreach (@result) {
    last if (substr($_,0,1) eq "#");
    push(@arg, $_) if ($_ ne "");
  }
  return @arg;
}


sub get_data {
  my $stream = shift(@_);
  my $data = shift(@_);
  my $comment = shift(@_) ? 0 : 1;
  my $ncomment = 0;
  my $line = 0;
  my $verbatim;
  my @last;
  my @a;
  my $i;

  @{$data} = ();
  foreach(<$stream>) {
    chop();
    my @arg = split("\r");
    ++$line if (!scalar(@arg));
    foreach(@arg) {
      ++$line;

      # commenting with /* */

      my $h = $_;
      my $fh = 0;
      my $lcomment = $ncomment;
      while (($i = rindex($h, "/*"))>=0) {
	$h = substr($h, 0, $i); ++$ncomment; $fh = 1;
      }

      my $t = $_;
      my $ft = 0;
      while (($i = index($t, "*/"))>=0) {
	$t = substr($t, $i+2); --$ncomment; $ft = 1;
      };
      error_line($line, "unmatched comment delimitor\n") if ($ncomment<0);
      
      if ($fh || $ft) {
	if ($lcomment) { $_ = ""; }
	elsif ($fh) { $_ = $h; }
	$_ .= $t if ($ft);
      }
      if ($comment) {
	next if (($_ = trim($_)) eq "");
	next if (substr($_,0,1) eq "#");
      }
      next if ($lcomment==$ncomment ? $ncomment : 0);

      # record

      $verbatim .= (length($verbatim) ? "\n" : "").$_;
      if (!$comment && substr(trim($_),0,1) eq "#") {
	@a = ($_);
      } else {
	@a = split_data($_); next if (!scalar(@a));
      }
      if (substr(@a[-1],-1) eq "&" || substr(@a[-1],-1) eq "\\") {
	if (scalar(@a[-1])==1) {
	  pop(@a);
       	}
	else { 
	  @a[-1] = substr(@a[-1],0,length(@a[-1])-1);
       	}
	@a[-1] = trim(@a[-1]);
	push(@last, @a); next;
      }
      push(@{$data}, [join("\t", $line, @last, @a), $verbatim]); @last = ();
      $verbatim = "";
    }
  }
  $::EMC::Flag{comment} = $ncomment;
  return $data;
}


sub format_newline {
  my $output = shift(@_);
  my $col = shift(@_);
  my $offset = shift(@_);
  my $index = shift(@_);
  my $ntabs = int($offset/8);
  my $i;

  ${$output} .= "\n" if ($index);
  for ($i=0; $i<$ntabs; ++$i) { ${$output} .= "\t"; }
  for ($i=0; $i<$offset-8*$ntabs; ++$i) { ${$output} .= " "; } 
  ${$col} = $offset;
}


sub format_output_new {
  my $separator = shift(@_);
  my $string = trim(shift(@_));
  return $separator ? "\n" : "" if ($string eq "");
  my $offset = shift(@_);
  my $tab = shift(@_);
  my @arg = split(" ", $string);
  my $output = "";
  my $newline = 1;
  my $index = 0;
  my $ivar = 0;
  my $col = 0;
  my $nvars;
  my $i;

  format_newline(\$output, \$col, $offset, 0);
  return $output .= $string if (substr($string,0,2) eq "(*");

  $string = shift(@arg);
  $string .= " -> ".join(" ", @arg) if (scalar(@arg));
  $string =~ s/ //g;
  $nvars = scalar(@arg = split("->", $string));
  foreach (@arg) {
    my @arg = split(",");
    my $last = $index+scalar(@arg);
    my $var = ++$ivar<$nvars ? pop(@arg) : "";
   
    foreach (@arg) {
      my $v = $index+1<$last ? "$_, " : $_;
      my $l = length($_);
      my $n = () = $_ =~ m/\{/g; 
      $offset += 2*$n;
      format_newline(\$output, \$col, $offset, $index ? 1 : 0) if ($col+$l>78);
      $n -= () = $_ =~ m/\}/g;
      $offset += 2*$n;
      $output .= $v;
      $col += $l;
      ++$index;
    }
    if ($ivar<$nvars) {
      my $l = length($var);
      if ($col+$l+4>78) {
	format_newline(\$output, \$col, $offset, $index ? 1 : 0);
	$newline = 1;
      }
      if ($newline) {
	my $v = $var;
	my $n = $tab-int(($col+$l)/8);
	if ($n>0) {
	  for ($i = 0; $i<$n; ++$i) {
	    $v .= "\t"; $col += 8;
	  };
	} else {
	  $v .= " "; $col += 1;
	}
	$output .= $v."-> ";
	$col += $l+3;
      } else {
	$output .= $var." -> ";
	$col += $l+4;
      }
      $newline = 0;
    }
  }
  return $output.($separator ? ",\n" : "");
}


sub format_output {
  my $separator = shift(@_);
  my $string = shift(@_);
  return $separator ? "\n" : "" if ($string eq "");
  my $offset = shift(@_);
  my $tab = shift(@_);
  my @arg = split(" ", $string);
  my $first = shift(@arg);
  my $rest = join(" ", @arg);
  my $output = "";
  my $i;
  my $n;

  $n = int($offset/8);
  for ($i = 0; $i<$n; ++$i) {
    $output .= "\t";
  };
  $tab = 0 if (($tab -= $n)<0);
  $offset -= 8*$n;
  for ($i = 0; $i<$offset; ++$i) {
    $output .= " ";
  };
  return "$output$string\n" if (substr($string,0,2) eq "(*");
  $output .= $first;
  return "$output".($separator ? ",\n" : "") if ($rest eq "");
  if (($n = $tab-int(length($output)/8))>0) {
    for ($i = 0; $i<$n; ++$i) {
      $output .= "\t";
    };
  } else {
    $output .= " ";
  }
  return "$output-> $rest".($separator ? ",\n" : "");
}


# SMILES routines

sub strip {
  my $src=shift(@_);
  my $dest="";
  my $i;

  for ($i=0; $i<length($src); ++$i) {
    my $c = substr($src,$i,1);
    next if (($c eq "-")||($c eq "+")||(($c ge "0")&&($c le "9")));
    $dest .= $c;
  }
  return $dest;
}


sub subchunk {
  my $chemistry = shift(@_);
  my $i = shift(@_);
  my $l = 0;

  for (; $i<length($chemistry); ++$i) {
    my $c = substr($chemistry,$i,1);

    if ($c eq '(') { ++$l; }
    elsif ($c eq ')') { --$l; }
    return $i if (!$l);
  }
  error("parenthesis error in '$chemistry'.\n");
}


sub count_clusters {
  my $chemistry = shift(@_);
  my $n = 1;
  my $l = 0;
  my $i;

  for ($i=0; $i<length($chemistry); ++$i) {
    my $c = substr($chemistry,$i,1);
    ++$n if (($c eq '.') && ($l == 0));
    if ($c eq '(') {
      my $in = subchunk($chemistry, $i++);
      my $nn = count_clusters(substr($chemistry,$i,$in-$i));
      $i = $in+1;
      my $a;
      for (; $i<length($chemistry); ++$i) {
	my $c = substr($chemistry,$i,1);
	last if ($c lt "0" || $c gt "9");
       	$a .= $c;
      }
      --$i; $n += ($a eq "" ? $nn : $a*$nn) if (--$nn);
    }
    elsif ($c eq ')') {
    }
    elsif ($c eq '[') {
      ++$l;
    }
    elsif ($c eq ']') {
      --$l;
    }
  }
  return $n;
}


# Chemistry support

sub list_unique {
  my $line = shift(@_);
  my %check = ();
  my @list;

  foreach (@_) {
    if (defined($check{$_})) {
      if ($line>0) {
	warning("omitting reoccurring entry '$_' in line $line of input.\n");
      }
      next;
    }
    push(@list, $_);
    $check{$_} = 1;
  }
  return @list;
}


sub list_index {
  my $i = 0;
  my $target = shift(@_);
  foreach (@_) {
    return $i if ($_ eq $target);
    ++$i;
  }
  return -1;
}


sub cluster_flag {
  my $line = shift(@_);
  my $name = shift(@_);
  my $mass = shift(@_);
  my $volume = shift(@_);

  if ($::EMC::ClusterFlag{first}) {
    $::EMC::ClusterFlag{mass} = $mass ne "" ? 1 : 0;
    $::EMC::ClusterFlag{volume} = $volume ne "" ? 1 : 0;
    $::EMC::ClusterFlag{first} = 0;
  } else {
    if (($mass ne "" ? 1 : 0)^$::EMC::ClusterFlag{mass}) {
      error_line($line, "inconsistent mass entry for cluster '$name'\n");
    }
    if (($volume ne "" ? 1 : 0)^$::EMC::ClusterFlag{volume}) {
      error_line($line, "inconsistent volume entry for cluster '$name'\n");
    }
  }
}


sub allow_list {
  my $hash = shift(@_);
  my @keys = keys(%{$hash});
  my %list;

  foreach (@keys) {
    $list{$_} = 1 if ($_ ne "flag");
  }
  return %list;
}


sub convert_name {
  my $string = shift(@_);

  $string =~ s/:/_/g;
  return $string;
}


sub eval_parms {
  foreach (@_) { $_ = eval($_); }
  return @_;
}


sub field_id {
  my $line = shift(@_);
  my @field = @_;

  foreach (@field) {
    my $f = $_;
    my $error = 1;
    foreach (keys(%{$::EMC::FieldList{id}})) {
      if (index($::EMC::FieldList{id}->{$_}, $f)>=0) {
	$f = $::EMC::FieldList{id}->{$_};
	$error = 0;
      }
    }
    error_line($line, "unknown field reference '$f'\n") if ($error);
    $_ = $f;
  }
  return @field;
}


sub group_id {
  my $line = shift(@_);
  my $id = shift(@_);
  my $field = shift(@_);
  my $mass = shift(@_);
  my $terminator = shift(@_);
  my @tmp = split(":", $id);
  my $name = shift(@tmp);
  my %allowed = (f => 2, field => 2, m => 2, mass => 2, t => 1, term => 1);

  return $id if (!scalar(@tmp));
  if (!$::EMC::Flag{expert}) {			# Check errors
    foreach (@tmp) {
      my @a = split("=");
      if (!defined($allowed{@a[0]})) {
	error(
	  "unrecognized group modifier '@a[0]' in line $line of input\n");
      }
    }
  }
  @{$field} = ();				# Filter options
  foreach (@tmp) {
    my @a = split("=");
    if (@a[0] eq "f" || @a[0] eq "field") { @{$field} = split(",", @a[1]); }
    elsif (@a[0] eq "m" || @a[0] eq "mass") { ${$mass} = @a[1]; }
    elsif (@a[0] eq "t" || @a[0] eq "term") { ${$terminator} = 1; }
    else { $name .= ":@a[0]"; }
  }
  @{$field} = field_id($line, @{$field});
  return $name;
}


sub variable_replace {
  my $var = shift(@_);
  my %h = ();
  my ($r, $v, $b, $f, $l);

  return $var if (!($var =~ m/\@/));
  foreach (@{$::EMC::Variables{data}}) {
    my @v = @{$_};
    my $id = uc(shift(@v));
    $h{"\@{$id}"} = join(", ", @v);
  }
  foreach (split("", $var)) {
    if ($_ eq "@") {
      if ($v ne "") { 
	$v .= "}"; $r .= (defined($h{$v}) ? $h{$v} : $v);
      }
      $v = $_."{"; $f = 1; $b = 0;
    } elsif ($f) {
      if (($_ =~ /[a-zA-Z]/)||($_ =~ /[0-9]/)||($b && $_ ne "}")) {
	$v .= $_;
      } elsif ($_ eq "{" && $l eq "@") {
	$b = 1;
      } else {
	$v .= "}";
	$r .= (defined($h{$v}) ? $h{$v} : $v).($b && $_ eq "}" ? "" : $_);
	$v = ""; $f = $b = 0;
      }
    } else {
      $r .= $_;
    }
    $l = $_;
  }
  $v .= "}" if ($v ne "");
  $r .= (defined($h{$v}) ? $h{$v} : $v);
  return $r;
}


# read chemistry

sub read_script {
  my $name = shift(@_);
  my $suffix = shift(@_);
  my $warning = shift(@_);
  my @items = (
    {item => "END", env => 1, mode => 0},
    {item => "COMMENTS", env => 1, mode => 1},
    {item => "SHORTHAND", env => 1, mode => 2},
    {item => "GROUPS", env => 1, mode => 3},
    {item => "CLUSTERS", env => 1, mode => 4},
    {item => "POLYMERS", env => 1, mode => 5},
    {item => "EMC", env => 0, mode => 6},
    {item => "VERBATIM", env => 0, mode => 6},
    {item => "VARIABLES", env => 0, mode => 7},
    {item => "OPTIONS", env => 0, mode => 8},
    {item => "ENVIRONMENT", env => 0, mode => 8},
    {item => "REPLICAS", env => 0, mode => 9}, 
    {item => "EXTRA", env => 0, mode => 9},
    {item => "NONBONDS", env => 0, mode => 10},
    {item => "BONDS", env => 0, mode => 11}, 
    {item => "ANGLES", env => 0, mode => 12},
    {item => "TORSIONS", env => 0, mode => 13},
    {item => "IMPROPERS", env => 0, mode => 14},
    {item => "LOOPS", env => 0, mode => 15},
    {item => "STRUCTURES", env => 1, mode => 16},
    {item => "TEMPLATE", env => 1, mode => 17},
    {item => "CHEMISTRY", env => 1, mode => 17},		# legacy
    {item => "STAGE", env => 1, mode => 18},
    {item => "PHASE", env => 1, mode => 18},			# legacy
    {item => "TRIAL", env => 1, mode => 19},
    {item => "PROFILES", env => 0, mode => 20},
    {item => "FIELD", env => 1, mode => 21},
    {item => "PARAMETERS", env => 1, mode => 22},
    {item => "REFERENCES", env => 1, mode => 23},
    {item => "LAMMPS", env => 0, mode => 24},
    {item => "ANALYZE", env => 0, mode => 25},
    {item => "ANALYSIS", env => 0, mode => 25},
    {item => "MASSES", env => 0, mode => 26},
    {item => "INCLUDE", env => 0, mode => 27},
    {item => "WRITE", env => 0, mode => 28}
  );
  my %flag = (
    comment => 0, env => 0, field => 0, template => 0);
  my %loop_check = (
    stage => 1, trial => 1, copy => 1);
  my %types = (
    polymer => ["alternate", "block", "random"],
    import => ["import"],
    surface => ["surface"]);
  my $line_last = 0;
  my $line_mode = 0;
  my $loop_pair = "";
  my $nloop_pairing = -1;
  my $env_flag = 0;
  my $env_options = 0;
  my $env_stage = "generic";
  my $env_trial = "generic";
  my $loop_stage = "generic";
  my $polymer_name = "";
  my $flag_element = 0;
  my $level = 0;
  my $ipoly = 0;
  my $mode = 2;
  my $mode_last;
  my $index = 0;
  my $comma = 0;
  my @previous_variables = ();
  my @previous;
  my @current;
  my $command;
  my %replicas;
  my %polymer;
  my $stream;
  my @last;
  my @arg;
  my $i;
  my @io;

  return if (!($::EMC::EMC{write}||$::EMC::Lammps{write}) && !(-e $name));
  ($stream, $name) = fopen($name, "r", @{$suffix});
  info("%s\n", "reading script from \"$name\"");
  reset_global_variables();
  foreach (keys(%types)) {
    my $type = $_;
    $i = 0; foreach(@{$types{$type}}) { $flag{$type}{$_} = ++$i; }
  }
  push(@io, {name => $name, data => get_data($stream, [], 1)});
  close($stream);
  while (scalar(@io)) {
    
    while (scalar(@io)) {				# pick data
      last if (scalar(@{${@io[0]}{data}}));
      shift(@io);
    }
    last if (!scalar(@io));

    my $s = shift(@{${@io[0]}{data}});			# select line
    my @data = split("\t", @{$s}[0]);
    my $verbatim = @{$s}[1];
    my $line = shift(@data);
    my @arg;

    $::EMC::Flag{source} = ${@io[0]}{name};

    foreach(@data) {
      if (scalar(split("="))>1) { 
	push(@arg, $_);
      } else {
	push(@arg, $_ =~ /(".+"|\S+)/g);
      }
    }
    @previous = @current; @current = @arg;

    if (@arg[0] eq "ITEM") {				# interpret item
      $polymer_name = "";
      $mode_last = $mode; $mode = -1;
      for ($i=0; $i<scalar(@items); ++$i) {		# find command
	next if (${$items[$i]}{item} ne $arg[1]);
	$mode = ${$items[$i]}{mode};
	$flag{env} = ${$items[$i]}{env};
	$line_mode = $line;
	my %answer = set_options($line, [["comment", 0]], \@arg, 1, 0);
	$flag{comment} = 1 if ($answer{comment});
	last;
      }
      if (!($flag{comment} || $flag{field}) && $mode<0) {
       	error_line($line, "unknown item \'$arg[1]\'\n");
      }
      if ($mode==8 && @current[1] eq "ENVIRONMENT") {
	error_line($line, "cannot alter environment once set\n") if ($env_flag);
	$::EMC::Project{name} = $arg[2] if ($arg[2] ne "");
	$::EMC::Flag{environment} = 1;
	@current[1] = "OPTIONS";
      }
      if (!$flag{template}) {				# apply outside of
	if ($mode == 27) {				# template

	  # INCLUDE
	  
	  my $ext = $::EMC::Include{extension};
	  my $path = $::EMC::Location{include};
	  my $name = flocate(@current[2], $ext, @{$path});
	  error_line($line, "cannot find '@current[2]'\n") if ($name eq "");
	  info("including \"$name\"\n");
	  $stream = fopen($name, "r");
	  unshift(@io, {name => $name, data => get_data($stream, [], 1)});
	  close($stream);
	  $mode = 0;
	  next;

	} elsif ($mode == 28) {

	  # WRITE

	  message("%s\n", join(" ", @current[2 .. scalar(@current)-1]));
	  $mode = 0;
	  next;
	}
      }

      if (!$flag_element) {				# derive elements
	my %check = (
	  GROUPS => 1, SHORTHAND => 1, STRUCTURES => 1, REPLICAS => 1);
	$flag_element = defined($check{$current[1]}) ? 1 : 0;
      } elsif ($current[1] eq "END") {
	$flag_element = 0;
      }

      if (!$env_flag && !$level) {
       	if ($command eq "field") {
	  my $name = $::EMC::Project{name};
	  my $pwd = cwd();
	  if ($::EMC::Flag{environment}) {
	    chdir("chemistry");
	    mkpath($command) if (! -e $command);
	    $name = "$command/$name";
	    info("creating chemistry \"$name\"\n");
	  } else {
	    info("creating field parameter file \"$name\"\n");
	  }
	  $::EMC::Flag{rules} = EMCField::main(
	      "-quiet", "-input", $::EMC::Verbatim{field}, $name);
	  $::EMC::Field{write} = 0;
	  chdir($pwd);
	} elsif ($command eq "parameters") {
	} elsif ($command eq "references") {
	}
      }
      
      $command = lc($arg[1]) if (!$level);
      $env_flag = 0 if ($command eq "stage" || $command eq "trial");

      if ($env_flag) {					# environment mode

	if (!($flag{env}||$flag{template}||$flag{comment})) {
	  error("'$command' section not allowed in environment mode\n");
	}
	if (!$level && $mode!=1) {
	  @{$::EMC::Verbatim{$command}} = ();
	  $env_trial = @arg[2] if (@arg[2] ne "");
	}
	next if ($mode == 18 || $mode == 19);
	if (!($level += $mode ? 1 : -1) &&		# write trials etc.
	  $mode==0 && defined($::EMC::Verbatim{$command})) {

	  my $pwd = cwd();
	 
	  mkdir("chemistry") if (!-e "chemistry");
	  chdir("chemistry");
	  $line_last = 0;
	 
	  if ($command eq "template") {			# write template
	 
	    my $dir = "stages/$::EMC::Project{directory}$::EMC::Project{name}";
	    mkpath($dir) if (! -e $dir);
	    my $name = "$dir/$env_stage".$::EMC::Script{extension};
	    if (!check_exist($command, $name)) {
	      write_job_stage($command, $name);
	    }
	  
	  } elsif ($command eq "structures") {		# write structures
	  
	    my $nstructures = 0;
	    foreach (@{$::EMC::Verbatim{structures}}) {
	      ++$nstructures if (substr(@{$_}[0],0,1) ne "#");
	    }
	    if (scalar(@{$::EMC::Trials{$env_stage}})>$nstructures) {
	      error(
		"missing structures before line $line of input\n");
	    }
	    my %trials; 
	    foreach (@{$::EMC::Trials{$env_stage}}) { $trials{$_} = 1; }
	    my $nargs = 1;
	    foreach (@{$::EMC::Verbatim{structures}}) {
	      my $n = scalar(split_data(@{$_}[0]));
	      $nargs = 2 if ($n>$nargs);
	    }
	    my $i = 0;
	    mkdir($command) if (! -e $command);
	    mkdir("$command/$env_stage") if (! -e "$command/$env_stage");
	    foreach (@{$::EMC::Verbatim{structures}}) {
	      my $verbatim = @{$_}[0];
	      my $line = @{$_}[1];
	      next if (substr($verbatim,0,1) eq "#");
	      my @arg = split_data($verbatim);
	      my $structure;
	      if (scalar(@arg)<$nargs) {
		error(
		  "mixed formats in structure section ".
		  "in line $line of input\n");
	      }
	      my $name = "$command/$env_stage/";
	      if ($nargs<2) {
		$name .= @{$::EMC::Loop{trial}}[$i++].".dat";
		$structure = @arg[0];
	      } elsif (!defined($trials{@arg[0]})) {
		warning(
		  "no trial for '@arg[0]' in line $line of input\n");
		next;
	      } else {
		$name .= @arg[0].".dat";
		$structure = @arg[1];
	      }
	      next if (check_exist($command, $name));
	      info("creating chemistry \"$name\"\n");
	      my $stream = fopen($name, "w");
	      printf($stream "%s\n", $structure);
	      close($stream);
	    }

	  } elsif ($command eq "field") {		# write field
	    
	    mkpath("$command/$env_stage") if (! -e "$command/$env_stage");
	    my $name = "$command/$env_stage/$::EMC::Project{name}";
	    info("creating chemistry \"$name\"\n");
	    EMCField::main(
	      "-quiet", "-input", $::EMC::Verbatim{field}, $name);
	    $::EMC::Field{write} = 0;
	  
	  } elsif ($command ne "comments") {		# write rest
	    
	    mkdir($command) if (! -e $command);
	    if ($env_stage ne "-" && $env_trial ne "-")
	    {
	      mkdir("$command/$env_stage") if (! -e "$command/$env_stage");
	      my $ext = $command eq "parameters" ||
			$command eq "references" ? "csv" : "dat";
	      my $name = "$command/$env_stage/$env_trial.$ext";
	      if (!check_exist($command, $name)) {

		info("creating chemistry \"$name\"\n");
		my $stream = fopen($name, "w");
		write_emc_verbatim($stream, $command);
		close($stream);
	      }
	    }
	  }
	  chdir($pwd);
	}
      } else {						# chemistry mode
	$::EMC::Parameters{flag} = 1 if ($mode>=10);
	$level += $mode ? 1 : -1;
      }
      @last = @arg; shift(@last); shift(@last);

      $flag{comment} = $flag{comment} ? $level ? 1 : 0 : $mode==1 ? 1 : 0;
      $flag{template} = $flag{template} ? $level ? 1 : 0 : $mode==17 ? 1 : 0;
      $flag{field} = $flag{field} ? $level ? 1 : 0 : $mode==21 ? 1 : 0;
      $flag{parameters} = $flag{parameters} ? $level ? 1 : 0 : $mode==22 ? 1:0;
      $flag{references} = $flag{references} ? $level ? 1 : 0 : $mode==23 ? 1:0;
     
      next if ($flag{template} ? $mode==17 : ($flag{field} && $mode==21));
      
      $mode = $flag{references} ? 23 : $mode;
      $mode = $flag{parameters} ? 22 : $mode;
      $mode = $flag{field} ? 21 : $mode;
      $mode = $flag{template} ? 17 : $mode;
      $mode = $flag{comment} ? 1 : $mode;

      if ($mode==0) {

	$line_last = 0;

      } elsif ($mode==18) {				# set item variables

	# STAGE

	$env_stage = check_loop("stage", @current[2], $line);
	$env_flag = 1;
	$mode = 0;
	--$level;
	next;

      } elsif ($mode==19) {

	# TRIAL
	
	$env_trial = check_loop("trial", @current[2], $line);
	$env_flag = 1;
	$mode = 0;
	--$level;
	next;

      } elsif ($mode==27 || $mode==28) {

	# INCLUDE or WRITE
	
	$mode = 0;
	--$level;
	next;
      }
      next if (!($mode == 1 || $mode == 17 || $mode == 21));
    } 
    
    # extract elements

    if ($flag_element && @arg[0] ne "ITEM") {
      if ($current[1] eq "REPLICAS") {
	$::EMC::Elements{(split(":",@arg[1]))[0]} = 1;
	$replicas{@arg[0]} = 1;
      } elsif (substr(@arg[1],0,1) ne "@") {
	my %next = (
	  "(" => 1, ")" => 1, ":" => 1, "=" => 1,
	  "#" => 1, "." => 1, "*" => 1);
	my $group = @arg[1];
	my $n = length($group);
	my $type = "";
	my $brackets = 0;
	my $charge = 0;
	for ($i = 0; $i < $n; ++$i) {
	  my $c = substr($group, $i, 1);
	  next if (defined($next{$c}));
	  next if (($c eq "0" || $c > 0) && !$brackets);
	  if ($brackets && ($c eq "-" || $c eq "+")) { $charge = 1; }
	  if ($c eq "[") { ++$brackets; next };
	  if ($c ne "]") { $type .= $c if (!$charge); }
	  else { --$brackets; }
	  if (!$brackets && !defined($replicas{$type})) {
	    $::EMC::Elements{$type} = 1;
	    $charge = 0;
	    $type = "";
	  }
	}
      }
    }

    # environment mode

    if ($env_flag) {
      next if ($env_options && @current[0] eq "project");
      if ($command eq "structures") {
       	if (substr($verbatim,0,1) ne "#") {
	  push(@{$::EMC::Verbatim{$command}}, [$verbatim, $line]);
	}
      } elsif ($command eq "field") {
	$verbatim = "\n$verbatim" if ($line_last && $line-$line_last>1);
	push(@{$::EMC::Verbatim{$command}}, [$verbatim, $line]);
      } else {
	next if (!$level);
	$verbatim = "\n$verbatim" if ($line_last && $line-$line_last>1);
	push(@{$::EMC::Verbatim{$command}}, $verbatim);
      }
      if (@current[0] eq "ITEM") {
	$env_options = @current[1] eq "OPTIONS" ? 1 : 0;
	--$level if (@current[1] eq "INCLUDE");
      }
      $line_last = $line;
      next;
    }

    # normal mode

    next if (substr(trim($verbatim),0,1) eq "#");

    if ($mode==0) {

      # END

      error_line($line, "data without defined mode\n");
    
    } elsif ($mode==1) {

      # COMMENTS:
      #   everything before matching ITEM END is not interpreted
      
      $flag{comment} = 1;
    
    } elsif ($mode==2) {

      # SHORTHAND:	name,chemistry,fraction[,mass[,volume]]

      my $mass;
      my @field;
      my $volume;
      my $terminator = 0;
      my $id = group_id($line, shift(@arg), \@field, \$mass, \$terminator);
      my $name = convert_name($id);
      my $chemistry = shift(@arg);
      my $i = defined($::EMC::XRef{$name}) ? $::EMC::XRef{$name} : $index++;
      
      check_name($name, $line, 0);

      $::EMC::XRef{$name} = $i;
      @::EMC::Clusters[$i] = convert_name($name);
      @::EMC::Chemistries[$i] = $chemistry;
      @::EMC::NClusters[$i] = count_clusters($chemistry);
      @::EMC::Fractions[$i] = shift(@arg);
      @::EMC::MolMass[$i] = $mass = shift(@arg);
      @::EMC::MolVolume[$i] = $volume = shift(@arg);
      $::EMC::Profile{$name} = 1 if ($::EMC::ProfileFlag{density});

      cluster_flag($line, $name, $mass, $volume);
      
      if ($mass ne "" && !$::EMC::Flag{mass_entry}) {
	error("no mass entry allowed for field '$::EMC::Field{type}'.\n"); }
      
      $i = 0; foreach(@::EMC::Groups) { last if ($name eq $_); ++$i}
      @::EMC::Groups[$i] = $name;
      undef($::EMC::Group{$name});
      ${$::EMC::Group{$name}}{id} = $id;
      ${$::EMC::Group{$name}}{chemistry} = $chemistry;
      ${$::EMC::Group{$name}}{nextra} = count_clusters($chemistry)-1;
      ${$::EMC::Group{$name}}{terminator} = $terminator;
      ${$::EMC::Group{$name}}{nconnects} = 0;
      ${$::EMC::Group{$name}}{connect} = [];
      ${$::EMC::Group{$name}}{field} = [@field];
      ${$::EMC::Group{$name}}{mass} = $mass;
      ${$::EMC::Group{$name}}{line} = $line;

      $::EMC::Polymer{$name}[0] = [(1, [(1)], [($name)], [(1)])];

    } elsif ($mode==3) {

      # GROUPS:		name,chemistry[,#,group,[,#,group,[...]]]

      if (scalar(@arg)<2) {
	error_line($line, "too few group entries (< 2)\n");
      }
      my $mass;
      my @field;
      my $terminator = 0;
      my $id = group_id($line, shift(@arg), \@field, \$mass, \$terminator);
      my $name = convert_name($id);
      my $chemistry = shift(@arg);
      my $poly = defined($flag{polymer}{$chemistry});
      my $nconnects = ($chemistry =~ tr/\*\<\>//);

      #tprint(__LINE__.":", $line, $verbatim);
      check_name($name, $line, 0);
      push(@::EMC::Groups, $name) if (!defined($::EMC::Group{$name}));

      undef($::EMC::Group{$name});
      ${$::EMC::Group{$name}}{id} = $id;
      if ((${$::EMC::Group{$name}}{polymer} = $poly)) {
	$polymer{$name}{group} = 1;
	$polymer{$name}{type} = $poly ? $flag{polymer}{$chemistry} : 0;
	${$::EMC::Group{$name}}{terminator} = $terminator;
	#tprint(__LINE__.":", $line, $name, $poly, $polymer{$name}{type});
	next;
      }
      ${$::EMC::Group{$name}}{chemistry} = $chemistry;
      ${$::EMC::Group{$name}}{nextra} = count_clusters($chemistry)-1;
      ${$::EMC::Group{$name}}{terminator} = $terminator;
      ${$::EMC::Group{$name}}{nconnects} = $nconnects;
      ${$::EMC::Group{$name}}{connect} = [];
      ${$::EMC::Group{$name}}{field} = [@field];
      ${$::EMC::Group{$name}}{mass} = $mass; 
      ${$::EMC::Group{$name}}{line} = $line;
      
      for ($i=0; $i<$nconnects; ++$i) { 
	@{${$::EMC::Group{$name}}{connect}}[$i] = []; }
     
      while (scalar(@arg)) {
	my $connect = shift(@arg);
	my @a = split(":", shift(@arg));
	my $gconnect = pop(@a);
	my $group = join(":", @a);
	check_name($group, $line, 0);
	if (substr($connect,0,1) =~ m/[0-9]/) {
	  if ((($connect = my_eval($connect))<1)||($connect>$nconnects)) {
	    error("connect out of bounds (not in [1, $nconnects>) ".
	      " in line $line of input\n");
	  }
	} else {
	  error("number expected for connect in line $line of input\n");
	}
	#if (!substr($gconnect,0,1) =~ m/[0-9]/) {
	#  error("number expected for gconnect in line $line of input\n");
	#}
	push(@{@{${$::EMC::Group{$name}}{connect}}[$connect-1]}, [$group, $gconnect]);
      }
    
    } elsif ($mode==4) {

      # CLUSTERS:	name,group,fraction[,mass[,volume]]
      # fraction -> mole, mass, or volume fraction
      # group -> surface: name,surface,nx,"file name"

      if (scalar(@arg)<3) {
	error_line($line, "too few cluster entries (< 3)\n");
      }
      my $name = shift(@arg); check_name($name, $line, 1);
      my $group = convert_name(shift(@arg));
      
      if (defined($flag{import}{$group})) {		# import
	
	my %flag = %::EMC::ImportDefault;
	my %mode = (
	  ".emc" => "emc", ".car" => "insight", ".mdf" => "insight",
	  ".pdb" => "pdb", ".psf" => "pdb"
	);
	my @order = (
	  "ncells", "name", "mode", "type", "flag", "density", "focus",
	  "tighten", "ntrials", "periodic", "field", "exclude", "depth",
	  "percolate", "unwrap", "guess", "charges", "formal", "translate"
	);
	my %allowed = (
	  charges => {charges => 1},
	  density => {mass => 1, number => 1},
	  depth => {depth => 1},
	  exclude => {box => 1, contour => 1, none => 1},
	  field => {field => 1},
	  flag => {fixed => 1, rigid => 1, mobile => 1},
	  focus => {focus => 1},
	  formal => {formal => 1},
	  guess => {guess => 1},
	  mode => {get => 1, emc => 1, insight => 1, pdb => 1},
	  name => {name => 1},
	  ncells => {ncells => 1},
	  ntrials => {ntrials => 1},
	  periodic => {x => 1, y => 1, z => 1},
	  tighten => {tighten => 1},
	  percolate => {percolate => 1},
	  translate => {translate => 1},
	  type => {crystal => 1, surface => 1, line => 1, structure => 1},
	  unwrap => {unwrap => 1}
	);
	my @ncells = split(":", $flag{ncells});
	my $i = 0;

	$flag{density} = "number" if ($::EMC::Field{type} eq "dpd");
	foreach (@arg) {
	  my @a = split("=");
	  if (scalar(@a)==1) {
	    if ($i==scalar(@order)) {
	      error_line($line, "too many arguments for import\n");
	    } else {
	      if ($i<2) {
		$flag{@order[$i++]} = @a[0];
	      } elsif (!defined(${$allowed{@order[$i]}}{@a[0]})) {
		error_line($line, 
		  "import @order[$i] option '@a[0]' not allowed\n");
	      } else {
		$flag{@order[$i++]} = @a[0];
	      }
	    }
	  } else {
	    if (!defined($allowed{@a[0]})) {
	      error_line($line, "import id '@a[0]' unknown\n");
	    } elsif (defined(${$allowed{@a[0]}}{@a[0]})) {
	      $flag{@a[0]} = @a[1];
	    } elsif (!defined(${$allowed{@a[0]}}{@a[1]})) {
	      error_line($line, "import @a[0] option '@a[1]' not allowed\n");
	    } else {
	      $flag{@a[0]} = @a[1];
	    }
	  }
	}

	$i = 0;
	foreach (split(":", $flag{ncells})) {
	  @ncells[$i++] = $::EMC::Flag{expert}||($_ eq "auto") ? $_ : eval($_);
	  last if ($i==3); }
       	delete($flag{n});

	my $filename = $flag{name}; delete($flag{name});
	my ($tmp, $path, $suffix) = fileparse($filename, '\.[^\.]*');
	if ($flag{mode} eq "") {
	  $suffix =~ s/(.*)"$/$1/g;
	  if ($suffix eq ".gz") {
	    ($tmp, $tmp, $suffix) = fileparse($tmp, '\.[^\.]*');
	  }
	  if (!defined($mode{$suffix})) {
	    error_line($line, "unsupported suffix '$suffix'\n");
	  }
	  $flag{mode} = $mode{$suffix};
	}

	my $type = $flag{type};
	my @field = ();
	foreach (split(":", $flag{field})) {
	  push(@field, field_id($line, $_)); }

	my @periodic = 
	    $flag{type} eq "crystal" ? (1, 1, 1) :
	    $flag{type} eq "surface" ? (0, 1, 1) :
	    $flag{type} eq "tube" ? (0, 0, 1) :
	    $flag{type} eq "structure" ? (0, 0, 0) : (0, 0, 0);
	
	undef(%::EMC::Import);				# allow only one!!!

	foreach (keys(%flag)) {
	  if ($_ eq "ncells") {
	    my @n = @ncells;
	    my @m = split(":", $flag{$_});
	    if (scalar(@m)==1) {
	      @n[0] = @m[0];
	    } elsif (scalar(@m)==3) {
	      my %index = (x => 0, y => 1, z => 2);
	      @n[0] = @m[$index{$::EMC::Direction{x}}];
	      @n[1] = @m[$index{$::EMC::Direction{y}}];
	      @n[2] = @m[$index{$::EMC::Direction{z}}];
	    } else {
	      error_line($line, "ncells can only have 1 or 3 entries\n");
	    }
	  } elsif ($_ eq "ntrials") {
	    $::EMC::Import{$_} = $flag{$_}>0 ? $flag{$_} : 1;
	  } elsif ($_ eq "periodic") {
	    my %index = (x => 0, y => 1, z => 2);
	    foreach (split(":", $flag{$_})) { @periodic[$index{$_}] = 1; }
	  } elsif ($_ eq "tighten") {
	    my $value = 
	      $flag{$_} eq "" || 
	      $flag{$_} eq "true" ? $::EMC::Tighten : eval($flag{$_});
	    if ($value eq "") {
	      if (!$::EMC::Flag{expert}) {
		error_line($line, "option tighten does not have a value\n");
	      }
	      $value = $flag{$_};
	    }
	    $::EMC::Import{$_} = $value if ($flag{$_} ne "false");
	  } elsif ($_ eq "focus" || $_ eq "guess" || $_ eq "unwrap") {
	    $::EMC::Import{$_} = $flag{$_}<0 ? -1 : flag($flag{$_});
	  } else {
	    $::EMC::Import{$_} = $flag{$_};
	  }
	}
	$::EMC::Import{periodic} = [@periodic];
	for ($i=0; $i<scalar(@ncells); ++$i) {
	  if ($i && @ncells[$i] eq "auto") {
	    next if ($::EMC::Import{type} ne "crystal");
	    @ncells[$i] = 1;
	  }
	  if (!$::EMC::Flag{expert} && @ncells[$i]<1) {
	    error("n < 1 for import '$name' in line $line of input\n"); }
	}
	if ($filename eq "") {
	  error_line($line, "missing file name for import '$name'\n"); }
	
	$::EMC::Import{name} = $name;
	$::EMC::Import{field} = [@field];
	$::EMC::Import{filename} = $filename;
	$::EMC::Import{nx} = @ncells[0];
	$::EMC::Import{ny} = @ncells[1];
	$::EMC::Import{nz} = @ncells[2];
	if ($::EMC::Import{depth}<0) {
	  $::EMC::Import{depth} = $::EMC::EMC{depth};
	}
	if ($::EMC::Flag{crystal}<0) {
	  $::EMC::Import{crystal} = $::EMC::Import{type} eq "crystal" ? 1 : 0;
	} else {
	  $::EMC::Import{crystal} = $::EMC::Flag{crystal};
	}

      } else {
	
	my $poly = defined($flag{polymer}{$group});
	my $fraction = shift(@arg);
	my $mass = shift(@arg);
	my $volume = shift(@arg);
	my $i = defined($::EMC::XRef{$name}) ? $::EMC::XRef{$name} : $index++;

	cluster_flag($line, $name, $mass, $volume);

	if ($mass ne "" && !$::EMC::Flag{mass_entry}) {
	  error("no cluster mass entry allowed for field '$::EMC::Field{type}'\n"); }
	if ($poly ? 0 : !defined($::EMC::Group{$group})) {
	  error("undefined group \'$group\' in line $line of input\n"); }
	#if ($poly ? 0 : scalar(@{${$::EMC::Group{$group}}{connect}})) {
	#error("cannot use group \'$group\' for polymers in line $line of input\n"); }
	if (!$::EMC::ProfileFlag{density} ? 0 : defined($::EMC::Profile{$name})) {
	  error("cluster name '$name' already taken by a profile in line $line of input\n"); }

	$::EMC::XRef{$name} = $i;
	@::EMC::Clusters[$i] = $name;
	@::EMC::Fractions[$i] = $fraction;
	@::EMC::MolMass[$i] = $mass;
	@::EMC::MolVolume[$i] = $volume;
	@::EMC::NClusters[$i] = $poly ? 1 : ${$::EMC::Group{$group}}{nextra}+1;
	$::EMC::Profile{$name} = 1 if ($::EMC::ProfileFlag{density});
	if (!defined($::EMC::Polymer{$name})) {
	  $polymer{$name}{cluster} = 1;
	  $polymer{$name}{type} = $poly ? $flag{polymer}{$group} : 0;
	  if ($poly) {
	    $::EMC::PolymerFlag{cluster} = 1;
	  } else {
	    $::EMC::Polymer{$name}[0] = [(1, [(1)], [($group)], [(1)])];
	  }
	}
      }
    
    } elsif ($mode==5) {

      # POLYMERS: 
      #   line 1: 	name,fraction[,mass[,volume]]
      #   fraction -> mole, mass, or volume fraction
      #   line 2:	fraction,group,n[,group,n[,...]]
      #   fraction -> mole fraction
      #   line ...:	same as line 2

      if (scalar(@arg)==1||defined($polymer{@arg[0]})) {	# first line
	my $name = shift(@arg); check_name($name, $line, 2);
	my %flag = %::EMC::PolymerFlag;
	set_list_polymer($line, \%flag, @arg);
	$polymer{$name}{options} = {%flag};
	$ipoly = 0;
	if (!defined($polymer{$name}{type})) {
	  expert_line($line, "undefined polymer \'$name\'\n");
	  $ipoly = -1;
	} elsif (!$polymer{$name}{type}) {
	  expert_line($line, "\'$name\' is not a polymer\n");
	  $ipoly = -1;
	}
	if (!$ipoly) {
	  $::EMC::Polymers{$polymer_name = $name} = $::EMC::XRef{$name};
	} 
      } elsif ($ipoly>=0) {				# subsequent lines
	my $fraction = shift(@arg);
	my %flag = %{$polymer{$polymer_name}{options}};
	$::EMC::Polymer{$polymer_name}[$ipoly] = [
	  ($fraction, [], [], [], 
	    @{$types{polymer}}[$polymer{$polymer_name}{type}-1], {%flag}
	  )
	];
	while (scalar(@arg)) {
	  my $name = shift(@arg);
	  my $n = shift(@arg);
	  my @a = split("=", $name);
	  my @t = split(":", @a[0]);
	  foreach(@t[0]) {
	    check_name($_, $line, 0);
	  }
	  #@::EMC::NClusters[$::EMC::XRef{$polymer_name}] += $n*${$::EMC::Group{$name}}{nextra};
	  push(@{${$::EMC::Polymer{$polymer_name}[$ipoly]}[1]}, 
	    $::EMC::Flag{expert} ? $n : my_eval($n));
	  push(@{${$::EMC::Polymer{$polymer_name}[$ipoly]}[2]},
	    @a[0]);
	  if (!$::EMC::Flag{expert} && !(substr($n,0,1) =~ m/[0-9]/)) {
	    error("number expected in line $line of input\n");
	  }
	  $n = scalar(@t);
	  if (scalar(@a)>1) {
	    @t = split(":", @a[1]);
	    if (scalar(@t)!=$n) {
	      error_line($line, "number of groups and weights are not equal\n");
	    }
	  } else {
	    foreach(@t) { $_ = 1; }
	  }
	  push(@{${$::EMC::Polymer{$polymer_name}[$ipoly]}[3]}, join(":", @t));
	}
	++$ipoly;
      }
    
    } elsif ($mode==6) {

      # EMC|VERBATIM:	phase	[position]
      
      my %answer = set_options(
	$line_mode, [["phase", 1], ["spot", 0]], \@last, 0, 0);
      my $phase = $answer{phase}; $phase = $::EMC::NPhases if ($phase<0);
      my $sub = $answer{spot}; $sub = 2 if ($sub<0);
      if ($sub>2) {
	error($line, "unallowed sub phase for EMC paragraph\n");
      }
      $verbatim = "\n$verbatim" if ($line_last && $line-$line_last>1);
      if (!defined($::EMC::Verbatim{build}[$phase])) {
	$::EMC::Verbatim{build}[$phase] = [[],[],[]];
      }
      push(@{@{$::EMC::Verbatim{build}[$phase]}[$sub]}, $verbatim);
      $line_last = $line;

    } elsif ($mode==24) {

      # LAMMPS

      my %answer = set_options(
	$line_mode, [["stage", "simulation"], ["spot", "tail"]], \@last, 0, 1);
      my $stage = set_allowed(
	$line, $answer{stage}, @{$::EMC::Lammps{stage}});
      my $spot = ("head", "tail")[${$::EMC::Lammps{spot}}{set_allowed(
	$line, $answer{spot}, keys(%{$::EMC::Lammps{spot}}))}];
     
      $verbatim = "\n$verbatim" if ($line_last && $line-$line_last>1);
      if (!defined(${${$::EMC::Verbatim{lammps}}{$stage}}{$spot})) {
	${${$::EMC::Verbatim{lammps}}{$stage}}{$spot} = [];
      }
      push(@{${${$::EMC::Verbatim{lammps}}{$stage}}{$spot}}, $verbatim);
      $line_last = $line;

    } elsif ($mode==7) {

      # VARIABLES

      if (1 || scalar(@arg)==2) {
	my $type = 1;
	$type = @last[0] eq "head" ? 0 :
		@last[0] eq "tail" ? 1 :
		@last[0] ? 1 : 0 if (@last[0] ne "");
	$::EMC::Variables{type} = $type;
	push(@{$::EMC::Variables{data}}, [@arg]);
      }
    
    } elsif ($mode==8) {

      # OPTIONS

      if (scalar(@arg)) {
	if (options($line, $warning, @arg)) {
	  error("unknown option '@arg[0]' in line $line of input\n");
	}
      }
    
    } elsif ($mode==9) {

      # REPLICAS or EXTRA
      
      my $n = scalar(@arg);

      error("missing extra types in line $line of input\n") if ($n<2);
      push(@::EMC::Replica, [@arg]);
    
    } elsif ($mode==26) {

      # MASSES

      my $i;
      my @p = (@arg[0]);
      my @a = @arg;
      for ($i=0; $i<5; ++$i) { push(@p, shift(@a)); }
      push(@p, join(" ", @a));
      @{${$::EMC::Reference{data}}{@arg[0]}} = @p;
      info("defining reference for @arg[0]\n");
    
    } elsif ($mode==10) {

      # NONBONDS

      my $n = scalar(@arg);

      if ($n<3) {
	error("incorrect parameter entry in line $line of input\n"); }
      if ($n<4) {
	@arg[3] = $::EMC::PairConstants{r}; }
      if ($n<5) {
	@arg[4] = $::EMC::PairConstants{gamma}; }

      @arg[0,1] = sort(@arg[0,1]);
      for ($i=2; $i<$n; ++$i) { @arg[$i] = eval(@arg[$i]); }

      push(@::EMC::Set, [@arg[0,1,2,3,4]]);
      $::EMC::Cutoff{@arg[0]} = @arg[3] if (@arg[0] eq @arg[1]);

    } elsif ($mode==11) {

      # BONDS

      if (scalar(@arg)==4) {
	$::EMC::Bonds{join("\t", sort(@arg[0,1]))} = join("\t", eval_parms(@arg[2,3]));
      }
    
    } elsif ($mode==12) {

      # ANGLES

      if (scalar(@arg)==5) {
	$::EMC::Angles{join("\t",
	  @arg[0] lt @arg[2] ? @arg[0,1,2] : @arg[2,1,0])} = join("\t", eval_parms(@arg[3,4]));
      }
    
    } elsif ($mode==13) {

      # TORSIONS

      if (scalar(@arg)>6) {
	if ((@arg[0]<@arg[3]) ||
	    (@arg[0]==@arg[3] && @arg[1]<@arg[2])) { @arg = reverse(@arg); }
	$::EMC::Torsions{join("\t", @arg[0..3])} = join("\t", eval_parms(splice(@arg, 4)));
      }
    
    } elsif ($mode==14) {

      # IMPROPERS

      if (scalar(@arg)==6) {
	@arg[0..3] = @arg[0,2,3,1] if (@arg[2]<@arg[1]);
	@arg[0..3] = @arg[0,3,1,2] if (@arg[3]<@arg[1]);
	@arg[0..3] = @arg[0,3,1,2] if (@arg[3]<@arg[2]);
	$::EMC::Impropers{join("\t", @arg[0..3])} = join("\t", eval_parms(splice(@arg, 4)));
      }
    
    } elsif ($mode==15) {

      # LOOPS

      if ($env_flag) {
	error(
	  "cannot define loops inside stage section in line $line of input\n");
      }
      if (scalar(@arg)>1) {
	my $variable = lc(shift(@arg));
	my @f = split(":", $variable);
	
	@f[0] = "stage" if (@f[0] eq "phase");			# legacy
	
	my $flag = (@f[1] eq "p" || @f[1] eq "pair" || @f[1] eq "paired") ? 1 : 0;
	my $hide = (@f[1] eq "h" || @f[1] eq "hide" || @f[1] eq "hidden") ? 1 : 0;
	my $double = (@f[1] eq "d" || @f[1] eq "double" || @f[1] eq "doubled") ? 1 : 0;
	my $list = (@f[1] eq "l" || @f[1] eq "list") ? 1 : 0;
	my $name = @f[0];

	$flag = 1 if ($hide);
	foreach (@arg) {
	  if ($_ =~ m/:/) {
	    my @a = split(":");
	    next if (@a[0] ne "s" && @a[0] ne "seq");
	    if (@f[0] ne "copy" && !$flag) {
	      #error_line($line, "sequences are not allowed when not paired\n");
	    }
	    if (scalar(@a)<3 || scalar(@a)>5) {
	      error_line($line, "incorrect sequence definition\n");
	    }
	  }
	}
	
	$variable = join(":", @f);
	if (scalar(@f)>1) {
	  error_line($line, "too many modes for '$name'\n") if (scalar(@f)>2);
	  error_line($line, "unknown mode '@f[1]'\n") if (!($flag||$double||$list));
	}
	if ($nloop_pairing<0 || !$flag) {
	  $nloop_pairing = scalar(@arg);
	  $loop_pair = @f[0];
	} elsif ($nloop_pairing != scalar(@arg)) {
	  print("nloop = $nloop_pairing != ", scalar(@arg), " {", join(", ", @arg), "}\n");
	  error_line($line, "unequal pair '$loop_pair' and '@f[0]'\n");
	}
	my $changed = 0;
	foreach (@::EMC::LoopVariables) {
	  my @f = split(":");
	  next if (@f[0] ne $name);
	  next if ($flag^(scalar(@f)>1 ? 1 : 0) ? 0 : 1);
	  delete $::EMC::Loop{$_};
	  $_ = $variable;
	  $changed = 1;
	  last;
	}
	my $v = (split(":", $variable))[0];
	$variable = $v if (defined($loop_check{$v}));
       	if (!(defined($::EMC::Loop{$variable}) || $changed)) {
	  push(@::EMC::LoopVariables, $variable);
	}
	foreach (@arg) {
	  my $s = $_;
	  foreach (@previous_variables) { my $v = uc($_); $s =~ s/\@$v//g; }
	  #if (!$::EMC::Flag{expert} && 
	  if ($s =~ m/\@/) {
	    my $ls = $s;
	    $s = variable_replace($s);
	    if ($s eq $ls && !$::EMC::Flag{expert}) {
	      error_line($line, "unallowed variable reference '$s'\n");
	    }
	    $_ = $s;
	  }
	}
	if ($variable eq "copy") {
	  @{$::EMC::Loop{$variable}} = @arg;
	  foreach (@{$::EMC::Loop{$variable}}) {
	    my @arg = split(":");
	    next if (scalar(@arg)>2 && (@arg[0] eq "s" || @arg[0] eq "seq"));
	    $_ = 1 if ($_ < 1);
	    $_ = int($_);
	  }
	} elsif ($variable eq "ncores") {
	  @{$::EMC::Loop{$variable}} = @arg;
	  foreach (@{$::EMC::Loop{$variable}}) {
	    $_ = 1 if ($_ < 1);
	    $_ = int($_);
	  }
	} else {
	  if ($list) {
	    my $x0 = shift(@arg);
	    my $xn = shift(@arg);
	    my $dx = shift(@arg);
	    my $n = int(($xn-$x0)/$dx+0.5);
	    my @a = ();
	    my $i;
	    for ($i=0; $i<$n; ++$i) { push(@a, $x0+$i*$dx); }
	    @{$::EMC::Loop{$variable}} = @a;
	  } else {
	    @{$::EMC::Loop{$variable}} = $flag ? @arg : 
				$double ? @arg : list_unique($line, @arg);
	  }
	}
	if ($variable eq "stage") {
	  $loop_stage = @arg[0];
	} elsif ($variable eq "trial") {
	  if ($loop_stage eq "") {
	    error("set stage before trial in line $line of input\n"); }
	  @{$::EMC::Trials{$loop_stage}} = 
				$double ? @arg : list_unique($line, @arg);
	    #list_unique($line, @{$::EMC::Trials{$loop_stage}}, @arg);
	}
	push(@previous_variables, $name);
      }
    
    } elsif ($mode==16) {

      # STRUCTURES
      
      if (!$::EMC::Flag{environment}) {
	error("'$command' section allowed in environment mode only\n");
      }

    } elsif ($mode==17) {

      # TEMPLATE

      $flag{template} = 1;
      if (!$::EMC::Flag{environment}) {
	error("'$command' section allowed in environment mode only\n");
      }
    
    } elsif ($mode==20) {

      # PROFILES
      # item1 -> profile name
      # item2 -> profile type (either 'cluster' or 'type')
      # subsequent items -> profile contributors

      my %allow_style = ("type" => 1, "cluster" => 1);
      my %allow_type = allow_list(\%::EMC::ProfileFlag);
      my $name = shift(@arg);
      my @a = split(":", shift(@arg));
      my $style = @a[0];
      my $type = @a[1] eq "" ? "density" : @a[1];
      my $binsize = @a[2] eq "" ? $::EMC::BinSize : eval(@a[2]);

      $binsize = $::EMC::BinSize if ($binsize<=0.0);
      $binsize = 1.0 if ($binsize>=1.0);
      if ($name eq $::EMC::Project{name}) {
	error_line($line, "cannot use project name '$::EMC::Project{name}'\n"); }
      if (!defined($allow_style{$style})) {
	error_line($line, "illegal profile style '$style'\n"); }
      if (!defined($allow_type{$type})) {
	error_line($line, "illegal profile type '$type'\n"); }
      if ($type eq "pressure" && !$::EMC::Lammps{chunk}) {
	error_line($line, "pressure profile needs LAMMPS chunks\n"); }
      if (defined($::EMC::Profile{$name})) {
	error_line($line, "profile name '$name' already exists\n"); }
       
      $::EMC::Profile{$name} = 1;
      push(@{${$::EMC::Profiles{$style}}{$name}}, $type, $binsize, @arg);
      if ($style=="type") { foreach (@arg) { set_convert_key($style, $_); } }
    
    } elsif ($mode==25) {

      # ANALYSIS, ANALYZE

      $flag{$command} = 1;
      if (!$env_flag) {
	my $script = shift(@arg);
	my $key = (split("\\.sh", $script))[0];
	my $hash;

	if (!defined(${$::EMC::Analyze{scripts}}{$key})) {
	  $hash = {active => 1, queue => 0, options => {type => $key}};
	  ${$::EMC::Analyze{scripts}}{$key} = $hash;
	  ${$hash}{script} = $script;
	} else {
	  ${$hash = ${$::EMC::Analyze{scripts}}{$key}}{active} = 1;
	}
	foreach (@arg) {
	  my @a = split("=");
	  if (@a[0] eq "active") {
	    ${$hash}{active} = flag(@a[1]); next;
	  } elsif (@a[0] eq "queue") {
	    ${$hash}{queue} = flag(@a[1]); next;
	  } elsif (@a[0] eq "script") {
	    ${$hash}{script} = @a[1]; next;
	  }
	  ${${$hash}{options}}{@a[0]} = @a[1] eq "" ? 1 : @a[1];
	}
	if (!defined(${$hash}{script})) {
	  error_line($line, "missing script definition\n");
	}
      }
    
    } elsif ($mode==21 || $mode==22 || $mode==23) {

      # FIELD, PARAMETERS, REFERENCES
     
      $flag{$command} = 1;
      if (!$env_flag) {
	$verbatim = "\n$verbatim" if ($line_last && $line-$line_last>1);
	push(@{$::EMC::Verbatim{$command}}, [$verbatim, $line]);
	$line_last = $line;
      }
    }
  }
  error("missing 'ITEM END'\n") if ($::EMC::Flag{environment}&&($level>0));
  check_validity($stream) if (!$::EMC::Flag{environment});
  create_environment() if ($::EMC::Flag{environment});
  $::EMC::Flag{source} = "";
}


sub check_loop {
  my $type = shift(@_);
  my $value = shift(@_);
  my $line = shift(@_);
  my $flag = 0;

  if (!$::EMC::Flag{environment}) {
    error(
      "'$type' section only allowed in environment mode\n");
  }
  if (defined($::EMC::Loop{$type})) {
    foreach (@{$::EMC::Loop{$type}}) {
      if ($_ eq $value) { $flag = 1; last; }
    }
    if (!$flag) {
      return @{$::EMC::Loop{$type}}[0] if ($::EMC::Flag{expert});
      error_line($line, "no loop '$type' value '$value'\n");
    }
    return $value eq "" ? "generic" : $value;
  }
  return "generic";
}


sub check_validity {
  my $stream = shift(@_);

  # validity check

  check_group_connectivity();

  if ((!$::EMC::Flag{reduced}) && (scalar(@::EMC::Clusters) != scalar(@::EMC::MolMass))) {
    error("mol masses need to be defined for set force field type\n");
  }
  
  my %clusters; foreach (@::EMC::Clusters) { $clusters{$_} = -1; }
  my $nphases = scalar(@::EMC::Phases);
  my @phases = ();
  my $iphase = 0;
  
  foreach (@::EMC::Phases) {
    ++$iphase; foreach (@$_) {
      if (defined $clusters{$_}) {
	if ($clusters{$_}<0) {				# keep order as entered
	  push(@{$phases[($clusters{$_} = $iphase)-1]}, $_); next;
	}
	warning("cluster '$_' is already assigned to phase $clusters{$_}\n");
      }
      else {
	if ($::EMC::Flag{expert}) {
	  push(@{$phases[($clusters{$_} = $iphase)-1]}, $_); next;
	} else {
	  #warning("ignoring cluster '$_': does not occur in chemistries\n");
	  error("cluster '$_': does not occur in chemistries\n");
	}
      }
    }
  }

#  foreach (keys(%type)) {
#    next if (!$type{$_});
#    next if (defined($::EMC::Polymers{$_}));
#    error("undefined polymer \'$_\' in clusters paragraph\n");
#  }
  
  @::EMC::Phases = (); 
  
  @::EMC::ClusterSampling = 
    defined($::EMC::Import{name}) ? ($::EMC::Import{name}) : ();
  foreach (@::EMC::Clusters) {				# add remains after end
    push(@{$phases[$nphases]}, $_) if ($clusters{$_}<1);
  }
  $iphase = 0;
  foreach (@phases) { 
    if (defined($_) && scalar(@$_)>0) {
      push(@::EMC::Phases, $_);
      info("phase%d = {%s}\n", ++$iphase, join(", ", @$_));
      push(@::EMC::ClusterSampling, @$_);
    }
  }
  $::EMC::NPhases = scalar(@::EMC::Phases);
  $::EMC::Shape = 
    $::EMC::ShapeDefault[$::EMC::NPhases>1 ? 1 : 0] if ($::EMC::Shape eq "");
  close($stream);
}


sub reset_global_variables {
  @::EMC::NClusters = ();
  @::EMC::Chemistries = ();
  @::EMC::Clusters = ();
  @::EMC::Clusters = ();
  @::EMC::Groups = ();
  @::EMC::Fractions = ();
  @::EMC::MolMass = ();
  undef(%::EMC::XRef);
  undef(%::EMC::Import);
  undef(%::EMC::Polymer);
}


sub check_name {
  my $line = "in line $_[1] of input";
  my $type = ("group", "cluster", "polymer")[$_[2]];
  my @restricted = $_[2] ? (@::EMC::Restricted) : (@::EMC::Restricted, @::EMC::RestrictedGroup);
  
  if (@_[0] eq "") {
    error("empty name $line\n");
  }
  if (substr(@_[0],0,1) =~ m/[0-9]/) {
    error("illegal $type name \'@_[0]\' (starts with a number) $line\n");
  }
  if (@_[0] =~ m/[+\-\.*\%\/]/) {
    error("illegal $type name \'@_[0]\' (contains an illegal character) $line\n");
  }
  foreach ((@restricted, $::EMC::Project{name})) {
    next if ($_ ne @_[0]);
    error("illegal $type name \'@_[0]\' (reserved variable) $line\n");
  }
  foreach (@::EMC::RestrictedStart) {
    next if ($_ ne substr(@_[0],0,length($_)));
    error("illegal $type name \'@_[0]\' (disallowed variable start) $line\n");
  }
}


sub check_group_connectivity {
  foreach (@::EMC::Groups) {
    my $name = $_;
    my $group = $::EMC::Group{$_};
    my $connect = ${$group}{connect};
    my $nconnects = ${$group}{nconnects};
    my $iconnect = 0;

    foreach (@{$connect}) {
      ++$iconnect;
      foreach (@{$_}) {
	group_connection(@{$_}, $name, $iconnect) if ($_->[1] =~ m/[0-9]/);
      }
    }
  }
  foreach (@::EMC::Groups) {
    my $line = "in line ${$::EMC::Group{$_}}{line} of input";
    foreach (@{$::EMC::Group{$_}{connect}}) {
      foreach (@{$_} = sort(@{$_})) {
	my @arg = @{$_};
	if (!defined($::EMC::Group{$arg[0]})) {
	  error("index \'$arg[0]\' refers to an undefined group $line\n");
	}
	next if (!@arg[1] =~ m/[0-9]/);
	my $nconnects = ${$::EMC::Group{$arg[0]}}{nconnects};
	if (@arg[1]<1 && @arg[1]>$nconnects) {
	  error("index \'$_\' out of bounds $line\n");
	}
      }
    }
  }
}


sub group_connection {
  my @src = (shift(@_), shift(@_));
  my @dest = (shift(@_), shift(@_));
  my $group = $::EMC::Group{@src[0]};
  my $connect = ${${$group}{connect}}[@src[1]-1];

  foreach (@{$connect}) {
    return if (@{$_}[0] eq @dest[0] && @{$_}[1] eq @dest[1]);
  }
  push(@{$connect}, [@dest]);
}


# read references

sub read_references {
  my $name = shift(@_);
  my $suffix = shift(@_);
  my $stream;
  my @input;
  my %exist;
  my $data;
  my $i;

  return if (!fexist($name, @{$suffix}) && !defined($::EMC::Verbatim{references}));
  $::EMC::Reference{flag} = 1;
  if (defined($::EMC::Verbatim{references})) {
    $data = $::EMC::Verbatim{references};
    info("reading references from input\n", $name);
  } else {
    ($stream, $name) = fopen($name, "r", @{$suffix});
    info("reading references from \"%s\"\n", $name);
    $data = get_data($stream, \@input, 0);
  }
  foreach (keys(%{$::EMC::Reference{data}})) {
    $exist{$_} = 1;
  }
  foreach (@{$data}) {
    my @arg = split("\t", @{$_}[0]);
    my $line = shift(@arg) if (scalar($stream));
    @arg = split(",", @arg[0]) if (scalar(@arg)<2);
    if ((scalar(@arg)<8)||(scalar(@arg)>9)) {
      error("incorrect number of entries in line $line of input\n");
    }
    @arg[3] = @arg[3]**(1/3);
    for ($i=0; $i<1; ++$i) {
      next if ($exist{@arg[$i]});
      ($::EMC::InverseType{@arg[($i+1)%2]}, $::EMC::Type{@arg[$i]},
	$::EMC::Mass{@arg[$i]}, $::EMC::Cutoff{@arg[$i]}) = @arg[$i,1,2,3];
      @{${$::EMC::Reference{data}}{@arg[$i]}} = @arg;
    }
  }
  foreach (sort(keys(%exist))) {
    my $ref = ${$::EMC::Reference{data}}{$_};
    my $mass = $ref->[2];
    my $mtotal = 0;
    foreach (split("\\\+", $mass)) {
      my $f = 1;
      foreach (split("\\\*", $_)) {
	$f *= defined($::EMC::Mass{$_}) ? $::EMC::Mass{$_} : eval($_);
      }
      $mtotal += $f;
    }
    $::EMC::InverseType{$_} = $::EMC::Type{$_} = $_;
    $::EMC::Mass{$_} = $ref->[2] = $mtotal;
  }
  if (defined($::EMC::InverseType{$::EMC::Reference{type}})) {
    my @arg = @{${$::EMC::Reference{data}}{$::EMC::InverseType{$::EMC::Reference{type}}}};
    ($::EMC::Reference{mass}, $::EMC::Reference{length}) = @arg[2,3];
  }
  info(
    "references: mass = %g, length = %g\n",
    $::EMC::Reference{mass}, $::EMC::Reference{length});
  if ($::EMC::Field{type} eq "dpd") {
    info("rescaling references\n");
    foreach (keys(%{$::EMC::Reference{data}})) {
      my @arg = @{${$::EMC::Reference{data}}{$_}};
      @arg[2,3] = (
	$::EMC::Reference{mass}>0 ? @arg[2]/$::EMC::Reference{mass} : 1,
	$::EMC::Reference{length}>0 ? @arg[3]/$::EMC::Reference{length} : 1);
      @{${$::EMC::Reference{data}}{$_}} = @arg;
    }
  }
  close($stream) if (scalar($stream));
  create_replicas();
}


sub define_reference {
  my $cutoff = $::EMC::Reference{length}>0 ? $::EMC::Reference{length} : 1.0;

  foreach (@_) {
    next if (!length($_));
    next if ($_ =~ m/\*/);
    next if (defined($::EMC::Type{$_}));
    next if (defined(${$::EMC::Reference{data}}{$_}));

    ($::EMC::InverseType{$_}, $::EMC::Type{$_},
      $::EMC::Mass{$_}, $::EMC::Cutoff{$_}) = ($_, $_, 1, $cutoff);
    @{${$::EMC::Reference{data}}{$_}} = ($_, $_, 1, 1, 2, 0, 1, $_);
  }
}


sub replica_settings {
  my $i;
  my %default;
  my %settings;
  my $type = shift(@_);
  my @df = ("", 1, 0, 1, 1);
  my @id = ("type", "fraction", "norm", "a", "r");
  $i = 0; foreach (@id) { $settings{$_} = @df[$i++]; }

  $i = 0;
  foreach (split(":")) {
    my @a = split("=");
    if (scalar(@a)==1) {
      $settings{@id[$i]} = @a[0];
    } else {
      if (!defined($default{@a[0]})) {
	error("illegal keyword for replica '$type'.\n");
      }
      $settings{@a[0]} = @a[1];
    }
    last if (++$i==scalar(@id));
  }
  return %settings;
}


sub create_replicas {
  my $rm = ($::EMC::Reference{mass}>0 ? $::EMC::Reference{mass} : 1);
  my $rl = ($::EMC::Reference{length}>0 ? $::EMC::Reference{length} : 1);

  foreach (@::EMC::Replica) {
    my @arg = @{$_};
    next if (scalar(@arg)<2);
    my @a = split(":", shift(@arg));
    my $type = @a[0];
    my $factor = scalar(@a)>1 ? @a[1] : 1;
    @a = split(":", @arg[-1]);
    my $offset = defined($::EMC::InverseType{@a[0]}) ? 0 : pop(@arg);
    my $fmass = defined($::EMC::Mass{$type}) ? 0 : 1;
    my $norm = 1;
    my $n = 0;

    $::EMC::InverseType{$type} = $::EMC::Type{$type} = $type;
    $::EMC::Cutoff{$type} = 0;
    $::EMC::Mass{$type} = 0 if ($fmass);
    my @types;
    foreach (@arg) {
      my @a = split(":");
      my $t = shift(@a);
      if (!defined($::EMC::InverseType{$t})) {
	error("type $t is undefined.\n");
      }
      push(@types, $t);
      my $f = defined(@a[0]) ? eval(shift(@a)) : 1;
      my $flag = flag(defined(@a[0]) ? shift(@a) : 1);
      my $src = $::EMC::InverseType{$t};
      $f = 1 if ($f<=0);
      $norm = 0 if (!$flag);
      $::EMC::Cutoff{$type} += $f*$::EMC::Cutoff{$src};
      $::EMC::Mass{$type} += $f*($::EMC::Reference{mass}>0 ? $::EMC::Mass{$src} : 1) if ($fmass);
      $n += $f;
    }
    $n = 1 if ((!$n)||(!$norm));
    my $f = (scalar(@arg)>1 ? 1 : 0);
    @{${$::EMC::Reference{data}}{$type}} = (
      $type, $type, 
      $fmass ? ($::EMC::Mass{$type} /= $n)/$rm : $::EMC::Mass{$type}/$rm, 
      ($::EMC::Cutoff{$type} /= $n)/$rl,
      1, 0, 0, "replica of ".($f ? "{" : "").join(", ", @types).($f ? "}" :""));
  }
}


# read parameters

sub read_parameters {
  my $name = shift(@_);
  my $suffix = shift(@_);
  my $aij0 = $::EMC::PairConstants{a};
  my $r0 = $::EMC::PairConstants{r};
  my $gamma = $::EMC::PairConstants{gamma};
  my $flag_wild = 0;
  my $flag_set = 0;
  my $error = 0;
  my $first = 1;
  my $stream;
  my @input;
  my %sites;
  my $i;
  my $j;

  return if (!$::EMC::Field{write});
  if (!fexist($name, @{$suffix}) &&
      !$::EMC::Parameters{read} &&
      !defined($::EMC::Verbatim{parameters})) {
    return if (!scalar(@::EMC::Set));
    foreach (@::EMC::Set) {
      my @arg = @{$_};
      foreach (@arg[0,1]) { 
	$::EMC::Cutoff{$_} = $r0 if (!defined($::EMC::Cutoff{$_})); }
      next if (@arg[0] ne @arg[1]);
      $::EMC::Cutoff{@arg[0]} = @arg[3];
    }
    foreach (@::EMC::Set) {
      my @arg = @{$_};
      next if (scalar(@arg)<2);
      $sites{@arg[0]} = 1 if (length(@arg[0])>0);
      $sites{@arg[1]} = 1 if (length(@arg[1])>0);
      define_reference(@arg[0,1]) if (!$::EMC::Reference{flag});
      my $key = join(":", sort(@arg[0,1]));
      $flag_wild = 1 if ($key eq "*:*");
      my $lref = $::EMC::Reference{length};
      my @cutoff = ($::EMC::Cutoff{@arg[0]}, $::EMC::Cutoff{@arg[1]});
      my $correction =
	$lref>0 ? 0.5*(@cutoff[0]**3+@cutoff[1]**3)/$lref**3 : 1;
      my $aij = eval(@arg[2]);
      my $length = 
	scalar(@arg)>3 ? @arg[3] :
	$lref>0 ? 0.5*(@cutoff[0]+@cutoff[1])/$lref : 1;
      my $gamma = scalar(@arg)>4 ? eval(@arg[4]) : $::EMC::PairConstants{gamma};
      if (!$correction) {
	warning("missing cut off for @arg[0]\n"); $error = 1;
      } else {
	$aij = ($::EMC::Flag{chi}>0 ? $aij/0.286 : $aij-25)/$correction+25;
	@{$::EMC::Parameters{$key}} = ($aij, $length, $gamma);
      }
    }
    error("missing reference parameters\n") if ($error);
    $flag_set = 1;
  } else {
    my $data;

    if (defined($::EMC::Verbatim{parameters})) {
      info("reading parameters from input\n");
      $data = $::EMC::Verbatim{parameters};
    } else {
      ($stream, $name) = fopen($name, "r", @{$suffix});
      info("reading parameters from \"%s\"\n", $name);
      $data = get_data($stream, \@input, 0);
    }
    info("assuming %s parameters\n", $::EMC::Flag{chi} ? "chi" : "dpd");
    foreach (@{$data}) {
      my @arg = split("\t", @{$_}[0]);
      @arg = split(",", @{$_}[0]) if (scalar(@arg)<2);
      my $line = shift(@arg) if (scalar($stream));
      next if (substr(@arg[0],0,1) eq "#");
      next if (@arg[0] eq "");
      if ($first) {
	$first = 0; shift(@arg); shift(@arg);
	@::EMC::Temperatures = @arg;
	next;
      }
      $sites{@arg[0]} = 1 if (length(@arg[0])>0);
      $sites{@arg[1]} = 1 if (length(@arg[1])>0);
      define_reference(@arg[0,1]) if (!$::EMC::Reference{flag});
      next if (!defined($::EMC::Type{$arg[0]}));
      next if (!defined($::EMC::Type{$arg[1]}));
      my $key = join(":", sort(@arg[0,1]));
      my $length = $::EMC::Reference{length}>0 ? 
	0.5*($::EMC::Cutoff{@arg[0]}+$::EMC::Cutoff{@arg[1]})/
	     $::EMC::Reference{length} : 1;
      my $correction = $::EMC::Reference{length}>0 ? 
	0.5*($::EMC::Cutoff{@arg[0]}**3+$::EMC::Cutoff{@arg[1]}**3)/
	     $::EMC::Reference{length}**3 : 1;

      # note: correction is needed for the way DPD interaction parameters are 
      # calculated based on length; might need to be removed in future

      @arg[2] = eval(@arg[2]);
      if (!$correction) {
	warning("missing cut off for @arg[0]\n"); $error = 1;
      } else {
	@{$::EMC::Parameters{$key}} = (
	  ($::EMC::Flag{chi}>0 ? @arg[2]/0.286:@arg[2]-25)/$correction+25, $length, $::EMC::PairConstants{gamma});
      }
    }
    error("missing reference parameters\n") if ($error);
    close($stream) if (scalar($stream));
  }

  # Add replicas

  create_replicas() if (!$::EMC::Reference{flag});
  foreach (@::EMC::Replica) {
    my @arg = @{$_};
    next if (scalar(@arg)<2);
    my @a = split(":", shift(@arg));
    if ($sites{@a[0]}) {
      warning("replica parameter %s already exists\n", @a[0]);
      next;
    }
    my $type = @a[0];
    my $factor = scalar(@a)>1 ? @a[1] : 1;
    @a = split(":", @arg[-1]);
    my $offset = defined($::EMC::InverseType{@a[0]}) ? 0 : pop(@arg);
    my $flag_exist = 0;
    my $flag_norm = 1;
    my @n = (0, 0, 0);
    my $count = 0;
    my @types;
    my @p;

    info("adding parameter $type using {%s}\n", join(", ", @arg));
    foreach (@arg) {
      my @a = split(":");
      $flag_norm = 0 if (!(defined(@a[2]) ? flag(@a[2]) : 1));
    }
    foreach (@arg) {
      my @a = split(":");				# create self
      my $t = shift(@a);
      my $frac = defined(@a[0]) ? eval(shift(@a)) : 1;

      push(@types, $t);
      $t = $::EMC::InverseType{$t};
      if (defined($::EMC::Parameters{join(":", $t, $t)})) {
	my @q = @{$::EMC::Parameters{join(":", $t, $t)}};
	@q[1] = 1 if (!@q[1]);
	my $i; for ($i=0; $i<3; ++$i) { 
	  my $f = ($i ? 1 : 1/@q[1]**3);
	  @n[$i] += $f*($flag_norm ? ($i ? $frac : 1/$frac) : 1);
	  @p[$i] += $f*@q[$i]*($i ? $frac : 1/$frac);
       	}
	$flag_exist = 1;
	++$count;
      }
    }
    if ($flag_exist) {
      my $i; for ($i=0; $i<3; ++$i) {
	@p[$i] *= $count if (!$flag_norm);
	@p[$i] /= @n[$i];
      }
      @p[2] = $gamma;
      @p[0] = (@p[0]-$aij0)*$factor+$aij0;
      @{$::EMC::Parameters{join(":", $type, $type)}} = @p;
      foreach (@types) { 
	@{$::EMC::Parameters{join(":", sort($type, $_))}} = @p;
      }
    }
    my $target = $::EMC::InverseType{@types[0]};
    foreach(sort(keys(%::EMC::Parameters))) {		# create others
      my @a = split(":");
      my $other = @a[0] eq $target ? @a[1] : @a[1] eq $target ? @a[0] : "";
      next if ($other eq "" || $other eq $type);
      my @n;
      my @p;

      $count = 0;
      foreach (@arg) {
	my @a = split(":");
	my $t = shift(@a);
	my $frac = defined(@a[0]) ? eval(shift(@a)) : 1;
	my $src = join(":", sort($other, $::EMC::InverseType{$t}));
	my @q = @{$::EMC::Parameters{$src}};
	
	my $i; for ($i=0; $i<scalar(@q); ++$i) { 
	  my $f = ($i ? 1 : 1/@q[1]**3);
	  @n[$i] += $f*($flag_norm ? ($i ? $frac : 1/$frac) : 1);
	  @p[$i] += $f*@q[$i]*($i ? $frac : 1/$frac);
       	}
	++$count;
      }
      my $i; for ($i=0; $i<3; ++$i) {
	@p[$i] *= $count if (!$flag_norm);
	@p[$i] /= @n[$i];
      }
      @p[2] = $gamma;
      @p[0] = (@p[0]-$aij0)*$factor+$aij0+$offset;
      @{$::EMC::Parameters{join(":", sort($other, $type))}} = @p;
      $sites{$type} = 1;
    }
  }
  if (!$flag_set) {					# create missing

    my $length = $::EMC::Reference{length}>0 ? $::EMC::Reference{length} : 1.0;
    
    foreach (@::EMC::Set) {
      my @v = @{$_};
      next if (scalar(@v)<2);
      my @b = (shift(@v), shift(@v));
      my @a = sort(@b); foreach (@a) { 
	$_ = defined($::EMC::InverseType{$_}) ? $::EMC::InverseType{$_} :
	     ($_ =~ m/\*/) ? $_ : $_;
      }
      my $key = join(":", @a);
      if (defined($::EMC::InverseType{@v[0]})) {
	@b = sort(@v[0,1]);
	my $source =  join(
	  ":", $::EMC::InverseType{@b[0]}, $::EMC::InverseType{@b[1]});
	if (defined($::EMC::Parameters{$key}) && 
	    defined($::EMC::Parameters{$source}))
	{
	  info("setting pair {%s} to {%s}\n", join(", ", @a), join(", ", @b));
	  @{$::EMC::Parameters{$key}} = @{$::EMC::Parameters{$source}};
	}
      }
      elsif (defined($::EMC::Parameters{$key})) {
	my @p = @{$::EMC::Parameters{$key}};
	my $i; for ($i=0; $i<scalar(@v); ++$i) { @p[$i] = @v[$i]; }
	info("setting pair {%s} to {%s}\n", join(", ", @a), join(", ", @p));
	@{$::EMC::Parameters{$key}} = @p;
      }
      else {
	define_reference(@a);
	my @p = ($aij0, $length, $::EMC::PairConstants{gamma});
	my $i; for ($i=0; $i<scalar(@v); ++$i) { @p[$i] = @v[$i]; }
	info("setting pair {%s} to {%s}\n", join(", ", @a), join(", ", @p));
	@{$::EMC::Parameters{$key}} = @p;
      }
    }
  }
  @::EMC::Sites = ();
  foreach(sort(keys(%sites))) {
    next if (!defined($sites{$_}));
    if ($::EMC::Reference{flag} && !defined($::EMC::Type{$_})) {
      warning(
	"omitted type \'$_\' (not defined in first column of ".
	"$::EMC::Reference{name}.csv)\n");
      next;
    }
    push(@::EMC::Sites, $_) if ($_ ne "*");
  }
  if ($::EMC::Flag{assume}) {
    for ($i = 0; $i<scalar(@::EMC::Sites); ++$i) {
      my $pair = join(":", @::EMC::Sites[$i,$i]);
      my $cutoff = $::EMC::Cutoff{@::EMC::Sites[$i]};
      if (!scalar(@{$::EMC::Parameters{$pair}})) {
	@{$::EMC::Parameters{$pair}} = ($aij0, $cutoff, $::EMC::PairConstants{gamma});
      }
    }
  }
  for ($i = 0; $i<scalar(@::EMC::Sites); ++$i) {
    for ($j = $i; $j<scalar(@::EMC::Sites); ++$j) {
      my $a = $::EMC::Sites[$i];
      my $b = $::EMC::Sites[$j];
      my $pair = join(":", $a, $b);
      next if ($flag_wild && $a eq $b);
      if (!defined($::EMC::Parameters{$pair}) || 
	  !scalar(@{$::EMC::Parameters{$pair}})) {
	warning("missing parameters for pair {%s, %s}\n", $a, $b);
      }
    }
  }
  if (${$::EMC::Field{dpd}}{bond})
  {
    info("transfering nonbond to bond parameters\n");
    foreach (sort(keys(%::EMC::Parameters)))
    {
      my @t = split(":");
      next if (scalar(@t)!=2);
      next if (defined($::EMC::Bonds{join("\t",@t)}));
      $::EMC::Bonds{join("\t",@t)} = join("\t",@{$::EMC::Parameters{$_}}[0,1]);
    }
  }
  if (scalar(@{$::EMC::FieldList{name}})) {
    info("replacing field name with project name\n");
  }
  @{$::EMC::FieldList{name}} = ($::EMC::Project{name});
  $::EMC::Field{name} = $::EMC::Field{id} = $::EMC::Project{name};
  $::EMC::Field{location} = "./";
  $::EMC::Parameters{flag} = 1;
  $::EMC::Field{type} = "dpd";
  update_fields("reset");
}


# EMC output

sub write_emc {
  return if (!$::EMC::EMC{write});

  my $name = shift(@_);
  
  if ((-e "$name.emc")&&!$::EMC::Replace{flag}) {
    warning("\"$name.emc\" exists; use -replace flag to overwrite\n");
    return;
  }

  info("creating EMC build script \"$name.emc\"\n");

  my $stream = fopen("$name.emc", "w");

  write_emc_header($stream);
  write_emc_variables_header($stream);
  write_emc_field($stream);
  write_emc_import($stream);
  printf($stream "\n") if (write_emc_verbatim($stream, "build", 0, 0));
  write_emc_groups($stream);
  write_emc_field_apply($stream);
  printf($stream "\n") if (write_emc_verbatim($stream, "build", 0, 1));
  write_emc_variables_sizing($stream);
  printf($stream "\n") if (write_emc_verbatim($stream, "build", 0, 2));
  write_emc_import_variables($stream);
  write_emc_simulation($stream);
  my $iphase = 0;
  foreach (@::EMC::Phases) {
    write_emc_phase($stream, ++$iphase, @$_);
  }
  printf($stream "\n") if (write_emc_verbatim($stream, "build", $iphase+1));
  write_emc_run($stream);
  write_emc_profile($stream);
  write_emc_focus($stream);
  write_emc_store($stream);
  close($stream);
}


sub write_emc_header {
  my $stream = shift(@_);
  my $date = date;

  chop($date);
  #printf($stream "#!/usr/bin/env emc$::EMC::EMC{suffix}\n(* EMC: Script *)
  printf($stream "(* EMC: Script *)

(* Created by $::EMC::Script v$::EMC::Version, $::EMC::Date
   on $date *)

");
}


sub write_emc_variables {
  my $stream = shift(@_);
  my @variables = @_;
  my $n = scalar(@variables);
  my $i;

  while (scalar(@variables) && @variables[-1] eq "") {
    pop(@variables); --$n;
  }
  return if (!scalar(@variables));
  printf($stream "variables\t= {\n");
  for ($i = 0; $i<$n; ++$i) {
    printf($stream "%s", format_output($i<$n-1, $variables[$i], 2, 2));
  }
  printf($stream "\n};\n\n");
}


@::EMC::Restricted = (

  # used in EMC script

  "seed", "ntotal", "fshape", "output", "field", "location", "nav", 
  "temperature", "radius", "nrelax", "weight_nonbonded", "weight_bonded",
  "weight_focus", "kappa", "cutoff", "inner_cutoff", "charge_cutoff",
  "nsites", "mass", "lbox", "lx", "ly", "lz", "nx", "ny", "nz", "all",
  "niterations",
  
  # used in generated BASH scripts

  "window", "dir", "last", "serial", "restart", "frestart", "fnorestart",
  "fwait", "femc", "freplace", "fbuild", "project", "chemistry", "home");

@::EMC::RestrictedGroup = ("random", "block", "alternate", "import");
@::EMC::RestrictedStart = ("density", "pressure", "nphase", "lphase");

sub write_emc_variables_header {
  my $stream = shift(@_);
  my @fields;
  my @locations;
  my %id = ();
  my $i = 0;
  my @flag;
  
  foreach (sort(keys(%::EMC::Fields))) {
    my $s = $::EMC::Fields{$_}->{location};
    my $i = $::EMC::Fields{$_}->{ilocation};
    next if (@flag[$i]);
    my $location = substr($s,0,1) eq "\$" ? $s :
		   substr($s,-1,1) eq "/" ? "\"$s\"" : "\"$s/\"";
    push(@locations, "location".($i ? $i : "")." $location");
    @flag[$i] = 1;
  }
  foreach (@{$::EMC::FieldList{name}}) {
    $id{$::EMC::FieldList{id}->{$_}} = $_;
  }
  foreach (sort(keys(%id))) {
    push(@fields, "field".($i ? $i : "")." \"$id{$_}\""); ++$i;
  }
  my @variables = (
    "seed $::EMC::Seed",
    "ntotal $::EMC::NTotal",
    "fshape $::EMC::Shape",
    "output \"$::EMC::Project{name}\"",
    @fields, @locations,
    "",
    "nav $::EMC::NAv",
    "temperature $::EMC::Temperature",
    "radius $::EMC::Build{radius}",
    "nrelax $::EMC::Build{nrelax}",
    "weight_nonbond ${$::EMC::Build{weight}}{nonbond}",
    "weight_bond ${$::EMC::Build{weight}}{bond}",
    "weight_focus ${$::EMC::Build{weight}}{focus}",
    "cutoff $::EMC::CutOff{pair}"
  );
  my $i;
 
  printf($stream "(* define variables *)\n\n");
  push(@variables, "core $::EMC::Core") if ($::EMC::Core>=0);
  push(@variables, "inner_cutoff $::EMC::CutOff{inner}") if ($::EMC::CutOff{inner}>=0);
  push(@variables, "charge_cutoff $::EMC::CutOff{charge}") if ($::EMC::Flag{charge});
  push(@variables, "kappa $::EMC::Kappa") if ($::EMC::Flag{charge});
  if (${$::EMC::EMC{run}}{ncycles}) {
    push(@variables, "");
    my $ptr = $::EMC::EMC{run};
    foreach ("nblocks", "nequil", "ncycles") {
      next if ($_ eq "flag");
      push(@variables, "$_ ${$ptr}{$_}") if (${$ptr}{$_});
    }
    $ptr = $::EMC::EMC{traject};
    push(@variables, "ntraject ${$ptr}{frequency}") if (${$ptr}{frequency});
  }
  if (defined($::EMC::Import{name})) {
    push(@variables, "");
    push(@variables, "import $::EMC::Import{filename}");
    push(@variables, "n$::EMC::Direction{x} $::EMC::Import{nx}");
  }
  if ($::EMC::NPhases) {
    push(@variables, "");
    for ($i = 1; $i<=$::EMC::NPhases; ++$i) { 
      push(@variables, "density$i $::EMC::Densities[$i-1]");
    }
    push(@variables,
      "lprevious 0",
      "lphase 0"
    );
  }
  if ($::EMC::Flag{omit}) {
    info("omitting chemistry file fractions\n");
  }
  elsif (scalar(@::EMC::Clusters)) {			# set fractions
    $i = 0;
    push(@variables, "");
    foreach (@::EMC::Clusters) {
      push(@variables, "f_$_ $::EMC::Fractions[$i++]");
    }
  }
  if (scalar(@::EMC::Groups)) {
    $i = 0;						# set chemistries
    push(@variables, "");
    foreach (@::EMC::Groups) {
      push(@variables, "chem_$_ \"".${$::EMC::Group{$_}}{chemistry}."\"");
    }
  }
  if (defined($::EMC::Variables{data})) {
    my @vars;
    foreach (@{$::EMC::Variables{data}}) {
      my @a = @{$_};
      my $var = shift(@a);
      push(@vars, "$var ".join(", ", @a));
      foreach (@variables) {
	my @b = split(" ");
	next if ($::EMC::Flag{expert});
	error("cannot redefine existing variable @b[0]\n") if ($var eq @b[0]);
      }
    }
    if ($::EMC::Variables{type} == 0) {
      unshift(@variables, @vars, "");
    } else {
      
      push(@variables, "", @vars);
    }
  }
  write_emc_variables($stream, @variables);

  #return;

  # bypassed: influences importing of multiple field entries
  # happens when moe than one command appears before importing fields

  my $i = 0;
  my $n = scalar(keys(%{$::EMC::EMC{output}}));

  printf($stream "output\t\t= {\n");
  foreach (sort(keys(%{$::EMC::EMC{output}}))) {
    if ($_ eq "flag") {
      --$n; next
    }
    my $option = "$_ ".boolean(${$::EMC::EMC{output}}{$_});
    printf($stream "%s", format_output(++$i<$n, $option, 2, 2));
  }
  printf($stream "\n};\n\n");
}


sub write_emc_variables_polymer {
  my $var = shift(@_);
  my $poly = shift(@_);
  my $name = shift(@_);
  my $t = shift(@_);
  my $int = shift(@_);
  my $skip = shift(@_);
  my $i = shift(@_);
  my $npolys = scalar(@{$poly});

  if (scalar(@{$poly})>1 ? 0 :				# regular clusters
      scalar(@{@{@{$poly}[0]}[2]})>1 ? 0 :
      @{@{@{$poly}[0]}[1]}[0]>1 ? 0 : 
      scalar(split(":", @{@{@{$poly}[0]}[2]}[0]))>1 ? 0 : 1
    ) {
    return if ($int);
    push(@{$var}, $t."_$name ".$t."g_@{@{@{$poly}[0]}[2]}[0]");
    push(@{$var}, "norm_$name ".@{@{$poly}[0]}[0]);
  } else {
    my $f = 1;
    if (1||scalar(@{$poly})>1) {			# polymers
      my $norm = ""; $f = 0;
      push(@{$var}, "") if ($i);
      if (!$int) {
	foreach (@{$poly}) {
	  $norm .= ($norm eq "" ? "" : "+").
		   ($int ? "int(@{$_}[0]*n_$name)" : @{$_}[0]);
	}
	push(@{$var}, "norm_$name $norm") if (!$int);
	push(@{$var}, "norm $norm") if ($int);
	push(@{$var}, "");
      }
      push(@{$var}, $t."_$name 0") if ($npolys>1);
    }
    foreach (@{$poly}) {
      my $fraction = @{$_}[0];
      my @n = @{@{$_}[1]};
      my @groups = @{@{$_}[2]};
      my @weights = @{@{$_}[3]};
      my $result;
      $i = -1; 
      if (!$skip) {
	foreach (@groups) {
	  my $m = $n[++$i];
	  next if ($::EMC::Flag{expert}? 0 : !$m);
	  my $v;
	  my @g = split(":", $_);
	  my @w = split(":", @weights[$i]);
	  if (scalar(@g)>1) {
	    my @a;
	    my $s;
	    my $i = 0;
	    my $fnumber = 1;
	    foreach (@w) { 
	      if (number($_)) { $_ = eval($_); } else { $fnumber = 0; } }
	    foreach (@w) {
	      my $u = $_;
	      if ($fnumber) { $s += $u; } else {
		if ($u =~ /\+/ || $u =~ /\-/) { $u = "($u)"; }
		$s .= $s eq "" ? $u : "+$u";
	      }
	    }
	    $s = 1.0 if ($fnumber && !$s);
	    foreach (@g) {
	      my $u = @w[$i++];
	      if (!number($u) && ($u =~ /\+/ || $u =~ /\-/)) { $u = "($u)"; }
	      push(@a, $u."*".$t."g_$_");
	    }
	    $v = "(".join("+", @a).")";
	    $v .= "/($s)" if (!$fnumber);
	    $v .= "/$s" if ($fnumber && $s!=1);
	  } else {
	    $v = $t."g_$_";
	  }
	  $result .= ($result eq "" ? "" : "+").(
	    $::EMC::Flag{expert} ? "$m*" : $m>1 ? "$m*" : "").$v;
	}
	next if ($result eq "");
      }
      push(@{$var}, $t."_$name ".
	($npolys>1 ? $t."_$name+" : "").
	($f ? $result :
	  ($i>0 ? "($result)" : $result).
	  ($result eq "" ? "" : "*").
	  ($int ? "int($fraction*n_$name/norm_$name+0.5)" : "$fraction").
	  ($int ? "" : "/norm_$name")));
    }
  }
}


sub write_emc_variables_sizing {
  my $stream = shift(@_);
  my $nclusters = scalar(@::EMC::Clusters);
  my $ngroups = scalar(@::EMC::Groups);
  my $flag_polymer = 0;
  my %groups = ();
  my @variables;
  my $ntotal;
  my $mtotal;
  my $vtotal;
  my $i;
  my $s;
  my $n;
  
  foreach (@::EMC::Clusters) {
    if (!defined($::EMC::Polymer{$_})) {
      error("missing polymer definition for cluster '$_'\n");
    }
    my $poly = $::EMC::Polymer{$_};
    last if (($flag_polymer = scalar(@{$poly})>1 ? 1 :
			      scalar(@{@{@{$poly}[0]}[1]})>1 ? 1 : 0));
  }
	
  # lengths

  if ($ngroups||$nclusters) {
    push(@variables, "");
    push(@variables, "(* lengths *)\n");
    if ($ngroups) {
      foreach (@::EMC::Groups) {
	push(@variables, "lg_$_ nsites(${$::EMC::Group{$_}}{id})");
      }
    }
    if ($nclusters) {
      $i = 0;
      foreach (@::EMC::Clusters) {
	write_emc_variables_polymer(
	  \@variables, $::EMC::Polymer{$_}, $_, "l", 0, 0, $i++);
      }
    }
  }

  # masses

  if ($::EMC::Flag{mol}||$::EMC::Flag{mass}||$::EMC::Flag{number}||$::EMC::Flag{volume}) {
    if ($ngroups) {
      push(@variables, "");
      push(@variables, "(* masses *)\n");
      foreach (@::EMC::Groups) {
	my $mass = ${$::EMC::Group{$_}}{mass};
	push(@variables, "mg_$_ ".($mass eq "" ? "mass(${$::EMC::Group{$_}}{id})" : $mass));
      }
    }
    if ($nclusters) {
      $i = 0;
      push(@variables, "");
      foreach (@::EMC::Clusters) {
	if ($::EMC::MolMass[$i]) {
	  push(@variables, "m_$_ ".$::EMC::MolMass[$i++]);
	} else {
	  write_emc_variables_polymer(
	    \@variables, $::EMC::Polymer{$_}, $_, "m", 0, 0, $i++);
	}
      }
    }
  }

  # volumes

  if ($::EMC::Flag{volume} && $nclusters) {
    push(@variables, "");
    push(@variables, "(* volumes *)\n");
    $i = 0;
    foreach (@::EMC::Clusters) {
      if (!$::EMC::MolVolume[$i]) {
	error("volume not set in $::EMC::Script{name}$::EMC::Script{extension} for \'$_\'\n");
      }
      push(@variables, "v_$_ $::EMC::MolVolume[$i++]");
    }
  }

  # fractions

  if ($nclusters) {
    push(@variables, "");
    if ($::EMC::Flag{mol}) {				# mol fractions
      info("assuming mol fractions\n");
      push(@variables, "(* mol fractions *)\n");
      foreach (@::EMC::Clusters) {
	push(@variables, "f_$_ f_$_*l_$_");
      }
    }
    elsif ($::EMC::Flag{mass}) {			# mass fractions
      info("assuming mass fractions\n");
      push(@variables, "(* mass fractions *)\n");
      foreach (@::EMC::Clusters) {
	push(@variables, "f_$_ f_$_*l_$_/m_$_");
      }
    }
    elsif ($::EMC::Flag{volume}) {			# volume fractions
      info("assuming volume fractions\n");
      push(@variables, "(* volume fractions *)\n");
      foreach (@::EMC::Clusters) {
	push(@variables, "f_$_ f_$_*v_$_/m_$_");
      }
    }
  }

  # normalization

  if (scalar(@::EMC::Fractions) && !$::EMC::Flag{number})
  {
    $i = 0;
    $s = "";
    push(@variables, "");
    push(@variables, "(* normalization *)\n");
    foreach (@::EMC::Fractions) {
      $s .= ($i>0 ? "+" : "")."f_".$::EMC::Clusters[$i++];
    }
    push(@variables, "norm $s") if ($s ne "");
    push(@variables, "");
    $i = 0;
    foreach (@::EMC::Fractions) {
      $s = $::EMC::Clusters[$i++];
      push(@variables, "f_$s f_$s/norm");
    }
  }

  # determine nmols

  if ($nclusters) {
    $i = 0;
    push(@variables, "");
    push(@variables, "(* sizing *)\n");
    foreach (@::EMC::Clusters) {
      if ($::EMC::Flag{number}) {
	push(@variables, "n_".$::EMC::Clusters[$i++]." f_$_");
      } else {
	push(@variables, "n_".$::EMC::Clusters[$i++]." int(f_$_*ntotal/l_$_+0.5)");
      }
    }
  }

  # polymer rescale

  if ($flag_polymer && $nclusters) {
    $i = 0;
    push(@variables, "");
    foreach (@::EMC::Clusters) {
      my $poly = $::EMC::Polymer{$_};
      next if (scalar(@{$poly})>1 ? 0 : 1);
      write_emc_variables_polymer(
	\@variables, $::EMC::Polymer{$_}, $_, "tmp_n", 1, 1, $i++);
      push(@variables, "n_$_ tmp_n_$_");
      write_emc_variables_polymer(
	\@variables, $::EMC::Polymer{$_}, $_, "m", 1, 0, $i++);
      push(@variables, "m_$_ n_$_ ? m_$_/n_$_ : 0");
      write_emc_variables_polymer(
	\@variables, $::EMC::Polymer{$_}, $_, "l", 1, 0, $i++);
      push(@variables, "l_$_ n_$_ ? l_$_/n_$_ : 0");
    }
  }

  push(@variables, "");
  push(@variables, "(* system sizing *)\n");
  push(@variables, "ntotal 0");
  push(@variables, "mtotal 0");

  # write variables

  if (scalar(@variables)) {
    printf($stream "(* determine simulation sizing *)\n\n");
    write_emc_variables($stream, @variables);
  }
}


sub write_emc_field {
  my $stream = shift(@_);
  my $n = scalar(keys(%::EMC::Fields));
  my $pos = $n>1 ? 4 : 2;
  my $none = 1;
  my $i = 0;

  printf($stream "(* define force field *)\n\n");
  printf($stream "field\t\t= {\n");
  foreach (sort(keys(%::EMC::Fields))) {
    my $ptr = $::EMC::Fields{$_};
    my $id = $ptr->{id};
    my $name = $ptr->{name};
    my $mode = $ptr->{type};
    my $location = $ptr->{location};
    my $ilocation = $ptr->{ilocation} ? $ptr->{ilocation} : "";
    my $pre = "location$ilocation+field".($i ? $i : "");
    my $style = $ptr->{style} ne "" ? $ptr->{style} :
		$none ? (++$i<$n ? "template" : "none") : "template";

    $none = 0 if ($style eq "none");
    printf($stream "  {\n") if ($n>1);
    printf($stream "%s,\n", format_output(0, "id $id", $pos, 2));
    printf($stream "%s,\n", format_output(0, "mode $mode", $pos, 2));
    if ($::EMC::Field{type} eq "get") {
      printf($stream "%s\n",
	format_output(0, "name $pre+\"$name.field\"", $pos, 2));
    } elsif ($::EMC::Field{type} eq "cff") {
      printf($stream "%s,\n", 
	format_output(0, "name {$pre+\".frc\", ".
	  "$pre+\"_templates.dat\"}", 4, 2));
    } elsif (-f "$::EMC::Root/field/$name.top" ||
	-f ($location ne "" ? "$location/" : "")."$name.top" ||
	$::EMC::Flag{rules}) {
      printf($stream "%s,\n",
	format_output(0, "name {$pre+\".prm\", $pre+\".top\"}", $pos, 2));
    } else {
      printf($stream "%s,\n",
	format_output(0, "name $pre+\".prm\"", $pos, 2));
    }
    printf($stream "%s\n", format_output(0, "compress false", $pos, 2));
    printf($stream "  }%s\n", $i<$n ? "," : "") if ($n>1);
  }
  printf($stream "};\n\n");
}


sub write_emc_groups {
  my $stream = shift(@_);
  my $n = scalar(@::EMC::Groups);
  my $i = 0;

  return if (!scalar(@::EMC::Groups));

  printf($stream "(* define groups *)\n\n");
  printf($stream "groups\t\t= {\n");
  foreach (@::EMC::Groups) {
    my $field;
    my $name = $_;
    my $id = $::EMC::Group{$name}{id};
    my $terminator = ${$::EMC::Group{$name}}{terminator};

    printf($stream format_output(0, "group {", 2, 2));
    printf($stream "\n");
    if (!$::EMC::Group{$name}{polymer}) {
      my @fields = @{$::EMC::Group{$name}{field}};
      if (scalar(@fields)>1) { $field = "{".join(", ", @fields)."}"; }
      elsif (scalar(@fields)==1) { $field = "@fields[0]"; }
    }
    if ($::EMC::Group{$name}{polymer}) {
      if (!defined($::EMC::Polymer{$name})) {
	error("polymer $name is not defined\n");
      }
      my $poly = $::EMC::Polymer{$name};
      my $flag = @{@{$poly}[0]}[5];
      printf($stream format_output(1, "id $id", 4, 2));
      printf($stream format_output(1, "fraction ${$flag}{fraction}, order -> ${$flag}{order}, bias -> ${$flag}{bias}", 4, 2));
      printf($stream format_output(1, "terminator true", 4, 2)) if ($terminator);
      printf($stream format_output(0, "polymers {", 4, 2));
      write_emc_polymers($stream, "group", $name);
      printf($stream "\n    }\n  }%s", $i++<$n-1 ? ",\n" : "");
    } elsif ($::EMC::Group{$name}{nconnects}) {
      my $j = 0;
      my $connect = ${$::EMC::Group{$name}}{connect};
      my $nconnects = ${$::EMC::Group{$name}}{nconnects};
      
      printf($stream format_output(1, "id $id, depth -> $::EMC::EMC{depth}, chemistry -> chem_$name", 4, 2));
      printf($stream format_output(1, "field $field", 4, 2)) if ($field ne "");
      printf($stream format_output(1, "terminator true", 4, 2)) if ($terminator);
      printf($stream format_output(0, "connects {", 4, 2));

      printf($stream "\n");
      foreach (@{${$::EMC::Group{$name}}{connect}}) {
	my @connect = @{$_}; ++$j;
	my $k = scalar(@connect);
	--$nconnects;
	foreach (sort({@{$a}[0] cmp @{$b}[0]} @connect)) {
	  my @arg = @{$_};
	  if (@arg[1] =~ m/[0-9]/) {
	    printf($stream 
	      format_output($nconnects ? 1 : --$k ? 1 : 0, 
		"{source \$end$j, destination -> {$arg[0], \$end$arg[1]}}",
	       	6, 2));
	  } else {
	    printf($stream 
	      format_output($nconnects ? 1 : --$k ? 1 : 0, 
		"{source \$end$j, element -> \"$arg[1]\",".
		"destination -> $arg[0]}", 6, 2));
	  }
	}
      }
      printf($stream "\n    }\n  }%s", $i++<$n-1 ? ",\n" : "");
    } else {
      printf($stream format_output(1, "id $id", 4, 2));
      printf($stream format_output(1, "depth $::EMC::EMC{depth}", 4, 2));
      #printf($stream format_output(1, "terminator true", 4, 2)) if ($terminator);
      printf($stream format_output(1, "field $field", 4, 2)) if ($field ne "");
      printf($stream format_output(0, "chemistry chem_$name", 4, 2));
      printf($stream "\n".format_output($i++<$n-1, "}", 2, 2));
    }
  }
  printf($stream "\n};\n\n");
}


sub write_emc_polymers {
  my $stream = shift(@_);
  my $typ = shift(@_);
  my $name = shift(@_);
  my $n = shift(@_);
  my $poly = $::EMC::Polymer{$name};
  my $npolys = scalar(@{$poly});
  my $flag = $npolys>1 ? 1 : 0;
  my %level = (cluster => 4, group => 8);
  my $ipoly = 0;
  my $lvl;

  if (!defined($level{$typ})) {
    error("unsupported polymer type '$typ'.\n");
  }
  $lvl = $level{$typ};
  foreach (@{$poly}) {
    my $i;
    my @g;
    my @w;
    my $fraction = @{$_}[0];
    my $nrepeats = join(", ", @{@{$_}[1]});
    my $groups = join(", ", create_emc_groups(@{@{$_}[2]}));
    my $weights = join(", ", create_emc_groups(@{@{$_}[3]}));
    my $type = @{$_}[4];
    
    if ($typ eq "group") {
      printf($stream "\n") if ($ipoly<1);
      printf($stream "%s\n", format_output(0, "{", $lvl-2, 2));
      printf($stream "%s", format_output(1, "index ".$ipoly++, $lvl, 2));
      printf($stream "%s", format_output(1, "fraction $fraction", $lvl, 2));
      printf($stream "%s", format_output(1, "type $type", $lvl, 2));
    } else {
      my $id = $name.($flag ? "_".++$ipoly : "");
      printf($stream "%s\n", format_output(0, "polymer {", $lvl-2, 2));
      printf($stream "%s", format_output(1, "id $id, system -> $::EMC::System{id}, type -> $type", $lvl, 2));
      printf($stream "%s", format_output(1, "n int($fraction*n_$name/norm_$name+0.5)", $lvl, 2));
    }
    printf($stream "%s", format_output(1, "niterations $::EMC::PolymerFlag{niterations}", $lvl, 2)) if ($::EMC::PolymerFlag{niterations}>0);
    printf($stream "%s", format_output(1, "groups {$groups}", $lvl, 2));
    printf($stream "%s", format_output(1, "weights {$weights}", $lvl, 2));
    printf($stream "%s", format_output(0, "nrepeat {$nrepeats}", $lvl, 2));
    printf($stream "\n%s", format_output(0, "}", $lvl-2, 2));
    printf($stream ",\n") if (--$npolys || $n);
  }
}


sub write_emc_field_apply {
  my $stream = shift(@_);
  my $mode = shift(@_); $mode = "repulsive" if ($mode eq "");
  my @types = (
    "angle", "torsion", "improper", "increment", "group", "debug", "error");
  my %debug = (
    full => 1, reduced => 1, false => 1);

  #printf($stream "(* apply force field *)\n\n");
  printf($stream "field\t\t= {\n");

  printf($stream "%s", format_output(1, "mode apply", 2, 2));
  printf($stream "%s\n", format_output(0, "check {", 2, 2));
  printf($stream "%s", format_output(1, "atomistic ".boolean($::EMC::FieldFlag{check}), 4, 2));
  printf($stream "%s\n  }", format_output(0, "charge ".boolean($::EMC::FieldFlag{charge}), 4, 2));
  foreach (@types) {
    if (($_ eq "debug" && defined($debug{$::EMC::FieldFlag{$_}})) ||
        (defined($::EMC::FieldFlags{$::EMC::FieldFlag{$_}}))) {
      printf($stream ",\n%s",
       	format_output(0, "$_ $::EMC::FieldFlag{$_}", 2, 2));
    }
  }
  printf($stream "\n");
  printf($stream "};\n\n");
  if ($::EMC::FieldFlag{debug} ne "false") {
    printf($stream "put\t\t= {name -> \"debug\"};\n\n");
  }
  #return if (!$::EMC::FieldFlags{ncalls}++);
  $::EMC::FieldFlags{ncalls}++;
}


sub write_emc_interaction {
  my $stream = shift(@_);
  my $mode = shift(@_); $mode = "repulsive" if ($mode eq "");
  my $field_exclude = $::EMC::Field{type} eq "dpd" ||
		      $::EMC::Field{type} eq "colloid" ? 1 : 0;
  my $flag = ($::EMC::Flag{exclude} &&
	      $::EMC::Import{exclude} eq "box" &&
	      defined($::EMC::Import{name}) &&
	      $::EMC::Import{type} eq "surface" &&
	      $::EMC::FieldFlags{ncalls}>1) ? 1 : 0;
  my $ptr = $::EMC::Build{cluster};

  return if ($field_exclude && !$flag);
  
  printf($stream "types\t\t= {\n");
  if (!$field_exclude) {
    printf($stream "%s\n", format_output(0, "$::EMC::Field{type} {", 2, 2));
    if ($::EMC::CutOff{inner}>0) {
      printf($stream "%s\n", 
	format_output(0, "pair {active -> true, mode -> $mode, ", 4, 2));
      printf($stream "%s\n", 
	format_output(0, "inner inner_cutoff, cutoff -> cutoff}", 20, 2));
    } elsif ($::EMC::Core>=0) {
      printf($stream "%s\n", 
	format_output(0, "pair {active -> true, mode -> $mode, ", 4, 2));
      printf($stream "%s\n", 
	format_output(0, "core core, cutoff -> cutoff}", 20, 2));
    } else {
      printf($stream "%s\n", 
	format_output(0, "pair {active -> true, mode -> $mode, cutoff -> cutoff}", 4, 2));
    }
    printf($stream "%s", format_output(0, "}", 2, 2));
  }
  if ($flag) {
    printf($stream ",\n") if (!$field_exclude);
    write_emc_region($stream);
  } else {
    printf($stream "\n");
  }
  printf($stream "};\n\n");
}


sub write_emc_moves_cluster {
  my $stream = shift(@_);
  my $comma = shift(@_);
  my $ptr = $::EMC::Moves{cluster};
  my $limit = join(", ", split(":", ${$ptr}{limit}));
  my $max = join(", ", split(":", ${$ptr}{max}));
  my $min = join(", ", split(":", ${$ptr}{min}));

  printf($stream "%s\n", format_output(0, "cluster {", 2, 2));
  printf($stream "%s", format_output(1, "active true", 4, 2));
  printf($stream "%s", format_output(1, "frequency ${$ptr}{frequency}", 4, 2));
  printf($stream "%s", format_output(1, "cut ${$ptr}{cut}", 4, 2)); 
  printf($stream "%s", format_output(1, "min {$min}", 4, 2));
  printf($stream "%s", format_output(1, "max {$max}", 4, 2));
  printf($stream "%s\n", format_output(0, "limit {$limit}", 4, 2));
  printf($stream "%s\n", format_output(0, "}", 2, 2), $comma ? "," : "");
}


sub write_emc_moves {
  my $stream = shift(@_);
  my @keys = sort(keys(%::EMC::Moves));
  my @active = ();
  my %functions = (
    cluster => \&write_emc_moves_cluster
  );
  my $n = 0;

  foreach (@keys) {
    push(@active, $_) if (
      defined($functions{$_}) && flag(${$::EMC::Moves{$_}}{active}));
  }
  return if (!($n = scalar(@active)));

  my $i;

  printf($stream "moves\t\t= {\n");
  for ($i=0; $i<$n; ++$i) {
    &{$functions{@active[$i]}}($stream, $i<$n-1);
  }
  printf($stream "};\n\n");
}


sub write_emc_region {
  my $stream = shift(@_);
  my $full = shift(@_);
  my $l = shift(@_) ? "lprevious" : "lxtal";
  my $hxx = $::EMC::Direction{x} eq "x" ? $l : "infinite";
  my $hyy = $::EMC::Direction{x} eq "y" ? $l : "infinite";
  my $hzz = $::EMC::Direction{x} eq "z" ? $l : "infinite";

  printf($stream "types\t\t= {\n") if ($full);
  printf($stream "%s\n", format_output(0, "region {", 2, 2));
  printf($stream "%s\n", format_output(0, "lj {active -> true, mode -> repulsive, ", 4, 2));
  printf($stream "%s\n", format_output(0, "data {", 6, 2));
  printf($stream "%s\n", format_output(0, "{", 8, 2));

  printf($stream "%s\n", format_output(0, "epsilon $::EMC::Region{epsilon}, sigma -> $::EMC::Region{sigma}, ", 10, 2));
  printf($stream "%s\n", format_output(0, "region {shape -> cuboid, type -> absolute, ", 12, 2));
  printf($stream "%s\n", format_output(0, "h {$hxx, $hyy, $hzz}", 14, 2));
  printf($stream "%s\n", format_output(0, "}", 10, 2));
  printf($stream "%s\n", format_output(0, "}", 8, 2));
  printf($stream "%s\n", format_output(0, "}", 6, 2));
  printf($stream "%s\n", format_output(0, "}", 4, 2));
  printf($stream "%s\n", format_output(0, "}", 2, 2));
  printf($stream "};\n\n") if ($full);
}


sub write_emc_import {
  return if (!defined($::EMC::Import{name}));

  my $stream = shift(@_);
  my $id = $::EMC::Import{name};
  my $field;

  if (scalar(@{$::EMC::Import{field}})>1) {
    $field = ",\n\t\t   field -> {".join(", ", @{$::EMC::Import{field}})."}";
  } elsif (scalar(@{$::EMC::Import{field}})==1) {
    $field = ",\n\t\t   field -> @{$::EMC::Import{field}}[0]";
  }
  if ($::EMC::Import{charges}>=0) {
    $field .= ",\n\t\t   charges -> ".boolean($::EMC::Import{charges});
  }
  printf($stream "(* import file *)\n");
  printf($stream "\n");
  if ($::EMC::Import{mode} eq "get" || 				# emc
      $::EMC::Import{mode} eq "emc") {
    printf($stream "get\t\t= {name -> import$field};\n");
  } elsif ($::EMC::Import{mode} eq "insight") {			# insight
    printf($stream 
      "insight\t\t= {id -> %s, name -> import, mode -> get,\n\t\t   ".
      "depth -> $::EMC::Import{depth}, crystal -> %s, percolate -> %s,\n\t\t   ".
      "formal -> %s, flag -> {charge -> %s}$field};\n",
      $id, boolean($::EMC::Import{crystal}),
      boolean($::EMC::Import{percolate}<0 ? $::EMC::Flag{percolate} :
       	$::EMC::Import{percolate}),
      boolean($::EMC::Import{formal}),
      boolean($::EMC::System{charge})
    );
  } elsif ($::EMC::Import{mode} eq "pdb") {			# pdb
    printf($stream 
      "pdb\t\t= {name -> import, mode -> get, detect -> true, ".
      "depth -> $::EMC::Import{depth},\n");
    printf($stream 
      "\t\t   crystal -> %s, flag -> {charge -> %s}$field};\n",
      boolean($::EMC::Import{crystal}), boolean($::EMC::System{charge}));
  }
  if (defined($::EMC::Import{tighten})) {			# tighten
    my @geometry = ("infinite", "infinite", "infinite");
    my $value = $::EMC::Import{tighten};
    my $flag = 1;
    
    $value = $::EMC::Tighten if ($value<0);
    if ($::EMC::Import{type} eq "surface") {
      foreach (($::EMC::Direction{x})) {
	@geometry[0] = $value if ($_ eq "x");
	@geometry[1] = $value if ($_ eq "y");
	@geometry[2] = $value if ($_ eq "z");
      }
    } elsif ($::EMC::Import{type} eq "tube") {
      @geometry = ($value, $value, $value);
      foreach (($::EMC::Direction{x})) {
	@geometry[0] = "infinite" if ($_ eq "x");
	@geometry[1] = "infinite" if ($_ eq "y");
	@geometry[2] = "infinite" if ($_ eq "z");
      }
    } elsif ($::EMC::Import{type} eq "structure") {
      @geometry = ($value, $value, $value);
    } else {
      $flag = 0;
    }

    if ($flag) {
      printf($stream 
	"deform\t\t= {mode -> tighten, type -> absolute,\n".
	"\t\t   geometry -> {%s}};\n", join(", ", @geometry));
    }
    if ($::EMC::Import{type} eq "structure") {
      printf($stream "focus\t\t= {mode -> middle, ntrials -> 1};\n");
    }
  }
  printf($stream "\n");

  write_emc_variables($stream, 
    "lxx geometry(id -> xx)",
    "lyy geometry(id -> yy)",
    "lzz geometry(id -> zz)",
    "lzy geometry(id -> zy)",
    "lzx geometry(id -> zx)",
    "lyx geometry(id -> yx)",
    "",
    "la lxx",
    "lb sqrt(lyx*lyx+lyy*lyy)",
    "lc sqrt(lzx*lzx+lzy*lzy+lzz*lzz)",
    "",
    "lbox vtotal()^(1/3)");
}


sub write_emc_import_variables {
  my $stream = shift(@_);

  return if (!defined($::EMC::Import{name}));

  my $x = $::EMC::Direction{x};
  my $y = $::EMC::Direction{y};
  my $z = $::EMC::Direction{z};
  my $nav = $::EMC::Flag{reduced} ? "" : "/nav";
  my @volume = ();
  my @variables = ();

  if ($::EMC::Import{type} eq "crystal") {			# crystal

    push(@variables,
      $::EMC::Import{ny} ne "auto" ?
	"n$y $::EMC::Import{ny}" :
      $::EMC::ImportNParallel ? 
	"n$y $::EMC::ImportNParallel" : 
	"n$y n$x",
      $::EMC::Import{nz} ne "auto" ?
	"n$z $::EMC::Import{nz}" :
	"n$z n$x",
    );
    @volume = ("vtotal vtotal()");

  } elsif ($::EMC::Import{type} eq "surface") {			# surface

    if (scalar(@::EMC::Phases)) {
      my $s = ""; foreach (@{@::EMC::Phases[0]}) {
	$s .= "+" if ($s ne ""); $s .= "l_$_*n_$_";
      }
      push(@variables, "nphase1 int($s+0.5)");
      if ($::EMC::Import{density} eq "number") {
	$s = "nphase1";
      } else {
	$s = ""; foreach (@{@::EMC::Phases[0]}) {
	  $s .= "+" if ($s ne ""); $s .= "m_$_*n_$_";
	}
      }
      push(@variables, "mphase1 $s");
      push(@variables, "vphase1 mphase1$nav/density1");
      push(@variables,
	$::EMC::Import{ny} ne "auto" ?
	  "n$y $::EMC::Import{ny}" :
	$::EMC::ImportNParallel ? 
	  "n$y $::EMC::ImportNParallel" : 
	  "n$y int((vphase1/fshape)^(1/3)/sqrt(l$y$y*l$z$z)+0.5)",
	$::EMC::Import{nz} ne "auto" ?
	  "n$z $::EMC::Import{nz}" :
	  "n$z n$y",

	"lxtal n$x*l$x$x",
	"lphase lxtal",
	"lbox sqrt((n$y*l$y$y)*(n$z*l$z$z))",
	"fshape lphase/lbox");
    } else {
      push(@variables,
	"n$x $::EMC::Import{nx}",
	"n$y $::EMC::Import{ny}",
	"n$z $::EMC::Import{nz}"
      );
      if ($::EMC::Import{ny} eq "auto" || $::EMC::Import{nz} eq "auto") {
	error("cannot automatically determine n$y and/or n$z\n");
      }
    }
    if ($::EMC::Import{exclude} eq "contour") {
      push(@volume,
	"vtotal vsites(ntrials -> $::EMC::Import{ntrials})",
       	"l$x$x vtotal/lbox^2");
    } else {
      push(@volume,
       	"vtotal vtotal()");
    }

  } elsif ($::EMC::Import{type} eq "structure") {		# structure

    push(@variables,
      $::EMC::Import{ny} ne "auto" ?
	"n$y $::EMC::Import{ny}" :
      $::EMC::ImportNParallel ? 
	"n$y $::EMC::ImportNParallel" : 
	"n$y n$x",
      $::EMC::Import{nz} ne "auto" ?
	"n$z $::EMC::Import{nz}" :
	"n$z n$x");
    push(@volume,
      "vtotal vsites(ntrials -> $::EMC::Import{ntrials})");

  } elsif ($::EMC::Import{type} eq "line") {			# line

    error("line not supported yet (line %s)\n", __LINE__);
    push(@volume,
      "vtotal vsites(ntrials -> $::EMC::Import{ntrials})");

  } else {
    error("unexpected error while calling import type\n");
  }

  printf($stream "(* import sizing *)\n\n");
  write_emc_variables($stream, @variables);
  
  my %index = (x => 0, y => 1, z => 2);
  my @periodic = ("true", "true", "true");
  if ($::EMC::Import{type} eq "surface") {
    @periodic[$index{$x}] = "false";
  } elsif ($::EMC::Import{type} eq "tube") {
    @periodic = ("false", "false", "false");
    @periodic[$index{$x}] = "true";
  } elsif ($::EMC::Import{type} eq "structure") {
    @periodic = ("false", "false", "false");
  }
  {
    my $extra;
    my $import = \%::EMC::Import;

    if (defined($import->{translate})) {
      my $d = $import->{translate};

      $d = "($d)" if ($d =~ m/\+|\-/);
      $d = "{$d*lxx/la, 0, 0}" if ($::EMC::Direction{x} eq "x");
      $d = "{$d*lyx/lb, $d*lyy/lb, 0}" if ($::EMC::Direction{x} eq "y");
      $d = "{$d*lzx/lc, $d*lzy/lc, $d*lzz/lc}" if ($::EMC::Direction{x} eq "z");
      $extra .= ",\n\t\t   translate -> $d";
    }
    $extra .= ",\n\t\t   " if ($import->{guess}>=0 || $import->{unwrap}>=0);
    $extra .= "guess -> ".boolean($import->{guess}) if ($import->{guess}>=0);
    $extra .= ", " if ($import->{guess}>=0 && $import->{unwrap}>=0);
    $extra .= "unwrap -> ".boolean($import->{unwrap}) if ($import->{unwrap}>=0);
    printf($stream 
      "crystal\t\t= {n -> {nx, ny, nz}, periodic -> {%s}%s};\n\n",
      join(", ", @periodic), $extra);
  }
  my @flags = ();
  push(@flags, $::EMC::Import{flag}) if ($::EMC::Import{flag} ne "mobile");
  push(@flags, "focus") if ($::EMC::Import{focus});
  if (scalar(@flags)) {
    my $flags = join(", ", @flags);
    $flags = "{$flags}" if (scalar(@flags)>1);
    printf($stream "flag\t\t= {oper -> set, flag -> $flags};\n\n");
  }
  printf($stream "simulation	= {
  systems	-> {
    properties	-> {id -> 0, t -> temperature}
  }\n};\n\n");

  if ($::EMC::Deform{flag}) {
    printf($stream 
"deform		= {
  mode		-> affine,
  type		-> $::EMC::Deform{type},
  frequency	-> 1,
  geometry	-> {
    xx		-> $::EMC::Deform{xx},
    yy		-> $::EMC::Deform{yy},
    zz		-> $::EMC::Deform{zz},
    zy		-> $::EMC::Deform{zy},
    zx		-> $::EMC::Deform{zx},
    yx		-> $::EMC::Deform{yx}}
};

run		= {ncycles -> $::EMC::Deform{ncycles}, nblocks -> $::EMC::Deform{nblocks}};

force		= {style -> none, message -> raw};
force		= {style -> init, message -> raw};\n\n");
  }

  write_emc_variables($stream, 
    "lxx geometry(id -> xx)",
    "lyy geometry(id -> yy)",
    "lzz geometry(id -> zz)",
    "lzy geometry(id -> zy)",
    "lzx geometry(id -> zx)",
    "lyx geometry(id -> yx)",
    "",
    "la lxx",
    "lb sqrt(lyx*lyx+lyy*lyy)",
    "lc sqrt(lzx*lzx+lzy*lzy+lzz*lzz)",
    "",
    "charge charge()",
    "mtotal mtotal()",
    "ntotal ntotal()",
    @volume,
    "nl_$::EMC::Import{name} nclusters()");
}


sub write_emc_simulation {
  my $stream = shift(@_);

  printf($stream "(* define interactions *)\n\n");
  printf($stream "simulation\t= {\n");
  printf($stream "%s\n", format_output(0, "units {", 2, 2));
  if ($::EMC::Flag{charge}) {
    printf($stream "%s", format_output(1, "permittivity $::EMC::Dielectric", 4, 2));
  }
  printf($stream "%s\n", format_output(0, "seed seed", 4, 2));
  
  if ($::EMC::Flag{charge}) {
    printf($stream "%s\n", format_output(0, "},", 2, 2));
    printf($stream "%s\n", format_output(0, "types {", 2, 2));
    printf($stream "%s\n", format_output(0, "coulomb {", 4, 2));
    if ($::EMC::Field{type} eq "dpd") {
      printf($stream "%s\n", format_output(0, "charge {active -> true, k -> kappa, cutoff -> charge_cutoff}", 6, 2));
    } else {
      printf($stream "%s\n", format_output(0, "pair {active -> true, cutoff -> charge_cutoff}", 6, 2));
    }
    printf($stream "%s\n", format_output(0, "}", 4, 2));
  }  
  printf($stream "%s\n", format_output(0, "}", 2, 2));
  printf($stream "};\n\n");
}


sub write_emc_phase {
  my $stream = shift(@_);
  my $phase = shift(@_);
  my @clusters = @_;
  my $x = $::EMC::Direction{x}.$::EMC::Direction{x};
  my $y = $::EMC::Direction{y}.$::EMC::Direction{y};
  my $z = $::EMC::Direction{z}.$::EMC::Direction{z};
  my $mode = defined($::EMC::Import{name}) ? 
	     ($::EMC::Import{type} eq "structure" ? ($phase<2 ? 2 : 1) : 1) :
	     ($phase>1 ? 1 : 0);
  my $fsplit = $phase ? defined(@::EMC::Splits[$phase-1]) ? 1 : 0 : 0;

  printf($stream "(* clusters %s *)\n\n", $phase>0 ? "phase $phase" : "system");
  printf($stream "\n") if (write_emc_verbatim($stream, "build", $phase, 0));
  write_emc_split($stream, $phase-1) if ($fsplit);
  write_emc_clusters($stream, @clusters);
  write_emc_field_apply($stream);
  printf($stream "\n") if (write_emc_verbatim($stream, "build", $phase, 1));
  
  printf($stream "(* build %s *)\n\n", $phase>0 ? "phase $phase" : "system");
  printf($stream "variables\t= {\n");
  printf($stream "%s", format_output(1, "nphase$phase ntotal()-ntotal", 2, 2));
  printf($stream "%s", format_output(1, "mphase$phase mtotal()-mtotal", 2, 2));
  printf($stream "%s", format_output(1, "vphase$phase ".($::EMC::Flag{reduced} ? "nphase$phase/" : "mphase$phase/nav/")."density$phase", 2, 2));

  if ($mode == 0) {					# first no import

    printf($stream "%s", format_output(1, "lbox (vphase$phase/fshape)^(1/3)", 2, 2));
    printf($stream "%s", format_output(1, "lphase1 fshape*lbox", 2, 2));
    printf($stream "%s", format_output(1, "l$x lphase1", 2, 2));
    printf($stream "%s", format_output(1, "l$y lbox", 2, 2));
    printf($stream "%s", format_output(1, "l$z lbox", 2, 2));
    printf($stream "%s", format_output(1, "lzy 0", 2, 2));
    printf($stream "%s", format_output(1, "lzx 0", 2, 2));
    printf($stream "%s", format_output(1, "lyx 0", 2, 2));
    printf($stream "%s", format_output(1, "lphase lphase1", 2, 2));
    printf($stream "%s", format_output(1, "ntotal nphase1", 2, 2));
    printf($stream "%s", format_output(1, "mtotal mphase1", 2, 2));
    printf($stream "%s", format_output(0, "vtotal vphase1", 2, 2));
  
  } elsif ($mode == 1) {				# surface and standard

    printf($stream "%s", format_output(1, "lprevious lphase", 2, 2));
    printf($stream "%s", format_output(1, "lphase$phase vphase$phase/lbox^2", 2, 2));
    printf($stream "%s", format_output(1, "l$x l$x+lphase$phase", 2, 2));
    printf($stream "%s", format_output(1, "lphase lphase+lphase$phase", 2, 2));
    printf($stream "%s", format_output(1, "ntotal ntotal+nphase$phase", 2, 2));
    printf($stream "%s", format_output(1, "mtotal mtotal+mphase$phase", 2, 2));
    printf($stream "%s", format_output(0, "vtotal vtotal+vphase$phase", 2, 2));

  } elsif ($mode == 2) {				# first structure
    
    printf($stream "%s", format_output(1, "ntotal ntotal+nphase1", 2, 2));
    printf($stream "%s", format_output(1, "mtotal mtotal+mphase1", 2, 2));
    printf($stream "%s", format_output(1, "vtotal vtotal+vphase1", 2, 2));
    printf($stream "%s", format_output(1, "lbox (vtotal/fshape)^(1/3)", 2, 2));
    printf($stream "%s", format_output(1, "lprevious lphase", 2, 2));
    printf($stream "%s", format_output(1, "lphase1 fshape*lbox", 2, 2));
    printf($stream "%s", format_output(1, "l$x lphase1", 2, 2));
    printf($stream "%s", format_output(1, "l$y lbox", 2, 2));
    printf($stream "%s", format_output(1, "l$z lbox", 2, 2));
    printf($stream "%s", format_output(0, "lphase lphase1", 2, 2));
  }
  printf($stream "\n};\n\n");
  write_emc_interaction($stream);
  write_emc_moves($stream);
  
  write_emc_build($stream, $phase, @clusters);
  printf($stream "\n") if (write_emc_verbatim($stream, "build", $phase, 2));

  return if ($::EMC::EMC{test}||${$::EMC::EMC{exclude}}{build});
  write_emc_force($stream);
}


sub write_emc_force {
  my $stream = shift(@_);

  printf($stream "force\t\t= {style -> none, message -> nkt};\n");
  printf($stream "force\t\t= {style -> init, message -> nkt};\n\n");
}


sub write_emc_clusters {
  my $stream = shift(@_);
  my @clusters = @_;
  my $n = scalar (@clusters);
  my $i = 0;

  printf($stream "clusters\t= {\n");
  printf($stream "%s", format_output(1, "progress ".
      (${$::EMC::EMC{progress}}{clusters} ? "list" : "none"), 2, 2));
  foreach (@clusters) {
    if (!defined($::EMC::Polymer{$_})) {
      --$n; 
      if ($::EMC::Flag{expert}) {
	warning("allowing undefined group '$_'\n");
      } else {
	error("undefined group '$_'\n");
      }
    }
  }
  foreach (@clusters) {
    --$n;
    my $ipoly = 0;
    if (!defined($::EMC::Polymers{$_})) {
      next if (!defined($::EMC::Polymer{$_}));
      my $group = @{${$::EMC::Polymer{$_}[$ipoly]}[2]}[0];
      printf($stream "%s\n", format_output(0, "cluster {", 2, 2));
      printf($stream "%s", format_output($n, "id $_, system -> $::EMC::System{id}, group -> ${$::EMC::Group{$group}}{id}, n -> n_$_}", 4, 2));
    } else {
      write_emc_polymers($stream, "cluster", $_, $n);
    }
  }
  printf($stream "\n};\n\n");
}


sub write_emc_verbatim {
  my $stream = shift(@_);
  my $index = shift(@_);
  my $phase = shift(@_);
  my $sub = shift(@_);
  my $n = 0;

  if ($phase ne "") {
    my $ptr = $::EMC::Verbatim{$index}[$phase>=0 ? $phase : 0];
    if (defined($ptr)) {
      if ($index eq "build") {
	foreach(@{@{$ptr}[$sub]}) {
	  printf($stream "%s\n", $_); ++$n;
	}
      } else {
	foreach(@{$ptr}) {
	  printf($stream "%s\n", $_); ++$n;
	}
      }
    }
  } else {
    foreach(@{$::EMC::Verbatim{$index}}) {
      printf($stream "%s\n", $_); ++$n;
    }
  }
  return $n;
}


sub create_emc_groups {
  my @groups;
  foreach (@_) {
    my @arg = split(":", $_);
    push(@groups, scalar(@arg)>1 ? "{".join(", ", @arg)."}" : $_);
  }
  return @groups;
}


sub create_clusters {
  my @clusters = ();

  foreach (@_) {
    if (defined($::EMC::Polymers{$_})) {
      my $poly = $::EMC::Polymer{$_};
      my $npolys = scalar(@{$poly});
      if ($npolys>1) {
	my $name = $_;
	my $i;
	for ($i=1; $i<=$npolys; ++$i) {
	  push(@clusters, $name."_".$i);
	}
      }
      else {
	push(@clusters, $_);
      }
    }
    else {
      push(@clusters, $_);
    }
  }
  return @clusters;
}


sub write_emc_build {
  return if ($::EMC::EMC{test});
  return if (${$::EMC::EMC{exclude}}{build});

  my $stream = shift(@_);
  my $phase = shift(@_);
  my $mode = "soft";
  my @clusters = create_clusters(@_);

  #write_emc_region($stream, 1, 1) if ($phase>1);
  
  my $n = scalar (@clusters)-1;
  my $i = 0;
  my $lx = $phase ? "2*fshape" : "fshape";
  my $fsplit = $phase ? defined(@::EMC::Splits[$phase-1]) ? 1 : 0 : 0;
  my @flags;

  foreach (sort(keys(%::EMC::System))) {
    next if ($_ eq "flag" || $_ eq "id");
    push(@flags, "$_ -> ".boolean($::EMC::System{$_}));
  }

  printf($stream "build\t\t= {\n");
  printf($stream "%s\n", format_output(0, "system {", 2, 2));
  printf($stream "%s", format_output(1, "id ".$::EMC::System{id}, 4, 2));
  printf($stream "%s", format_output(1, "split ".boolean($fsplit), 4, 2));
  #printf($stream "%s", format_output(1, "density density", 4, 2));
  printf($stream "%s", format_output(1, "geometry {xx -> lxx, yy -> lyy, zz -> lzz", 4, 2));
  printf($stream "\t\t    zy -> lzy, zx -> lzx, yx -> lyx},\n");
  if (!defined($::EMC::Import{name})) {
    printf($stream "%s", format_output(1, "deform {$::EMC::Deform{xx}, $::EMC::Deform{yy}, $::EMC::Deform{zz}, $::EMC::Deform{zy}, $::EMC::Deform{zx}, $::EMC::Deform{yx}}", 4, 2)) if ($::EMC::Deform{flag});
  }
  printf($stream "%s", format_output(1, "temperature temperature", 4, 2));
  printf($stream "%s", format_output(0, "flag {".join(", ", @flags)."}", 4, 2));
  printf($stream "\n");
  printf($stream "%s", format_output(1, "}", 2, 2));

  printf($stream "%s\n", format_output(0, "select {", 2, 2));
  printf($stream "%s", format_output(1, "progress ".
      (${$::EMC::EMC{progress}}{build} ? "list" : "none"), 4, 2));
  printf($stream "%s", format_output(1, "frequency 1", 4, 2));
  printf($stream "%s", format_output(1, "name \"error\"", 4, 2));
  if ($::EMC::Build{center}) {
    printf($stream "%s", format_output(1, "center ".boolean($::EMC::Build{center}), 4, 2));
    my $v = $::EMC::Build{origin};
    printf($stream "%s", format_output(1, "origin {$v->{x}, $v->{y}, $v->{z}}", 4, 2));
  }
  printf($stream "%s", format_output(1, "order $::EMC::Build{order}", 4, 2));
  printf($stream "%s", format_output(1, "cluster {".join(", ", @clusters)."}", 4, 2));
  printf($stream "%s", format_output(1, "relax {ncycles -> nrelax, radius -> radius}", 4, 2));

  if ($::EMC::Record{flag}) {
    printf($stream "%s\n", format_output(0, "record {", 4, 2));
    printf($stream "%s", format_output(1, "name ".$::EMC::Record{name}, 6, 2));
    printf($stream "%s", format_output(1, "frequency ".$::EMC::Record{frequency}, 6, 2));
    my $n = scalar(keys(%::EMC::Record));
    foreach (sort(keys(%::EMC::Record))) {
      --$n; if ($_ ne "flag" && $_ ne "name" && $_ ne "frequency") {
	printf($stream "%s",
	  format_output($n, "$_ ".$::EMC::Record{$_}, 6, 2));
      }
    }
    printf($stream "\n    },\n");
  }

  printf($stream "%s\n", format_output(0, "grow {", 4, 2));
  printf($stream "%s", format_output(1, "method energetic", 6, 2));
  printf($stream "%s", format_output(1, "check all", 6, 2));
  printf($stream "%s", format_output(1, "nbonded 20", 6, 2));
  printf($stream "%s", format_output(1, "ntrials 20", 6, 2));
  printf($stream "%s", format_output(1, "niterations $::EMC::Build{niterations}", 6, 2));
  printf($stream "%s", format_output(1, "theta $::EMC::Build{theta}", 6, 2));
  
  my $exclude = $phase>1 ? $::EMC::Flag{exclude} : 0;

  #if ($phase<2 && defined($::EMC::Import{name}) && $::EMC::Import{type} ne "structure") {
  #  $exclude = $phase = 1; $mode = "hard";
  #}

  printf($stream "%s\n", format_output(0, "weight {", 6, 2));
  printf($stream "%s", format_output(1, "bonded weight_bond, nonbonded -> weight_nonbond", 8, 2));
  printf($stream "%s", format_output($exclude, "focus weight_focus}", 8, 2));
  if ($exclude) {
    my $x = $::EMC::Direction{x} eq "x" ? "xx-lphase$phase" : "xx";
    my $y = $::EMC::Direction{x} eq "y" ? "yy-lphase$phase" : "yy";
    my $z = $::EMC::Direction{x} eq "z" ? "zz-lphase$phase" : "zz";

    printf($stream "%s\n", format_output(0, "exclude {", 6, 2));
    printf($stream "%s", format_output(1, "shape cuboid, type -> absolute, mode -> $mode", 8, 2));
    printf($stream "%s", format_output(1, "h {xx -> l$x, yy -> l$y, zz -> l$z", 8, 2));
    printf($stream "\t\t    zy -> lzy, zx -> lzx, yx -> lyx}\n");
    printf($stream "\n%s", format_output(0, "}", 6, 2));
  }
  
  printf($stream "\n%s", format_output(0, "}", 4, 2));

  printf($stream "\n%s", format_output(0, "}", 2, 2));

  printf($stream "\n};\n\n");
}


sub write_emc_split {
  my $stream = shift(@_);
  my $phase = shift(@_);
  my $direction = $::EMC::Direction{x};
  my @clusters = $phase ? create_clusters(@{@::EMC::Phases[$phase-1]}) : ();
  my $unwrap = 1;

  foreach (@{$::EMC::Splits[$phase]}) {
    my $hash = $_;
    my @focus = ();
    my $thickness = $hash->{thickness};
    my @center = (
      $direction eq "x" ? "0.5" : "0.0",
      $direction eq "y" ? "0.5" : "0.0",
      $direction eq "z" ? "0.5" : "0.0"
    );
    my @h = (
      $direction eq "x" ? $thickness : "infinite",
      $direction eq "y" ? $thickness : "infinite",
      $direction eq "z" ? $thickness : "infinite",
      "0.0", "0.0", "0.0"
    );

    if ($hash->{type} eq "absolute") {
      if ($direction eq "x") {
	@center = ("0.5*lxx", "0.0", "0.0");
      } elsif ($direction eq "y") {
	@center = ("0.5*lyx", "0.5*lyy", "0.0");
      } elsif ($direction eq "z") {
	@center = ("0.5*lzx", "0.5*lzy", "0.5*lzz");
      }
    }
    
    printf($stream "split\t\t= {\n");
    printf($stream format_output(1, "system ".$::EMC::System{id}, 2, 2));
    printf($stream format_output(1, "direction ".$direction, 2, 2));
    printf($stream format_output(1, "mode ".$hash->{mode}, 2, 2));
    printf($stream format_output(1, "unwrap ".boolean($unwrap), 2, 2));
    printf($stream format_output(1, "fraction ".$hash->{fraction}, 2, 2));
    $unwrap = 0;
    
    foreach ("sites", "groups", "clusters") {
      if ($hash->{$_} ne "all") {
	push(@focus, {$_ => $hash->{$_}});
      } elsif ($_ eq "clusters") {
	push(@focus, {$_ => \@clusters}) if (scalar(@clusters));
      }
    }
    if (scalar(@focus)) {
      my $i;
      my $n = scalar(@focus)-1;

      printf($stream format_output(0, "focus {", 2, 2));
      printf($stream "\n");
      for ($i=0; $i<=$n; ++$i) {
	my $select = @focus[$i];
	my $key = (keys(%{$select}))[0];

	printf($stream format_output($i<$n, "$key {".join(", ", @{$select->{$key}})."}", 4, 2));
	printf($stream "\n") if ($i==$n);
      }
      printf($stream format_output(1, "}", 2, 2));
    }
    printf($stream format_output(0, "region {", 2, 2));
    printf($stream "\n");
    printf($stream format_output(1, "shape cuboid", 4, 2));
    printf($stream format_output(1, "type ".$hash->{type}, 4, 2));
    printf($stream format_output(1, "center {".join(", ", @center)."}", 4, 2));
    printf($stream format_output(0, "h {".join(", ", @h)."}", 4, 2));
    printf($stream "\n");
    printf($stream format_output(0, "}", 2, 2));
    printf($stream "\n};\n\n");
  }
}


sub write_emc_run {
  my $stream = shift(@_);

  return if (${$::EMC::EMC{run}}{ncycles}<=0);

  my @moves = sort(keys(%{$::EMC::EMC{moves}}));
  my $nmoves = 0;

  foreach (@moves) {
    ++$nmoves if (${$::EMC::EMC{moves}}{$_});
  }
  return if (!$nmoves);

  my $ntraject = $::EMC::EMC{ntraject} ?
		    $::EMC::EMC{ntraject} : $::EMC::EMC{nblocks};
  
  printf($stream "(* run conditions *)\n\n");
  printf($stream "simulation\t= {\n");
  printf($stream "%s\n", format_output(0, "moves {", 2, 2));

  my $i = 0; foreach(@moves) {
    printf($stream "%s\n", format_output(0, "$_ {", 4, 2));
    printf($stream "%s", format_output(1, "active true", 6, 2));
    printf($stream "%s\n", format_output(0, "frequency ${$::EMC::EMC{moves}}{$_}", 6, 2));
    printf($stream "%s", format_output(++$i<$nmoves, "}", 4, 2));
  }
  printf($stream "\n%s\n", format_output(0, "}", 2, 2));
  printf($stream "};\n\n");

  my %select;
  my $fselect = 0;

  foreach ("cluster", "group", "site") {
    my %hash;
    foreach (split(":", ${$::EMC::EMC{run}}{$_."s"})) {
      $hash{$_} = $_ if ($_ ne "all");
    }
    next if (!scalar(keys(%hash)));
    @{$select{$_}} = sort(keys(%hash));
    ++$fselect;
  }

  if ($fselect)
  {
    printf($stream "(* set selection *)\n\n");
    printf($stream "flag\t\t= {\n");
    printf($stream "%s", format_output(1, "oper set", 2, 2));
    printf($stream "%s", format_output(0, "flag fixed", 2, 2));
    printf($stream "\n};\n\n");

    my $count = $fselect;

    printf($stream "flag\t\t= {\n");
    printf($stream "%s", format_output(1, "oper unset", 2, 2));
    printf($stream "%s", format_output(1, "flag fixed", 2, 2));
    foreach (sort(keys(%select))) {
      if (scalar(@{$select{$_}})>1) {
	printf($stream "%s", format_output(--$count, "$_ {".join(", ", @{$select{$_}})."}", 2, 2));
      } else {
	printf($stream "%s", format_output(--$count, "$_ @{$select{$_}}[0]", 2, 2));
      }
    }
    printf($stream "\n};\n\n");
  }

  if (${$::EMC::EMC{run}}{nequil}) {
    printf($stream "(* equilibrate *)\n\n");
    printf($stream "run\t\t= {\n");
    printf($stream "%s", format_output(1, "ncycles nequil", 2, 2));
    printf($stream "%s", format_output(0, "nblocks nblocks", 2, 2));
    printf($stream "\n};\n\n");
    write_emc_force($stream);
  }
  
  printf($stream "(* run *)\n\n");
  if (${$::EMC::EMC{traject}}{frequency}) {
    printf($stream "traject\t\t= {\n");
    printf($stream "%s", format_output(1, "mode put", 2, 2));
    printf($stream "%s", format_output(1, "frequency ntraject", 2, 2));
    printf($stream "%s", format_output(1, "name output", 2, 2));
    printf($stream "%s", format_output(0, "append ".boolean(flag(${$::EMC::EMC{traject}}{append})), 2, 2));
    printf($stream "\n};\n\n");
  }

  printf($stream "run\t\t= {\n");
  printf($stream "%s", format_output(1, "ncycles ncycles", 2, 2));
  printf($stream "%s", format_output(0, "nblocks nblocks", 2, 2));
  printf($stream "\n};\n\n");
  write_emc_force($stream);

  if ($fselect) {
    printf($stream "(* unset selection *)\n\n");
    printf($stream "flag\t\t= {\n");
    printf($stream "%s", format_output(1, "oper unset", 2, 2));
    printf($stream "%s", format_output(0, "flag fixed", 2, 2));
    printf($stream "\n};\n\n");
  }
}


sub write_emc_focus {
  my $stream = shift(@_);

  return if (!$::EMC::Flag{focus});

  my @focus = ();

  foreach (@::EMC::Focus) {
    if ($_ eq "-") { next; }
    elsif (!defined($::EMC::XRef{$_})) {
      warning("undefined focus cluster \'$_\'\n");
    }
    push(@focus, $_);
  }
  printf($stream "(* focus *)\n\n");
  if (scalar(@focus)==0) {
    printf($stream "focus\t\t= {};\n\n");
  }
  elsif (scalar(@focus)==1) {
    printf($stream "focus\t\t= {clusters -> @focus[0]};\n\n");
  }
  else {
    printf($stream "focus\t\t= {clusters -> {".join(", ", @focus)."}};\n\n");
  }
}


sub strtype {
  my $key = @_[0];
  $key =~ s/\*/_s_/g;
  $key =~ s/\'/_q_/g;
  $key =~ s/\"/_qq_/g;
  $key =~ s/\-/_m_/g;
  $key =~ s/\+/_p_/g;
  $key =~ s/\=/_e_/g;
  $key =~ s/__/_/g;
  $key =~ s/_$//g;
  return $key;
}


sub write_emc_profile {
  my $stream = shift(@_);

  my @clusters;					# non-polymers through EMC
  foreach (@::EMC::Clusters) {
    push(@clusters, $_) if (defined($::EMC::Polymers{$_}));
  }
  my $n = scalar(@clusters);
  my $fcluster = 
	$n && %::EMC::Profiles && defined($::EMC::Profiles{cluster}) ? 1 : 0;
 
  $fcluster = 0 if (!$::EMC::PolymerFlag{cluster});	# profiles through EMC
  @clusters = @::EMC::Clusters if ($fcluster);
  $n = scalar(@clusters);

  #return if (!((%::EMC::Convert && defined($::EMC::Convert{type})) || $n || $fcluster));
  return if (!($n || $fcluster));
  
  printf($stream "(* LAMMPS profile variables *)\n\n");
  printf($stream "variables\t= {\n");
  if (0 && %::EMC::Convert && defined($::EMC::Convert{type})) {
    my $itypes = scalar(keys(%{$::EMC::Convert{type}}));
    if ($itypes) {
      foreach (sort(keys(%{$::EMC::Convert{type}}))) {
	my $key = convert_key("type", $_);
	$_ =~ s/\*$/* /g;
	printf($stream 
	  format_output(--$itypes || $n, "type_".$key." type($_)+1", 2, 2));
      }
      printf($stream "\n") if ($n);
    }
  }
  foreach (@clusters) {
    --$n if (!$fcluster);
    if (!defined($::EMC::Polymers{$_})) {
      printf($stream
	format_output($n, "nl_$_ nclusters(clusters -> $_)", 2, 2));
    } else {
      my $name = $_;
      my $poly = $::EMC::Polymer{$name};
      my $npolys = scalar(@{$poly});
      my $ipoly = 0;
      my $flag = $npolys>1 ? 1 : 0;
      foreach (@{$poly}) {
	my $id = $name.($flag ? "_".++$ipoly : "");
	printf($stream "%s",
	  format_output(--$npolys || $n, 
	    "nl_$name ".($ipoly>1 ? "nl_$name+" : "").
	    "nclusters(clusters -> $id)", 2, 2)
	);
      }
    }
  }
  if ($fcluster) {
    printf($stream "\n");
    my $last = "";

    foreach (@::EMC::ClusterSampling) {
      printf($stream "%s",
	format_output(1, "n0_$_ $last"."1", 2, 2));
      printf($stream "%s",
	format_output(--$n, "n1_$_ n0_$_+nl_$_-1", 2, 2));
      $last = "n1_$_+";
    }
  }
  printf($stream "\n};\n\n");
};


sub write_emc_store {
  my $stream = shift(@_);

  printf($stream "(* storage *)\n");

  if (!$::EMC::EMC{test}) {
    printf($stream "\nput\t\t= {name -> output, compress -> true};\n");

    if ($::EMC::PDB{write}&&!${$::EMC::EMC{exclude}}{build}) {
      printf($stream "\npdb\t\t= {name -> output,");
      printf($stream " compress -> ".boolean($::EMC::PDB{compress}).",");
      printf($stream " extend -> ".boolean($::EMC::PDB{extend}).",");
      printf($stream "\n\t\t  ");
      printf($stream " forcefield -> $::EMC::Field{type},");
      printf($stream " detect -> false,");
      printf($stream " hexadecimal -> ".boolean($::EMC::Flag{hexadecimal}).",");
      printf($stream "\n\t\t  ");
      printf($stream " unwrap -> ".boolean($::EMC::PDB{unwrap}).",");
      printf($stream " pbc -> ".boolean($::EMC::PDB{pbc}).",");
      printf($stream " atom -> $::EMC::PDB{atom},");
      printf($stream " residue -> $::EMC::PDB{residue},");
      printf($stream "\n\t\t  ");
      printf($stream " segment -> $::EMC::PDB{segment},");
      printf($stream " rank -> ".boolean($::EMC::PDB{rank}).",");
      printf($stream " vdw -> ".boolean($::EMC::PDB{vdw}).",");
      printf($stream " cut -> ".boolean($::EMC::PDB{cut}).",");
      printf($stream "\n\t\t  ");
      printf($stream " fixed -> ".boolean($::EMC::PDB{fixed}).",");
      printf($stream " rigid -> ".boolean($::EMC::PDB{rigid}).",");
      printf($stream " connectivity -> ".boolean($::EMC::PDB{connect}).",");
      printf($stream "\n\t\t  ");
      printf($stream " parameters -> ".boolean($::EMC::PDB{parameters}));
      printf($stream "};\n");
    }
  }

  if ($::EMC::Lammps{write}&&!${$::EMC::EMC{exclude}}{build}) {
    printf($stream "\nlammps\t\t= {name -> output, mode -> put, ".
      "forcefield -> $::EMC::Field{type},\n");
    printf($stream
      "\t\t   parameters -> true, types -> false, unwrap -> true,\n".
      "\t\t   charges -> %s%s%s%s%s", boolean($::EMC::Flag{charge}),
      $::EMC::CutOff{repulsive} ? ", cutoff -> true" : "",
      $::EMC::Flag{ewald}>=0 ? ", ewald -> ".boolean($::EMC::Flag{ewald}) : "",
      $::EMC::Flag{cross} ? ", cross -> true" : "",
      $::EMC::Field{type} eq "colloid" ? ", sphere -> true" : "");
    if (defined($::EMC::Shake{flag})) {
      printf($stream ", shake -> false") if (!$::EMC::Shake{flag});
    }
    if ($::EMC::EMC{test}) {
      printf($stream ", data -> false");
    }
    if ($::EMC::Lammps{version}<$::EMC::Lammps{new_version}) {
      printf($stream ",\n\t\t   version -> $::EMC::Lammps{version}");
    }
    printf($stream "};\n");
  }

  if (!$::EMC::EMC{test}) {
    if ($::EMC::Insight{write}&&!${$::EMC::EMC{exclude}}{build}) {
      printf($stream "\ninsight\t\t= {name -> output, ");
      printf($stream "compress -> ".boolean($::EMC::Insight{compress}).", ");
      printf($stream "forcefield -> $::EMC::Field{type},\n");
      printf($stream "\t\t   unwrap -> ".boolean($::EMC::Insight{unwrap}).", ");
      printf($stream "pbc -> ".boolean($::EMC::Insight{pbc}));
      printf($stream "};\n");
    }
  }

  if (${$::EMC::EMC{export}}{smiles} ne "") {
    printf($stream "
export		= {
  smiles	-> {name -> output+\"_smiles\", compress -> true, style -> ${$::EMC::EMC{export}}{smiles}}
};");
  }
}


# LAMMPS input script

sub lammps_pressure_coupling {
  my @couple = split(":", $::EMC::Pressure{couple});
  my @direction = split("[+]", $::EMC::Pressure{direction});
  my $string;
  my $mode;

  if (scalar(@couple)==1 && scalar(@direction)==3) {
    if (@couple[0] eq "couple") { 
      $mode = "iso";
    }
    elsif (@couple[0] eq "uncouple") {
      $mode = $::EMC::Flag{triclinic} ? "tri" : "aniso";
    }
    $string .= "\n\t\t$mode \${pressure} \${pressure} \${pdamp}";
  }
  else
  {
    my %d = (x => 0, y => 0, z => 0);
    my @dir = split("[+]", @couple[1]);
    foreach(@direction) { $d{$_} = 1; }
    @direction = (); foreach (sort(keys(%d))) {
      $string .= "\n\t\t$_ \${pressure} \${pressure} \${pdamp} &" if ($d{$_});
      push(@direction, $_) if ($d{$_});
    }
    @dir = @direction if (!scalar(@dir));
    if (@couple[0] eq "couple") {
      %d = (x => 0, y => 0, z => 0);
      foreach (@dir) { $d{$_} = 1; }
    } else {
      %d = (x => 1, y => 1, z => 1);
      foreach (@dir) { $d{$_} = 0; }
    }
    @dir = (); foreach (sort(keys(%d))) { push(@dir, $_) if ($d{$_}); }
    $string .= "\n\t\tcouple ".(scalar(@dir)>1 ? join("", @dir) : "none");
  }
  return $string;
}


sub write_lammps {
  return if (!$::EMC::Lammps{write});

  my $name = shift(@_);

  if ((-e "$name.in")&&!$::EMC::Replace{flag}) {
    warning("\"$name.in\" exists; use -replace flag to overwrite\n");
    return;
  }

  info("creating LAMMPS run script \"$name.in\"\n");

  if ($::EMC::Field{type} eq "charmm") {
    my $stream = fopen("$name.cmap", "a");	# touch
    close($stream);
  }

  my $stream = fopen("$name.in", "w");
  my %write = %{$::EMC::Lammps{func}};
  my $verbatim = $::EMC::Verbatim{lammps};

  foreach (@{$::EMC::Lammps{stage}}) {
    write_lammps_verbatim($stream, $_, "head");
    $write{$_}->($stream);
    write_lammps_verbatim($stream, $_, "tail");
  }

  close($stream);
}


sub write_lammps_verbatim {
  my $stream = shift(@_);
  my $stage = shift(@_);
  my $spot = shift(@_);

  return if (!defined($::EMC::Verbatim{lammps}));
  return if (!defined(${$::EMC::Verbatim{lammps}}{$stage}));
  return if (!defined(${${$::EMC::Verbatim{lammps}}{$stage}}{$spot}));
  
  my $lines = "\n# Verbatim paragraph\n\n";
  my $args = $::EMC::Verbatim{lammps};

  info("adding verbatim lammps $spot paragraph at $stage\n");
  printf($stream "# Verbatim paragraph\n\n%s\n\n",
    join("\n", @{${${$::EMC::Verbatim{lammps}}{$stage}}{$spot}}));
}


sub write_lammps_header {
  my $stream = shift(@_);
  my $date = date;
  my $atom_style = (
    $::EMC::Field{type} eq "colloid" ? "sphere\nnewton\t\toff" :
    $::EMC::Field{type} eq "dpd" ? ("hybrid molecular".
      ($::EMC::Flag{charge} ? " charge" : "")) :   
    $::EMC::Flag{charge} ? "full" : "molecular");
  my $units = $::EMC::Units{type} eq "reduced" ? "lj" : $::EMC::Units{type};

  chop($date);
  printf($stream "%s",
"# LAMMPS input script for standardized atomistic simulations
# Created by $::EMC::Script v$::EMC::Version, $::EMC::Date as part of EMC
# on $date

# LAMMPS atomistic input script

echo		screen
units		$units
atom_style	$atom_style

");
}


sub write_lammps_variables {
  my $stream = shift(@_);

  printf($stream "%s", 
"# Variable definitions

variable	project		index	\"$::EMC::Project{name}\"	# project name
variable	source		index	$::EMC::Build{dir}	# data directory
variable	params		index	$::EMC::Build{dir}	# parameter directory
variable	temperature	index	$::EMC::Temperature		# system temperature
variable	tdamp		index	$::EMC::Lammps{tdamp}		# temperature damping"
.($::EMC::Pressure{flag} ? "
variable	pressure	index	$::EMC::Pressure{value}		# system pressure
variable	pdamp		index	$::EMC::Lammps{pdamp}		# pressure damping" : "")
.($::EMC::Shear{flag} ? "
variable	rate		index	$::EMC::Shear{rate}		# shear rate
variable	tramp		index	$::EMC::Shear{ramp}		# shear ramp
variable	framp		index	".($::EMC::Shear{mode} ne "" ? 1 : 0).
"\t\t# 0: skip, 1: apply" :
 "")."
variable	dielectric	index	$::EMC::Dielectric		# medium dielectric
variable	kappa		index	$::EMC::Kappa		# electrostatics kappa"
.($::EMC::Cutoff{repulsive} ? "" : "
variable	cutoff		index	$::EMC::CutOff{pair}		# standard cutoff")
.($::EMC::CutOff{ghost}>=0 ? "
variable	ghost_cutoff	index	$::EMC::CutOff{ghost}		# ghost region cutoff" : "")
.($::EMC::CutOff{center}>=0 ? "
variable	center_cutoff	index	$::EMC::CutOff{center}		# center cutoff" : "")
.($::EMC::CutOff{inner}>=0 ? "
variable	inner_cutoff	index	$::EMC::CutOff{inner}		# inner cutoff" : "")."
variable	charge_cutoff	index	$::EMC::CutOff{charge}		# charge cutoff
variable	precision	index	$::EMC::Precision		# kspace precision
variable	lseed		index	723853		# langevin seed
variable	vseed		index	486234		# velocity seed"
.($::EMC::Field{type} eq "colloid" ? "
variable	bseed		index	298537		# brownian seed" : "")."
variable	tequil		index	$::EMC::Lammps{tequil}		# equilibration time
variable	dlimit		index	$::EMC::Lammps{dlimit}		# nve/limit distance
variable	trun		index	$::EMC::Lammps{trun}		# run time
variable	frestart	index	".($::EMC::Lammps{restart} ? 1 : 0)
."		# 0: equil, 1: restart
variable	dtrestart	index	$::EMC::Lammps{dtrestart}		# delta restart time
variable	dtdump		index	$::EMC::Lammps{dtdump}		# delta dump time
variable	dtthermo	index	$::EMC::Lammps{dtthermo}		# delta thermo time
variable	timestep	index	$::EMC::Timestep		# integration time step
variable	tfreq		index	$::EMC::Lammps{tfreq}		# profile sampling freq
variable	nsample		index	$::EMC::Lammps{nsample}		# profile conf sampling
variable	dtime		equal	\${tfreq}*\${nsample}	# profile dtime
variable	restart		index	\${params}/\${project}.restart

if \"\${frestart} != 0\" then &
\"variable	data		index	\${restart}\" &
else &
\"variable	data		index	\${params}/\${project}.data\" &

");
}


sub write_lammps_interaction {
  my $stream = shift(@_);
  my $special_bonds = (
    $::EMC::Field{type} eq "cff" ? "0 0 1" :
    $::EMC::Field{type} eq "dpd" ? "1 1 1" :
    $::EMC::Field{type} eq "martini" ? "0 1 1" :
    $::EMC::Field{type} eq "opls" ? "0 0 0.5" : 
    $::EMC::Field{type} eq "sdk" ? "0 0 1" :
    $::EMC::Field{type} eq "colloid" ? "1 1 1" :
    "0 0 0");
  my $cut = "\${cutoff}";
  my $icut = "\${inner_cutoff}";
  my $zcut = "\${center_cutoff}";
  my $ccut = "\${charge_cutoff}";
  my $long = $::EMC::Flag{ewald} ? "long" : "cut";
  my @momentum = @{$::EMC::Lammps{momentum}};
  my $pair_style = (
    $::EMC::Field{type} eq "colloid" ? "colloid $cut" :
    $::EMC::Field{type} eq "dpd" ? (
      ($::EMC::Flag{charge} ?
	"hybrid/overlay &\n\t\tdpd/charge \${charge_cutoff} \${kappa} &\n\t\t":
	"").
      "dpd \${temperature} \${cutoff} \${vseed}") :
    $::EMC::Field{type} eq "charmm" ?
      ($::EMC::Flag{charge} ? 
	"lj/charmm/coul/$long $icut $cut $ccut" : "lj/charmm $cut")."\n".
      "fix\t\tcmap all cmap \${params}/\${project}.cmap\n".
      "fix_modify\tcmap energy yes" :
    $::EMC::Field{type} eq "cff" ? 
      ($::EMC::Flag{charge} ? 
	"lj/class2/coul/$long $cut $ccut" : "lj/class2 $cut") :
    $::EMC::Field{type} eq "sdk" ? 
      ($::EMC::Flag{charge} ? "lj/sdk/coul/$long $cut $ccut" : "lj/sdk $cut") :
    $::EMC::Field{type} eq "martini" ?
      ($::EMC::Flag{charge} ? "lj/gromacs/coul/gromacs $icut $cut &\n\t\t$zcut $ccut" : 
		     "lj/gromacs $icut $cut") :
      ($::EMC::Flag{charge} ? "lj/cut/coul/$long $cut $ccut" : "lj/cut $cut"));

  printf($stream "%s",
"# Interaction potential definition

pair_style	$pair_style
".($::EMC::Field{type} ne "colloid" ? "bond_style\tharmonic\n" : "").
($::EMC::Field{type} eq "sdk" ? "angle_style\tsdk\n" : "").
"special_bonds	lj/coul $special_bonds".
($::EMC::Flag{triclinic} ? "
box		tilt large" : "")."
if \"\${frestart} != 0\" then \"read_restart \${data}\" else \"read_data \${data}".
($::EMC::Field{type} eq "charmm" ? " fix cmap crossterm CMAP" : "")."\"".
($::EMC::Shear{flag}||$::EMC::Flag{triclinic} ? "
if \"\${frestart} == 0\" then \"change_box all triclinic\"" : "")."
include		\${params}/\${project}.params

# Integration conditions (check)
".($::EMC::Field{type} eq "dpd" ? "
neighbor	$::EMC::Lammps{skin} multi
".($::EMC::Lammps{communicate} ? "communicate	" : "comm_modify	mode ").
		"single vel yes cutoff \${ghost_cutoff}
neigh_modify	delay 0 every 2 check yes" : "")."
timestep	\${timestep}\n".
($::EMC::Flag{charge} ?
  ($::EMC::Field{type} ne "martini" ? 
    ($::EMC::Flag{ewald} ? "if \"\${flag_charged} != 0\" then \"kspace_style pppm/cg \${precision}\"\n" : "") : "").
      "dielectric\t\${dielectric}\n" : "").
($::EMC::Lammps{momentum_flag} ? 
  join(" ", "fix\t\tmom all momentum",
    shift(@momentum), "linear", @momentum) : "")
.($::EMC::Field{type} eq "colloid" ? "
neighbor	$::EMC::Lammps{skin} multi
neigh_modify	delay 0 every 1 check yes
neigh_modify	include all
comm_modify	mode multi vel yes" : "")."

");
}


sub write_lammps_equilibration {
  my $stream = shift(@_);

  printf($stream "%s",
"# Equilibration
".
($::EMC::Lammps{multi} ? "\nthermo_style\tmulti" : "")."
thermo		\${dtthermo}
if \"\${frestart} != 0\" then \"jump SELF simulate\"\n".
($::EMC::Flag{shake} ? "timestep\t1\nunfix\t\tshake\n" : "").
"velocity	all create \${temperature} \${vseed} &
		dist gaussian rot yes mom yes sum yes
".($::EMC::Field{type} eq "dpd" ? "" :
  "fix\t\ttemp all langevin \${temperature} \${temperature} \${tdamp} &\n\t\t\${lseed}\n").
"fix		int all nve/limit \${dlimit}
run		\${tequil}
".($::EMC::Field{type} eq "dpd" ? "" :
"unfix		temp\n").
"unfix		int
write_restart	\${project}.restart2

");
}


sub write_lammps_simulation {
  my $stream = shift(@_);

  printf($stream "%s",
"# Simulation

label		simulate

"
);
}


sub write_lammps_integrator {
  my $stream = shift(@_);
  my $shear_mode = $::EMC::Shear{mode} eq "" ? "erate" : $::EMC::Shear{mode};
  my $shake = "";
  
  if (defined($::EMC::Shake{flag})&&!$::EMC::Shake{flag}) {
    $shake = "shake all shake ";
    $shake .= "$::EMC::Shake{tolerance} $::EMC::Shake{iterations} $::EMC::Shake{output}";
    my $index = 1;
    my $offset = 16;
    my $column = $offset+length($shake);
    my %key = (mass => "m", type => "t", bond => "b", angle => "a");

    foreach ("mass", "type", "bond", "angle") {
      if (defined($::EMC::Shake{$_})) {
	my $ptr = $::EMC::Shake{$_};
	my $flag = $_ eq "mass" ? 0 : 1;
	my $pre = "type"; $pre .= "_$_" if ($_ ne "type");

	$shake .= " &\n\t\t$key{$_}";
	$column = $offset+length($key{$_});
	foreach (@{$ptr}) {
	  my $type = $flag ? "\${".join("_", $pre, @{$_})."}" : @{$_}[0];
	  my $n = length($type);
	  
	  if ($column+$n>77) {
	    $shake .= " &\n\t\t$type"; $column = $offset+$n;
	  } else {
	    $shake .= " $type"; $column += $n+1;
	  }
	}
      }
    }
    $shake = "\nfix\t\t$shake";
  }

  printf($stream "%s",
"# Integrator
".
($::EMC::Flag{shake} ? "
timestep	\${timestep}\ninclude\t\t\${params}/\${project}.params\n" : "").
$shake.($::EMC::Field{type} eq "dpd" ? 
  ($::EMC::Pressure{flag} ?  "
fix		press all press/berendsen &".lammps_pressure_coupling() : "")."
fix		int all nve" :
  ($::EMC::Shear{flag} ? 
  ($::EMC::Pressure{flag} ?
  ($::EMC::Field{type} eq "colloid" ? "
fix		press all press/berendsen &".lammps_pressure_coupling() : " 	
fix		int all npt/sllod temp \${temperature} \${temperature} \${tdamp} &".lammps_pressure_coupling()) : 
  ($::EMC::Field{type} eq "colloid" ? "
fix		int all nve/noforce" : "
fix		int all nvt/sllod \${temperature} \${temperature} \${tdamp}"))."

if \"(\${frestart} != 0) || (\${framp} == 0)\" then \"jump SELF deform\"
fix		def all deform 1 xy $shear_mode \${rate} remap v
run		\${tramp}
unfix		def

label		deform
fix		def all deform 1 xy erate \${rate} remap v" : 
  ($::EMC::Pressure{flag} ? " 
fix		int all npt temp \${temperature} \${temperature} \${tdamp} &".lammps_pressure_coupling() : "
fix		temp all langevin \${temperature} \${temperature} \${tdamp} &\n\t\t\${lseed}
fix		int all nve")))."\n\n"
);
}


sub write_lammps_sample {
  my $stream = shift(@_);
  my %flag;

  $::EMC::Sample{volume} = 1 if ($::EMC::Sample{"green-kubo"});
  foreach(sort(keys(%::EMC::Sample))) {
    my $key = $_;
    next if ($key eq "flag" || $key eq "msd" || $key eq "gyration");
    next if (!$::EMC::Sample{$key});
    info("adding $key sampling\n");
    printf($stream "# System sampling: $key\n");
    if ($key eq "energy") {
      printf($stream "
variable	pe equal pe
variable	ke equal ke
variable	etotal equal etotal
variable	enthalpy equal enthalpy
variable	evdwl equal evdwl
variable	ecoul equal ecoul
variable	epair equal epair
variable	ebond equal ebond
variable	eangle equal eangle
variable	edihed equal edihed
variable	eimp equal eimp
variable	emol equal emol
variable	elong equal elong
variable	etail equal etail

fix		ene all ave/time \${tfreq} \${nsample} \${dtime} &
		c_thermo_temp &
	       	v_pe v_ke v_etotal v_enthalpy v_evdwl &
		v_ecoul v_epair v_ebond v_eangle v_edihed v_eimp &
		v_emol v_elong v_etail &
		file \${project}.energy

");
    }
    elsif ($key eq "pressure") {
      printf($stream "
fix		sample_press all ave/time \${tfreq} \${nsample} \${dtime} &
		c_thermo_temp &
		c_thermo_press[1] c_thermo_press[2] c_thermo_press[3] &
		c_thermo_press[4] c_thermo_press[5] c_thermo_press[6] &
		file \${project}.pressure

");
    }
    elsif ($key eq "volume") {
      printf($stream "
variable	volume equal vol
variable	hxx equal lx
variable	hyy equal ly
variable	hzz equal lz
variable	hxy equal xy
variable	hxz equal xz
variable	hyz equal yz

fix		vol all ave/time \${tfreq} \${nsample} \${dtime} &
		v_volume v_hxx v_hyy v_hzz v_hyz v_hxz v_hxy &
		file \${project}.volume

");
    }
    elsif ($key eq "green-kubo") {
      printf($stream "
variable	kB		equal	1.3806504e-23	# [J/K Boltzmann]
variable	atm2Pa		equal	101325.0	# [Pa Atmosphere]
variable	A2m		equal	1.0e-10		# [m]
variable	fs2s		equal	1.0e-15		# [s]

variable	convert 	equal	\${atm2Pa}*\${atm2Pa}*\${fs2s}*\${A2m}*\${A2m}*\${A2m}

fix		cnu all ave/correlate \${tfreq} \${nsample} \${dtime} &
		c_thermo_press[4] c_thermo_press[5] c_thermo_press[6]
fix		anu all ave/correlate \${tfreq} \${nsample} \${dtime} &
		c_thermo_press[4] c_thermo_press[5] c_thermo_press[6] ave running

variable	scale		equal	\${convert}/\${kB}*\${nsample}*\${timestep}*1000

variable	nu_xy		equal	trap(f_cnu[3])*\${scale}
variable	nu_xz		equal	trap(f_cnu[4])*\${scale}
variable	nu_yz		equal	trap(f_cnu[5])*\${scale}
variable	nu		equal	(v_nu_xy+v_nu_xz+v_nu_yz)/3.0

variable	anu1		equal	trap(f_anu[3])*\${scale}
variable	anu2		equal	trap(f_anu[4])*\${scale}
variable	anu3		equal	trap(f_anu[5])*\${scale}
variable	nu_avg		equal	(v_anu1+v_anu2+v_anu3)/3.0

fix		nu all ave/time \${dtime} 1 \${dtime} &
		v_nu_avg v_nu v_nu_xy v_nu_xz v_nu_yz title1 &
		\"# Time-averaged data: multiply with <vol>/<T> [LAMMPS units] for nu in [mPa s]\" &
		file \${project}.green-kubo

thermo_style	custom step temp c_thermo_temp pe ke press c_thermo_press vol

");
    }
  }
}


sub write_lammps_intermediate {
  
  return if (!($::EMC::ProfileFlag{flag}||%::EMC::Profiles||
	       $::EMC::Sample{gyration}||$::EMC::Sample{msd}));

  my $stream = shift(@_);
  my $binsize = $::EMC::BinSize;
  my $x = $::EMC::Direction{x};
  my $g = "profile";
  my $offset = 4;
  my $i;
  my $l;

  if ($::EMC::Sample{msd}) {
    info("adding msd analysis\n");
  }
  if ($::EMC::ProfileFlag{flag}||%::EMC::Profiles) {
    info("adding profile analysis\n");
  }
  if ($::EMC::ProfileFlag{flag}||$::EMC::Sample{msd}||$::EMC::Sample{gyration}) {
    my %dim = ("1d" => 0, "2d" => 0, "3d" => 0, msd => 0);
    $dim{"1d"} = ($::EMC::ProfileFlag{density}||$::EMC::ProfileFlag{pressure});
    $dim{"3d"} = ($::EMC::ProfileFlag{density3d});
    $dim{"msd"} = ($::EMC::Sample{msd});
    $dim{"gyration"} = ($::EMC::Sample{gyration});
    if ($::EMC::ProfileFlag{pressure}) {
      if (!$::EMC::Lammps{chunk}) {
	error("Pressure profiles can only be used in combination with LAMMPS chunks\n");
      }
      my $m = "all"; $g = $m;
      my $name = ($::EMC::Lammps{prefix} ? $::EMC::Project{name}."_" : "").$m;
      printf($stream "# Cluster sampling: $m\n\n");
      printf($stream "compute\t\tchunk_$m $g chunk/atom bin/1d $x 0.0 $binsize units reduced\n");
      printf($stream "compute\t\tpress_$m $g stress/atom NULL\n");
      printf($stream "fix\t\tpress_$m $g ave/chunk &\n");
      printf($stream "\t\t\${tfreq} \${nsample} \${dtime} chunk_$m &\n");
      printf($stream "\t\tc_press_$m\[1] c_press_$m\[2] c_press_$m\[3] &\n");
      printf($stream "\t\tc_press_$m\[4] c_press_$m\[5] c_press_$m\[6] &\n");
      printf($stream "\t\tfile $name.pressure\n\n");
    }
    printf($stream "# Cluster sampling: init\n\nvariable\tin\tequal\t0\n\n")
      if (scalar(@::EMC::ClusterSampling));
    for ($i=0; $i<scalar(@::EMC::ClusterSampling); ++$i) {
      my $m = $::EMC::ClusterSampling[$i]; $g = $m;
      my $name = ($::EMC::Lammps{prefix} ? $::EMC::Project{name}."_" : "").$m;
      
      printf($stream "# Cluster sampling: $m\n\n");
      printf($stream "variable\ti0\tequal\t\${in}+1\n");
      printf($stream "variable\tin\tequal\t\${in}+\${nl_$m}\n");
      printf($stream "group\t\t$g\tmolecule <>\t\${i0}\t\${in}\n\n");
      if ($::EMC::Lammps{chunk}) {
	if ($dim{"1d"}) {
	  printf($stream "compute\t\tchunk_1d_$m $g chunk/atom bin/1d &\n\t\t$x 0.0 $binsize units reduced\n"); }
	if ($dim{"3d"}) {
	  printf($stream "compute\t\tchunk_3d_$m $g chunk/atom bin/3d &\n\t\tx 0.0 $binsize y 0.0 $binsize z 0.0 $binsize units reduced\n"); }
	if ($::EMC::ProfileFlag{pressure}) {
	  printf($stream "compute\t\tpress_$m $g stress/atom NULL\n");
	}
	if ($dim{"msd"}) {
	  my $ave = $dim{"msd"}==2 ? "/ave" : "";
	  printf($stream "compute\t\tchunk_msd_$m $g chunk/atom molecule\n");
	  printf($stream "compute\t\tmsd_$m $g msd/chunk$ave chunk_msd_$m\n");
	}
	if ($dim{"gyration"}) {
	  printf($stream "compute\t\tchunk_gyration_$m $g chunk/atom molecule\n");
	  printf($stream "compute\t\tgyration_$m $g gyration/chunk chunk_gyration_$m\n");
	}
      } elsif ($dim{"3d"}) {
	error("3D profiles can only be used in combination with LAMMPS chunks\n");
      } elsif ($dim{"msd"}) {
	printf($stream "compute\t\tmsd_$m $g msd/molecule\n");
      } elsif ($dim{"gyration"}) {
	error("gyration can only be used in combination with LAMMPS chunks\n");
      }
      if ($::EMC::ProfileFlag{density}) {
	printf($stream "\nif \"\${nl_$m} > 0\" then &\n");
	if ($::EMC::Lammps{chunk}) {
	  printf($stream "\"fix\t\tdens_1d_$m $g ave/chunk &\n");
	  printf($stream "\t\t\${tfreq} \${nsample} \${dtime} chunk_1d_$m &\n");
	  printf($stream "\t\tdensity/mass file $name.density\"\n");
	} else {
	  printf($stream "\"fix\t\tdens_$m $g ave/spatial &\n");
	  printf($stream "\t\t\${tfreq} \${nsample} \${dtime} $x 0.0 $binsize &\n");
	  printf($stream "\t\tdensity/mass file $name.density units reduced\"\n");
	}
      }
      if ($::EMC::ProfileFlag{density3d}) {
	printf($stream "\nif \"\${nl_$m} > 0\" then &\n");
	printf($stream "\"fix\t\tdens_3d_$m $g ave/chunk &\n");
	printf($stream "\t\t\${tfreq} \${nsample} \${dtime} chunk_3d_$m &\n");
	printf($stream "\t\tdensity/mass file $name.density3d\"\n");
      }
      if ($::EMC::ProfileFlag{pressure}) {
	if (!$::EMC::Lammps{chunk}) {
	  error("Pressure profiles can only be used in combination with LAMMPS chunks\n");
	}
	printf($stream "\nif \"\${nl_$m} > 0\" then &\n");
	printf($stream "\"fix\t\tpress_1d_$m $g ave/chunk &\n");
	printf($stream "\t\t\${tfreq} \${nsample} \${dtime} chunk_1d_$m &\n");
	printf($stream "\t\tc_press_$m\[1] c_press_$m\[2] c_press_$m\[3] &\n");
	printf($stream "\t\tc_press_$m\[4] c_press_$m\[5] c_press_$m\[6] &\n");
	printf($stream "\t\tfile $name.pressure\"\n");
      }
      if ($::EMC::Sample{msd}) {
	printf($stream "\nif \"\${nl_$m} > 0\" then &\n");
	printf($stream "\"fix\t\tmsd_$m $g ave/time &\n");
	printf($stream "\t\t\${tfreq} \${nsample} \${dtime} &\n");
	printf($stream "\t\tc_msd_$m\[*\] mode vector file $name.msd\"\n");
      }
      if ($::EMC::Sample{gyration}) {
	printf($stream "\nif \"\${nl_$m} > 0\" then &\n");
	printf($stream "\"fix\t\tgyration_$m $g ave/time &\n");
	printf($stream "\t\t\${tfreq} \${nsample} \${dtime} &\n");
	printf($stream "\t\tc_gyration_$m mode vector file $name.gyration\"\n");
      }
      #printf($stream "group\t\t$g\tdelete\n");
      printf($stream "\n");
      $l = $m;
    }
  }
  if (defined($::EMC::Profiles{type})) {
    foreach (sort(keys %{$::EMC::Profiles{type}})) {
      my $index = 1;
      my $m = $_; $g = $m;
      my $name = ($::EMC::Lammps{prefix} ? $::EMC::Project{name}."_" : "").$m;
      my @a = @{${$::EMC::Profiles{type}}{$m}};
      my $type = shift(@a);
      my $binsize = shift(@a);
      
      printf($stream "# Profile sampling: $m\n\n");
      print($stream "group\t\t$g\ttype");
      foreach (sort(@a)) {
	#printf($stream " \${type_".convert_key("type", $_)."}");
	printf($stream " \${type_$_}");
      }
      printf($stream "\n");
      if ($::EMC::Lammps{chunk}) {
	if ($type eq "density" || $type eq "pressure") {
	  printf($stream "compute\t\tchunk_$m $g chunk/atom bin/1d $x 0.0 $binsize units reduced\n");
	} elsif ($type eq "density3d") {
	  printf($stream "compute\t\tchunk_".$m."_3d $g chunk/atom bin/3d &\n\t\tx 0.0 $binsize y 0.0 $binsize z 0.0 $binsize units reduced\n");
	}
	if ($type eq "density") {
	  printf($stream "fix\t\tdens_$m $g ave/chunk &\n");
	  printf($stream "\t\t\${tfreq} \${nsample} \${dtime} chunk_$m &\n");
	  printf($stream "\t\tdensity/mass file $name.density\n");
	} elsif ($type eq "density3d") {
	  printf($stream "fix\t\tdens_$m $g ave/chunk &\n");
	  printf($stream "\t\t\${tfreq} \${nsample} \${dtime} chunk_".$m."_3d &\n");
	  printf($stream "\t\tdensity/mass file $name.density3d\n");
	} elsif ($type eq "pressure") {
	  printf($stream "compute\t\tpress_$m $g stress/atom NULL\n");
	  printf($stream "fix\t\tpress_$m $g ave/chunk &\n");
	  printf($stream "\t\t\${tfreq} \${nsample} \${dtime} chunk_$m &\n");
	  printf($stream "\t\tc_press_$m\[1] c_press_$m\[2] c_press_$m\[3] &\n");
	  printf($stream "\t\tc_press_$m\[4] c_press_$m\[5] c_press_$m\[6] &\n");
	  printf($stream "\t\tfile $name.pressure\n");
	}
      } else {
	printf($stream "\"fix\t\tdens_$m $g ave/spatial &\n");
	printf($stream "\t\t\${tfreq} \${nsample} \${dtime} $x 0.0 $binsize &\n");
	printf($stream "\t\tdensity/mass file $name.density units reduced\n");
      }
      #printf($stream "group\t\t$g\tdelete\n");
      printf($stream "\n");
    }
  }
  if (defined($::EMC::Profiles{cluster})) {
    foreach (sort(keys %{$::EMC::Profiles{cluster}})) {
      my $m = $_; $g = $m;
      my $name = ($::EMC::Lammps{prefix} ? $::EMC::Project{name}."_" : "").$m;
      my @arg = @{${$::EMC::Profiles{cluster}}{$m}};
      my $type = shift(@arg);
      my $binsize = shift(@arg);
      my $t = shift(@arg);
      
      printf($stream "# Profile sampling: $m\n\n");
      printf($stream "group\t\t$g\tmolecule <>\t\${n0_$t}\t\${n1_$t}\n");
      foreach (@arg) {
	if (0) {
	  printf($stream "group\t\ttmp0\tmolecule <>\t\${n0_$_}\t\${n1_$_}\n");
	  printf($stream "group\t\ttmp1\tunion\ttmp0\t$m\n");
	  printf($stream "group\t\ttmp0\tdelete\n");
	  printf($stream "group\t\t$g\tdelete\n");
	  printf($stream "group\t\t$g\tunion\ttmp1\n");
	  printf($stream "group\t\ttmp1\tdelete\n");
	} else {
	  printf($stream "group\t\ttmp\tmolecule <>\t\${n0_$_}\t\${n1_$_}\n");
	  printf($stream "group\t\t$g\tunion\t$g\ttmp\n");
	  printf($stream "group\t\ttmp\tdelete\n");
	}
      }
      if ($::EMC::Lammps{chunk}) {
	if ($type eq "density" || $type eq "pressure") {
	  printf($stream "compute\t\tchunk_$m $g chunk/atom bin/1d $x 0.0 $binsize units reduced\n");
	} elsif ($type eq "density3d") {
	  printf($stream "compute\t\tchunk_".$m."_3d $g chunk/atom bin/3d &\n\t\tx 0.0 $binsize y 0.0 $binsize z 0.0 $binsize units reduced\n");
	}
	if ($type eq "density") {
	  printf($stream "fix\t\tdens_$m $g ave/chunk &\n");
	  printf($stream "\t\t\${tfreq} \${nsample} \${dtime} chunk_$m &\n");
	  printf($stream "\t\tdensity/mass file $name.density\n");
	} elsif ($type eq "density3d") {
	  printf($stream "fix\t\tdens_$m $g ave/chunk &\n");
	  printf($stream "\t\t\${tfreq} \${nsample} \${dtime} chunk_".$m."_3d &\n");
	  printf($stream "\t\tdensity/mass file $name.density3d\n");
	} elsif ($type eq "pressure") {
	  printf($stream "compute\t\tpress_$m $g stress/atom NULL\n");
	  printf($stream "fix\t\tpress_$m $g ave/chunk &\n");
	  printf($stream "\t\t\${tfreq} \${nsample} \${dtime} chunk_$m &\n");
	  printf($stream "\t\tc_press_$m\[1] c_press_$m\[2] c_press_$m\[3] &\n");
	  printf($stream "\t\tc_press_$m\[4] c_press_$m\[5] c_press_$m\[6] &\n");
	  printf($stream "\t\tfile $name.pressure\n");
	}
      } else {
	printf($stream "\"fix\t\tdens_$m $g ave/spatial &\n");
	printf($stream "\t\t\${tfreq} \${nsample} \${dtime} $x 0.0 $binsize &\n");
	printf($stream "\t\tdensity/mass file $name.density units reduced\n");
      }
      #printf($stream "group\t\t$g\tdelete\n");
      printf($stream "\n");
    }
  }
}


sub write_lammps_footer {
  my $stream = shift(@_);

  printf($stream
"# Run conditions

restart		\${dtrestart} \${project}.restart1 \${project}.restart2
dump		1 all custom \${dtdump} \${project}.dump id type x y z
run		\${trun}

");
}


# NAMD script

sub write_namd {
  return if (!$::EMC::NAMD{write});

  my $name = shift(@_);

  if ((-e "$name.namd")&&!$::EMC::Replace{flag}) {
    warning("\"$name.namd\" exists; use -replace flag to overwrite\n");
    return;
  }

  info("creating NAMD run script \"$name.namd\"\n");

  my $stream = fopen("$name.namd", "w");
  
  write_namd_header($stream);
  write_namd_verbatim($stream);
  write_namd_footer($stream);
  close($stream);
}


sub write_namd_header {
  my $stream = shift(@_);
  my $date = date; chop($date);

  printf($stream "%s",
"# LAMMPS input script for standardized atomistic simulations
# Created by $::EMC::Script v$::EMC::Version, $::EMC::Date as part of EMC
# on $date

# Variable definitions

set			project		\"$::EMC::Project{name}\"
set			source		\"$::EMC::Build{dir}\"
set			params		\"$::EMC::Build{dir}\"
set			frestart	".($::EMC::Lammps{restart} ? 1 : 0)."
set			restart		\"\"

set			ftemperature	".($::EMC::Pressure{flag} ? 0 : 1)."
set			temperature	$::EMC::Temperature
set			temp_damp	$::EMC::NAMD{temp_damp}

set			fpressure	$::EMC::Pressure{flag}
set			pressure	$::EMC::Pressure{value}
set			pres_period	$::EMC::NAMD{pres_period}
set			pres_decay	$::EMC::NAMD{pres_decay}

set			cutoff_inner	$::EMC::CutOff{inner}
set			cutoff_outer	$::EMC::CutOff{pair}
set			cutoff_ghost	".($::EMC::CutOff{ghost}>0 ? $::EMC::CutOff{ghost} : $::EMC::CutOff{pair}+2)."

set			timestep	$::EMC::Timestep
set			dtnonbond	$::EMC::NAMD{dtnonbond}
set			dtcoulomb	$::EMC::NAMD{dtcoulomb}
set			dtupdate	$::EMC::NAMD{dtupdate}
set			dtthermo	$::EMC::NAMD{dtthermo}
set			dtdcd		$::EMC::NAMD{dtdcd}
set			dtrestart	$::EMC::NAMD{dtrestart}
set			dttiming	$::EMC::NAMD{dttiming}

set			tminimize	$::EMC::NAMD{tminimize}
set			trun		$::EMC::NAMD{trun}

# Input

structure		\"\${source}/\${project}.psf\"
coordinates		\"\${source}/\${project}.pdb\"

if { \${frestart} eq \"0\" } {
  source		\"\${source}/\${project}.cell\"
  temperature		\${temperature}
} else {
  binCoordinates	\"\${restart}/\${project}.restart.coor\"
  binVelocities		\"\${restart}/\${project}.restart.vel\"
  extendedSystem	\"\${restart}/\${project}.restart.xsc\"
}

# Force calculations

paraTypeCharmm		on
parameters		\"\${params}/\${project}.prm\"

exclude			scaled1-4
1-4scaling		1.0
switching		on
switchDist		\${cutoff_inner}
cutoff			\${cutoff_outer}
pairlistdist		\${cutoff_ghost}

PME			yes
PMEGridSpacing		1.0

# Integrator

rigidbonds		all
timestep		\${timestep}
nonBondedFreq		\${dtnonbond}
fullElectFrequency	\${dtcoulomb}
stepsPerCycle		\${dtupdate}

# Temperature

if { \${ftemperature} } {
  langevin		on
  langevinDamping	\${temp_damp}
  langevinTemp		\${temperature}
  langevinHydrogen	off
}

# Pressure

if { \${fpressure} } {
  useGroupPressure	yes
  useFlexibleCell	no
  useConstantArea	no
  langevinPiston	on
  langevinPistonTarget	\${pressure}
  langevinPistonPeriod	\${pres_period}
  langevinPistonDecay	\${pres_decay}
  langevinPistonTemp	\${temperature}	
}

# Output

outputname		\${project}
outputEnergies		\${dtthermo}
outputPressure		\${dtthermo}
restartfreq		\${dtrestart}
outputTiming		\${dttiming}

if { \${dtdcd} > 0 } {
  DCDFile		\${project}.dcd
  DCDFreq		\${dtdcd}
}

wrapAll			on

");
}


sub write_namd_verbatim {
  return if (!defined($::EMC::NAMD{verbatim}));

  my $stream = shift(@_);

  printf($stream "# Verbatim from .esh\n\n");
  foreach (@{$::EMC::NAMD{verbatim}}) {
    printf($stream "%s\n", $_);
  }
  printf($stream "\n");
}


sub write_namd_footer {
  my $stream = shift(@_);

  printf($stream "%s",
"# Run conditions

if { \${frestart} == 0 } {
  puts			\"UserInfo: running minimizer\"
  minimize		\${tminimize}
  reinitvels		\${temperature}
}

puts			\"UserInfo: starting run\"
run			\${trun}
");
}


# create environment

sub create_environment {
  if (!%::EMC::Loop) {
    error("cannot create environment with undefined loops\n");
  }
  if ($::EMC::Queue{ncores}<1) {
    error("queue_ncores not set\n");
  }
  push(@{$::EMC::Loop{stage}}, "generic") if (!defined($::EMC::Loop{stage}));
  push(@{$::EMC::Loop{trial}}, "generic") if (!defined($::EMC::Loop{trial}));

  my $pwd = $::EMC::WorkDir;
  my $root = $::EMC::Root;
  
  $pwd =~ s/^~/$ENV{HOME}/;
  $::EMC::WorkDir =~ s/^~/\${HOME}/g;
  $::EMC::Root =~ s/^$ENV{HOME}/\${HOME}/g;

  set_variables();
  create_dirs("analyze", "build", "chemistry", "run", "test");
  
  chdir("chemistry");
  mkdir("scripts") if (! -e "scripts");
  my $name = "scripts/$::EMC::Project{script}.sh";
  create_dirs(dirname($name));
  if (!check_exist("chemistry", $name)) {
    info("creating job create chemistry script \"$name\"\n");
    my $stream = fopen($name, "w");
    chmod(0755, $stream);
    write_job_create($stream, $name =~ tr/\///);
    close($stream);
  }
  chdir($pwd);
  
  foreach ("analyze", "build", "run", "test") {
    chdir($_);
    write_job($_);
    chdir($pwd);
  }

  $::EMC::WorkDir = $pwd;
  $::EMC::Root = $root;
}


sub create_dirs {
  my %check = ("analyze", "build", "run", "test");

  foreach (@_) {
    return if (defined($check{$_}) && 
              ($::EMC::RunName{$_} eq "" || $::EMC::RunName{$_} eq "-"));
    my $last = "";
    foreach (split("/", $_)) { mkdir($last.$_); $last .= "$_/"; }
  }
}


# write job script

sub write_job {
  my $type = shift(@_);
  my $script = "$::EMC::RunName{$type}.sh";

  return if ($::EMC::RunName{$type} eq "" || $::EMC::RunName{$type} eq "-");
  if ($type eq "test") {
    mkpath($::EMC::RunName{$type}) unless(-d $::EMC::RunName{$type});
    $script = "$::EMC::RunName{$type}/setup.sh";
  }
  if ((-e $script)&&!$::EMC::Replace{flag}) {
    warning("\"$script\" exists; use -replace flag to overwrite\n");
    return;
  }

  info("creating job $type script \"$script\"\n");

  my $stream = fopen($script, "w");

  chmod(0755, $stream);
  write_job_header($stream, $type);
  write_job_functions($stream, $type);
  write_job_submit($stream, $type);
  write_job_settings($stream, $type);
  write_job_footer($stream, $type);

  close($stream);
}


sub my_job_print {
  my $stream = shift(@_);
  my $indent = shift(@_);
  my $s = shift(@_);
  my $nspace = $indent%8;
  my $ntab = ($indent-$nspace)/8;
  my $i;

  for ($i=0; $i<$ntab; ++$i) { printf($stream "\t"); }
  for ($i=0; $i<$nspace; ++$i) { printf($stream " "); }
  printf($stream $s."\n");
}

 
sub write_job_indent {
  my $stream = shift(@_);
  my $nindent = shift(@_);
  my $i;

  foreach (split("\n", shift(@_))) {
    my $arg = $_;
    my $ntab = length(($arg =~ /^(\t*)/)[0]); $arg =~ s/^\t+//;
    my $nspace = length(($arg =~ /^( *)/)[0]); $arg =~ s/^\s+//;
    my $indent = 2*$nindent+8*$ntab+$nspace;
    my $n = 80*($::EMC::Flag{width}+1)*int(($indent+10)/
					  (80*($::EMC::Flag{width}+1))+1);
    my $npars = 0;
    my $s = "";

    foreach (split(" ", $arg)) {
      my $tmp = $s.(length($s) ? " $_" : $_);
      if ($indent+length($tmp)+1<=$n-2) { $s = $tmp; next; }
      my_job_print($stream, $indent+2*$npars, $s." \\");
      $npars += ($s =~ tr/\(//)-($s =~ tr/\)//);
      $s = $_;
    }
    my_job_print($stream, $indent+2*$npars, $s) if (length($s));
  }
}


sub write_job_loops {
  my $stream = shift(@_);
  my $type = shift(@_);
  my $indent = shift(@_);
  my $text = shift(@_);
  my $indent0 = $indent;
  my %pairing = ();
  my @previous = ();
  my @vars = ();
  my $nchains = $::EMC::NChains;
  
  $nchains = 1 if ($nchains<1);
  job_loops_pairing(\%pairing, \@vars);
  if ($type eq "run") {
    write_job_indent(
      $stream, $indent++,
	"for ichoice in \$(seq \$(calc \"1-\${fbuild}\") 1); do");
    write_job_indent(
      $stream, $indent,
	"if [ \${ichoice} == 0 ]; then nserials=1; else nserials=$nchains; fi;");
    write_job_indent(
      $stream, $indent++, 
	"for iserial in \$(create_copies \${nserials}); do");
    write_job_indent(
      $stream, $indent, "jobids=();");
  }
  foreach (@vars) {					# create loops
    my @arg = split(":");
    my $name = @arg[0];
    my @pairs;

    if ($name eq "copy") {
      write_job_indent(
	$stream, $indent++, 
	  "for copy in \$(zero 2 \$(create_copies \${copys[0]})); do");
    } else {
      @pairs = @{$pairing{$name}};
      write_job_indent(
	$stream, $indent++, "for i_$name in \${!$name"."s[@]}; do");
      my $list = scalar(@previous) ? 
	"\$(replace \${$name"."s[\$i_$name]} ".join(" ", @previous).")" :
	"\${$name"."s[\$i_$name]}";
      write_job_indent(
	$stream, $indent++, "for $name in \$(create_list $list); do");
      push(@previous, "\@".uc($name), "\${$name}");
    }
    foreach (@pairs) {
      my $names = "l_$_"."s";
      if ($_ eq "copy") {
	write_job_indent($stream, $indent++,
	  "for copy in \$(zero 2 \$(create_copies \${copys[\$i_$name]})); do");
      } else {
	my $list = scalar(@previous) ? 
	  "\$(replace \${$_"."s[\$i_$name]} ".join(" ", @previous).")" :
	  "\${$_"."s[\$i_$name]}";
	write_job_indent(
	  $stream, $indent++, "for $_ in \$(create_list $list); do");	
      }
      push(@previous, "\@".uc($_), "\${$_}");
    }
  }

  write_job_indent($stream, $indent, $text);		# write text
 
  $indent0 += 2 if ($type eq "run"); 
  while ($indent>$indent0) {				# write postamble
    write_job_indent($stream, --$indent, "done;");
  }
  write_job_indent($stream, $indent,
    "pack_exec;\necho;\nlast_jobids=(\"\${jobids[@]}\");");
  write_job_indent($stream, --$indent, "done;") if ($type eq "run");
  write_job_indent($stream, --$indent, "done;") if ($type eq "run");
}


sub write_job_func_test {
  my $stream = shift(@_);
  my $options = "\n    -project \"$::Project{directory}$::EMC::Project{name}\" \\";
 
  printf($stream "\nsub submit {\n");
  foreach (@::EMC::LoopVariables) {
    my $var = (split(":"))[0];
    $options .= "\n    -$var \"\${$var}\" \\";
    printf($stream 
      "  local $var=\"@{$::EMC::Loop{$_}}[0]\";\n")
  }
  printf($stream "
  run \"\${chemistry}/scripts/$::EMC::Project{script}.sh\" \\$options
    $::EMC::Project{name};
  run emc_setup.pl \\
    -project=$::EMC::Project{name} \\
    -workdir=\${home} \\
    $::EMC::Project{name}$::EMC::Script{extension};
}\n\n");
}


sub job_loops_pairing {					# setup pairing
  my $pairing = shift(@_);
  my $vars = shift(@_);
  my $last = "";
  my $fcopy = 0;
  my $i = 0;

  foreach (@::EMC::LoopVariables) {
    my @arg = split(":");
    my $name = @arg[0];
    my $fpair = @arg[1] eq "p" || @arg[1] eq "pair" ? 1 : 0;
    my $fhide = @arg[1] eq "h" || @arg[1] eq "hide" ? 1 : 0;
    
    if (($fpair || $fhide) && $i>0) {
      push(@{$pairing->{$last}}, $name);
    } elsif ($name eq "copy") {
      $fcopy = 1;
    } else {
      push(@{$vars}, $name);
      @{$pairing->{$name}} = ();
      $last = $name;
    }
    ++$i;
  }
  unshift(@{$vars}, "copy") if ($fcopy);
}


sub write_job_dir {
  my $text;
  my $flag;
 
  foreach (@_) { 
    my @arg = split(":");
    my $name = @arg[0];
    my $fhide = @arg[1] eq "h" || @arg[1] eq "hide" ? 1 : 0;
    if ($name eq "copy") {
      $flag = 1;
    } elsif ($fhide) {
      next;
    } else {
      $text .= "/\${$name}";
    }
  }
  $text .= "/\${copy}" if ($flag);
  return $text;
}


sub write_job_func {
  my $stream = shift(@_);
  my $type = shift(@_);
  my $text = shift(@_);
  my @vars = $type eq "run" ? split(" ", "dir serial iserial nserials ichoice restart frestart") :
	     $type eq "analyze" ? split(" ", "dir last") : ();
  my $i;

  if ($type eq "test") {
    return;
  }

  foreach (@::EMC::LoopVariables) {
    my @arg = split(":");
    my $name = @arg[0];
    my $fpair = @arg[1] eq "p" || @arg[1] eq "pair" ? 1 : 0;

    push(@vars, "i_$name") if (!$fpair && $name ne "copy");
    push(@vars, $name);
    ++$i;
  }

  printf($stream 
"
submit() {
  local ".join(" ", sort(@vars)).";

  printf \"### started at \$(date)\\n\\n\";
");
  write_job_loops($stream, $type, 1, $text);
  printf($stream "%s", "  printf \"### finished at \$(date)\\n\\n\";\n}\n\n");
}


sub write_job_stage {
  my $command = shift(@_);
  my $name = shift(@_);
  my $date = date;
  chop($date);

  info("creating chemistry \"$name\"\n");
  my $stream = fopen($name, "w");
  chmod(0755, $stream);
  printf($stream "#!/usr/bin/env emc_setup.pl
#
#  script:	$name
#  author:  	$::EMC::Script v$::EMC::Version, $::EMC::Date
#  date:	$date
#  purpose:	EMC setup chemistry file as part of a multiple simulation
#  		workflow; this file is auto-generated
#

");
  write_emc_verbatim($stream, $command);
  close($stream);
}


sub write_job_header {
  my $stream = shift(@_);
  my $type = shift(@_);
  my $date = date;
  my $text;

  chop($date);
  if ($type eq "test") {
    $text = "EMC test script for setting up a single test configuration";
  } else {
    $text = "EMC wrap around script for setting up multiple configurations";
  }
  printf($stream
"#!/bin/bash
#
#  script:	run_$type.sh
#  author:	$::EMC::Script v$::EMC::Version, $::EMC::Date
#  date:	$date
#  purpose:	$text;
#		to be used in conjuction with EMC v$::EMC::EMCVersion or higher;
#		this script is auto-generated
#
#  Copyright (c) 2004-$::EMC::Year Pieter J. in 't Veld
#  Distributed under GNU Public License as stated in LICENSE file in EMC root
#  directory
#
");
}


sub write_job_functions {
  my $stream = shift(@_);
  my $type = shift(@_);

  # GENERAL

  if ($type ne "test") {
    printf($stream 
"
# variables

script=\$(basename \"\$0\");

# functions

run() {
  echo \"\$@\"; \"\$@\";  }

first() {
  echo \"\$1\"; }

shft() {
  shift; echo \"\$@\"; }

calc() {
  perl -e 'print(eval(\$ARGV[0]));' -- \$@; } 

zero() {
  perl -e '
    \@a = \@ARGV;
    \$n = eval(shift(\@a));
    foreach (\@a) { \$n = length(\$_) if (\$n<length(\$_)); }
    foreach (\@a) { \$_ =~ s/^0+//; \$_ = sprintf(\"\%0\".\$n.\"d\", int(eval(\$_))); }
    print(join(\" \", \@a));
    ' -- \$@;
}

split() {
  echo \$1 | awk '{split(\$0,a,\"'\$2'\"); print a['\$3']}'; }

join() {
  perl -e 'print(join(\",\", \@ARGV).\"\\n\");' -- \$@; }

last() { 
  local s=\$1;
  while [ \"\$1\" != \"\" ]; do s=\$1; shift; done;
  echo \"\$s\"; }

start() {
  perl -e '
    \$h = \$ARGV[0]+0; \$m = \$ARGV[1]+\$ARGV[2];
    if ((\$d = int(\$m/60))) { \$h += \$d; \$m -= 60*\$d; }
    \$h = \"0\".\$h if (\$h<10); \$m = \"0\".\$m if (\$m<10);
    print(\"\$h\$m\\n\");
    ' -- \$(date +\%H) \$(date +\%M) \$1; }

substr() {
  perl -e 'print(substr(\$ARGV[0],eval(\$ARGV[1])));' -- \$@; }

location() {
  local home=\"\$(pwd -P)\";
  cd \"\$(dirname \$1)\";
  pwd -P;
  cd \"\${home}\";
}

strip() {
  local dir=\$(echo \$1 | awk '{split(\$0,a,\"'\$HOME/'\"); print a[2]}');

  if [ \"\$dir\" = \"\" ]; then dir=\$1; fi;
  if [ \"\$dir\" = \"\$HOME\" ]; then dir=\"\"; fi;
  echo \"\$dir\";
}

create_list() {
  local list=(\$(perl -e \'
    \@arg = split(\":\", \$ARGV[0]);
    \@a = shift(\@arg); foreach(\@arg) { push(\@a, eval(\$_)); }
    print(join(\" \", \@a))\' -- \$1));

  if [ \"\${list[0]}\" == \"s\" -o \"\${list[0]}\" == \"seq\" ]; then
    if [ \"\${list[4]}\" == \"w\" ]; then
      echo \$(seq -\${list[4]} \${list[1]} \${list[3]} \${list[2]});
    else
      echo \$(seq \${list[1]} \${list[3]} \${list[2]});
    fi;
  else
    echo \"\$1\";
  fi;
}

create_copies() {
  local list=(\$(perl -e \'print(join(\" \", split(\":\", \@ARGV[0])))\' -- \$1));

  if [ \"\${list[0]}\" == \"s\" -o \"\${list[0]}\" == \"seq\" ]; then
    echo \$(seq -w \${list[1]} \${list[3]} \${list[2]});
  else
    echo \$(seq -w 0 \$(calc \"\$1-1\"));
  fi;
}

#tmp=1;
run_sh() {
  local output;
  local line=(-memory \${memorypercore} -ppn \${ncorespernode});

  if [ \"\${queue_account}\" != \"\" ]; then
    line+=(-account \${queue_account});
  fi;
  if [ \"\${queue_user}\" != \"\" ]; then
    line+=(\${queue_user});
  fi;
  line+=(\$@);
  echo \"run.sh \${line[@]}\"; 
  #jobid=\$tmp; tmp=\$((tmp+1)); echo \${jobid}; return;
  while IFS= read -r; do output+=(\"\$REPLY\"); done < <(run.sh \${line[@]});
  printf \"%%s\\n\" \"\${output[@]}\";
  jobid=\$(perl -e '
    \$a = (split(\" \", \@ARGV[0]))[-1];
    \$a =~ s/[<|>]//g; 
    print(\$a);\' -- \"\${output[3]}\");
}

run_check() {
  local dir=\"\$1\";
  local error=();
  local file;
  local stat;

  for file in \"\${dir}/\"*.sh; do
    if [ -e \"\${file}\" ]; then 
      stat=\"\$(run_stat.sh \$(\"\${file}\" job))\";
      case \"\${stat}\" in 
	Q) error+=(\"queued \\\"\${file}\\\"\");;
	R) error+=(\"running \\\"\${file}\\\"\");;
      esac;
    fi;
  done;
  if [ \${#error[@]} -gt 0 ]; then
    for file in \"\${error[@]}\"; do
      echo \"error: cannot overwrite \${file}\";
    done;
    printf \"\\nerror: $type script not executed\\n\\n\";
    exit;
  fi;
  run rm -rf \"\${dir}\";
  run mkdir \"\${dir}\";
}

wait_id() {
  local id;

  jobid=0;
  if [ \${#last_jobids[@]} -gt 0 ]; then
    jobid=\"\${last_jobids[0]}\";				# determine dependence
    last_jobids=(\${last_jobids[@]:1});
    if [ \${#waitids[@]} -gt 0 ]; then
      for id in \${waitids[@]}; do
	if [ \"\${jobid}\" == \"\${id}\" ]; then return; fi;
      done;
    fi;
    if [ \"\${jobid}\" != \"-1\" -a \"\${jobid}\" != \"0\" ]; then
      if [ \"\${waitids}\" == \"\" ]; then waitids=\"\${jobid}\";
      else waitids=\"\${waitids}:\${jobid}\"; fi;
    fi;
  fi;
}

pack_file() {
  local dir=\"\${home}/\${pack_dir}\";
  echo \$(perl -e \'printf(\"%%s/%%04d%%s\", \@ARGV);\' -- \"\${dir}\" \${npack[0]} \$1);
}

pack_exec() {
  local i wait;
  local file=\"\$(pack_file)\";
  local dir=\"\$(dirname \"\${file}\")\";
 
  file=\$(basename \"\${file}\");
  if [ \${npack[1]} -lt 1 ]; then return; fi;		# skip on empty
  if [ \"\${waitids}\" != \"\" ]; then wait=\" -wait \${waitids}\"; fi;
  if [ \${fpack} == 1 ]; then				# based on scripts
    run pushd \"\${dir}\";
    chmod +x \"\${file}.sh\";
    printf \"\\n  wait;\\n\\n\" >>\"\${file}.sh\";
    printf 'elif [ \"\$1\" == \"job\" ]; then\\n\\n' >>\"\${file}.sh\";
    if [ \"\${queue}\" == \"local\" ]; then
      printf \"  echo \${jobid};\\n\\n\" >>\"\${file}.sh\";
      printf \"fi;\\n\\n\" >>\"\${file}.sh\";
    fi;
    run_sh \\
      -n \${ncorespernode} -single \${wait} \\
      -walltime \${walltime} -starttime \${starttime} -queue \${queue} \\
      -project \${file} -output \${file}.log ./\${file}.sh run;
    if [ \"\${queue}\" != \"local\" ]; then
      printf \"  echo \${jobid};\\n\\n\" >>\"\${file}.sh\";
      printf \"fi;\\n\\n\" >>\"\${file}.sh\";
    fi;
    run popd;
  else
    run_sh \${wait} \"\$@\";				# direct execution
  fi;
  for i in \${!jobids[@]}; do
    if [ \"\${jobids[\$i]}\" == \"-1\" ]; then jobids[\$i]=\${jobid}; fi;
  done;
  npack[0]=\$(calc \"\${npack[0]}+1\");
  npack[1]=0;
  waitids=();
}

pack_header() {
  printf '#!/bin/bash\\n\\n';
  printf 'run() { echo \"\$@\"; \"\$@\"; }\\n\\n';
  printf 'if [ \"\$1\" == \"run\" ]; then\\n';
}

run_pack() {
  local command=\$1; shift;				# should be -n
  local n=\$1; shift; 					# ncores to run with
  local file=\"\$(pack_file)\";
  local dir=\"\$(dirname \"\${file}\")\";

  if [ \${command} != \"-n\" ]; then
    echo \"panic: first argument of run_pack != '-n'\"; echo; exit;
  fi;
  wait_id;
  jobids+=(-1);						# future dependence

  fpack=0;						# set fpack
  if [ \"\${ncorespernode}\" != \"default\" ]; then
    if [ \${n} -lt \${ncorespernode} ]; then fpack=1; fi;
  fi;
  
  if [ \${fpack} == 1 ]; then				# execute packing
    echo \"run_pack.sh -n \$n \$@\"; 
    if [ ! -e \"\${file}.sh\" ]; then pack_header >\"\${file}.sh\"; fi;
    echo >>\"\${file}.sh\";
    echo \"  run cd \\\"\$(pwd)\\\"\" >>\"\${file}.sh\";
    echo \"  run run.sh -n \$n -system local \$@ &\" >>\"\${file}.sh\";
    echo \"\$(pwd)\" >>\"\${file}.dirs\";
    npack[1]=\$(calc \"\${npack[1]}+\${n}\");
    if [ \"\$(calc \"\${npack[1]}+\${n}\")\" -gt \"\${ncorespernode}\" ]; then
      pack_exec;
    fi;
  else
    npack[1]=1;						# direct execution
    pack_exec -n \$n \"\$@\";
  fi;
}

run_null() {
  jobids+=(0);						# no dependence
}
");
  }
  print($stream "
replace() {
  perl -e \'
    for (\$i=1; \$i<scalar(\@ARGV); \$i+=2) {
      my \$a; foreach(split(\"\", \$ARGV[\$i])) {
       	\$a .= \$l eq \"@\" && \$_ ne \"{\" ? \"{\$_\" : \$_; \$l = \$_; }
      \$a .= \"}\" if (\$l ne \"}\");
      \$h{\$a} = \$ARGV[\$i+1]; \$h{\$a} =~ s/^0+//;
    }
    foreach(split(\"\", \$ARGV[0])) {
      if (\$_ eq \"[\") {
	++\$brackets;
      } elsif (\$_ eq \"]\") {
	--\$brackets;
      }
      if (\$_ eq \"@\" && !\$brackets) {
	if (\$v ne \"\") { 
	  \$v .= \"}\"; \$r .= (defined(\$h{\$v}) ? \$h{\$v} : \$v);
	}
	\$v = \$_.\"{\"; \$f = 1; \$b = 0;
      } elsif (\$f) {
	if ((\$_ =~ /[a-zA-Z]/)||(\$_ =~ /[0-9]/)||(\$b && \$_ ne \"}\")) {
	  \$v .= \$_;
	} elsif (\$_ eq \"{\" && \$l eq \"@\") {
	  \$b = 1;
	} else {
	  \$v .= \"}\";
	  \$r .= (defined(\$h{\$v}) ? \$h{\$v} : \$v).(\$b && \$_ eq \"}\" ? \"\" : \$_);
	  \$v = \"\"; \$f = \$b = 0;
	}
      } else {
	\$r .= \$_;
      }
      \$l = \$_;
    }
    \$v .= \"}\" if (\$v ne \"\");
    \$r .= (defined(\$h{\$v}) ? \$h{\$v} : \$v);
    print(\$r);
  \' -- \$@;
}
");

  # ANALYZE

  if ($type eq "analyze" && defined($::EMC::Analyze{scripts})) {
    if (${${$::EMC::Analyze{scripts}}{cavity}}{active}) {
      $::EMC::Analyze{data} = 0;
    }
    printf($stream
"
help() {
  echo \"EMC analyze script created by $::EMC::Script v$::EMC::Version, $::EMC::Date\n\";
  echo \"Usage:\n  \$script [-option [#]]\n\";
  echo \"Options:\";
  echo \"  -help\t\tthis message\";
  echo \"  -[no]archive\tcontrol creation of exchange tar archive\";
  echo \"  -[no]data\tcontrol transferral of exchange file list into tar archive\";
  echo \"  -[no]emc\tcontrol creation of last trajectory structure in EMC format\";
  echo \"  -[no]pdb\tcontrol creation of last trajectory structure in PDB format\";
  echo \"  -[no]replace\tcontrol replacement of exiting results\";
  echo \"  -skip\t\tset number of entries to skip [\${skip}]\";
  echo \"  -source\tset data source directory [\${source}]\";
  echo \"  -window\tset averaging window [\${window}]\";
  echo;
  exit;
}

run_init() {
  femc=0;
  fpdb=1;
  farchive=$::EMC::Analyze{archive};
  fdata=$::EMC::Analyze{data};
  freplace=$::EMC::Analyze{replace};
  skip=$::EMC::Analyze{skip};
  window=$::EMC::Analyze{window};
  source=\"$::EMC::Analyze{source}\";

  while [ \"\$1\" != \"\" ]; do
    case \"\$1\" in
      -archive) farchive=1;;
      -noarchive) farchive=0;;
      -data) fdata=1;;
      -nodata) fdata=0;;
      -emc) femc=1;;
      -noemc) femc=0;;
      -pdb) fpdb=1;;
      -nopdb) fpdb=0;;
      -replace) freplace=1;;
      -noreplace) freplace=0;;
      -skip) shift; skip=\$(calc \"\$1\");;
      -window) shift; window=\$(calc \"\$1\");;
      -source) shift; source=\"\$1\";;
      *) help;;
    esac
    shift;
  done;
}

run_analyze() {
  local script=\"\$1\"; shift;

  if [ \"\$(basename \${script})\" == \"\${script}\" ]; then
    if [ -e \"\${root}/scripts/analyze/\${script}\" ]; then
      script=\"\${root}/scripts/analyze/\${script}\";
    elif [ -e \"\${root}/scripts/analyze/\${script}.sh\" ]; then
      script=\"\${root}/scripts/analyze/\${script}.sh\";
    elif [ -e \"\${home}/chemistry/analyze/\${script}\" ]; then
      script=\"\${home}/chemistry/analyze/\${script}\";
    elif [ -e \"\${home}/chemistry/analyze/\${script}.sh\" ]; then
      script=\"\${home}/chemistry/analyze/\${script}.sh\";".
($::EMC::Analyze{user} ne "" ? "
    if [ -e \"$::EMC::Analyze{user}/\${script}\" ]; then
      script=\"$::EMC::Analyze{user}/\${script}\";
    elif [ -e \"$::EMC::Analyze{user}/\${script}.sh\" ]; then
      script=\"$::EMC::Analyze{user}/\${script}.sh\";" : "")."
    fi;
  fi;
  run \"\$script\" \"\$@\";
}

analyze() {
  local dir=\"\$1\"; shift;
  local target=\"\$1\"; shift;
  local archive=\"\$1\"; shift;

");
    foreach (sort(keys(%{$::EMC::Analyze{scripts}}))) {
      my $key = $_;
      my $hash = ${$::EMC::Analyze{scripts}}{$key};

      next if (!${$hash}{active});
      
      my $script = ${$hash}{script};
      my %options = (
	archive => "\${archive}",
	dir	=> "\${dir}",
	replace => "\${freplace}",
	skip	=> "\${skip}".($key eq "green-kubo" ? "+1" : ""),
	target	=> "\${target}",
	window	=> "\${window}"
      );
      my $lines = "run_analyze $script \\\n";
      my $line = " ";
      my $option;

      foreach (keys(%{${$hash}{options}})) {
	$options{$_} = ${${$hash}{options}}{$_};
      }
      foreach (sort(keys(%options))) {
	$line .= " -$_ \"$options{$_}\"";
      }
      $option = " \\\n  $::EMC::Project{name}";
      write_job_indent($stream, 1, $lines.$line.$option);
    }
    printf($stream "}\n");
  }

  # BUILD

  if ($type eq "build" || ($type eq "run" && !$::EMC::Lammps{restart})) {

    my $options = "\n      -project \"$::EMC::Project{directory}$::EMC::Project{name}\" \\";
    my $values = "";
   
    foreach(@::EMC::LoopVariables) {
      my $var = (split(":"))[0];
      $values .= "\n  local $var=\"\$1\"; shift;";
      $options .= "\n      -$var \"\${$var}\" \\";
    }
    
    printf($stream
"
run_emc() {
  local dir=\"\$1\"; shift;$values

  printf \"### \${dir}\\n\\n\";
  if [ ! -e \${dir} ]; then
    run mkdir -p \${dir};
  fi;

  if [ -e \${dir}/$::EMC::Project{name}.data -a \${freplace} = 0 ]; then
    printf \"# $::EMC::Project{name}.data already exists -> skipped\\n\\n\";
    run_null;
    return;
  fi;

  run cd \${dir};
  run \"\${chemistry}/scripts/$::EMC::Project{script}.sh\" \\$options
    $::EMC::Project{name};
  run \\
    emc_setup.pl \\
      -project=$::EMC::Project{name} \\
      -workdir=\${home} \\
      -emc_execute=false \\
      $::EMC::Project{name}$::EMC::Script{extension};
  
  if [ \${femc} = 1 ]; then
    walltime=\${build_walltime};
    run_pack -n 1 \\
      -walltime \${build_walltime} -starttime \${starttime} -queue \${queue} \\
      -project $::EMC::Project{name} -output build.out \\
      emc_\${HOST} -seed=\${seed} build.emc
    seed=\$(calc \${seed}+1);
  else
    run_null;
  fi;

  run cd \"\${home}\";
  echo;
}
");
  
}
  if ($type eq "build") {
    printf($stream
"
help() {
  echo \"EMC build script created by $::EMC::Script v$::EMC::Version, $::EMC::Date\n\";
  echo \"Usage:\n  \$script [-option]\n\";
  echo \"Options:\";
  echo \"  -help\t\tthis message\";
  echo \"  -[no]emc\tcontrol execution of EMC\";
  echo \"  -[no]replace\tcontrol replacement of emc and lammps scripts\";
  echo;
  exit;
}


run_init() {
  femc=1;
  fbuild=1;
  freplace=$::EMC::Build{replace};
  while [ \"\$1\" != \"\" ]; do
    case \"\$1\" in
      -emc) femc=1;;
      -noemc) femc=0;;
      -replace) freplace=1;;
      -noreplace) freplace=0;;
      *) help;;
    esac
    shift;
  done;
}
");
  }

  # RUN

  if ($type eq "run") {
    my $restart_name = "$::EMC::Lammps{restart_dir}/*/*.restart?";
    my $restart_file = $::EMC::Lammps{restart} ? "\n".
      "  else\n".
      "    frestart=1;\n".
      "    restart=\$(first \$(ls -1t $restart_name));\n".
      "    if [ ! -e \"\${restart}\" ]; then\n".
      "      printf \"# $restart_name does not exist -> skipped\\n\\n\";\n".
      "      run cd \$home;\n".
      "      return;\n".
      "    fi;\n".
      "    restart=\"-file \\\"'ls -1td $restart_name'\\\"\";" : "";
    my $shear_line = $::EMC::Shear{rate} ? "\n      -var framp ".(
	$::EMC::Shear{ramp} eq "" ? 0 : $::EMC::Shear{ramp} eq "false" ? 0 : 1)." \\" : "";
    my $run_line = $::EMC::Lammps{trun_flag} ?
	($::EMC::Lammps{trun} ne "" ? "\n\t-var trun ".eval($::EMC::Lammps{trun})." \\" : "") : "";

    printf($stream
"
help() {
  echo \"EMC run script created by $::EMC::Script v$::EMC::Version, $::EMC::Date\n\";
  echo \"Usage:\n  \$script [-option]\n\";
  echo \"Options:\";
  echo \"  -help\t\tthis message\";
  echo \"  -[no]build\tcontrol inclusion of building initial structures\";
  echo \"  -[no]emc\tcontrol execution of EMC\";
  echo \"  -[no]replace\tcontrol replacement of emc and lammps scripts\";
  echo \"  -[no]restart\tcontrol restarting already run MD simulations\";
  echo;
  exit;
}

run_init() {
  fbuild=0;
  femc=1;
  freplace=$::EMC::Build{replace};
  fnorestart=$::EMC::Flag{norestart};
  while [ \"\$1\" != \"\" ]; do
    case \"\$1\" in
      -build) fbuild=1;;
      -nobuild) fbuild=0;;
      -emc) femc=1;;
      -noemc) femc=0;;
      -replace) freplace=1; fnorestart=1;;
      -noreplace) freplace=0; fnorestart=0;;
      -restart) fnorestart=0;;
      -norestart) if [ \${freplace} != 1 ]; then fnorestart=1; fi;;
      *) help;;
    esac
    shift;
  done;
}
") if (!$::EMC::Lammps{restart});

    printf($stream
"
run_lammps() {
  local dir=\"\$1\"; shift;
  local frestart=\"\$1\"; shift;
  local ncores=\"\$1\"; shift;
  local output restart wait;
  
  printf \"### \${dir}\\n\\n\";
  if [ ! -e \${dir} ]; then
    run mkdir -p \${dir};
  fi;

  if [ \${fbuild} != 1 ]; then
    if [ ! -e \${dir}/../build/$::EMC::Project{name}.data ]; then
      printf \"# ../build/$::EMC::Project{name}.data does not exists -> skipped\\n\\n\";
      run_null;
      return;
    fi;
    if [ ! -e \${dir}/../build/$::EMC::Project{name}.params ]; then
      printf \"# ../build/$::EMC::Project{name}.params does not exists -> skipped\\n\\n\";
      run_null;
      return;
    fi;
    if [ ! -e \${dir}/../build/$::EMC::Project{name}.in ]; then
      printf \"# ../build/$::EMC::Project{name}.in does not exists -> skipped\\n\\n\";
      run_null;
      return;
    fi;
  fi;

  if [ \${freplace} != 1 ]; then
    if [ \${frestart} != 1 ]; then
      if [ -e \${dir}/$::EMC::Project{name}.dump ]; then
	printf \"# $::EMC::Project{name}.dump exists -> skipped\\n\\n\";
	run_null;
	return;
      fi;
    else
      restart=\"-file \'../*/*.restart?\'\";".
      $restart_file."
    fi;
  fi;

  run cd \${dir};
  run cp ".($::EMC::Lammps{restart} ? "$::EMC::Lammps{restart_dir}/" : "")."../build/$::EMC::Project{name}.in .;
  set -f;
  walltime=\${run_walltime};
  run_pack -n \${ncores} \"\${restart}\" \\
    -walltime \${run_walltime} -starttime \${starttime} -queue \${queue} \\
    -input $::EMC::Project{name}.in -output $::EMC::Project{name}.out \\
    -project $::EMC::Project{name} \\
      lmp_\${HOST} -nocite \\
	-var source $::EMC::Lammps{restart_dir}/build \\".
	$run_line.$shear_line."
	-var frestart \${frestart} \\
	-var restart \@FILE \\
	-var lseed \$(substr \${seed} -8) \\
	-var vseed \$(substr \$(calc \"\${seed}+1\") -8);
  set +f;

  seed=\$(calc \${seed}+2);
  run cd \"\${home}\";
  echo;
}
");
  }

  # TEST

  if ($type eq "test") {
    my $replace;
    my $options = "\n    -project \"$::EMC::Project{directory}$::EMC::Project{name}\" \\";
   
    printf($stream "\n# functions\n\n");
    printf($stream "run() {\n  echo \"\$@\"; \$@; }\n\n");
    printf($stream "submit() {\n");
    foreach (@::EMC::LoopVariables) {
      my $var = (split(":"))[0];
      my @a = split(":", @{$::EMC::Loop{$_}}[0]);
      my $value = @a[0] eq "s" || @a[0] eq "seq" ? @a[1] : @a[0];
      $options .= "\n    -$var \"\${$var}\" \\";
      if ($replace ne "") {
	printf($stream 
	  "  local $var=\"\$(replace \"$value\" $replace)\";\n");
	$replace .= " ";
      } else {
	printf($stream 
	  "  local $var=\"$value\";\n");
      }
      $replace .= "@\{".uc($var)."} \"\$$var\"";
    }
    printf($stream "
  run \"\${chemistry}/scripts/$::EMC::Project{script}.sh\" \\$options
    $::EMC::Project{name};
  run emc_setup.pl \\
    -project=$::EMC::Project{name} \\
    -workdir=\${home} \\
    $::EMC::Project{name}$::EMC::Script{extension};
}\n\n");
  }
}


sub write_job_submit {
  my $stream = shift(@_);
  my $type = shift(@_);
  my @loop_variables;
  my @loop_values;

  foreach (@::EMC::LoopVariables) { 
    push(@loop_variables, (split(":"))[0]);
    push(@loop_values, "\${".(split(":"))[0]."}");
  }

  if ($type eq "analyze") {
    
    # ANALYZE

    write_job_func($stream, $type,
"dir=\"data".write_job_dir(@::EMC::LoopVariables)."\";
printf \"# \${dir}\\n\\n\";
if [ ! -e \"\${dir}\" ]; then
  printf \"# no such directory -> skipped\\n\\n\";
fi;
run cd \"\${dir}\";
run analyze \"\${dir}\" \"\${target}\" \"\${files}\";
if [ -e \"build/$::EMC::Project{name}.params\" ]; then
  echo \"\${dir}/build/$::EMC::Project{name}.params\" >>\"\${target}/\${files}\";
  if [ ! -e \"\${target}/\${dir}/build/$::EMC::Project{name}.params\" ]; then
    mkdir -p \"\${target}/\${dir}/build\";
    cp -p \"build/$::EMC::Project{name}.params\" \"\${target}/\${dir}/build\";
  fi;
fi;
run cd \"\${home}\";
echo;
"); 

  } elsif ($type eq "build") {

    # BUILD
 
    write_job_func($stream, $type,
      "run_emc \\\n".
      "  data".write_job_dir(@::EMC::LoopVariables)."/build \\\n".
      "  @loop_values;");
  
  } elsif ($type eq "run") {

    # RUN

    write_job_func($stream, $type,
"serial=0;
frestart=0;
dir=data".write_job_dir(@::EMC::LoopVariables).";

restart=\"\$(first \$dir/*/*.restart?)\";
if [ \${fnorestart} != 1 -a -e \"\${restart}\" ]; then
  frestart=1;
  restart=\"\$(first \$(ls -1t \$dir/*/*.restart?))\";
  serial=\$(calc \$(basename \$(dirname \"\${restart}\"))+1);
fi;

case \$ichoice in 
  0)  if [ \${frestart} != 1 ]; then
	run_emc \\
	  \${dir}/build @loop_values;
      else
	run_null;
      fi;;
  1)  serial=\$(calc \"\${serial}+\${iserial}\");
      if [ \${iserial} -gt 0 ]; then frestart=1; fi;
      run_lammps \\
	\"\${dir}/\$(zero 2 \${serial})\" \${frestart} \${ncores};;
esac
");
  } elsif ($type eq "test") {

    # TEST

    write_job_func($stream, $type, "");

  } else {

    error("unsupported type \'$type\'\m");

  }
}


sub write_job_settings {
  my $stream = shift(@_);

  printf($stream "");
}


sub queue_entry {
  my $arg;
  ($arg) = @_[0] =~ m/"([^"]*)"/;
  return $arg eq "none" ? "" : $arg;
}


sub write_job_footer {
  my $stream = shift(@_);
  my $type = shift(@_);
  my $header;
  my $trailer;
  my $host;

  if ($type eq "analyze") {
    printf($stream "archive() {
  local select;

  cd \"\${target}\";
  if [ \"\${farchive}\" == \"0\" ]; then return; fi;
  if [ ! -e \${files} ]; then return; fi;
  for file in \${files}; do
    if [ ! -e \${file} ]; then continue; fi;
    if [ \"\${select}\" == \"\" ]; then select=\${file};
    else select=\"\${select} \${file}\"; fi;
  done;
  if [ \"\${fdata}\" == \"0\" ]; then return; fi;
  if [ \"\${select}\" != \"\" ]; then
    run tar -zvcf \${data} -T \${select};
  fi;
  rm -f \${files};
  cd \"\${home}\";
}\n
");
    $header =" 
  run_init \"\$@\";

  mkdir -p exchange/files;
  files=\$(mktemp exchange/files/XXXXXXXX);
  mkdir -p exchange/data;
  data=exchange/data/\$(basename \${files}).tgz;
  
  target=\"\${home}\";
  if [ \"\${source}\" != \"\" ]; then
    data=\"\${home}/\${data}\";
    cd \"\${source}\";
    home=\"\$(pwd)\";
  fi;
  
  cutoff=$::EMC::CutOff{pair};
";
  } elsif ($type eq "build") {
    $header = "\n  run_init \"\$@\";\n";
  } elsif ($type eq "run") {
    $header = "\n  run_init \"\$@\";\n" if (!$::EMC::Lammps{restart});
  } elsif ($type eq "test") {
    printf($stream
"# main
$host
  cd \"$::EMC::WorkDir\";
  root=\"\$(dirname \$(which emc_\${HOST}))/..\";
  home=\"\$(pwd)\";
  chemistry=\"\${home}/chemistry\";
  cd \"test/$::EMC::RunName{$type}\";

  submit;
");
    return;
  }

  $trailer = "\n  stage=generic;" if (!defined($::EMC::Loop{stage}));
  
  $host = "\n  HOST=\"$::EMC::ENV{host}\";" if ($::EMC::ENV{host} ne "");

  foreach (@::EMC::Modules) {
    my @arg = split("=", $_);
    if (@arg[0] eq "unload") {
      $header .= "\n  module unload @arg[1];";
    } elsif (@arg[0] eq "load") { 
      $header .= "
  if [ \"\$(module load @arg[1] 2>&1 | grep error)\" != \"\" ]; then
    echo \"Error: cannot load module @arg[1]\";\n    echo; exit -1;
  fi;\n";
    }
  }

  printf($stream "%s",
"# main
$host
  root=\"\$(dirname \$(which emc_\${HOST}))/..\";

  cd \"$::EMC::WorkDir\";
  home=\"$::EMC::WorkDir\";
  log=\"\${home}/$type/\$(basename \$0 .sh).log\";
  chemistry=\"\${home}/chemistry\";
$header
  queue=$::EMC::Queue{$type};
  queue_account=\"".queue_entry($::EMC::Queue{account})."\";
  queue_user=\"".queue_entry($::EMC::Queue{user})."\";
  starttime=\"now\";
".($type eq "analyze" ? "
  walltime=$::EMC::RunTime{analyze};" : "
  build_walltime=$::EMC::RunTime{build};
  run_walltime=$::EMC::RunTime{run};")."
  seed=\$(date +%s);
  ncorespernode=$::EMC::Queue{ppn};
  memorypercore=$::EMC::Queue{memory};
  ncores=".($type eq "run" ? $::EMC::Queue{ncores} : 1).";$trailer

  fpack=0;
  waitids=();
  npack=(0 0);
  if [ \${ncorespernode} != \"default\" ]; then
    if [ \${ncores} -lt \${ncorespernode} ]; then fpack=1;
    elif [ \${fbuild} == 1 -a \${femc} == 1 ]; then fpack=1; fi
    if [ \${fpack} = 1 ]; then
      pack_dir=\"$type/\$(basename \${script} .sh)\";
      if [ -e \"\${pack_dir}\" ]; then run_check \${pack_dir}; fi;
      mkdir -p \${pack_dir};
    fi;
  fi;

");

  foreach (@::EMC::LoopVariables) {
    printf($stream "  ".(split(":"))[0]."s=(".join(" ", @{$::EMC::Loop{$_}}).");\n")
  }
  
  printf($stream "\n  submit 2>&1 | tee \"\${log}\";\n");
  printf($stream "\n  archive;\n") if ($type eq "analyze");
  printf($stream "\n");
}


sub write_job_create {
  my $stream = shift(@_);
  my $nlevels = shift(@_);
  my $date = date; chop($date);
  my $ext = ".dat";
  my $root = ".."; while (--$nlevels) { $root .= "/.."; }
  my $replacements;
  my $cases;
  my $loops;

  foreach (@::EMC::LoopVariables) {			# loop vars
    next if ($_ eq "trial");
    next if ($_ eq "stage");
    my $var = (split(":"))[0];
    $cases .= "\n      -$var) shift; $var=\"\$1\";;";
    $loops .= "\n  replace \"\@".uc($var)."\" \"\$$var\";";
  }
  $replacements = $loops if ($::EMC::Flag{expert});
  if (defined($::EMC::Variables{data})) {
    foreach (reverse(@{$::EMC::Variables{data}})) {	# environment vars
      my @var = @{$_};
      
      $replacements .= 
	"\n  replace \"\@".uc(shift(@var))."\" \"".
	join(", ", @var)."\";";
    }
    $replacements .= $loops;
  } elsif (!$::EMC::Flag{expert}) {
    $replacements .= $loops;
  }

  printf($stream					# script
"#!/bin/bash
#
#  script:	scripts/$::EMC::Project{script}.sh
#  author:	$::EMC::Script v$::EMC::Version, $::EMC::Date
#  date:	$date
#  purpose:	Create chemistry file based on sample definitions; this
#  		script is auto-generated
#

# functions

init() {
  while [ \"\$1\" != \"\" ]; do
    case \"\$1\" in
      -project) shift; project=\"\$1\";;
      -trial) shift; trial=\"\$1\";;
      -phase) shift; stage=\"\$1\";;
      -stage) shift; stage=\"\$1\";;$cases
      -*) shift;;
      *) if [ \"\$chemistry\" = \"\" ]; then chemistry=\"\$home/\$1$::EMC::Script{extension}\"; fi;;
    esac;
    shift;
  done;

  if [ \"\$chemistry\" = \"\" ]; then chemistry=\"\$home/chemistry$::EMC::Script{extension}\"; fi;
  if [ \"\$trial\" = \"\" ]; then trial=\"generic\"; fi;
  if [ \"\$stage\" = \"\" ]; then stage=\"generic\"; fi;
  
  template=stages/\$project/\$stage$::EMC::Script{extension};
  if [ ! -e \"\$template\" ]; then error \"nonexistent template \'\$template\'\"; fi;
}

error() {
  echo \"Error: \$@\";
  echo;
  exit -1;
}

# create chemistry file

create() {
  cp \"\$template\" \"\$chemistry\";

  replace \"\@GROUPS\" \"groups/\$stage\" \"\$trial\";
  replace \"\@CLUSTERS\" \"clusters/\$stage\" \"\$trial\";
  replace \"\@POLYMERS\" \"polymers/\$stage\" \"\$trial\";
  replace \"\@SHORTHAND\" \"shorthand/\$stage\" \"\$trial\";
  replace \"\@STRUCTURE\" \"structures/\$stage\" \"\$trial\";
  $replacements
  
  replace \"\@WORKDIR\" \"$::EMC::WorkDir\";
  replace \"\@EMCROOT\" \"$::EMC::Root\";
  replace \"\@STAGE\" \"\$stage\";
  replace \"\@TRIAL\" \"\$trial\";

  chmod a+rx \"\$chemistry\";
}

replace() {
  if [ \"\$3\" = \"\" ]; then
    if [ \"\$2\" != \"\" ]; then
      replace.pl -v -q \"\$1\" \"\$2\" \"\$chemistry\";
    fi;
  elif [ -f \"\$2/\$3$ext\" ]; then 
    replace.pl -v -q \"\$1\" \"\$(cat \$2/\$3$ext)\" \"\$chemistry\";
  fi;
}

# main

  home=\$(pwd);
  project=\"$::EMC::Project{directory}$::EMC::Project{name}\";
  cd \$(dirname \$0)/$root;
  init \$@;
  create;
");
}


# field file

sub write_field {
  return if (!$::EMC::Field{write});

  my $name = shift(@_);

  if ((-e "$name.prm")&&!$::EMC::Replace{flag}) {
    warning("\"$name.prm\" exists; use -replace flag to overwrite\n");
    return;
  }

  if (defined($::EMC::Verbatim{field})) {
    info("creating field parameter file \"$name.prm\"\n");
    EMCField::main(
      "-quiet", "-input", $::EMC::Verbatim{field}, $name);
    return;
  }

  return if (!($::EMC::Parameters{flag} && $::EMC::Field{type} eq "dpd"));

  my $stream = fopen("$name.prm", "w");

  info("creating field parameter file \"$name.prm\"\n");
  write_field_header($stream);
  write_field_masses($stream);
  write_field_parameters($stream);
  write_field_footer($stream);

  close($stream);
}


sub write_field_header {
  my $stream = shift(@_);
  my $date = date;
  chop($date);

  printf($stream
"#
#  DPD interaction parameters
#  to be used in conjuction with EMC v$::EMC::EMCVersion or higher
#  created by $::EMC::Script v$::EMC::Version, $::EMC::Date
#  on $date
#

# Force field definition

ITEM	DEFINE

FFMODE	DPD
FFTYPE	COARSE
VERSION	V$::EMC::Version
CREATED	".`date +%d-%m-%Y`.
"MIX	NONE
DENSITY	REDUCED
ENERGY	REDUCED
LENGTH	REDUCED
NBONDED	$::EMC::FieldFlag{nbonded}
CUTOFF	$::EMC::PairConstants{r}
GAMMA	$::EMC::PairConstants{gamma}
DEFAULT	$::EMC::PairConstants{a}
ANGLE	".(%::EMC::Angles ? "WARN" : "IGNORE")."
TORSION	".(%::EMC::Torsions ? "WARN" : "IGNORE")."
IMPROP	".(%::EMC::Impropers ? "WARN" : "IGNORE")."

ITEM	END

");
}


sub write_field_masses {
  my $stream = shift(@_);

  printf($stream
"# Masses

ITEM	MASS

# type	mass	element	ncons	charge	comment\n\n".
(${$::EMC::Field{dpd}}{auto} ?  "*	1.0000	*	2	0	Anything\n" : ""));
  
  my %ref; foreach (sort(keys(%{$::EMC::Reference{data}}))) {
    my @a = @{${$::EMC::Reference{data}}{$_}}; shift(@a);
    @{$ref{shift(@a)}} = @a;
  }
  foreach (sort(keys(%ref))) {
    my $type = $_ eq "" ? "*" : $_;
    my @a = @{$ref{$_}};
    if ($type eq "*") {
      @a = ("*", "1", "*", "2", "0", "Anything") if (!scalar(@a));
    } else {
      @a[1] = eval(@a[1]);
    }
    printf($stream "%s\t%.4f\t%s\t%ld\t%g\t%s\n", $type,@a[1],$type,@a[3,4,-1]);
  }
  printf($stream
"
ITEM	END

# Typing equivalences

ITEM	EQUIVALENCE

# type	pair	bond	angle	torsion	improper

ITEM	END

");
}


sub write_field_parameters {
  my $stream = shift(@_);

  undef(%::EMC::Nonbonds);
  if (${$::EMC::Field{dpd}}{auto}) {
    my $ptr = \%::EMC::PairConstants;
    $::EMC::Nonbonds{"*\t*"} =  join("\t", $ptr->{a},$ptr->{r},$ptr->{gamma});
  }
  if (!defined($::EMC::Bonds{"*\t*"})) {
    $::EMC::Bonds{"*\t*"} = join("\t", split(",", $::EMC::BondConstants));
  }
  if ($::EMC::Flag{angle} && !defined($::EMC::Angles{"*\t*\t*"})) {
    $::EMC::Angles{"*\t*\t*"} = join("\t", split(",", $::EMC::AngleConstants));
  }
  foreach(sort(keys(%::EMC::Parameters))) {
    my @t = split(":");
    next if (scalar(@t) != 2);
    my @a = @{$::EMC::Parameters{$_}};
    my $flag = 0;
    foreach (@t) {
      $_ = defined($::EMC::Type{$_}) ? $::EMC::Type{$_} :
	   ($_ =~ m/\*/) ? $_ : "";
      last if (($flag = $_ eq "" ? 1 : 0));
    }
    next if ($flag);
    @t = reverse(@t) if (@t[1] lt @t[0]);
    $::EMC::Nonbonds{join("\t", @t)} = join("\t", @a);
  }

  write_field_item($stream, "nonbond");
  write_field_item($stream, "bond");
  write_field_item($stream, "angle");
  write_field_item($stream, "torsion");
  write_field_item($stream, "improper");
}


sub write_field_item {
  my $stream = shift(@_);
  my $item = lc(shift(@_));
  my $Item = uc(substr($item,0,1)).substr($item,1);
  my %data = (
    nonbond => \%::EMC::Nonbonds, bond => \%::EMC::Bonds, angle => \%::EMC::Angles,
    torsion => \%::EMC::Torsions, improper => \%::EMC::Impropers);
  my %header = (
    nonbond => "type1\ttype2\ta\tcutoff\tgamma",
    bond => "type1\ttype2\tk\tl0",
    angle => "type1\ttype2\ttype3\tk\ttheta0",
    torsion => "type1\ttype2\ttype3\ttype4\tk\tn\tdelta\t[...]",
    improper => "type1\ttype2\ttype3\ttype4\tk\tpsi0");
  my @n = (0,0);
  my $flag;

  foreach (keys(%{$data{$item}})) { ++@n[($_ =~ m/\*/) ? 0 : 1]; }
  for ($flag=0; $flag<2; ++$flag) {
    next if (!@n[$flag]);
    printf($stream "# %s%s parameters\n\n", $Item, $flag ? "" : " wildcard");
    printf($stream "ITEM\t%s%s\n\n", uc($item), $flag ? "" : "_AUTO");
    printf($stream "# %s\n\n", $header{$item});
    foreach (sort(keys(%{$data{$item}}))) {
      next if ((($_ =~ m/\*/) ? 0 : 1)^$flag);
      my @constants = split("\t",  ${$data{$item}}{$_});
      printf($stream "%s", $_);
      foreach(@constants) { printf($stream "\t%.5g", $_); }
      printf($stream "\n");
    }
    printf($stream "\nITEM\tEND\n\n");
  }
}


sub write_field_footer {
  my $stream = shift(@_);

  printf($stream
"# Templates

ITEM	TEMPLATES

# name	smiles

ITEM	END
");
}


# main

{
  initialize(@ARGV);
  
  if (!$::EMC::Flag{environment}) {
    write_emc($::EMC::Build{name});
    if (!${$::EMC::EMC{exclude}}{build}) {
      write_field($::EMC::Project{name});
      write_lammps($::EMC::Project{name});
      write_namd($::EMC::Project{name});
    }

    if (flag($::EMC::EMC{execute})) {
      my $emc;
      if ($^O eq "MSWin32") {
	$emc = scrub_dir(dirname($0)."/../bin/".$::EMC::EMC{executable}.".exe");
      } else {
	$emc = (split("\n", `which $::EMC::EMC{executable}`))[0];
      }
      error("cannot find '$::EMC::EMC{executable}' in path\n") if (! -e $emc);
      info("executing '$emc'\n\n");
      if ($^O eq "MSWin32") {
	system("$emc $::EMC::Build{name}.emc");
      } elsif ($::EMC::Flag{info}) {
	system("$emc $::EMC::Build{name}.emc 2>&1 | tee $::EMC::Build{name}.out");
      } else {
	system("$emc $::EMC::Build{name}.emc &> $::EMC::Build{name}.out");
      }
    } else {
      print("\n") if ($::EMC::Flag{info});
    }
  } else {
    print("\n") if ($::EMC::Flag{info});
  }
}

