#!/usr/bin/env nextflow
nextflow.enable.dsl = 2

/*
 * Use echo to print 'Hello World!' to a file
 */
process sayHello {

    publishDir 'results', mode: 'copy'

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

process random_decision {

    output:
        stdout decision

    script:
    """
    bash ${projectDir}/scripts/random_decision.sh
    """
}

/*
 * Pipeline parameters
 */
params.greeting = 'greetings.csv'
params.batch = 'test-batch'

workflow {

    main:
        greeting_ch = Channel.fromPath(params.greeting)
                            .splitCsv()
                            .map { line -> line[0] }

        sayHello(greeting_ch)

        // Pick the path based on an external random decision (0 ⇒ skip, 1 ⇒ uppercase)
        random_decision()
        def decision_ch = random_decision.out
                                .map { it.trim() }
                                .view { "Random branch decision: $it" }

        sayHello.out
            .combine(decision_ch)
            .view { "Greeting + decision pair: $it" }
            .set { decorated_ch }

        decorated_ch
            .filter { tuple -> tuple[1] == "0" }
            .map { tuple -> tuple[0] }
            .view { "Skipping uppercase for: $it" }
            .set { skip_uppercase_ch }

        decorated_ch
            .filter { tuple -> tuple[1] == "1" }
            .map { tuple -> tuple[0] }
            .view { "Running uppercase on: $it" }
            .set { convert_input_ch }

        def converted_ch = convertToUpper(convert_input_ch)
            .view { "Converted file produced: $it" }

        def uppercase_ch = skip_uppercase_ch.mix(converted_ch)

        collectGreetings(uppercase_ch.collect(), params.batch)

        collectGreetings.out.count.view { "There were $it greetings in this batch" }
}
