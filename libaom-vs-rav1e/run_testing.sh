#!/bin/zsh

qualities=(10 15 17 19 20 23 25 27 29 31 33 35 37 40 42 45 48 50 52 55 58 60)
aom_workers=15
rav1e_workers=12

make_directories() {
    mkdir -p "./.working/samples"
    mkdir "./.working/ssimulacra2_scores"
    mkdir "./.working/av1an-temp"
    echo "Creating scenes.json"
    av1an --min-scene-len 14 --extra-split 240 --sc-only --scenes "./.working/scenes.json" --temp "./.working/av1an-temp/scene_detection" -i input.mkv &>/dev/null
}

create_directories() {

    if [ -s "./input.mkv.lwi" ]; then rm "./input.mkv.lwi"; fi

    if [ -d "./.working" ]; then
        echo "Found a work in progress test. Do you want to continue? [y/n]" 
        read answer
        case $answer in
            [Yy]* ) echo "Resuming old test...";;
            [Nn]* )
                echo "Removing old test..."
                rm -rf "./.working"
                make_directories
                echo "Starting new test..."
            ;;
        esac
    else
        make_directories
    fi
}

encode_samples() {
    local progress=0

    for i in {1..$#qualities}; do
        local Q=$qualities[$i];

        echo -ne "Encoding samples... ($progress/$(($#qualities * 2)) done)\r"

        if [ ! -s "./.working/samples/aom-q$Q.mkv" ]; then
            av1an -i "./input.mkv" \
                -v "--end-usage=q --cpu-used=3 --cq-level=$Q --threads=2 --enable-cdef=0 --aq-mode=0 --enable-qm=1 --lag-in-frames=64 --arnr-strength=1 --arnr-maxframes=15 --sharpness=0 --quant-sharpness=0 --disable-trellis-quant=0 --enable-fwd-kf=1 --min-q=1 --deltaq-mode=1 --bit-depth=10 --tune-content=psy --enable-chroma-deltaq=1 --tune=ssim --sb-size=dynamic --quant-b-adapt=1" \
                --set-thread-affinity=2 --scenes "./.working/scenes.json" --temp "./.working/av1an-temp/aom-q$Q" \
                --chunk-method lsmash --concat mkvmerge \
                -w $aom_workers -o "./.working/samples/aom-q$Q.mkv" &>/dev/null
        fi

        progress=$(($progress + 1))
        echo -ne "Encoding samples... ($progress/$(($#qualities * 2)) done)\r"

        if [ ! -s "./.working/samples/rav1e-q$Q.mkv" ]; then
            av1an -i "./input.mkv" \
                -e rav1e -v "--speed 2 --threads 2 --quantizer $(($Q * 4)) --keyint 0 --no-scene-detection" \
                --set-thread-affinity=2 --scenes "./.working/scenes.json" --temp "./.working/av1an-temp/rav1e-q$Q" \
                --chunk-method lsmash --concat mkvmerge \
                -w $rav1e_workers -o "./.working/samples/rav1e-q$Q.mkv" &>/dev/null
        fi

        progress=$(($progress + 1))
    done

    echo -ne "Encoding samples... ($progress/$(($#qualities * 2)) done)\r"
    echo -ne '\n'
}

ssimulacra2() {
    local progress=0

    echo -ne "Running SSIMULACRA2... ($progress/$(($#qualities * 2)) done)\r"

    for i in {1..$#qualities}; do
        local Q=$qualities[$i];

        echo -ne "Running SSIMULACRA2... ($progress/$(($#qualities * 2)) done)\r"

        if [ ! -s "./.working/ssimulacra2_scores/aom-q$Q" ] ; then
            ssimulacra2_rs video "./input.mkv" "./.working/samples/aom-q$Q.mkv" -f 4 2> /dev/null | grep "Mean:" | cut -c 7- > "./.working/ssimulacra2_scores/aom-q$Q"
        fi

        progress=$(($progress + 1))
        echo -ne "Running SSIMULACRA2... ($progress/$(($#qualities * 2)) done)\r"

        if [ ! -s "./.working/ssimulacra2_scores/rav1e-q$Q" ]; then
            ssimulacra2_rs video "./input.mkv" "./.working/samples/rav1e-q$Q.mkv" -f 4 2> /dev/null | grep "Mean:" | cut -c 7- > "./.working/ssimulacra2_scores/rav1e-q$Q"
        fi

        progress=$(($progress + 1))
    done

    echo -ne "Running SSIMULACRA2... ($progress/$(($#qualities * 2)) done)\r"
    echo -ne '\n'
}

generate_csv() {
    echo "Writing data to CSV file..."
    echo -n "" > data.csv
    echo "encoder,quality,SSIMULACRA2 Mean,bitrate" >> data.csv

    for i in {1..$#qualities}; do
        local Q=$qualities[$i];

        if [ -f "./.working/ssimulacra2_scores/aom-q$Q" ]; then
            echo -n "aom,$Q," >> data.csv
            echo -n "$(cat ././.working/ssimulacra2_scores/aom-q$Q)," >> data.csv
            echo "$(mediainfo --Output="Video;%BitRate%" ./.working/samples/aom-q$Q.mkv) / 1000000" | bc -l >> data.csv
        fi
    done

    for i in {1..$#qualities}; do
        local Q=$qualities[$i];

        if [ -f "./.working/ssimulacra2_scores/rav1e-q$Q" ]; then
            echo -n "rav1e,$Q," >> data.csv
            echo -n "$(cat ././.working/ssimulacra2_scores/rav1e-q$Q)," >> data.csv
            echo "$(mediainfo --Output="Video;%BitRate%" ./.working/samples/rav1e-q$Q.mkv) / 1000000" | bc -l >> data.csv
        fi
    done

    echo "Everything is done."
}

create_directories
encode_samples
ssimulacra2
generate_csv