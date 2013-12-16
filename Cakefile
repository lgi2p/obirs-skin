
fs = require 'fs'
exec = require('child_process').exec

task 'genconfig', 'generate the default configuration file: config.json', (options) ->
    jsonConfig = JSON.stringify({
        port: 4001
        endpointURI: 'http://localhost:8890/sparql'
        graphURI: 'http://kalitmo.org/itcancer'
        ontologyFilePath: "#{__dirname}/data/ontologies/mesh/desc2013.xml"
        indexationFilePath: "#{__dirname}/data/indexations/kalitmo-publications.json"
        engine: 'mohameth2010'
    }, null, 4)

    fs.writeFileSync('./config.json', jsonConfig, 'utf-8')


task 'compile', 'compile the project to javascript', (options) ->
    exec 'rm -r lib', (err) ->
        exec 'coffee -cbo lib src', (err, stdout, stderr) ->
            if err
                throw err
            exec 'find lib -name *.js -exec sed "1d" {} -i \\;', (err, stdout, stderr) ->
                if err
                    throw err
    exec 'coffee -cbo public/js/lib public/js/src', (err, stdout, stderr) ->
        if err
            throw err
        exec 'find public/js/lib -name *.js -exec sed "1d" {} -i \\;', (err, stdout, stderr) ->
            if err
                throw err