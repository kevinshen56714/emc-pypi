#!/bin/bash

run() {
  echo "$@";
  "$@";
}

  names=(
    Type Round Commands Notes Script Root Phases Densities Root Convert Project
    Focus CheckExist Verbatim Trials Loop XRef Profile Cluster Chemistries
    Fractions MolMass MolVolume Groups Group Import Polymer Extra Set Bonds
    Angles Torsions Impropers Loop Cutoff InverseType Sites Variables 
  );

  for name in ${names[@]}; do 
    run replace.pl -q "$name" "::$name" emc_setup.pl
  done;

  run replace.pl N::Clusters ::NClusters

  exit;

  flags=(
    CenterFlag InfoFlag DebugFlag WarnFlag ChiFlag AssumeFlag ChargeFlag
    EwaldFlag HexadecimalFlag MassFlag MassEntryFlag MolFlag NumberFlag
    MSDFlag OmitFlag VolumeFlag AtomisticFlag ReducedFlag ShakeFlag PairFlag
    CrossFlag BondFlag AngleFlag PressureFlag EnvironmentFlag
  );

  newflags=(
    center info debug warn chi assume charge
    ewald hexadecimal mass mass_entry mol number
    msd omit volume atomistic reduced shake pair
    cross bond angle pressure environment
  );

  results=();
  for i in ${!flags[@]}; do
    value=($(grep ${flags[$i]} emc_setup.pl | head -1));
    results+=("${newflags[$i]} => ${value[@]: -1}");
  done;

  IFS=$'\n'; sorted=($(sort <<<"${results[*]}")); unset IFS;
  echo "${sorted[@]}";

  for i in ${!flags[*]}; do
    run replace.pl -q "${flags[$i]}" "Flag{${newflags[$i]}}" emc_setup.pl
  done;
 
 
  cutoffs=(
    ChargeCutOff GhostCutOff InnerCutOff
  );

  newcutoffs=(
    charge ghost inner
  );

  for i in ${!cutoffs[*]}; do
    run replace.pl -q "${cutoffs[$i]}" "CutOff{${newcutoffs[$i]}}" emc_setup.pl
  done;

  names=(
    OSType Version Date Year pi Extension EMCVersion Record Dielectric Gamma
    Kappa NPhases Seed Shape Core Radius NRelax Depth Grace Precision Timestep
    ShapeDefault NTotal Build Host Columns NCores NChains Flag
    ImportNParallel PairConstants BondConstants AngleConstants Increment
    Temperature BinSize Pressure Density NAv Analyze Chemistry ClusterFlag
    CutOff Deform Direction EMC Field FieldFlag FieldFlags FieldNames Fields
    Lammps OptionsFlag Parameters PDBFlag ProfileFlag Reference Replace Region
    RunTime RunQueue RunName SampleFlag Shake Shear System
  );

  for name in ${names[@]}; do 
    run replace.pl -q "$name" "::$name" emc_setup.pl
  done;

  run replace.pl -q "N::Cores" "::NCores" emc_setup.pl

