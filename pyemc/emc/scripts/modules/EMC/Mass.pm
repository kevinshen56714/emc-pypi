#!/usr/bin/env perl
#
#  module:	EMC::Mass.pm
#  author:	Pieter J. in 't Veld
#  date:	November 15, 2024.
#  purpose:	Element operations; part of EMC distribution

#  Copyright (c) 2004-2025 Pieter J. in 't Veld
#  Distributed under GNU Public License as stated in LICENSE file in EMC root
#  directory
#
#  notes:
#    20241115	Inception of v1.0
#

package EMC::Mass;

use strict;
use Exporter;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

$VERSION = "1.0";
@ISA = qw(Exporter);
#@EXPORT = qw(&main);

use EMC::Message;
use EMC::List;

# constants

$EMC::Mass::Table = [
    [-1, "Lp", "Lone Pair", 1.000, 2, 1, [0]],
    [1, "H", "Hydrogen", 1.0079, 1, 2, [1, -1]],
    [1, "D", "Deuterium", 2.0141, 1, 2, [1, -1]],
    [2, "He", "Helium", 4.0026, 0, 1, [0]],
    [3, "Li", "Lithium", 6.941, 1, 1, [1]],
    [4, "Be", "Beryllium", 9.0122, 2, 1, [2]],
    [5, "B", "Boron", 10.811, 3, 2, [3, -3]],
    [6, "C", "Carbon", 12.011, 4, 2, [4, 2]],
    [6, "c", "Aromatic Carbon", 12.011, 3, 2, [4, 2]],
    [7, "N", "Nitrogen", 14.0067, 3, 8, [-3, -2, -1, 2, 3, 4, 5, 1]],
    [7, "n", "Aromatic Nitrogen", 14.0067, 2, 8, [-3, -2, -1, 2, 3, 4, 5, 1]],
    [8, "O", "Oxygen", 15.9994, 2, 1, [-2]],
    [9, "F", "Fluor", 18.998, 1, 2, [-1, 1]],
    [10, "Ne", "Neon", 20.180, 0, 1, [0]],
    [11, "Na", "Sodium", 22.990, 1, 1, [1]],
    [12, "Mg", "Magnesium", 24.305, 2, 1, [2]],
    [13, "Al", "Aluminium", 26.982, 3, 1, [3]],
    [14, "Si", "Silicon", 28.085, 4, 3, [4, -4, 2]],
    [15, "P", "Phosphorus", 30.974, 3, 4, [-3, 1, 3, 5]],
    [16, "S", "Sulfur", 32.066, 2, 4, [-2, 2, 4, 6]],
    [16, "s", "Aromatic Sulfur", 32.066, 2, 4, [-2, 2, 4, 6]],
    [17, "Cl", "Chlorine", 35.4527, 1, 7, [-1, 1, 3, 5, 7, 2, 4]],
    [18, "Ar", "Argon", 39.948, 0, 1, [0]],
    [19, "K", "Potassium", 39.098, 1, 1, [1]],
    [20, "Ca", "Calcium", 40.078, 2, 1, [2]],
    [21, "Sc", "Scandium", 44.956, 3, 1, [3]],
    [22, "Ti", "Titanium", 47.867, 2, 3, [2, 3, 4]],
    [23, "V", "Vanadium", 50.942, 2, 4, [2, 3, 4, 5]],
    [24, "Cr", "Chromium", 51.996, 6, 3, [2, 3, 6]],
    [25, "Mn", "Manganese", 54.938, 6, 5, [2, 4, 7, 3, 6]],
    [26, "Fe", "Iron", 55.845, 6, 4, [2, 3, 4, 6]],
    [27, "Co", "Cobalt", 58.933, 4, 3, [2, 3, 4]],
    [28, "Ni", "Nickel", 58.693, 4, 4, [2, 1, 3, 4]],
    [29, "Cu", "Copper", 63.546, 3, 3, [1, 2, 3]],
    [30, "Zn", "Zinc", 65.39, 2, 1, [2]],
    [31, "Ga", "Gallium", 69.723, 3, 2, [3, 2]],
    [32, "Ge", "Germanium", 72.61, 4, 3, [-4, 2, 4]],
    [33, "As", "Arsenic", 74.922, 3, 4, [-3, 3, 5, 2]],
    [34, "Se", "Selenium", 78.96, 2, 4, [-2, 4, 6, 2]],
    [35, "Br", "Bromine", 79.904, 1, 5, [-1, 1, 5, 3, 4]],
    [36, "Kr", "Krypton", 83.80, 0, 1, [0]],
    [37, "Rb", "Rubidium", 85.468, 1, 1, [1]],
    [38, "Sr", "Strontium", 87.62, 2, 1, [2]],
    [39, "Y", "Yttrium", 88.906, 3, 1, [3]],
    [40, "Zr", "Zirconium", 91.224, 4, 3, [4, 2, 3]],
    [41, "Nb", "Niobium", 92.906, 3, 4, [3, 5, 2, 4]],
    [42, "Mo", "Molybdenum", 95.94, 6, 5, [3, 6, 2, 4, 5]],
    [43, "Tc", "Technetium", 97.907, 6, 1, [6]],
    [44, "Ru", "Ruthenium", 101.07, 6, 6, [3, 4, 8, 2, 6, 7]],
    [45, "Rh", "Rhodium", 102.906, 6, 4, [4, 2, 3, 6]],
    [46, "Pd", "Palladium", 106.42, 6, 3, [2, 4, 6]],
    [47, "Ag", "Silver", 107.868, 1, 3, [1, 2, 3]],
    [48, "Cd", "Cadmium", 112.411, 2, 2, [2, 1]],
    [49, "In", "Indium", 114.818, 3, 3, [3, 1, 2]],
    [50, "Sn", "Tin", 118.710, 4, 2, [2, 4]],
    [51, "Sb", "Antimony", 121.760, 3, 4, [-3, 3, 5, 4]],
    [52, "Te", "Tellurium", 127.60, 2, 4, [-2, 4, 6, 2]],
    [53, "I", "Iodine", 126.904, 1, 6, [-1, 1, 5, 7, 3, 4]],
    [54, "Xe", "Xenon", 131.29, 0, 1, [0]],
    [55, "Cs", "Caesium", 132.905, 1, 1, [1]],
    [56, "Ba", "Barium", 137.327, 2, 1, [2]],
    [57, "La", "Lanthanum", 138.905, 3, 1, [3]],
    [58, "Ce", "Cerium", 140.116, 4, 2, [3, 4]],
    [59, "Pr", "Praseodymium", 140.908, 3, 1, [3]],
    [60, "Nd", "Neodymium", 144.242, 4, 2, [3, 4]],
    [61, "Pm", "Promethium", 144.913, 3, 1, [3]],
    [62, "Sm", "Samarium", 150.36, 3, 2, [3, 2]],
    [63, "Eu", "Europium", 151.964, 3, 2, [3, 2]],
    [64, "Gd", "Gadolinium", 157.25, 3, 1, [3]],
    [65, "Tb", "Terbium", 158.925, 3, 2, [3, 4]],
    [66, "Dy", "Dysprosium", 162.500, 3, 1, [3]],
    [67, "Ho", "Holmium", 164.930, 3, 1, [3]],
    [68, "Er", "Erbium", 167.259, 3, 1, [3]],
    [69, "Tm", "Thulium", 168.934, 3, 2, [3, 2]],
    [70, "Yb", "Ytterbium", 173.04, 3, 2, [3, 2]],
    [71, "Lu", "Lutetium", 174.967, 3, 1, [3]],
    [72, "Hf", "Hafnium", 178.49, 4, 1, [4]],
    [73, "Ta", "Tantalum", 180.948, 5, 3, [5, 3, 4]],
    [74, "W", "Tungsten", 183.84, 6, 5, [6, 2, 3, 4, 5]],
    [75, "Re", "Rhenium", 186.207, 6, 8, [2, 4, 6, 7, -1, 1, 3, 5]],
    [76, "Os", "Osmium", 190.23, 6, 5, [3, 4, 6, 8, 2]],
    [77, "Ir", "Iridium", 192.217, 6, 5, [3, 4, 6, 1, 2]],
    [78, "Pt", "Platinum", 195.084, 6, 5, [2, 4, 6, 1, 3]],
    [79, "Au", "Gold", 196.967, 3, 3, [1, 3, 2]],
    [80, "Hg", "Mercury", 200.59, 2, 2, [1, 2]],
    [81, "Tl", "Thallium", 204.383, 3, 3, [1, 3, 2]],
    [82, "Pb", "Lead", 207.2, 4, 2, [2, 4]],
    [83, "Bi", "Bismuth", 208.980, 3, 5, [3, -3, 2, 4, 5]],
    [84, "Po", "Polonium", 208.982, 2, 4, [2, 4, -2, 6]],
    [85, "At", "Astatine", 209.987, -1, 0],
    [86, "Rn", "Radon", 222.018, 0, 1, [0]],
    [87, "Fr", "Francium", 223.020, -1, 0],
    [88, "Ra", "Radium", 226.0254, 2, 1, [2]],
    [89, "Ac", "Actinium", 227.027, 3, 1, [3]],
    [90, "Th", "Thorium", 232.038, 4, 1, [4]],
    [91, "Pa", "Protactinium", 231.036, 5, 1, [5]],
    [92, "U", "Uranium", 238.029, 6, 5, [3, 4, 6, 2, 5]],
    [93, "Np", "Neptunium", 237.048, -1, 0],
    [94, "Pu", "Plutonium", 244.064, -1, 0],
    [95, "Am", "Americium", 243.061, -1, 0],
    [96, "Cm", "Curium", 247.070, -1, 0],
    [97, "Bk", "Berkelium", 247.070, -1, 0],
    [98, "Cf", "Californium", 251.080, -1, 0],
    [99, "Es", "Einsteinium", 252.083, -1, 0],
    [100, "Fm", "Fermium", 257.095, -1, 0],
    [101, "Md", "Mendelevium", 258.098, -1, 0],
    [102, "No", "Nobelium", 259.101, -1, 0],
    [103, "Lr", "Lawrencium", 262.110, -1, 0],
    [104, "Rf", "Rutherfordium", 263.113, -1, 0],
    [105, "Db", "Dubnium", 262.114, -1, 0],
    [106, "Sg", "Seaborgium", 266.122, -1, 0],
    [107, "Bh", "Bohrium", 264.1247, -1, 0],
    [108, "Hs", "Hassium", 269.134, -1, 0],
    [109, "Mt", "Meitnerium", 268.139, -1, 0],
    [110, "Ds", "Darmstadtium", 272.146, -1, 0],
    [111, "Rg", "Roentgenium", 272.154, -1, 0],
    [112, "Cn", "Copernicium", 277, -1, 0],
    [113, "Uut", "Ununtrium", 284, -1, 0],
    [114, "Uuq", "Ununquadium", 289, -1, 0],
    [115, "Uup", "Ununpentium", 288, -1, 0],
    [116, "Uuh", "Ununhexium", 292, -1, 0],
    [117, "Uus", "Ununseptium", 294, -1, 0],
    [118, "Uuo", "Ununoctium", 294, -1, 0]
  ];

# functions

sub hash {
  my $table = {};

  foreach (@{$EMC::Mass::Table}) {
    my @arg = @{$_};
    my $index = shift(@arg);
    my $element = shift(@arg);

    $table->{$element} = {
      index => $index,
      element => $element,
      name => shift(@arg),
      mass => shift(@arg),
      nconnects => shift(@arg),
      nvalences => shift(@arg),
      valence => ref(@arg[0]) eq "ARRAY" ? [@{@arg[0]}] : undef
    };
  }
  return $table;
}


sub list {
  my $table = [];

  foreach (@{$EMC::Mass::Table}) {
    my @arg = @{$_};
    my $index = shift(@arg);

    next if ($index>0 && defined($table->[$index]));
    $table->[$index>0 ? $index : 0] = {
      index => $index,
      element => shift(@arg),
      name => shift(@arg),
      mass => shift(@arg),
      nconnects => shift(@arg),
      nvalences => shift(@arg),
      valence => ref(@arg[0]) eq "ARRAY" ? [@{@arg[0]}] : undef
    };
  }
  return $table;
}

