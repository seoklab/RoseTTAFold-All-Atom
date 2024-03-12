#!/bin/bash -eu

# inputs
in_fasta="$1"
out_dir="$2"

# resources
CPU="$3"
MEM="$4"

DB_BFD="$5"
DB_TEMPL="$6"
DB_UR30="$7"

# Running signalP 6.0
tmp_dir="$out_dir/signalp"
mkdir -p "$tmp_dir"
signalp6 --fastafile "$in_fasta" \
	--organism other \
	--output_dir "$tmp_dir" \
	--format none \
	--mode slow
trim_fasta="$tmp_dir/processed_entries.fasta"
if [[ ! -s $trim_fasta ]]; then # empty file -- no signal P
	trim_fasta="$in_fasta"
fi

tmp_dir="$out_dir/hhblits"
mkdir -p "$tmp_dir"
out_prefix="$out_dir/t000_"

function run-hhblits() {
	hhblits -o /dev/null -mact 0.35 -maxfilt 100000000 -neffmax 20 -cov 25 \
		-cpu "$CPU" -maxmem "$MEM" -nodiff -realign_max 100000000 -maxseq 1000000 \
		-n 4 -e "$e" -v 0 "$@"
}

# perform iterative searches against UniRef30
if [[ ! -s ${out_prefix}.msa0.a3m ]]; then
	prev_a3m="$trim_fasta"
	for e in 1e-10 1e-6 1e-3; do
		echo "Running HHblits against UniRef30 with E-value cutoff $e"
		if [[ ! -s $tmp_dir/t000_.$e.a3m ]]; then
			run-hhblits -d "$DB_UR30" -i "$prev_a3m" -oa3m "$tmp_dir"/t000_.$e.a3m
		fi
		hhfilter -maxseq 100000 -id 90 -cov 75 \
			-i "$tmp_dir"/t000_.$e.a3m -o "$tmp_dir"/t000_.$e.id90cov75.a3m
		hhfilter -maxseq 100000 -id 90 -cov 50 \
			-i "$tmp_dir"/t000_.$e.a3m -o "$tmp_dir"/t000_.$e.id90cov50.a3m

		prev_a3m="$tmp_dir/t000_.$e.id90cov50.a3m"
		n75="$(grep -c "^>" "$tmp_dir"/t000_.$e.id90cov75.a3m)"
		n50="$(grep -c "^>" "$tmp_dir"/t000_.$e.id90cov50.a3m)"

		if ((n75 > 2000)); then
			if [[ ! -s ${out_prefix}.msa0.a3m ]]; then
				cp "$tmp_dir"/t000_.$e.id90cov75.a3m "${out_prefix}".msa0.a3m
				break
			fi
		elif ((n50 > 4000)); then
			if [[ ! -s ${out_prefix}.msa0.a3m ]]; then
				cp "$tmp_dir"/t000_.$e.id90cov50.a3m "${out_prefix}".msa0.a3m
				break
			fi
		else
			continue
		fi
	done

	# perform iterative searches against BFD if it failes to get enough sequences
	if [[ ! -s ${out_prefix}.msa0.a3m ]]; then
		e=1e-3
		echo "Running HHblits against BFD with E-value cutoff $e"
		if [[ ! -s $tmp_dir/t000_.$e.bfd.a3m ]]; then
			run-hhblits -d "$DB_BFD" -i "$prev_a3m" -oa3m "$tmp_dir"/t000_.$e.bfd.a3m
		fi

		hhfilter -maxseq 100000 -id 90 -cov 75 \
			-i "$tmp_dir"/t000_.$e.bfd.a3m -o "$tmp_dir"/t000_.$e.bfd.id90cov75.a3m
		hhfilter -maxseq 100000 -id 90 -cov 50 \
			-i "$tmp_dir"/t000_.$e.bfd.a3m -o "$tmp_dir"/t000_.$e.bfd.id90cov50.a3m

		prev_a3m="$tmp_dir/t000_.$e.bfd.id90cov50.a3m"
		n75="$(grep -c "^>" "$tmp_dir"/t000_.$e.bfd.id90cov75.a3m)"
		n50="$(grep -c "^>" "$tmp_dir"/t000_.$e.bfd.id90cov50.a3m)"

		if ((n75 > 2000)); then
			if [[ ! -s ${out_prefix}.msa0.a3m ]]; then
				cp "$tmp_dir"/t000_.$e.bfd.id90cov75.a3m "${out_prefix}".msa0.a3m
			fi
		elif ((n50 > 4000)); then
			if [[ ! -s ${out_prefix}.msa0.a3m ]]; then
				cp "$tmp_dir"/t000_.$e.bfd.id90cov50.a3m "${out_prefix}".msa0.a3m
			fi
		fi
	fi

	if [[ ! -s ${out_prefix}.msa0.a3m ]]; then
		cp "$prev_a3m" "${out_prefix}".msa0.a3m
	fi
fi

echo "Running PSIPRED"
make_ss.sh "$out_dir"/t000_.msa0.a3m "$out_dir"/t000_.ss2

if [[ ! -s $out_dir/t000_.hhr ]]; then
	echo "Running hhsearch"
	cat "$out_dir"/t000_.ss2 "$out_dir"/t000_.msa0.a3m \
		>"$out_dir"/t000_.msa0.ss2.a3m

	hhsearch -b 50 -B 500 -z 50 -Z 500 -mact 0.05 -cpu "$CPU" -maxmem "$MEM" \
		-aliw 100000 -e 100 -p 5.0 -d "$DB_TEMPL" \
		-i "$out_dir"/t000_.msa0.ss2.a3m \
		-o "$out_dir"/t000_.hhr \
		-atab "$out_dir"/t000_.atab -v 0
fi
