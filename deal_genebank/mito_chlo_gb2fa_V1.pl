#!/usr/bin/perl -w 
##############################################################
# This script is to change the format from genebank to fasta,
# and this lience is especially for chloroplast genome.
#
# Auther:
#		Chentao YANG yangchento@genomics.cn 2015/04/20
#############################################################
use strict;
use Bio::DB::Taxonomy;
use Bio::SeqIO;
use Bio::SeqFeatureI;
my $seq_obj;
my $arguNum = 3;
my $inputfile = $ARGV[0];
my $output = $ARGV[1];
die  "Usage:\n\tperl $0 <inputfile> <output name> <mito|chlo>" unless (@ARGV == $arguNum);
#------check mito or chlo---------
my $tag ;
if ($ARGV[2] =~ /mito/) {
	$tag = 'mitochondrion';
}elsif($ARGV[2] =~ /chlo/){
	$tag = 'chloroplast';
}else {
	$tag = 'OTHER';
	print "mito(mitochondrion) or chlo(chloroplast) ?\nAnyway tag is set to 'OTHER'! ";
	exit;
}


open GEN,">$output.gene.fa";
open CDS_N,">$output.cds.fa";
open CDS_P,">$output.cds.pep";
open RRNA,">$output.rRNA.fa";
open TRNA,">$output.tRNA.fa";
open ERR,">$output.err";
open TAX,">$output.tax.txt";
open FA,">$output.fa";

my $in = Bio::SeqIO-> new(-file => "$inputfile", "-format" => 'genbank');
while (my $seq_obj=$in->next_seq()) {
	## get the whole complete mitochondrion/chloroplast genome sequence
	my $source = $seq_obj->seq; 
	
	my $sou_len = $seq_obj->length; 
	
	## get the primary id 
	my $primary_id = $seq_obj->primary_id; 
	
	## get the accession number just like (NC_020607)
	my $key = $seq_obj->accession_number; 
	$key = &norm_key ($key);
#	print "$key\n";
	## get the complete classification information and join them with blank.
	my $taxonomy = join(" ", $seq_obj->species->classification); 
	
	## get the organism name 
	my $organism = $seq_obj->species->node_name; 
	$organism =~ s/ /\_/g;
	print FA ">$key\_$organism\_$tag\_$sou_len\_bp\n$source\n";
	
	## In genebank format file, you alwagys see some features such as source, 
	## gene, CDS, extro, intro, rRNA, tRNA and so on, they are all feature object 
	## with Bio::Perl method,just use following format to deal them, and you will 
	## get all information you want.
	for my $feature ($seq_obj->top_SeqFeatures){
		my ($db_xref,$val,$location,$subseq,$start,$end,$pro,$translation);
		if ($feature->primary_tag eq 'source' )  {
			if ($feature->has_tag('db_xref')) {
				for $db_xref ($feature->get_tag_values('db_xref')){
					my $tax_id = $1 if ($db_xref =~ /taxon:(\d+)/);
					print TAX "$key\t$tax_id\t$taxonomy\n";
				#	print "$tax_id\n";
				}
			}
		}elsif ($feature->primary_tag eq 'gene' )  {
		    my $seq = $feature->spliced_seq->seq;
			if ($feature->has_tag('gene')) {
				for $val ($feature->get_tag_values('gene')){
					print GEN ">$key\_$organism\_$val\n$seq\n";
				}
			}else{
					print GEN ">$key\_$organism\_NA\n$seq\n";
					print ERR "Be careful! $key  This feature does not have gene tag!\n";
			}
	
		
		}elsif ($feature->primary_tag eq 'CDS' )  {
		    my $seq = $feature->spliced_seq->seq;
#			$feature->has_tag('gene') ? $val = ($feature->get_tag_values('gene'))[0] : $val = "NA";
#			$feature->has_tag('product') ? $pro = ($feature->get_tag_values('product'))[0] : $pro = "NA";

			if ($feature->has_tag('gene')) {
				for $val ($feature->get_tag_values('gene')){
					if ($feature->has_tag('product')){
						for $pro ($feature->get_tag_values('product')){
							if ($feature->has_tag('translation')){
								for $translation ($feature->get_tag_values('translation')){
									print CDS_N ">$key\_$organism\_$val\n$seq\n";
									my $trans_len = length $translation;
									print CDS_P ">gi_$key\_$val\_$organism\_$trans_len\_aa\n$translation\n";
								}
							}
						}
					}
				}
			}else{
				if ($feature->has_tag('product')){
					for $pro ($feature->get_tag_values('product')){
						if ($feature->has_tag('translation')){
							for $translation ($feature->get_tag_values('translation')){
								print ERR "Be careful! $key  This feature does not have gene tag!\n";
								print CDS_N ">$key\_$organism\_NA\n$seq\n";
								my $trans_len = length $translation;
								print CDS_P ">gi_$key\_$pro\_$organism\_$trans_len\_aa\n$translation\n";
								}
							}
						}
				}else{
					if ($feature->has_tag('translation')){
						for $translation ($feature->get_tag_values('translation')){
							print ERR "Be careful! $key  This feature has gene tag neither nor product tag!\n";
							print CDS_N ">$key\_$organism\_NA\n$seq\n";
							my $trans_len = length $translation;
							print CDS_P ">gi_$key\_NA\_$organism\_$trans_len\_aa\n$translation\n";
						}
					}
				}
					
			}
	
		}elsif ($feature->primary_tag eq 'rRNA' )  {
		    my $seq = $feature->spliced_seq->seq;
			if ($feature->has_tag('gene')) {
				for $val ($feature->get_tag_values('gene')){
					print RRNA ">$key\_$organism\_$val\n$seq\n";
				}
			}else{
					print ERR "Be careful! $key  This feature don't have gene tag!\n";
					print RRNA ">$key\_$organism\_NA\n$seq\n";
			}

		}elsif ($feature->primary_tag eq 'tRNA' )  {
		    my $seq = $feature->spliced_seq->seq;
			if ($feature->has_tag('gene')) {
				for $val ($feature->get_tag_values('gene')){
					print TRNA ">$key\_$organism\_$val\n$seq\n";
				}
			}else{
					print ERR "Be careful! $key  This feature don't have gene tag!\n";
					print TRNA ">$key\_$organism\_NA\n$seq\n";
			}
		}
	}
}
close  GEN;
close  CDS_N;
close  CDS_P;
close  RRNA;
close  TRNA;
close  ERR;
close  TAX;
close  FA;


sub norm_key {
	my $k = shift;
	my $key;
	if ($k =~ /^NC/) {
		$key = $k;
		return $key;
	}else {
		$k =~ s/([A-Z]{1,2})/$1_/;
		return $k;
	}
}

sub norm_org {
	my $o = shift;
	my $org;
	my @aa = split /\s+/,$o;
	if (@aa == 2 ){
		$org = $o;
	}else {
		$org = $aa[0]." ".$aa[1];
	}
	return $org;
}
