#!/bin/zsh

ARNRS=(0 1 2 3 4 5)

for i in {1..$#ARNRS}; do
    local ARNR=$ARNRS[$i];

    av1an -i "./input.mkv" \
        -v "--end-usage=q --cpu-used=3 --cq-level=21 --threads=2 --enable-cdef=0 --aq-mode=0 --enable-qm=1 --lag-in-frames=64 --arnr-strength=$ARNR --arnr-maxframes=15 --sharpness=0 --quant-sharpness=0 --disable-trellis-quant=0 --enable-fwd-kf=1 --min-q=1 --deltaq-mode=1 --bit-depth=10 --tune-content=psy --enable-chroma-deltaq=1 --tune=ssim --sb-size=dynamic --quant-b-adapt=1" \
        --set-thread-affinity=2 --scenes "./scenes.json" \
        --chunk-method lsmash --concat mkvmerge \
        -w 8 -o "./output/aom-arnr$ARNR.mkv"
done

echo "Running SSIMULACRA2..."

for i in {1..$#ARNRS}; do
    local ARNR=$ARNRS[$i];

    if [ ! -f "output-ssimu2/aom-arnr$ARNR" ]; then
        ssimulacra2_rs video "./input.mkv" "output/aom-arnr$ARNR.mkv" -f 4 | grep Mean: | cut -c 7- > "output-ssimu2/aom-arnr$ARNR"
    fi
done

echo -n "" > data.csv
echo "arnr strength,ssimu2 score,filesize (mb)" > data.csv

for i in {1..$#ARNRS}; do
    local ARNR=$ARNRS[$i];

    if [ -f "output-ssimu2/aom-arnr$ARNR" ]; then
        local filesize=$(echo $(du -s output/aom-arnr$ARNR.mkv | awk '{print $1}') / 1024 | bc -l)
        echo $ARNR,$(cat output-ssimu2/aom-arnr$ARNR),$filesize >> data.csv
    fi
done