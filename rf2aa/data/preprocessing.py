import subprocess
from pathlib import Path

from rf2aa.paths import resolve_path


def make_msa(
    fasta_file,
    chain,
    model_runner
):
    out_dir_base = Path(model_runner.config.output_path)
    hash = model_runner.config.job_name
    out_dir = out_dir_base / hash / chain
    out_dir.mkdir(parents=True, exist_ok=True)

    command = model_runner.config.database_params.command
    num_cpus = model_runner.config.database_params.num_cpus
    ram_gb = model_runner.config.database_params.mem
    sequence_database = resolve_path(
        model_runner.config.database_params.sequencedb)
    template_database = resolve_path(model_runner.config.database_params.hhdb)
    uniclust_database = resolve_path(model_runner.config.database_params.urdb)

    out_a3m = out_dir / "t000_.msa0.a3m"
    out_atab = out_dir / "t000_.atab"
    out_hhr = out_dir / "t000_.hhr"
    if out_a3m.exists() and out_atab.exists() and out_hhr.exists():
        return out_a3m, out_hhr, out_atab

    search_command = [
        command,
        fasta_file,
        out_dir,
        str(num_cpus),
        str(ram_gb),
        sequence_database,
        template_database,
        uniclust_database,
    ]
    print(search_command)
    _ = subprocess.run(search_command, check=True)
    return out_a3m, out_hhr, out_atab
