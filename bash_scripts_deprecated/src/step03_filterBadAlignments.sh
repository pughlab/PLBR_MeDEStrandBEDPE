#!/bin/bash

#SBATCH --mail-type=ALL
#SBATCH --mail-user=ming.han@uhn.ca
#SBATCH -t 1-00:00:00
#SBATCH -D ./logs_slurm/
#SBATCH --mem=60G
#SBATCH -J step3_filterBadAlignments 
#SBATCH -p himem
#SBATCH -c 4
#SBATCH -N 1
#SBATCH -o ./%j-%x.out
#SBATCH -e ./%j-%x.err

# getopts ###################################################
usage(){
    echo 
    echo "Usage: bash step3_filterBadAlignments.sh -s SAMPLE_NAME -i INPUT_DIR -b UNFILT_BAM -o OUT_DIR -p PICARD_DIR" 
    echo 
}
no_args="true"

## Help 
Help()
{
    # Display Help
    echo 
    echo "Filtering out bad alignments (unmapped, secondary, insert size, edit distance)"
    echo
    echo "Usage: bash step3_filterBadAlignments.sh -s SAMPLE_NAME -i INPUT_DIR -b UNFILT_BAM -o OUT_DIR -p PICARD_DIR"
    echo "options:"
    echo "-h   [HELP]      print help"
    echo "-s   [REQUIRED]  short and unique sample name without file extensions"
    echo "-i   [REQUIRED]  input directory with bam (full path)"
    echo "-b   [REQUIRED]  unfiltered bam (full path)"
    echo "-o   [REQUIRED]  output directory (full path)"
    echo "-p   [REQUIRED]  full path to directory containing  picard.jar"
    echo
}

## Get the options
while getopts ":hs:i:b:o:p:" option; do
    case "${option}" in
        h) Help
           exit;;
        s) SAMPLE_NAME=${OPTARG};;
        i) INPUT_DIR=${OPTARG};;
        b) BAM_F=${OPTARG};;
        o) OUT_DIR=${OPTARG};;
        p) PICARD_DIR=${OPTARG};;
       \?) echo "Error: Invalid option"
           exit;;
    esac
    no_args="false"
done

[[ "$no_args" == "true" ]] && { usage; exit 1; }


# Main program ##############################################

echo "Processing step3_filterBadAlignments... " 
echo "Job started at "$(date) 
time1=$(date +%s)

#source /cluster/home/t110409uhn/bin/miniconda3/bin/activate wf_cfmedip_manual
#module load picard

BAM_FILT1="${SAMPLE_NAME}.filter1.bam"
MPP="${BAM_FILT1%.*}.mapped_proper_pair.txt"
BAM_FILT2="${SAMPLE_NAME}.filter2.bam"
HiMM="${BAM_FILT2%.*}.high_mismatch.txt"
BAM_FILT3="${SAMPLE_NAME}.filter3.bam"

## filter1 - remove unmapped and secondary reads
samtools view -b \
    -F 260 \
    ${INPUT_DIR}/${BAM_F} \
    -o ${OUT_DIR}/${BAM_FILT1}

## filter2 - remove reads belonging to inserts shorter than 119nt or greater than 501nt
samtools view \
    ${OUT_DIR}/${BAM_FILT1} \
    | awk 'sqrt($9*$9)>119 && sqrt($9*$9)<501' \
    | awk '{print $1}' \
    > ${OUT_DIR}/${MPP}

java -jar $PICARD_DIR/picard.jar FilterSamReads \
    I=${OUT_DIR}/${BAM_FILT1} \
    O=${OUT_DIR}/${BAM_FILT2} \
    READ_LIST_FILE=${OUT_DIR}/${MPP} \
    FILTER=includeReadList \
    WRITE_READS_FILES=false \
    USE_JDK_DEFLATER=true \
    USE_JDK_INFLATER=true

## filter3 - remove reads with edit distance > 7
samtools view \
    ${OUT_DIR}/${BAM_FILT2} \
    | awk '{read=$0;sub(/.*NM:i:/,X,$0);sub(/\t.*/,X,$0);if(int($0)>7){print read}}' \
    | awk '{print $1}' \
    > ${OUT_DIR}/${HiMM} 

java -jar $PICARD_DIR/picard.jar FilterSamReads \
    I=${OUT_DIR}/${BAM_FILT2} \
    O=${OUT_DIR}/${BAM_FILT3} \
    READ_LIST_FILe=${OUT_DIR}/${HiMM} \
    FILTER=excludeReadList \
    WRITE_READS_FILES=false \
    USE_JDK_DEFLATER=true \
    USE_JDK_INFLATER=true

echo "Finished processing filter out bad alignments."

time2=$(date +%s)
echo "Job ended at "$(date) 
echo "Job took $(((time2-time1)/3600)) hours $((((time2-time1)%3600)/60)) minutes $(((time2-time1)%60)) seconds"
echo ""

## EOF
