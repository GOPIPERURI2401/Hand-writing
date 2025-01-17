#!/bin/bash
set -e

export LC_ALL=en_US.UTF-8

HERE=$(dirname "$0")
export PATH=$HERE:$PATH

[ $# -ne 4 ] && {
    echo "Usage: ${0##*/} <arpaLM> <langDir> <testDir> <Dummy-symb>" >&2;
    exit 1;
}

lm="$1"
langd="$2"
testd="$3"
DUMMY="$4"

rm -rf ${testd}; mkdir ${testd}
#for f in phones.txt words.txt L.fst L_disambig.fst phones; do
for f in phones.txt words.txt L_disambig.fst phones; do
    cp -r ${langd}/${f} ${testd}/${f}
done

cat ${lm} | find_arpa_oovs.pl ${testd}/words.txt > ${testd}/oovs_${lm##*/}.txt

# The grep commands remove certain "invalid" n-grams from the 
# language model, which should not have been there in the first 
# place. The program remove_oovs.pl removes N-grams containing 
# words not in our vocabulary (which would cause a crash in 
# fstcompile); eps2disambig.pl turns the <eps> ($\epsilon$) 
# symbols on backoff arcs into a special symbol #0 which we use 
# to make the grammar determinizable.
#cat ${lm} | \
#    grep -v '<s> <s>' | grep -v '</s> <s>' | grep -v '</s> </s>' | \
#    arpa2fst - | \
#    fstprint | \
#    remove_oovs.pl ${testd}/oovs_${lm##*/}.txt | \
#    eps2disambig.pl | \
#    awk -v dm=$DUMMY '
#         { if (NF>=4) {if ($3=="<s>") $3="<eps>"; if ($4=="<s>") $4="<eps>";
#                       if ($3=="</s>") $3=dm; if ($4=="</s>") $4="<eps>"; }
#           print }' | \
#    fstcompile \
#    --isymbols=${testd}/words.txt \
#    --osymbols=${testd}/words.txt \
#    --keep_isymbols=false \
#    --keep_osymbols=false | \
#    fstrmepsilon | \
#    fstarcsort --sort_type=ilabel > ${testd}/G.fst

cat ${lm} | \
    grep -v '<s> <s>' | grep -v '</s> <s>' | grep -v '</s> </s>' | \
    arpa2fst - | \
    fstprint | \
    remove_oovs.pl ${testd}/oovs_${lm##*/}.txt | \
    eps2disambig.pl | \
    awk -v dm=$DUMMY '{
        if (NF>=4) {
            N=$1;
            if ($3=="<s>") $3="<eps>";
            if ($4=="<s>") $4="<eps>";
            if ($3=="</s>") {
                $3=dm; 
                $4="<eps>";
                F=$2;
                $2="BIYO";
                $5=$5-log(2); 
                $0=$0"\n"$1" "F" <eps> <eps> "$5
            }
        } 
        W[NR]=$0
        }END{
            for (i in W){
                print gensub(/BIYO/,N+1,"g",W[i])
            } 
            print N+1" "F" <eps> <eps> 0"
        }' | \
    fstcompile \
    --isymbols=${testd}/words.txt \
    --osymbols=${testd}/words.txt \
    --keep_isymbols=false \
    --keep_osymbols=false | \
    fstrmepsilon | \
    fstarcsort --sort_type=ilabel > ${testd}/G.fst

#awk -v dm="<dummy>" '{if (NF>=4) {N=$1;if ($3=="<s>") $3="<eps>"; if ($4=="<s>") $4="<eps>"; if ($3=="</s>") {$3=dm; $4="<eps>";F=$2;$2="BIYO";$5=$5-log(2); $0=$0"\n"$1" "F" <eps> <eps> "$5};} W[NR]=$0}END{for (i in W){print gensub(/BIYO/,N+1,"g",W[i])} print N+1" "F" <eps> <eps> 0"}'
echo
set +e
fstisstochastic ${testd}/G.fst || echo "[info]: G not stochastic." 1>&2
set -e
echo "# We do expect the first of these 2 numbers to be close to zero (the second is"
echo "# nonzero because the backoff weights make the states sum to >1)."
# The output is like:
# 9.14233e-05 -0.259833
# we do expect the first of these 2 numbers to be close to zero (the second is
# nonzero because the backoff weights make the states sum to >1).

exit 0
