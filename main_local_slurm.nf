#!/usr/bin/env nextflow

/*
 * Use echo to print 'Hello World!' to a file
 */
process sayHello {

    publishDir 'results', mode: 'copy'
    executor 'local'
    cpus 1
    memory '1 GB'

    input:
        val greeting

    output:
        path "${greeting}-output.txt"

    script:
    """
    echo '$greeting' > '$greeting-output.txt'
    """
}

/*
 * Use a text replacement tool to convert the greeting to uppercase
 */
process convertToUpper {

    publishDir 'results', mode: 'copy'
    container 'oras://ghcr.io/mkandes/ubuntu:22.04-amd64'
    executor 'slurm'
    queue 'debug'
    time '00:10:00'
    cpus 2
    memory '4 GB'
    clusterOptions '--account=sds166 --nodes=1 --ntasks=1 -o logs/%x-%j.out -e logs/%x-%j.err'
    scratch true
    beforeScript '''
      set -euo pipefail
      export SCRATCH_DIR="/scratch/$USER/job_${SLURM_JOB_ID}"
      mkdir -p "$SCRATCH_DIR/tmp"
      export TMPDIR="$SCRATCH_DIR/tmp"
      export NXF_OPTS="-Djava.io.tmpdir=$TMPDIR"
      echo "[NF] Using node-local scratch at: $SCRATCH_DIR"
    '''

    input:
        path input_file

    output:
        path "UPPER-${input_file}"

    script:
    """
    cat '$input_file' | tr '[a-z]' '[A-Z]' > 'UPPER-${input_file}'
    """
}

/*
 * Collect uppercase greetings into a single output file
 */
process collectGreetings {

    publishDir 'results', mode: 'copy'
    executor 'local'
    cpus 1
    memory '1 GB'

    input:
        path input_files
        val batch_name

    output:
        path "COLLECTED-${batch_name}-output.txt" , emit: outfile
        val count_greetings , emit: count

    script:
        count_greetings = input_files.size()
    """
    cat ${input_files} > 'COLLECTED-${batch_name}-output.txt'
    """
}

/*
 * Pipeline parameters
 */
params.greeting = 'greetings.csv'
params.batch = 'test-batch'

workflow {

    // create a channel for inputs from a CSV file
    greeting_ch = Channel.fromPath(params.greeting)
                        .splitCsv()
                        .map { line -> line[0] }

    // emit a greeting
    sayHello(greeting_ch)

    // convert the greeting to uppercase
    convertToUpper(sayHello.out)

    // collect all the greetings into one file
    collectGreetings(convertToUpper.out.collect(), params.batch)

    // emit a message about the size of the batch
    collectGreetings.out.count.view { "There were $it greetings in this batch" }

    // optional view statements
    //convertToUpper.out.view { "Before collect: $it" }
    //convertToUpper.out.collect().view { "After collect: $it" }
}
