library(SummarizedExperiment)
library(data.table)
library(GenomicRanges)
library(BSgenome.Hsapiens.UCSC.hg19)
library(tidyverse)
library(diffloop)
library(Matrix)
library(cowplot)
library(BuenColors)
"%ni%" <- Negate("%in%")

# Read in ATAC data
peaksdf <- fread("../../data/panHeme/29August2017_EJCsamples_allReads_500bp.bed")
peaks <- makeGRangesFromDataFrame(peaksdf, seqnames = "V1", start.field = "V2", end.field = "V3")
counts <-  data.matrix(fread("../../data/panHeme/29August2017_EJCsamples_allReads_500bp.counts.txt"))
cpm <- round(sweep(counts, 2, colSums(counts), FUN="/") * 1000000, 1)
log2cpm <- log2(cpm+1)
# Min / max scale
log2cpm.minmax <- log2cpm / rowMax(log2cpm)

# Exclude variants with coding consequences
coding_consequences <- c("missense_variant","synonymous_variant","frameshift_variant",
                         "splice_acceptor_variant","splice_donor_variant","splice_region_variant",
                         "inframe_insertion","stop_gained","stop_retained_variant",
                         "start_lost","stop_lost","coding_sequence_variant","incomplete_terminal_codon_variant")

# Read in merged gene / CS data
CS.df.merged <- fread("../../data/VEP/CS.ukid.ukbb_v2.VEP_merged.bed")%>%  mutate(chr = paste0("chr",chr)) %>%
  filter(Consequence %ni% coding_consequences) 
CS.gr <- GRanges(CS.df.merged)

# Find overlaps between peaks and all rare variants
idx <- findOverlaps(peaks,CS.gr)

# Construct overlap data.frame and granges with peaks, cpm, and finemap info
atac_overlap <- data.frame(
  CS.df.merged[idx@to,c("UKID","trait","PP","gene","BRIDGE")],
  log2cpm[idx@from,]
) 
atac_overlap_long <- atac_overlap %>% pivot_longer(.,cols = -c("UKID","trait","PP","gene","BRIDGE"),names_to="celltype",values_to = "log2cpm")

# Gene vs. no gene
bridge_rare <- CS.df.merged %>% filter(UKID %in% atac_overlap$UKID, gene != "") %>% .$UKID %>% unique() %>% length()
nobridge_rare <- CS.df.merged %>% filter(UKID %in% atac_overlap$UKID,gene == "") %>% .$UKID %>% unique() %>% length()
bridge_norare <- CS.df.merged %>% filter(gene != "",UKID %ni% atac_overlap$UKID) %>% .$UKID %>% unique() %>% length()
nobridge_norare <- CS.df.merged %>% filter(gene == "",UKID %ni% atac_overlap$UKID)  %>% .$UKID %>% unique() %>% length()

counts <- c("br"=bridge_rare,"no_b_r"=nobridge_rare,"b_no_r"=bridge_norare,"no_b_no_r"=nobridge_norare)
counts
fisher.test(matrix(counts, nrow = 2))
